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
