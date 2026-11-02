import 'dart:convert';

import 'package:fede_apps_core/fede_apps_core.dart' show DeviceIdentity, SyncFields;
import 'package:flutter_test/flutter_test.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/models/playlist_model.dart';
import 'package:metronomo_standalone/models/session_model.dart';
import 'package:metronomo_standalone/providers/pattern_editor_provider.dart';
import 'package:metronomo_standalone/providers/playlist_provider.dart';
import 'package:metronomo_standalone/providers/session_provider.dart';
import 'package:metronomo_standalone/services/deep_link_service.dart';
import 'package:metronomo_standalone/services/share_import_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _created = '2025-01-01T10:00:00.000';

Map<String, dynamic> _oldPatternJson(String id) => {
      'id': id,
      'name': 'Pat $id',
      'description': '',
      'structure': '3',
      'pulses': [
        {'subdivisions': [1, 0], 'durationRatio': 1.0},
      ],
      'colorHex': '#F98533',
      'tags': <String>[],
      'createdAt': _created,
      'updatedAt': _created,
    };

/// Session in the legacy format (patterns only referenced by id).
Map<String, dynamic> _oldSessionJson(String id, {List<String> patternIds = const []}) => {
      'id': id,
      'name': 'Ses $id',
      'description': '',
      'globalBpm': 100,
      'patternsConfig': [
        for (var i = 0; i < patternIds.length; i++)
          {'patternId': patternIds[i], 'volume': 0.8, 'isMuted': false, 'isSolo': false, 'orderIndex': i},
      ],
      'soundSet': 'Default',
      'randomSilencePercentage': 0.0,
      'isTrainingEnabled': false,
      'trainingConfig': {'startBpm': 60, 'endBpm': 120, 'bpmIncrement': 5, 'intervalSeconds': 60},
      'createdAt': _created,
      'updatedAt': _created,
    };

Map<String, dynamic> _oldPlaylistJson(String id, List<String> sessionIds) => {
      'id': id,
      'name': 'Lista $id',
      'description': '',
      'sessionIds': sessionIds,
      'createdAt': _created,
      'updatedAt': _created,
    };

Session _session(String id, {String? name, int rev = 1}) => Session(
      id: id,
      name: name ?? id,
      globalBpm: 90,
      patternsConfig: [
        SessionPatternConfig(patternId: 'p-$id').embedding(Pattern(id: 'x', name: 'P', structure: '4')),
      ],
      rev: rev,
    );

/// Raw JSON list stored under [key].
Future<List<dynamic>> _stored(String key) async =>
    json.decode((await SharedPreferences.getInstance()).getString(key)!) as List<dynamic>;

Future<(PatternEditorProvider, SessionProvider, PlaylistProvider)> _loadAll() async {
  final patterns = PatternEditorProvider();
  final sessions = SessionProvider();
  final playlists = PlaylistProvider();
  // Same wiring as main.dart: playlists migrate after sessions/patterns load.
  final playlistsLoad = playlists.loadPlaylists(resolveSession: (id) async {
    await sessions.ensureLoaded;
    await patterns.ensureLoaded;
    return sessions.getSessionById(id)?.withEmbeddedPatterns(patterns.getPatternById);
  });
  await patterns.loadPatterns();
  await sessions.loadSessions();
  await playlistsLoad;
  return (patterns, sessions, playlists);
}

