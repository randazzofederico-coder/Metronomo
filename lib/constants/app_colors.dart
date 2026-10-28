import 'package:flutter/material.dart';

/// App palette. The app is dark-only: the [BuildContext] parameter is kept so
/// call sites don't change (and to allow theming again in the future).
class AppColors {
  // Main Backgrounds
  static Color background(BuildContext context) => const Color(0xFF1E1A17);
  static Color surface(BuildContext context) => const Color(0xFF2C2621);
  static Color surfaceHighlight(BuildContext context) => const Color(0xFF3F342D);

  // Accents
  static Color accentCyan(BuildContext context) => const Color(0xFFF98533);
  static Color accentRed(BuildContext context) => const Color(0xFFE55353);
  static Color waveformMaster(BuildContext context) => const Color(0xFFE08B6B);
  static Color accentGreen(BuildContext context) => const Color(0xFF4CAF50);
  static Color accentAmber(BuildContext context) => const Color(0xFFFFB300);

  // UI Elements
  static Color border(BuildContext context) => const Color(0xFF4A3F35);
  static Color textPrimary(BuildContext context) => const Color(0xFFF2EBE5);
  static Color textSecondary(BuildContext context) => const Color(0xFFBCAAA4);

  // Control Specific
  static Color faderTrack(BuildContext context) => const Color(0xFF191411);
  static Color knobFill(BuildContext context) => const Color(0xFF3A322C);

  // Status (These don't change by theme but take context for consistency)
  static Color success(BuildContext context) => const Color(0xFF4CAF50);
  static Color error(BuildContext context) => const Color(0xFFD32F2F);
  static Color warning(BuildContext context) => const Color(0xFFEF6C00);

  // Aliases for compatibility
  static Color primary(BuildContext context) => accentCyan(context);
  static Color divider(BuildContext context) => border(context);

  /// Fill color for a sequencer event, scaled by its volume (0.0–1.5 = 0–150%).
  ///
  /// [baseOpacity] is the opacity used at 100%. Below 100% the color fades and
  /// desaturates; above 100% it becomes more opaque (up to 2.5× [baseOpacity]).
  static Color eventFill(Color typeColor, double volume, double baseOpacity) {
    final v = volume.clamp(0.0, 1.5);
    final low = v.clamp(0.0, 1.0);
    final hsl = HSLColor.fromColor(typeColor);
    final color = hsl.withSaturation(hsl.saturation * (0.25 + 0.75 * low)).toColor();
    final maxOpacity = (baseOpacity * 2.5).clamp(0.0, 1.0);
    final opacity = v <= 1.0
        ? baseOpacity * (0.25 + 0.75 * low)
        : baseOpacity + (maxOpacity - baseOpacity) * ((v - 1.0) / 0.5);
    return color.withOpacity(opacity.clamp(0.0, 1.0));
  }
}
