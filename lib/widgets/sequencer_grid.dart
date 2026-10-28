import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/theme/beat_colors.dart';
import 'package:metronomo_standalone/widgets/playback_clock.dart';

/// Identifies one event (subdivision) inside a pattern.
typedef SequencerCell = ({int pulse, int sub});

/// Sequencer cells of a pattern: one box per pulse (width proportional to its
/// duration), split into its subdivisions. Wraps to 2–3 rows when the cells
/// would get narrower than [minCellWidth].
///
/// While playing, a small bar under the cells marks the event currently
/// sounding (position comes from the nearest [PlaybackClock]; the grid only
/// rebuilds when the active event changes). Cell colors are never altered:
/// their intensity is the event volume.
///
/// All callbacks are optional: without them the grid is read-only.
class SequencerGrid extends StatefulWidget {
  final List<HomeMetronomePulse> pulses;

  /// Quick tap on an event.
  final void Function(SequencerCell cell)? onCellTap;

  /// Long press on a sounding event (type != 0) — "volume mode".
  final void Function(SequencerCell cell)? onCellLongPressStart;

  /// Vertical drag offset from the long-press origin (negative = up).
  final void Function(double dy)? onCellLongPressMove;
  final VoidCallback? onCellLongPressEnd;

  /// Event highlighted with an outline (e.g. while editing its volume).
  final SequencerCell? highlightedCell;

  static const double minCellWidth = 45.0;

  const SequencerGrid({
    super.key,
    required this.pulses,
    this.onCellTap,
    this.onCellLongPressStart,
    this.onCellLongPressMove,
    this.onCellLongPressEnd,
    this.highlightedCell,
  });

  /// Event sounding at [beat] (beats since play started) in a pattern made of
  /// [pulses], or null if [beat] is negative (stopped).
  static SequencerCell? cellAt(List<HomeMetronomePulse> pulses, double beat) {
    if (beat < 0 || pulses.isEmpty) return null;
    double cycle = 0;
    for (final p in pulses) {
      cycle += p.durationRatio;
    }
    if (cycle <= 0) return null;
    final double pos = beat % cycle;
    double start = 0;
    for (int i = 0; i < pulses.length; i++) {
      final double len = pulses[i].durationRatio;
      if (pos < start + len || i == pulses.length - 1) {
        final int subs = pulses[i].subdivisions.length;
        final double frac = len > 0 ? ((pos - start) / len).clamp(0.0, 0.999999) : 0.0;
        return (pulse: i, sub: (frac * subs).floor());
      }
      start += len;
    }
    return null;
  }

  @override
  State<SequencerGrid> createState() => _SequencerGridState();
}

