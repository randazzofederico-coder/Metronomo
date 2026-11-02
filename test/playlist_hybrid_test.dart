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

Session _session(String id, {String? name, int bpm = 90}) => Session(
      id: id,
      name: name ?? id,
      globalBpm: bpm,
      patternsConfig: [
        SessionPatternConfig(patternId: 'p-$id').embedding(Pattern(id: 'x', name: 'P', structure: '4')),
      ],
    );

/// Same wiring as main.dart.
Future<(PatternEditorProvider, SessionProvider, PlaylistProvider)> _loadAll() async {
  final patterns = PatternEditorProvider();
  final sessions = SessionProvider();
  final playlists = PlaylistProvider()..attachLibrary(sessions: sessions, patterns: patterns);
  final playlistsLoad = playlists.loadPlaylists();
  await patterns.loadPatterns();
  await sessions.loadSessions();
  await playlistsLoad;
  return (patterns, sessions, playlists);
}

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  setUp(() async {
    DeviceIdentity.debugReset();
    SharedPreferences.setMockInitialValues({});
  });

  group('hybrid playlists', () {
    Future<(SessionProvider, PlaylistProvider)> setupWithItem() async {
      final (_, sessions, playlists) = await _loadAll();
      await sessions.addSession(_session('lib', name: 'Original'));
      await playlists.addPlaylist(Playlist(id: 'pl', name: 'L'));
      await playlists.addSessionToPlaylist('pl', sessions.getSessionById('lib')!);
      return (sessions, playlists);
    }

    test('editing the library session is reflected in the playlist (no playlist rev)', () async {
      final (sessions, playlists) = await setupWithItem();
      final before = playlists.getPlaylistById('pl')!;

      await sessions.updateSession(sessions.getSessionById('lib')!.copyWith(name: 'Edited', globalBpm: 140));

      final pl = playlists.getPlaylistById('pl')!;
      expect(pl.rev, before.rev); // no sync churn on library edits
      final item = pl.items.single;
      expect(item.sourceSessionId, 'lib');
      expect(playlists.isInLibrary(item), isTrue);
      expect(playlists.resolveSession(item).name, 'Edited');
      expect(playlists.resolveSession(item).globalBpm, 140);
      expect(playlists.resolvedSessions(pl).map((s) => s.name), ['Edited']);
      expect(item.session.name, 'Original'); // snapshot not refreshed on edits
    });

    test('mutating the playlist refreshes snapshots opportunistically', () async {
      final (sessions, playlists) = await setupWithItem();
      await sessions.updateSession(sessions.getSessionById('lib')!.copyWith(name: 'Edited'));
      final snapshotId = playlists.getPlaylistById('pl')!.items.single.session.id;

      await playlists.updatePlaylist(playlists.getPlaylistById('pl')!.copyWith(name: 'Renamed'));
      final item = playlists.getPlaylistById('pl')!.items.single;
      expect(item.session.name, 'Edited');
      expect(item.session.id, snapshotId); // snapshot keeps its own id
    });

    test('deleting the library session: playlist keeps playing the latest snapshot', () async {
      final (sessions, playlists) = await setupWithItem();
      await sessions.updateSession(sessions.getSessionById('lib')!.copyWith(name: 'Edited', globalBpm: 150));
      final before = playlists.getPlaylistById('pl')!;
      await _tick();

      final removed = await sessions.deleteSession('lib');

      final pl = playlists.getPlaylistById('pl')!;
      expect(pl.rev, before.rev + 1); // snapshot refreshed once
      expect(pl.updatedAt, before.updatedAt); // nothing visible changed
      final item = pl.items.single;
      expect(playlists.isInLibrary(item), isFalse); // → "No está en la biblioteca"
      expect(item.session.name, 'Edited');
      expect(playlists.resolveSession(item).globalBpm, 150);
      expect(item.session.id, isNot('lib'));

      // Persisted.
      final (_, _, reloaded) = await _loadAll();
      expect(reloaded.getPlaylistById('pl')!.items.single.session.name, 'Edited');

      // Undo of the library delete: linked again.
      await sessions.restoreSession(removed!.$1, removed.$2);
      expect(playlists.isInLibrary(playlists.getPlaylistById('pl')!.items.single), isTrue);
    });

    test('"Restaurar en la biblioteca" revives the same id (tombstone) with the snapshot', () async {
      final (sessions, playlists) = await setupWithItem();
      await sessions.addSession(_session('other'));
      final createdAt = sessions.getSessionById('lib')!.createdAt;
      await sessions.deleteSession('lib');
      final tombRev = sessions.allSessions.singleWhere((s) => s.id == 'lib').rev;
      final item = playlists.getPlaylistById('pl')!.items.single;

      final restored = await sessions.restoreFromSnapshot(item.session, id: item.sourceSessionId!);
      expect(restored.id, 'lib');
      expect(restored.rev, tombRev + 1);
      expect(restored.name, 'Original');
      expect(restored.createdAt, createdAt);
      expect(sessions.allSessions.where((s) => s.id == 'lib').length, 1);
      expect(sessions.sessions.map((s) => s.id).toList().indexOf('lib'),
          lessThan(sessions.sessions.map((s) => s.id).toList().indexOf('other')));
      expect(playlists.isInLibrary(playlists.getPlaylistById('pl')!.items.single), isTrue);

      // Restoring again is a no-op.
      final again = await sessions.restoreFromSnapshot(item.session, id: 'lib');
      expect(again.rev, restored.rev);
    });

    test('"Restaurar en la biblioteca" without tombstone creates the same id; unlinked items get linked', () async {
      final (_, sessions, playlists) = await _loadAll();
      final snapshot = _session('snap', name: 'Snap').asEmbeddedCopy(id: 'snap-copy');
      await playlists.addPlaylist(Playlist(id: 'pl', name: 'L', items: [
        PlaylistItem(id: 'i1', sourceSessionId: 'gone', session: snapshot),
        PlaylistItem(id: 'i2', session: snapshot.asEmbeddedCopy(id: 'unlinked')),
      ]));

      final a = await sessions.restoreFromSnapshot(snapshot, id: 'gone');
      expect(a.id, 'gone');
      expect(a.rev, 1);
      expect(a.updatedAt, snapshot.updatedAt);

      // Unlinked item (e.g. imported before the hybrid model).
      final i2 = playlists.getPlaylistById('pl')!.items[1];
      expect(playlists.isInLibrary(i2), isFalse);
      await sessions.restoreFromSnapshot(i2.session, id: i2.session.id);
      await playlists.linkItemToLibrary('pl', 'i2', i2.session.id);
      final items = playlists.getPlaylistById('pl')!.items;
      expect(items.every(playlists.isInLibrary), isTrue);
      expect(items[1].sourceSessionId, 'unlinked');
    });

    test('phase-3 items (link + own snapshot id) need no migration; re-load is idempotent', () async {
      final lib = _session('s1', name: 'Library');
      final pl = Playlist(id: 'pl', name: 'L', items: [
        PlaylistItem(id: 'i1', sourceSessionId: 's1', session: lib.asEmbeddedCopy(id: 'emb-1')),
      ], rev: 4);
      SharedPreferences.setMockInitialValues({
        'session_library': json.encode([lib.toJson()]),
        'playlist_library': json.encode([pl.toJson()]),
      });
      final (_, sessions, playlists) = await _loadAll();
      expect(playlists.getPlaylistById('pl')!.rev, 4);
      await sessions.updateSession(sessions.getSessionById('s1')!.copyWith(name: 'Edited'));
      final item = playlists.getPlaylistById('pl')!.items.single;
      expect(item.session.id, 'emb-1');
      expect(playlists.resolveSession(item).name, 'Edited');

      final (_, _, again) = await _loadAll();
      expect(again.getPlaylistById('pl')!.rev, 4);
    });
  });

  group('shared playlists → session library', () {
    Map<String, dynamic> oldSession(String id) => {
          'id': id,
          'name': 'Ses $id',
          'globalBpm': 100,
          'patternsConfig': [
            {'patternId': 'rp', 'volume': 0.8, 'orderIndex': 0},
          ],
        };

    test('current payload: sessions added once, items linked, re-import never duplicates', () async {
      final (patterns, sessions, playlists) = await _loadAll();
      final service = ShareImportService(patterns: patterns, sessions: sessions, playlists: playlists);
      final remote = Playlist(id: 'remote-pl', name: 'Remota', items: [
        PlaylistItem.fromLibrary(_session('a', name: 'A')),
        PlaylistItem.fromLibrary(_session('a', name: 'A')),
        PlaylistItem.fromLibrary(_session('b', name: 'B')),
      ]);
      final bundle = SharedBundle(
        shareId: 'share-1',
        type: SharedType.playlist,
        name: 'Remota',
        data: remote.toJson(),
        sessions: [for (final s in remote.sessions) s.toJson()],
      );
      final libraryBefore = sessions.sessions.length;

      final result = await service.import(bundle);
      expect(sessions.sessions.length, libraryBefore + 2);
      final pl = playlists.getPlaylistById(result.localId)!;
      expect(pl.items.length, 3);
      expect(pl.items[0].sourceSessionId, pl.items[1].sourceSessionId);
      expect(pl.items.every(playlists.isInLibrary), isTrue);
      expect(playlists.resolvedSessions(pl).map((s) => s.name), ['A', 'A', 'B']);
      for (final item in pl.items) {
        expect(sessions.getSessionById(item.sourceSessionId!), isNotNull);
        expect(item.session.id, isNot(item.sourceSessionId)); // snapshot has its own id
      }

      final again = await service.import(bundle);
      expect(again.alreadyInLibrary, isTrue);
      expect(sessions.sessions.length, libraryBefore + 2);

      // Deleted playlist → re-imported, reusing the same library sessions.
      await playlists.deletePlaylist(result.localId);
      await service.import(bundle);
      expect(sessions.sessions.length, libraryBefore + 2);
      expect(playlists.getPlaylistById(result.localId)!.items.every(playlists.isInLibrary), isTrue);
    });

    test('legacy payload (sessionIds + sessions) also goes to the library', () async {
      final (patterns, sessions, playlists) = await _loadAll();
      final service = ShareImportService(patterns: patterns, sessions: sessions, playlists: playlists);
      final libraryBefore = sessions.sessions.length;
      final bundle = SharedBundle(
        shareId: 'old-share',
        type: SharedType.playlist,
        name: 'Remota',
        data: {'id': 'remote-pl', 'name': 'Remota', 'sessionIds': ['rs1', 'gone', 'rs1']},
        sessions: [oldSession('rs1')],
        patterns: [
          {
            'id': 'rp',
            'name': 'RP',
            'description': '',
            'structure': '3',
            'pulses': [
              {'subdivisions': [1, 0], 'durationRatio': 1.0},
            ],
            'colorHex': '#F98533',
            'tags': <String>[],
            'createdAt': '2025-01-01T10:00:00.000',
            'updatedAt': '2025-01-01T10:00:00.000',
          },
        ],
      );
      final result = await service.import(bundle);
      expect(sessions.sessions.length, libraryBefore + 1);
      final pl = playlists.getPlaylistById(result.localId)!;
      expect(pl.items.length, 2);
      expect(pl.items.every(playlists.isInLibrary), isTrue);
      final lib = sessions.getSessionById(pl.items.first.sourceSessionId!)!;
      expect(lib.patternsConfig.single.hasEmbeddedPattern, isTrue);

      await service.import(bundle);
      expect(sessions.sessions.length, libraryBefore + 1);
    });
  });

  group('undo = back in time', () {
    test('restore after delete: same updatedAt and position, rev goes up', () async {
      final (_, sessions, _) = await _loadAll();
      for (final id in ['a', 'b', 'c']) {
        await sessions.addSession(_session(id));
      }
      final ids = sessions.sessions.map((s) => s.id).toList();
      final original = sessions.getSessionById('b')!;
      await _tick();

      final removed = await sessions.deleteSession('b');
      await _tick();
      await sessions.restoreSession(removed!.$1, removed.$2);

      final back = sessions.getSessionById('b')!;
      expect(sessions.sessions.map((s) => s.id).toList(), ids);
      expect(back.updatedAt, original.updatedAt);
      expect(back.createdAt, original.createdAt);
      expect(back.rev, original.rev + 2);
      expect(back.deleted, isFalse);

      final reloaded = SessionProvider();
      await reloaded.loadSessions();
      expect(reloaded.getSessionById('b')!.updatedAt, original.updatedAt);
      expect(reloaded.sessions.map((s) => s.id).toList(), ids);
    });

    test('restore after the tombstone was purged goes back to its position', () async {
      final (_, sessions, _) = await _loadAll();
      for (final id in ['a', 'b', 'c']) {
        await sessions.addSession(_session(id));
      }
      final ids = sessions.sessions.map((s) => s.id).toList();
      final removed = await sessions.deleteSession('b');
      // Simulate a purge: drop the tombstone from storage and reload.
      final prefs = await SharedPreferences.getInstance();
      final list = (json.decode(prefs.getString('session_library')!) as List)
        ..removeWhere((e) => e['id'] == 'b');
      await prefs.setString('session_library', json.encode(list));
      final fresh = SessionProvider();
      await fresh.loadSessions();

      await fresh.restoreSession(removed!.$1, removed.$2);
      expect(fresh.sessions.map((s) => s.id).toList(), ids);
      expect(fresh.getSessionById('b')!.updatedAt, removed.$1.updatedAt);
      expect(fresh.getSessionById('b')!.rev, removed.$1.rev + 1);
    });

    test('undo of an overwrite restores the exact previous version', () async {
      final (_, sessions, _) = await _loadAll();
      await sessions.addSession(_session('a', name: 'v1'));
      await sessions.addSession(_session('b'));
      final previous = sessions.getSessionById('a')!;
      await _tick();
      await sessions.updateSession(previous.copyWith(name: 'v2', globalBpm: 200));
      await _tick();

      await sessions.revertSession(previous);
      final back = sessions.getSessionById('a')!;
      expect(back.name, 'v1');
      expect(back.globalBpm, previous.globalBpm);
      expect(back.updatedAt, previous.updatedAt);
      expect(back.rev, previous.rev + 2);
      expect(sessions.sessions.map((s) => s.id).toList().indexOf('a'),
          lessThan(sessions.sessions.map((s) => s.id).toList().indexOf('b')));
    });

    test('undo of remove-from-playlist and of playlist delete restores it exactly', () async {
      final (_, sessions, playlists) = await _loadAll();
      await playlists.addPlaylist(Playlist(id: 'p1', name: 'Uno'));
      await playlists.addPlaylist(Playlist(id: 'p2', name: 'Dos'));
      for (final id in ['s1', 's2', 's3']) {
        await sessions.addSession(_session(id));
        await playlists.addSessionToPlaylist('p1', sessions.getSessionById(id)!);
      }
      final before = playlists.getPlaylistById('p1')!;
      await _tick();

      final removed = await playlists.removeItemFromPlaylist('p1', 1);
      expect(removed!.$1.sourceSessionId, 's2');
      await _tick();
      await playlists.undoItemRemoval(removed.$2);

      final back = playlists.getPlaylistById('p1')!;
      expect(back.items.map((i) => i.id), before.items.map((i) => i.id));
      expect(back.updatedAt, before.updatedAt);
      expect(back.rev, before.rev + 2);

      await _tick();
      final del = await playlists.deletePlaylist('p1');
      await playlists.restorePlaylist(del!.$1, del.$2);
      final restored = playlists.getPlaylistById('p1')!;
      expect(playlists.playlists.map((p) => p.id), ['p1', 'p2']);
      expect(restored.updatedAt, before.updatedAt);
      expect(restored.rev, before.rev + 4);
      expect(playlists.allPlaylists.firstWhere((p) => p.id == 'p1').deleted, isFalse);
      expect(SyncFields.readRev(restored.toJson()), restored.rev);
    });
  });
}
