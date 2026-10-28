import 'package:flutter/material.dart';

class AppColors {
  // Helper
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  // Main Backgrounds
  static Color background(BuildContext context) => isDark(context) ? const Color(0xFF1E1A17) : const Color(0xFFFFF4EB); 
  static Color surface(BuildContext context) => isDark(context) ? const Color(0xFF2C2621) : const Color(0xFFFFFFFF);    
  static Color surfaceHighlight(BuildContext context) => isDark(context) ? const Color(0xFF3F342D) : const Color(0xFFFFE4CC); 

  // Accents
  static Color accentCyan(BuildContext context) => isDark(context) ? const Color(0xFFF98533) : const Color(0xFFF97316); 
  static Color accentRed(BuildContext context) => isDark(context) ? const Color(0xFFE55353) : const Color(0xFFD32F2F); 
  static Color waveformMaster(BuildContext context) => isDark(context) ? const Color(0xFFE08B6B) : const Color(0xFFD9734E); 
  static Color accentGreen(BuildContext context) => isDark(context) ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32); 
  static Color accentAmber(BuildContext context) => isDark(context) ? const Color(0xFFFFB300) : const Color(0xFFF59E0B);

  // UI Elements
  static Color border(BuildContext context) => isDark(context) ? const Color(0xFF4A3F35) : const Color(0xFFF2DFCE); 
  static Color textPrimary(BuildContext context) => isDark(context) ? const Color(0xFFF2EBE5) : const Color(0xFF3E2723); 
  static Color textSecondary(BuildContext context) => isDark(context) ? const Color(0xFFBCAAA4) : const Color(0xFF8D6E63); 

  // Control Specific
  static Color faderTrack(BuildContext context) => isDark(context) ? const Color(0xFF191411) : const Color(0xFFEFE8E1); 
  static Color knobFill(BuildContext context) => isDark(context) ? const Color(0xFF3A322C) : const Color(0xFFFDFDFD); 
  
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