class _SequencerGridState extends State<SequencerGrid> {
  ValueListenable<double>? _clock;
  SequencerCell? _active;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final clock = PlaybackClock.of(context);
    if (clock != _clock) {
      _clock?.removeListener(_onTick);
      _clock = clock;
      _clock?.addListener(_onTick);
      _onTick();
    }
  }

  @override
  void didUpdateWidget(covariant SequencerGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Structure may have changed: recompute without an extra rebuild.
    _active = SequencerGrid.cellAt(widget.pulses, _clock?.value ?? -1);
  }

  @override
  void dispose() {
    _clock?.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    final beat = _clock?.value ?? -1;
    final cell = SequencerGrid.cellAt(widget.pulses, beat);
    if (cell != _active && mounted) setState(() => _active = cell);
  }

  @override
  Widget build(BuildContext context) {
    final pulses = widget.pulses;
    return LayoutBuilder(
      builder: (context, constraints) {
        final int items = pulses.length;
        int rows = 1;
        // If cells get too squeezed, divide them into multiple rows.
        if (items > 0 && constraints.maxWidth / items < SequencerGrid.minCellWidth) {
          rows = items > 16 ? 3 : 2;
        }
        final int itemsPerRow = (items / rows).ceil();

        final rowWidgets = <Widget>[];
        for (int r = 0; r < rows; r++) {
          final int start = r * itemsPerRow;
          if (start >= items) break;
          final int end = (start + itemsPerRow).clamp(0, items);

          final cells = <Widget>[
            for (int i = start; i < end; i++) _buildPulse(context, i, compact: rows > 1),
          ];
          // Pad the last row with empty space if needed.
          while (cells.length < itemsPerRow) {
            cells.add(const Expanded(child: SizedBox.shrink()));
          }
          rowWidgets.add(Row(children: cells));
        }
        return Column(children: rowWidgets);
      },
    );
  }

  Widget _buildPulse(BuildContext context, int i, {required bool compact}) {
    final pulse = widget.pulses[i];
    final int subdivCount = pulse.subdivisions.length;
    final int? activeSub = _active?.pulse == i ? _active!.sub : null;

    return Expanded(
      flex: (pulse.durationRatio * 100).round().clamp(1, 10000),
      child: Padding(
        padding: const EdgeInsets.only(left: 2, right: 2, top: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: compact ? 36 : 42,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border(context), width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  // Align to bottom so the "step down" of sub-beats happens from the top.
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(subdivCount, (subIndex) {
                    return Expanded(child: _buildEvent(context, pulse, i, subIndex, compact: compact));
                  }),
                ),
              ),
            ),
            // Playhead: a small bar under the event that is sounding. Lives in
            // the space of the old bottom margin, so the height doesn't change
            // and the cells' colors (= volume) are never altered.
            SizedBox(
              height: 4,
              child: Row(
                children: List.generate(subdivCount, (subIndex) {
                  final bool on = activeSub == subIndex;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1, left: 3, right: 3),
                      // Container (not a childless DecoratedBox, which sizes to 0x0).
                      child: Container(
                        decoration: BoxDecoration(
                          color: on ? AppColors.textPrimary(context) : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvent(BuildContext context, HomeMetronomePulse pulse, int i, int subIndex, {required bool compact}) {
    final int type = pulse.subdivisions[subIndex];
    final bool isHead = subIndex == 0;
    final bool sounds = type != BeatColors.silence;
    final SequencerCell cell = (pulse: i, sub: subIndex);
    final bool highlighted = widget.highlightedCell == cell;
    final Color typeColor = BeatColors.of(context, type);

    final Widget box = Container(
      // Height difference step for sub-beats.
      margin: EdgeInsets.only(top: isHead ? 0 : 8),
      decoration: BoxDecoration(
        // Color intensity reflects the event volume.
        color: sounds
            ? AppColors.eventFill(typeColor, pulse.volumeAt(subIndex), 0.2)
            : AppColors.background(context),
        border: Border(
          right: subIndex < pulse.subdivisions.length - 1
              ? BorderSide(color: AppColors.background(context), width: 3)
              : BorderSide.none,
          top: isHead ? BorderSide.none : BorderSide(color: AppColors.border(context).withOpacity(0.5), width: 1),
        ),
      ),
      foregroundDecoration:
          highlighted ? BoxDecoration(border: Border.all(color: typeColor, width: 2)) : null,
      alignment: Alignment.center,
      // Only the first subdivision shows the pulse number; the type is the color.
      child: isHead
          ? Text(
              '${i + 1}',
              style: TextStyle(
                color: sounds ? AppColors.textPrimary(context) : AppColors.textSecondary(context),
                fontWeight: FontWeight.bold,
                fontSize: compact ? 12 : 16,
              ),
            )
          : null,
    );

    final bool interactive = widget.onCellTap != null || widget.onCellLongPressStart != null;
    if (!interactive) return box;

    final bool canLongPress = sounds && widget.onCellLongPressStart != null;
    return GestureDetector(
      onTap: widget.onCellTap == null ? null : () => widget.onCellTap!(cell),
      onLongPressStart: canLongPress ? (_) => widget.onCellLongPressStart!(cell) : null,
      onLongPressMoveUpdate: canLongPress && widget.onCellLongPressMove != null
          ? (details) => widget.onCellLongPressMove!(details.offsetFromOrigin.dy)
          : null,
      onLongPressEnd: canLongPress && widget.onCellLongPressEnd != null ? (_) => widget.onCellLongPressEnd!() : null,
      child: box,
    );
  }
}
