import 'package:fede_apps_core/fede_apps_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:metronomo_standalone/l10n/l10n.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/models/playlist_model.dart';
import 'package:metronomo_standalone/models/session_model.dart';
import 'package:metronomo_standalone/providers/pattern_editor_provider.dart';
import 'package:metronomo_standalone/providers/playlist_provider.dart';
import 'package:metronomo_standalone/providers/session_provider.dart';
import 'package:metronomo_standalone/services/metronomo_sync_adapter.dart';
import 'package:metronomo_standalone/services/pattern_repository.dart';
import 'package:metronomo_standalone/services/playlist_repository.dart';
import 'package:metronomo_standalone/services/session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Each simulated device keeps its libraries under its own prefs keys.
class _PatternRepo extends PatternRepository {
  _PatternRepo(this.prefix, {super.sync});
  final String prefix;
  @override
  String get storageKey => '${prefix}_${super.storageKey}';
}

class _SessionRepo extends SessionRepository {
  _SessionRepo(this.prefix, {super.sync});
  final String prefix;
  @override
  String get storageKey => '${prefix}_${super.storageKey}';
}

class _PlaylistRepo extends PlaylistRepository {
  _PlaylistRepo(this.prefix, {super.sync});
  final String prefix;
  @override
  String get storageKey => '${prefix}_${super.storageKey}';
}

/// One installation of the app: its libraries (wired like main.dart), the
/// adapter and its own [LibrarySync] against the shared in-memory cloud.
class _Device {
  _Device(this.name, this.sync)
      : patterns = PatternEditorProvider(repository: _PatternRepo(name, sync: sync)),
        sessions = SessionProvider(repository: _SessionRepo(name, sync: sync)),
        playlists = PlaylistProvider(repository: _PlaylistRepo(name, sync: sync)) {
    playlists.attachLibrary(sessions: sessions, patterns: patterns);
    adapter = MetronomoSyncAdapter(patterns: patterns, sessions: sessions, playlists: playlists);
  }

  final String name;
  final LibrarySync sync;
  final PatternEditorProvider patterns;
  final SessionProvider sessions;
  final PlaylistProvider playlists;
  late final MetronomoSyncAdapter adapter;

  Future<void> start() async {
    final load = playlists.loadPlaylists();
    await patterns.loadPatterns();
    await sessions.loadSessions();
    await load;
    await sync.configure(adapter);
    await syncNow();
  }

  Future<void> syncNow() async {
    await sync.syncNow(force: true);
    await _settle();
    expect(sync.status.value.state, SyncState.idle, reason: '$name: ${sync.status.value.lastError}');
  }

  Map<String, Map<String, dynamic>> cloud(InMemoryRemoteStore store, String collection) {
    final c = store.collections('u1', 'metronomo')?[collection];
    return c is Map ? Map<String, Map<String, dynamic>>.from(c.map((k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map)))) : {};
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Session _session(String id, {String? name, int bpm = 90}) => Session(
      id: id,
      name: name ?? id,
      globalBpm: bpm,
      patternsConfig: [
        SessionPatternConfig(patternId: 'p-$id').embedding(Pattern(id: 'x', name: 'P', structure: '4')),
      ],
    );

const _user = FedeUser(uid: 'u1', email: 'a@b.com', displayName: 'Fede');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryRemoteStore store;
  late ValueNotifier<FedeUser?> user;
  final created = <LibrarySync>[];

  _Device device(String name) {
    final sync = LibrarySync(
      store: store,
      user: user,
      deviceId: name,
      listenLifecycle: false,
      prefsPrefix: 'fac_sync_${name}_',
    );
    created.add(sync);
    return _Device(name, sync);
  }

  setUp(() {
    DeviceIdentity.debugReset();
    SharedPreferences.setMockInitialValues({});
    store = InMemoryRemoteStore();
    user = ValueNotifier(_user);
    L10n.current = lookupAppLocalizations(const Locale('es'));
  });

  tearDown(() {
    for (final s in created) {
      s.dispose();
    }
    created.clear();
  });

  test('collections are applied patterns → sessions → playlists', () {
    final a = device('A');
    expect(a.adapter.appId, 'metronomo');
    expect(a.adapter.collections, ['patterns', 'sessions', 'playlists']);
  });

  test('local changes in each collection upload', () async {
    final a = device('A');
    await a.start();

    await a.patterns.addPattern(Pattern(id: 'pat', name: 'Clave', structure: '3/2'));
    await a.sessions.addSession(_session('s1', name: 'Zamba'));
    await a.playlists.addPlaylist(Playlist(id: 'pl', name: 'Show'));
    await a.playlists.addSessionToPlaylist('pl', a.sessions.getSessionById('s1')!);
    await a.syncNow();

    expect(a.cloud(store, 'patterns').keys, contains('pat'));
    expect(a.cloud(store, 'sessions').keys, contains('s1'));
    expect(a.cloud(store, 'playlists').keys, contains('pl'));
    expect(a.cloud(store, 'sessions')['s1']!['rev'], 1);

    // Delete = tombstone (rev + 1) that also uploads.
    await a.patterns.deletePattern('pat');
    await a.syncNow();
    expect(a.cloud(store, 'patterns')['pat']!['deleted'], isTrue);
    expect(a.cloud(store, 'patterns')['pat']!['rev'], 2);
  });

