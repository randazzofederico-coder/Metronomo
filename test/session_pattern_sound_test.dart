import 'package:flutter_test/flutter_test.dart';
import 'package:metronomo_standalone/models/session_model.dart';

void main() {
  group('SessionPatternConfig.soundSet', () {
    test('defaults to null (follows the session sound) and is omitted from JSON', () {
      final config = SessionPatternConfig(patternId: 'p1');
      expect(config.soundSet, isNull);
      expect(config.toJson().containsKey('soundSet'), isFalse);
    });

    test('round-trips through JSON', () {
      final config = SessionPatternConfig(patternId: 'p1', soundSet: 'Bombo');
      final restored = SessionPatternConfig.fromJson(config.toJson());
      expect(restored.soundSet, 'Bombo');
    });

    test('legacy JSON without soundSet loads as null', () {
      final restored = SessionPatternConfig.fromJson({'patternId': 'p1', 'volume': 0.8});
      expect(restored.soundSet, isNull);
    });

    test('copyWith keeps, changes or clears the sound set', () {
      final config = SessionPatternConfig(patternId: 'p1', soundSet: 'Madera');
      expect(config.copyWith(patternId: 'p2').soundSet, 'Madera');
      expect(config.copyWith(soundSet: 'Claves').soundSet, 'Claves');
      expect(config.copyWith(soundSet: null).soundSet, isNull);
    });
  });
}
