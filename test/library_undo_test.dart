import 'package:flutter_test/flutter_test.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/models/playlist_model.dart';
import 'package:metronomo_standalone/models/session_model.dart';
import 'package:metronomo_standalone/providers/pattern_editor_provider.dart';
import 'package:metronomo_standalone/providers/playlist_provider.dart';
import 'package:metronomo_standalone/providers/session_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Session _session(String id) => Session(id: id, name: id, globalBpm: 90, patternsConfig: []);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('deleteSession + restoreSession keeps position and persists', () async {
    final p = SessionProvider();
    await p.loadSessions(); // seeds the default session at index 0
    await p.addSession(_session('a'));
    await p.addSession(_session('b'));
    final idsBefore = p.sessions.map((s) => s.id).toList();

    final removed = await p.deleteSession('a');
    expect(removed!.$2, 1);
    expect(p.getSessionById('a'), isNull);

    await p.restoreSession(removed.$1, removed.$2);
    expect(p.sessions.map((s) => s.id).toList(), idsBefore);

    // Restoring twice is a no-op.
    await p.restoreSession(removed.$1, removed.$2);
    expect(p.sessions.length, idsBefore.length);

    final reloaded = SessionProvider();
    await reloaded.loadSessions();
    expect(reloaded.sessions.map((s) => s.id).toList(), idsBefore);
  });

  test('deletePattern + restorePattern keeps position and persists', () async {
    final p = PatternEditorProvider();
    await p.loadPatterns(); // 2 default patterns
    await p.addPattern(Pattern(id: 'x', name: 'X'));
    final idsBefore = p.patterns.map((e) => e.id).toList();

    final removed = await p.deletePattern(idsBefore.first);
    await p.restorePattern(removed!.$1, removed.$2);
    expect(p.patterns.map((e) => e.id).toList(), idsBefore);

    final reloaded = PatternEditorProvider();
    await reloaded.loadPatterns();
    expect(reloaded.patterns.map((e) => e.id).toList(), idsBefore);
  });

  test('playlists: delete/restore and remove/insert session', () async {
    final p = PlaylistProvider();
    await p.loadPlaylists();
    await p.addPlaylist(Playlist(id: 'p1', name: 'Uno', sessionIds: ['s1', 's2', 's3']));
    await p.addPlaylist(Playlist(id: 'p2', name: 'Dos', sessionIds: []));

    final removed = await p.deletePlaylist('p1');
    expect(p.getPlaylistById('p1'), isNull);
    await p.restorePlaylist(removed!.$1, removed.$2);
    expect(p.playlists.map((e) => e.id).toList(), ['p1', 'p2']);

    await p.removeSessionFromPlaylist('p1', 1);
    expect(p.getPlaylistById('p1')!.sessionIds, ['s1', 's3']);
    await p.insertSessionInPlaylist('p1', 1, 's2');
    expect(p.getPlaylistById('p1')!.sessionIds, ['s1', 's2', 's3']);
  });
}
