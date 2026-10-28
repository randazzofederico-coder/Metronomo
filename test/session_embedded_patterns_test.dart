import 'package:flutter_test/flutter_test.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/models/session_model.dart';
import 'package:metronomo_standalone/providers/pattern_editor_provider.dart';
import 'package:metronomo_standalone/providers/playlist_provider.dart';
import 'package:metronomo_standalone/providers/session_provider.dart';
import 'package:metronomo_standalone/services/deep_link_service.dart';
import 'package:metronomo_standalone/services/share_import_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Pattern _pattern(String id, {String name = 'P', String structure = '3'}) => Pattern(
      id: id,
      name: name,
      structure: structure,
      pulses: [HomeMetronomePulse([1, 0]), HomeMetronomePulse([2], 1.0, [0.5])],
    );

Session _legacySession(String id, List<String> patternIds) => Session(
      id: id,
      name: 'Legacy $id',
      globalBpm: 100,
      patternsConfig: [
        for (var i = 0; i < patternIds.length; i++)
          SessionPatternConfig(patternId: patternIds[i], volume: 0.7, orderIndex: i),
      ],
    );

void main() {
  group('SessionPatternConfig embedded pattern', () {
    test('legacy JSON has no embedded pattern', () {
      final c = SessionPatternConfig.fromJson({'patternId': 'p1', 'volume': 0.8});
      expect(c.hasEmbeddedPattern, isFalse);
      expect(c.embeddedPattern, isNull);
      expect(c.toJson().containsKey('pulses'), isFalse);
    });

    test('embedded pattern round-trips through JSON (incl. event volumes)', () {
      final c = SessionPatternConfig(patternId: 'p1').embedding(_pattern('lib', name: 'Clave', structure: '3+2'));
      final restored = SessionPatternConfig.fromJson(c.toJson());
      expect(restored.hasEmbeddedPattern, isTrue);
      final p = restored.embeddedPattern!;
      expect(p.id, 'p1'); // keeps the config id, not the source pattern id
      expect(p.name, 'Clave');
      expect(p.structure, '3+2');
      expect(p.pulses.length, 2);
      expect(p.pulses[0].subdivisions, [1, 0]);
      expect(p.pulses[1].volumes, [0.5]);
    });

    test('copyWith keeps the embedded pattern', () {
      final c = SessionPatternConfig(patternId: 'p1').embedding(_pattern('x'));
      expect(c.copyWith(volume: 0.2).hasEmbeddedPattern, isTrue);
      expect(c.copyWith(patternId: 'p2').embeddedPattern!.id, 'p2');
    });
  });

  group('Session.withEmbeddedPatterns', () {
    test('embeds resolvable patterns, keeps the rest, preserves mix settings', () {
      final s = _legacySession('s1', ['a', 'missing']);
      final lib = {'a': _pattern('a', name: 'A')};
      final migrated = s.withEmbeddedPatterns((id) => lib[id]);

      expect(migrated.patternsConfig[0].hasEmbeddedPattern, isTrue);
      expect(migrated.patternsConfig[0].name, 'A');
      expect(migrated.patternsConfig[0].volume, 0.7);
      expect(migrated.patternsConfig[1].hasEmbeddedPattern, isFalse);
      expect(migrated.needsEmbedding, isTrue);
      expect(migrated.id, 's1');
    });

    test('embeddedPatterns lists distinct patterns for sharing', () {
      final lib = {'a': _pattern('a'), 'b': _pattern('b')};
      final s = _legacySession('s1', ['a', 'b', 'a']).withEmbeddedPatterns((id) => lib[id]);
      expect(s.embeddedPatterns.map((p) => p.id), ['a', 'b']);
    });
  });

  group('SessionProvider.embedMissingPatterns (migration)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('migrates legacy sessions once and survives deleting the library pattern', () async {
      final patterns = PatternEditorProvider();
      await patterns.loadPatterns(); // seeds the default Chacarera patterns
      final sessions = SessionProvider();
      await sessions.loadSessions(); // seeds the legacy default Chacarera session

      expect(sessions.sessions.single.needsEmbedding, isTrue);
      expect(await sessions.embedMissingPatterns(patterns.getPatternById), 1);
      expect(sessions.sessions.single.needsEmbedding, isFalse);
      // Idempotent
      expect(await sessions.embedMissingPatterns(patterns.getPatternById), 0);

      // Library deletion no longer affects the session.
      for (final p in List.of(patterns.patterns)) {
        await patterns.deletePattern(p.id);
      }
      final reloaded = SessionProvider();
      await reloaded.loadSessions();
      final config = reloaded.sessions.single.patternsConfig.first;
      expect(config.hasEmbeddedPattern, isTrue);
      expect(config.structure, '3/2');
    });
  });

  group('ShareImportService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<(PatternEditorProvider, SessionProvider, ShareImportService)> setup() async {
      final patterns = PatternEditorProvider();
      await patterns.loadPatterns();
      final sessions = SessionProvider();
      await sessions.loadSessions();
      final playlists = PlaylistProvider();
      await playlists.loadPlaylists();
      return (
        patterns,
        sessions,
        ShareImportService(patterns: patterns, sessions: sessions, playlists: playlists),
      );
    }

    test('legacy session link: patterns are embedded, not added to the library', () async {
      final (patterns, sessions, service) = await setup();
      final libraryBefore = patterns.patterns.length;

      final shared = _pattern('remote-1', name: 'Remoto', structure: '5');
      final bundle = SharedBundle(
        shareId: 'share-xyz',
        type: SharedType.session,
        name: 'Compartida',
        data: _legacySession('remote-session', ['remote-1']).toJson(),
        patterns: [shared.toJson()],
      );

      final result = await service.import(bundle);
      expect(patterns.patterns.length, libraryBefore);

      final imported = sessions.getSessionById(result.localId)!;
      final config = imported.patternsConfig.single;
      expect(config.hasEmbeddedPattern, isTrue);
      expect(config.name, 'Remoto');
      expect(config.structure, '5');

      // Idempotent
      final again = await service.import(bundle);
      expect(again.alreadyInLibrary, isTrue);
      expect(again.localId, result.localId);
    });

    test('shared pattern link still goes to the pattern library', () async {
      final (patterns, _, service) = await setup();
      final before = patterns.patterns.length;
      final result = await service.import(SharedBundle(
        shareId: 'share-p',
        type: SharedType.pattern,
        name: 'Remoto',
        data: _pattern('remote-2').toJson(),
      ));
      expect(patterns.patterns.length, before + 1);
      expect(patterns.getPatternById(result.localId), isNotNull);
    });
  });
}