  test('untouched default seeds stay local; edited ones sync', () async {
    final a = device('A');
    await a.start();
    expect(a.sessions.getSessionById('default-session-chacarera'), isNotNull);
    expect(a.cloud(store, 'sessions'), isEmpty);
    expect(a.cloud(store, 'patterns'), isEmpty);

    final b = device('B');
    await b.start();
    // No "(otro dispositivo)" copies of the seeds.
    expect(b.sessions.sessions.map((s) => s.name), ['Chacarera']);

    await a.sessions.updateSession(a.sessions.getSessionById('default-session-chacarera')!.copyWith(globalBpm: 100));
    await a.syncNow();
    await b.syncNow();
    expect(b.sessions.getSessionById('default-session-chacarera')!.globalBpm, 100);
    expect(b.sessions.sessions, hasLength(1));
  });

  test('remote session update is reflected in playlists (hybrid resolution)', () async {
    final a = device('A');
    final b = device('B');
    await a.start();
    await a.sessions.addSession(_session('s1', name: 'Original'));
    await a.playlists.addPlaylist(Playlist(id: 'pl', name: 'Show'));
    await a.playlists.addSessionToPlaylist('pl', a.sessions.getSessionById('s1')!);
    await a.syncNow();
    await b.start();

    final plRev = b.playlists.getPlaylistById('pl')!.rev;
    var notified = 0;
    b.playlists.addListener(() => notified++);

    await a.sessions.updateSession(a.sessions.getSessionById('s1')!.copyWith(name: 'Edited', globalBpm: 150));
    await a.syncNow();
    await b.syncNow();

    final pl = b.playlists.getPlaylistById('pl')!;
    final item = pl.items.single;
    expect(b.playlists.isInLibrary(item), isTrue);
    expect(b.playlists.resolveSession(item).name, 'Edited');
    expect(b.playlists.resolveSession(item).globalBpm, 150);
    expect(pl.rev, plRev); // no playlist churn
    expect(notified, greaterThan(0)); // playlist screens rebuild
  });

  test('remote session delete: playlist keeps playing its snapshot, no conflict copy', () async {
    final a = device('A');
    final b = device('B');
    await a.start();
    await a.sessions.addSession(_session('s1', name: 'Original', bpm: 90));
    await a.playlists.addPlaylist(Playlist(id: 'pl', name: 'Show'));
    await a.playlists.addSessionToPlaylist('pl', a.sessions.getSessionById('s1')!);
    await a.syncNow();
    await b.start();

    // Edited and deleted on A before B hears about the edit.
    await a.sessions.updateSession(a.sessions.getSessionById('s1')!.copyWith(name: 'Edited', globalBpm: 150));
    await a.sessions.deleteSession('s1');
    await a.syncNow();
    await b.syncNow();
    await b.syncNow();
    await a.syncNow();

    expect(b.sessions.getSessionById('s1'), isNull);
    for (final d in [a, b]) {
      expect(d.playlists.playlists, hasLength(1), reason: d.name); // no "(otro dispositivo)" copy
      final item = d.playlists.getPlaylistById('pl')!.items.single;
      expect(d.playlists.isInLibrary(item), isFalse, reason: d.name);
      expect(d.playlists.resolveSession(item).name, 'Edited', reason: d.name);
      expect(d.playlists.resolveSession(item).globalBpm, 150, reason: d.name);
    }
  });

  test('remote session delete refreshes the snapshot of a playlist changed locally', () async {
    final a = device('A');
    final b = device('B');
    await a.start();
    await a.sessions.addSession(_session('s1', name: 'Original'));
    await a.syncNow();
    await b.start();
    await b.playlists.addPlaylist(Playlist(id: 'plB', name: 'Local'));
    await b.playlists.addSessionToPlaylist('plB', b.sessions.getSessionById('s1')!);
    await b.syncNow();

    // A edits the session: B's synced playlist resolves to it, but its
    // snapshot stays "Original" (library edits don't refresh snapshots).
    await a.sessions.updateSession(a.sessions.getSessionById('s1')!.copyWith(name: 'Edited on A'));
    await a.syncNow();
    await b.syncNow();
    final synced = b.playlists.getPlaylistById('plB')!;
    expect(synced.items.single.session.name, 'Original');

    // B changes the playlist without syncing (revert keeps current snapshots).
    await b.playlists.revertPlaylist(synced.copyWith(name: 'Renamed on B'));
    final rev = b.playlists.getPlaylistById('plB')!.rev;
    expect(b.playlists.getPlaylistById('plB')!.items.single.session.name, 'Original');

    // A deletes the session.
    await a.sessions.deleteSession('s1');
    await a.syncNow();
    await b.syncNow();

    expect(b.sessions.getSessionById('s1'), isNull);
    final pl = b.playlists.getPlaylistById('plB')!;
    expect(pl.rev, rev + 1); // before-delete hook ran (local change)
    expect(pl.items.single.session.name, 'Edited on A');
    expect(b.playlists.resolveSession(pl.items.single).name, 'Edited on A');
  });

