import 'package:flutter/material.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';

/// Colors of the sequencer event types, in a single place.
///
/// Event types (see `HomeMetronomePulse.subdivisions`):
///  * 0 = silence
///  * 1 = accent (strong)
///  * 2 = normal
///  * 3 = soft
class BeatColors {
  BeatColors._();

  static const int silence = 0;
  static const int accent = 1;
  static const int normal = 2;
  static const int soft = 3;

  /// Number of event types; tapping a cell cycles through them.
  static const int typeCount = 4;

  /// Base color for an event [type]. Silence returns the highlight surface.
  static Color of(BuildContext context, int type) {
    switch (type) {
      case accent:
        return AppColors.accentRed(context);
      case normal:
        return AppColors.primary(context);
      case soft:
        return AppColors.accentGreen(context);
      default:
        return AppColors.surfaceHighlight(context);
    }
  }
}

/// Identity color of each pattern in a session (card stripe, title and its
/// row in the macro cycle), by position. Hues are chosen away from the beat
/// type colors (red / orange / green) so they don't read as event types.
class PatternColors {
  PatternColors._();

  static const List<Color> palette = [
    Color(0xFF4FC3F7), // light blue
    Color(0xFFBA68C8), // purple
    Color(0xFFFFD54F), // yellow
    Color(0xFFF48FB1), // pink
    Color(0xFF4DD0E1), // cyan
    Color(0xFF9FA8DA), // indigo
    Color(0xFFB0BEC5), // blue grey
    Color(0xFFBCAAA4), // taupe
  ];

  static Color forIndex(int index) => palette[index % palette.length];
}
