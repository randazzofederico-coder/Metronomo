import 'package:flutter/material.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';

/// Visual shell of a pattern in a session: a header row, the sequencer and a
/// footer (mixer). Content is provided by the screen, so the same card is used
/// by the editable metronome and the read-only playlist player.
class PatternCard extends StatelessWidget {
  final Widget header;
  final Widget sequencer;
  final Widget? footer;

  const PatternCard({
    super.key,
    required this.header,
    required this.sequencer,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      // Precision control: excluded from the global UI scale.
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 8),
            sequencer,
            if (footer != null) ...[
              const SizedBox(height: 6),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