  test('concurrent edits keep both versions (conflict copy, Spanish name)', () async {
    final a = device('A');
    final b = device('B');
    await a.start();
    await a.sessions.addSession(_session('s1', name: 'Zamba'));
    await a.playlists.addPlaylist(Playlist(id: 'pl', name: 'Show'));
    await a.playlists.addSessionToPlaylist('pl', a.sessions.getSessionById('s1')!);
    await a.syncNow();
    await b.start();

    await a.sessions.updateSession(a.sessions.getSessionById('s1')!.copyWith(globalBpm: 100));
    await b.sessions.updateSession(b.sessions.getSessionById('s1')!.copyWith(globalBpm: 120));
    await a.playlists.updatePlaylist(a.playlists.getPlaylistById('pl')!.copyWith(name: 'Show A'));
    await b.playlists.updatePlaylist(b.playlists.getPlaylistById('pl')!.copyWith(name: 'Show B'));
    await a.syncNow();
    await b.syncNow();
    await a.syncNow();

    for (final d in [a, b]) {
      final sessions = d.sessions.sessions.where((s) => !s.id.startsWith('default-')).toList();
      expect(sessions, hasLength(2), reason: d.name);
      final copy = sessions.firstWhere((s) => s.id != 's1');
      expect(copy.name, 'Zamba (otro dispositivo)');
      expect({sessions[0].globalBpm, sessions[1].globalBpm}, {100, 120});

      final playlists = d.playlists.playlists;
      expect(playlists, hasLength(2), reason: d.name);
      final plCopy = playlists.firstWhere((p) => p.id != 'pl');
      expect(plCopy.name, endsWith(' (otro dispositivo)'));
      expect(plCopy.items.single.sourceSessionId, 's1'); // items kept as is
    }
  });

  test('conflict copy name follows the app language', () {
    final a = device('A');
    L10n.current = lookupAppLocalizations(const Locale('en'));
    final copy = a.adapter.conflictCopy('patterns', {'id': 'x', 'name': 'Clave', 'rev': 3});
    expect(copy['name'], 'Clave (other device)');
    expect(copy['id'], isNot('x'));
  });

  test('two devices converge (random-ish operations)', () async {
    final a = device('A');
    final b = device('B');
    await a.start();
    await b.start();

    await a.sessions.addSession(_session('s1'));
    await b.sessions.addSession(_session('s2'));
    await a.patterns.addPattern(Pattern(id: 'p1', name: 'P1', structure: '4'));
    await b.playlists.addPlaylist(Playlist(id: 'pl', name: 'L'));
    await a.syncNow();
    await b.syncNow();
    await a.syncNow();
    await b.playlists.addSessionToPlaylist('pl', b.sessions.getSessionById('s1')!);
    await a.sessions.deleteSession('s2');
    await b.patterns.updatePattern(b.patterns.getPatternById('p1')!.copyWith(name: 'P1 bis'));
    await a.syncNow();
    await b.syncNow();
    await a.syncNow();

    String key(List<Map<String, dynamic>> items) => (items.map((e) => '${e['id']}:${e['rev']}:${e['deleted'] ?? false}').toList()..sort()).join(',');
    for (final c in ['patterns', 'sessions', 'playlists']) {
      expect(key(await a.adapter.readAll(c)), key(await b.adapter.readAll(c)), reason: c);
    }
    expect(b.sessions.getSessionById('s2'), isNull);
    expect(a.patterns.getPatternById('p1')!.name, 'P1 bis');
    expect(a.playlists.getPlaylistById('pl')!.items.single.sourceSessionId, 's1');
  });

  test('applyRemote does not notify the sync nor stamp items', () async {
    final a = device('A');
    await a.start();
    final remote = _session('r1', name: 'Remote').withSync(
      rev: 7,
      deleted: false,
      device: 'other',
      updatedAt: DateTime.utc(2020),
    );
    await a.adapter.applyRemote('sessions', upserts: [remote.toJson()], removals: const []);
    final stored = a.sessions.allSessions.firstWhere((s) => s.id == 'r1');
    expect(stored.rev, 7);
    expect(stored.device, 'other');
    expect(stored.updatedAt, DateTime.utc(2020));
    expect(a.sessions.sessions.last.id, 'r1'); // new ones appended
  });
}
