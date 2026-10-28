import 'package:flutter/material.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';

/// Visual shell of a pattern in a session, shared by the editable metronome
/// and the read-only playlist player.
///
/// Compact layout: a single header row — title · structure · mixer · menu —
/// above the sequencer. When the card is too narrow for that, the mixer drops
/// to its own row under the sequencer.
///
/// Each pattern has an identity [accent] color (left stripe), so patterns are
/// easy to tell apart and to match with their row in the macro cycle.
class PatternCard extends StatelessWidget {
  final Color accent;
  final Widget title;
  final Widget structure;
  final Widget? mixer;
  final Widget? menu;
  final Widget sequencer;

  /// Minimum inner width to fit the mixer in the header row.
  static const double singleRowMinWidth = 300;

  const PatternCard({
    super.key,
    required this.accent,
    required this.title,
    required this.structure,
    this.mixer,
    this.menu,
    required this.sequencer,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      // Precision control: excluded from the global UI scale.
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(12),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final singleRow = mixer == null || constraints.maxWidth >= singleRowMinWidth;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 40,
                        child: Row(
                          children: [
                            Flexible(flex: 3, fit: FlexFit.tight, child: title),
                            const SizedBox(width: 6),
                            Flexible(flex: 2, child: structure),
                            if (singleRow && mixer != null) ...[
                              const SizedBox(width: 4),
                              mixer!,
                            ],
                            if (menu != null) menu!,
                          ],
                        ),
                      ),
                      sequencer,
                      if (!singleRow) ...[
                        const SizedBox(height: 2),
                        Align(alignment: Alignment.centerRight, child: mixer!),
                      ],
                    ],
                  );
                },
              ),
            ),
            // Identity stripe
            Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: accent)),
          ],
        ),
      ),
    );
  }
}