void main() {
  setUp(() async {
    DeviceIdentity.debugReset();
    SharedPreferences.setMockInitialValues({});
  });

  group('old JSON → sync fields', () {
    test('Pattern: rev 1, not deleted, existing keys unchanged', () {
      final old = _oldPatternJson('a');
      final p = Pattern.fromJson(old);
      expect(p.rev, 1);
      expect(p.deleted, isFalse);
      expect(p.deletedAt, isNull);
      expect(p.device, isNull);
      final out = p.toJson();
      for (final k in old.keys) {
        expect(out[k], old[k], reason: k);
      }
      expect(out[SyncFields.rev], 1);
      expect(out.containsKey(SyncFields.deleted), isFalse);
    });

    test('Session: rev 1, not deleted, existing keys unchanged', () {
      final old = _oldSessionJson('s', patternIds: ['a']);
      final s = Session.fromJson(old);
      expect(s.rev, 1);
      expect(s.deleted, isFalse);
      final out = s.toJson();
      for (final k in ['id', 'name', 'globalBpm', 'soundSet', 'createdAt', 'updatedAt']) {
        expect(out[k], old[k], reason: k);
      }
      expect(out[SyncFields.rev], 1);
    });

    test('Playlist: rev 1, legacy sessionIds kept until migrated', () {
      final pl = Playlist.fromJson(_oldPlaylistJson('pl', ['s1', 's2']));
      expect(pl.rev, 1);
      expect(pl.deleted, isFalse);
      expect(pl.items, isEmpty);
      expect(pl.needsMigration, isTrue);
      expect(pl.toJson()['sessionIds'], ['s1', 's2']);
    });

    test('sync fields round-trip', () {
      final deletedAt = DateTime(2026, 1, 2, 3, 4);
      final p = Pattern(id: 'a', name: 'A', rev: 7, deleted: true, deletedAt: deletedAt, device: 'dev1');
      final back = Pattern.fromJson(p.toJson());
      expect(back.rev, 7);
      expect(back.deleted, isTrue);
      expect(back.deletedAt, deletedAt);
      expect(back.device, 'dev1');
    });
  });

  group('rev bumps', () {
    test('create = 1, edits +1, device and updatedAt set', () async {
      final deviceId = await DeviceIdentity.ensure();
      final p = PatternEditorProvider();
      await p.loadPatterns();
      await p.addPattern(Pattern(id: 'x', name: 'X', rev: 5)); // incoming rev is ignored
      expect(p.getPatternById('x')!.rev, 1);
      expect(p.getPatternById('x')!.device, deviceId);

      final before = p.getPatternById('x')!.updatedAt;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await p.updatePattern(p.getPatternById('x')!.copyWith(name: 'Renamed'));
      expect(p.getPatternById('x')!.rev, 2);
      expect(p.getPatternById('x')!.updatedAt.isAfter(before), isTrue);

      // Stale copy (e.g. undo of an overwrite) still bumps from the stored rev.
      await p.updatePattern(Pattern(id: 'x', name: 'Old', rev: 1));
      expect(p.getPatternById('x')!.rev, 3);

      final reloaded = PatternEditorProvider();
      await reloaded.loadPatterns();
      expect(reloaded.getPatternById('x')!.rev, 3);
      expect(reloaded.getPatternById('x')!.device, deviceId);
    });

    test('duplicate session = new id with rev 1', () async {
      final s = SessionProvider();
      await s.loadSessions();
      await s.addSession(_session('orig'));
      await s.updateSession(s.getSessionById('orig')!.copyWith(name: 'v2'));
      await s.updateSession(s.getSessionById('orig')!.copyWith(name: 'v3'));
      expect(s.getSessionById('orig')!.rev, 3);

      await s.addSession(s.getSessionById('orig')!.copyWith(id: 'copy', name: 'Copia'));
      expect(s.getSessionById('copy')!.rev, 1);
      expect(s.getSessionById('orig')!.rev, 3);
    });

    test('playlist edits (add/remove/reorder/rename) bump rev', () async {
      final p = PlaylistProvider();
      await p.loadPlaylists();
      await p.addPlaylist(Playlist(id: 'pl', name: 'L'));
      int rev() => p.getPlaylistById('pl')!.rev;
      expect(rev(), 1);
      await p.addSessionToPlaylist('pl', _session('a'));
      await p.addSessionToPlaylist('pl', _session('b'));
      expect(rev(), 3);
      await p.reorderItemsInPlaylist('pl', 0, 2);
      expect(p.getPlaylistById('pl')!.items.map((i) => i.session.name), ['b', 'a']);
      expect(rev(), 4);
      await p.removeItemFromPlaylist('pl', 0);
      expect(rev(), 5);
      await p.updatePlaylist(p.getPlaylistById('pl')!.copyWith(name: 'Otro'));
      expect(rev(), 6);
    });
  });

  group('tombstones', () {
    test('deleted items are hidden everywhere but kept as tombstones', () async {
      final p = PatternEditorProvider();
      await p.loadPatterns();
      await p.addPattern(Pattern(id: 'x', name: 'X'));
      await p.deletePattern('x');

      expect(p.patterns.any((e) => e.id == 'x'), isFalse);
      expect(p.getPatternById('x'), isNull);
      final tomb = p.allPatterns.singleWhere((e) => e.id == 'x');
      expect(tomb.deleted, isTrue);
      expect(tomb.deletedAt, isNotNull);
      expect(tomb.rev, 2);

      final reloaded = PatternEditorProvider();
      await reloaded.loadPatterns();
      expect(reloaded.getPatternById('x'), isNull);
      expect(reloaded.allPatterns.any((e) => e.id == 'x' && e.deleted), isTrue);
    });

    test('sessions and playlists: delete = tombstone, undo revives (rev +1)', () async {
      final s = SessionProvider();
      await s.loadSessions();
      await s.addSession(_session('a'));
      final removed = await s.deleteSession('a');
      expect(s.sessions.any((e) => e.id == 'a'), isFalse);
      expect(s.allSessions.singleWhere((e) => e.id == 'a').rev, 2);
      await s.restoreSession(removed!.$1, removed.$2);
      expect(s.getSessionById('a')!.rev, 3);
      expect(s.getSessionById('a')!.deleted, isFalse);

      final p = PlaylistProvider();
      await p.loadPlaylists();
      await p.addPlaylist(Playlist(id: 'pl', name: 'L'));
      await p.deletePlaylist('pl');
      expect(p.playlists, isEmpty);
      expect(p.allPlaylists.single.deleted, isTrue);
    });

    test('re-adding a deleted id revives the tombstone (no duplicate ids)', () async {
      final p = PatternEditorProvider();
      await p.loadPatterns();
      await p.addPattern(Pattern(id: 'x', name: 'X'));
      await p.deletePattern('x');
      await p.upsertPattern(Pattern(id: 'x', name: 'X again'));
      expect(p.allPatterns.where((e) => e.id == 'x').length, 1);
      expect(p.getPatternById('x')!.name, 'X again');
      expect(p.getPatternById('x')!.rev, 3);
    });

    test('all-deleted library is not re-seeded with defaults', () async {
      final p = PatternEditorProvider();
      await p.loadPatterns();
      for (final pat in List.of(p.patterns)) {
        await p.deletePattern(pat.id);
      }
      final reloaded = PatternEditorProvider();
      await reloaded.loadPatterns();
      expect(reloaded.patterns, isEmpty);
    });

    test('tombstones older than 30 days are purged on load (and persisted)', () async {
      final now = DateTime.now();
      final old = Pattern(
          id: 'old', name: 'Old', rev: 2, deleted: true,
          deletedAt: now.subtract(SyncFields.tombstoneRetention + const Duration(days: 1)));
      final recent = Pattern(
          id: 'recent', name: 'Recent', rev: 2, deleted: true,
          deletedAt: now.subtract(const Duration(days: 5)));
      final alive = Pattern(id: 'alive', name: 'Alive');
      SharedPreferences.setMockInitialValues({
        'pattern_library': json.encode([old.toJson(), recent.toJson(), alive.toJson()]),
      });
  
      final p = PatternEditorProvider();
      await p.loadPatterns();
      expect(p.allPatterns.map((e) => e.id), ['recent', 'alive']);
      expect(p.patterns.map((e) => e.id), ['alive']);
      expect((await _stored('pattern_library')).map((e) => e['id']), ['recent', 'alive']);
    });
  });

  group('self-contained playlists', () {
    test('migration from sessionIds embeds sessions (skips missing ids)', () async {
      SharedPreferences.setMockInitialValues({
        'pattern_library': json.encode([_oldPatternJson('pa')]),
        'session_library': json.encode([_oldSessionJson('s1', patternIds: ['pa'])]),
        'playlist_library': json.encode([_oldPlaylistJson('pl', ['s1', 'missing', 's1'])]),
      });
  
      final (_, sessions, playlists) = await _loadAll();
      final pl = playlists.getPlaylistById('pl')!;
      expect(pl.needsMigration, isFalse);
      expect(pl.rev, 2);
      expect(pl.items.length, 2);
      expect(pl.items[0].id, isNot(pl.items[1].id));
      for (final item in pl.items) {
        expect(item.sourceSessionId, 's1');
        expect(item.session.id, isNot('s1')); // own id, not a library item
        expect(item.session.name, 'Ses s1');
        expect(item.session.patternsConfig.single.hasEmbeddedPattern, isTrue);
        expect(item.session.patternsConfig.single.structure, '3');
      }
      // The library session is untouched.
      expect(sessions.getSessionById('s1'), isNotNull);

      // Persisted in the new format, without sync fields in embedded sessions.
      final stored = (await _stored('playlist_library')).single as Map<String, dynamic>;
      expect(stored.containsKey('sessionIds'), isFalse);
      expect((stored['items'] as List).length, 2);
      final embedded = (stored['items'] as List).first['session'] as Map<String, dynamic>;
      expect(embedded.containsKey(SyncFields.rev), isFalse);

      // Second load: nothing to migrate, same items, no extra rev.
      final (_, _, again) = await _loadAll();
      final pl2 = again.getPlaylistById('pl')!;
      expect(pl2.rev, 2);
      expect(pl2.items.map((i) => i.id), pl.items.map((i) => i.id));
    });

    test('loading without a resolver keeps legacy references on disk', () async {
      SharedPreferences.setMockInitialValues({
        'playlist_library': json.encode([_oldPlaylistJson('pl', ['s1'])]),
      });
        final p = PlaylistProvider();
      await p.loadPlaylists();
      await p.updatePlaylist(p.getPlaylistById('pl')!.copyWith(name: 'Renamed'));
      final stored = (await _stored('playlist_library')).single as Map<String, dynamic>;
      expect(stored['sessionIds'], ['s1']);
    });

    test('deleting or editing a library session leaves playlists intact', () async {
      final (patterns, sessions, playlists) = await _loadAll();
      await sessions.addSession(_session('lib', name: 'Original'));
      await playlists.addPlaylist(Playlist(id: 'pl', name: 'L'));
      await playlists.addSessionToPlaylist(
          'pl', sessions.getSessionById('lib')!.withEmbeddedPatterns(patterns.getPatternById));
      final revBefore = playlists.getPlaylistById('pl')!.rev;

      await sessions.updateSession(sessions.getSessionById('lib')!.copyWith(name: 'Edited'));
      await sessions.deleteSession('lib');

      final pl = playlists.getPlaylistById('pl')!;
      expect(pl.rev, revBefore);
      expect(pl.items.single.session.name, 'Original');
      expect(pl.items.single.sourceSessionId, 'lib');

      final (_, _, reloaded) = await _loadAll();
      expect(reloaded.getPlaylistById('pl')!.items.single.session.name, 'Original');
    });

    test('the same session can appear twice in a playlist', () async {
      final p = PlaylistProvider();
      await p.loadPlaylists();
      await p.addPlaylist(Playlist(id: 'pl', name: 'L'));
      final s = _session('a');
      await p.addSessionToPlaylist('pl', s);
      await p.addSessionToPlaylist('pl', s);
      final items = p.getPlaylistById('pl')!.items;
      expect(items.length, 2);
      expect(items[0].id, isNot(items[1].id));
      expect(items[0].session.id, isNot(items[1].session.id));
      expect(items.every((i) => i.sourceSessionId == 'a'), isTrue);
    });

    test('updating an embedded session only changes the playlist', () async {
      final (_, sessions, playlists) = await _loadAll();
      await sessions.addSession(_session('lib', name: 'Original'));
      await playlists.addPlaylist(Playlist(id: 'pl', name: 'L'));
      await playlists.addSessionToPlaylist('pl', sessions.getSessionById('lib')!);
      final item = playlists.getPlaylistById('pl')!.items.single;
      final rev = playlists.getPlaylistById('pl')!.rev;

      await playlists.updateItemSession('pl', item.id, item.session.copyWith(globalBpm: 150));
      final updated = playlists.getPlaylistById('pl')!;
      expect(updated.rev, rev + 1);
      expect(updated.items.single.session.globalBpm, 150);
      expect(updated.items.single.session.id, item.session.id);
      expect(sessions.getSessionById('lib')!.globalBpm, 90);
    });
  });

  group('shared playlists', () {
    Future<(SessionProvider, PlaylistProvider, ShareImportService)> setup() async {
      final (patterns, sessions, playlists) = await _loadAll();
      return (
        sessions,
        playlists,
        ShareImportService(patterns: patterns, sessions: sessions, playlists: playlists),
      );
    }

    test('legacy payload (sessionIds + sessions list) becomes embedded items', () async {
      final (sessions, playlists, service) = await setup();
      final libraryBefore = sessions.sessions.length;
      final bundle = SharedBundle(
        shareId: 'old-share',
        type: SharedType.playlist,
        name: 'Remota',
        data: _oldPlaylistJson('remote-pl', ['rs1', 'gone', 'rs1']),
        sessions: [_oldSessionJson('rs1', patternIds: ['rp'])],
        patterns: [_oldPatternJson('rp')],
      );
      final result = await service.import(bundle);
      expect(result.sessionCount, 2);
      expect(sessions.sessions.length, libraryBefore); // library untouched

      final pl = playlists.getPlaylistById(result.localId)!;
      expect(pl.items.length, 2);
      expect(pl.items.first.session.patternsConfig.single.hasEmbeddedPattern, isTrue);

      final again = await service.import(bundle);
      expect(again.alreadyInLibrary, isTrue);
    });

    test('current payload (items) imports self-contained', () async {
      final (sessions, playlists, service) = await setup();
      final remote = Playlist(id: 'remote-pl', name: 'Remota', items: [
        PlaylistItem.fromLibrary(_session('a', name: 'A')),
        PlaylistItem.fromLibrary(_session('a', name: 'A')),
      ]);
      final libraryBefore = sessions.sessions.length;
      final result = await service.import(SharedBundle(
        shareId: 'new-share',
        type: SharedType.playlist,
        name: 'Remota',
        data: remote.toJson()..['sessionIds'] = [for (final s in remote.sessions) s.id],
        sessions: [for (final s in remote.sessions) s.toJson()],
      ));
      expect(sessions.sessions.length, libraryBefore);
      final pl = playlists.getPlaylistById(result.localId)!;
      expect(pl.items.length, 2);
      expect(pl.items.map((i) => i.session.name), ['A', 'A']);
      expect(pl.items[0].id, isNot(pl.items[1].id));
      expect(pl.rev, 1);
    });
  });
}
