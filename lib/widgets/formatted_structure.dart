import 'package:flutter/material.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';

/// Read-only display of a pattern structure where each subdivision appears
/// below a divider, like a fraction.
///
///  * "2/3"   → "2" over "―" over "3"
///  * "2:3/3" → "2:3" over "―" over "3"
///  * "3+2"   → "3" + "2" (no subdivisions, no divider)
class FormattedStructure extends StatelessWidget {
  final String structure;

  const FormattedStructure(this.structure, {super.key});

  @override
  Widget build(BuildContext context) {
    final String cleaned = structure.replaceAll(' ', '');
    if (cleaned.isEmpty) {
      return Text("—", style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14));
    }

    final List<String> segments = cleaned.split('+');
    final List<Widget> segmentWidgets = [];
    final textColor = AppColors.textPrimary(context);

    for (int s = 0; s < segments.length; s++) {
      if (s > 0) {
        segmentWidgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text("+", style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14, fontWeight: FontWeight.bold)),
        ));
      }

      final String seg = segments[s];
      final int slashIdx = seg.indexOf('/');

      if (slashIdx >= 0) {
        // Fraction-style: top / divider / bottom
        final String topPart = seg.substring(0, slashIdx);
        final String bottomPart = seg.substring(slashIdx + 1);
        final topWidth = topPart.length * 10.0 + 8;
        final bottomWidth = bottomPart.length * 10.0 + 8;
        final width = (topWidth > bottomWidth ? topWidth : bottomWidth).clamp(24.0, 120.0);
        final style = TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1);

        segmentWidgets.add(SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(topPart, style: style),
              Container(
                width: width - 4,
                height: 1,
                color: AppColors.textSecondary(context).withOpacity(0.5),
                margin: const EdgeInsets.symmetric(vertical: 1),
              ),
              Text(bottomPart, style: style),
            ],
          ),
        ));
      } else {
        // Simple number, no subdivision
        segmentWidgets.add(Text(seg, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)));
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: segmentWidgets,
    );
  }
}
