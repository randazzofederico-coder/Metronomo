import 'package:flutter/material.dart';

/// Centralized dark theme. Component themes here replace the per-call styling
/// that used to be repeated in every dialog / snackbar.
///
/// Palette values mirror [AppColors] (the app is dark-only).
class AppTheme {
  AppTheme._();

  static const Color _background = Color(0xFF1E1A17);
  static const Color _surface = Color(0xFF2C2621);
  static const Color _surfaceHighlight = Color(0xFF3F342D);
  static const Color _primary = Color(0xFFF98533);
  static const Color _red = Color(0xFFE55353);
  static const Color _textPrimary = Color(0xFFF2EBE5);
  static const Color _textSecondary = Color(0xFFBCAAA4);

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _background,
      colorScheme: const ColorScheme.dark(
        primary: _primary,
        onPrimary: Colors.white,
        secondary: _red,
        onSecondary: Colors.white,
        error: Color(0xFFD32F2F),
        onError: Colors.white,
        surface: _surface,
        onSurface: _textPrimary,
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
    final text = base.textTheme;

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: _surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: _textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceHighlight,
        titleTextStyle: text.headlineSmall?.copyWith(color: _textPrimary),
        contentTextStyle: text.bodyMedium?.copyWith(color: _textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surfaceHighlight,
        contentTextStyle: text.bodyMedium?.copyWith(color: _textPrimary),
        actionTextColor: _primary,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
    );
  }
}
