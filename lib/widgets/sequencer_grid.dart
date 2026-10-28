import 'package:flutter/material.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/theme/beat_colors.dart';

/// Identifies one event (subdivision) inside a pattern.
typedef SequencerCell = ({int pulse, int sub});

/// Sequencer cells of a pattern: one box per pulse (width proportional to its
/// duration), split into its subdivisions. Wraps to 2–3 rows when the cells
/// would get narrower than [minCellWidth].
///
/// All callbacks are optional: without them the grid is read-only.
class SequencerGrid extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int items = pulses.length;
        int rows = 1;
        // If cells get too squeezed, divide them into multiple rows.
        if (items > 0 && constraints.maxWidth / items < minCellWidth) {
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
    final pulse = pulses[i];
    final int subdivCount = pulse.subdivisions.length;

    return Expanded(
      flex: (pulse.durationRatio * 100).round().clamp(1, 10000),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
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
    );
  }

  Widget _buildEvent(BuildContext context, HomeMetronomePulse pulse, int i, int subIndex, {required bool compact}) {
    final int type = pulse.subdivisions[subIndex];
    final bool isHead = subIndex == 0;
    final bool sounds = type != BeatColors.silence;
    final SequencerCell cell = (pulse: i, sub: subIndex);
    final bool highlighted = highlightedCell == cell;
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

    final bool interactive = onCellTap != null || onCellLongPressStart != null;
    if (!interactive) return box;

    final bool canLongPress = sounds && onCellLongPressStart != null;
    return GestureDetector(
      onTap: onCellTap == null ? null : () => onCellTap!(cell),
      onLongPressStart: canLongPress ? (_) => onCellLongPressStart!(cell) : null,
      onLongPressMoveUpdate: canLongPress && onCellLongPressMove != null
          ? (details) => onCellLongPressMove!(details.offsetFromOrigin.dy)
          : null,
      onLongPressEnd: canLongPress && onCellLongPressEnd != null ? (_) => onCellLongPressEnd!() : null,
      child: box,
    );
  }
}
