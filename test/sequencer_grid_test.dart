import 'package:flutter_test/flutter_test.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/widgets/sequencer_grid.dart';

void main() {
  group('SequencerGrid.cellAt (playing-event highlight)', () {
    // "3/2": 3 pulses of 1 beat, 2 subdivisions each.
    final simple = [
      HomeMetronomePulse([1, 3]),
      HomeMetronomePulse([2, 3]),
      HomeMetronomePulse([2, 3]),
    ];

    test('stopped → no cell', () {
      expect(SequencerGrid.cellAt(simple, -1), isNull);
    });

    test('finds pulse and subdivision', () {
      expect(SequencerGrid.cellAt(simple, 0.0), (pulse: 0, sub: 0));
      expect(SequencerGrid.cellAt(simple, 0.6), (pulse: 0, sub: 1));
      expect(SequencerGrid.cellAt(simple, 1.2), (pulse: 1, sub: 0));
      expect(SequencerGrid.cellAt(simple, 2.99), (pulse: 2, sub: 1));
    });

    test('wraps around the pattern cycle', () {
      expect(SequencerGrid.cellAt(simple, 3.0), (pulse: 0, sub: 0));
      expect(SequencerGrid.cellAt(simple, 7.5), (pulse: 1, sub: 1));
    });

    test('respects uneven pulse durations ("2:3/3" → 2 pulses of 1.5 beats)', () {
      final uneven = [HomeMetronomePulse([1, 0, 0], 1.5), HomeMetronomePulse([1, 0, 0], 1.5)];
      expect(SequencerGrid.cellAt(uneven, 1.4), (pulse: 0, sub: 2));
      expect(SequencerGrid.cellAt(uneven, 1.5), (pulse: 1, sub: 0));
      expect(SequencerGrid.cellAt(uneven, 3.1), (pulse: 0, sub: 0));
    });
  });
}
