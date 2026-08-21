import 'package:flutter/material.dart';

class AppTheme {
  // Premium Dark Palette
  static const Color primaryDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color accentColor = Color(0xFF38BDF8); // Light Blue 400
  static const Color accentGradientStart = Color(0xFF0EA5E9);
  static const Color accentGradientEnd = Color(0xFF38BDF8);
  static const Color textPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondary = Color(0xFF94A3B8); // Slate 400

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.apply(fontFamily: 'Nunito', bodyColor: textPrimary, displayColor: textPrimary).copyWith(
      displayLarge: base.displayLarge?.copyWith(fontFamily: 'Outfit', color: textPrimary),
      displayMedium: base.displayMedium?.copyWith(fontFamily: 'Outfit', color: textPrimary),
      displaySmall: base.displaySmall?.copyWith(fontFamily: 'Outfit', color: textPrimary),
      headlineLarge: base.headlineLarge?.copyWith(fontFamily: 'Outfit', color: textPrimary, fontWeight: FontWeight.w700),
      headlineMedium: base.headlineMedium?.copyWith(fontFamily: 'Outfit', color: textPrimary, fontWeight: FontWeight.w700),
      headlineSmall: base.headlineSmall?.copyWith(fontFamily: 'Outfit', color: textPrimary, fontWeight: FontWeight.w700),
      titleLarge: base.titleLarge?.copyWith(fontFamily: 'Outfit', color: textPrimary, fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(fontFamily: 'Outfit', color: textPrimary, fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontFamily: 'Outfit', color: textPrimary, fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(color: textPrimary),
      bodyMedium: base.bodyMedium?.copyWith(color: textPrimary),
      bodySmall: base.bodySmall?.copyWith(color: textSecondary),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: accentColor,
        secondary: accentColor,
        surface: surfaceDark,
        onSurface: textPrimary,
      ),
      textTheme: _buildTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: accentColor,
        unselectedItemColor: textSecondary,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155), // Slate 700
        thickness: 1,
        space: 1,
      ),
    );
  }

  // A dummy light theme just in case someone forces it, though we locked it to dark
  static ThemeData get lightTheme => darkTheme;
}
