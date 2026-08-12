import 'package:flutter/material.dart';


class AppTheme {
  // Colores Premium
  static const Color primaryDark = Color(0xFF0B132B); // Azul medianoche
  static const Color primaryLight = Color(0xFF1C2541); // Azul marino elegante
  static const Color creamBackground = Color(0xFFF8F9FA); // Blanco crema

  // Configuración de texto base
  static TextTheme _buildTextTheme(TextTheme base) {
    return base.apply(fontFamily: 'Nunito').copyWith(
      displayLarge: base.displayLarge?.copyWith(fontFamily: 'Outfit'),
      displayMedium: base.displayMedium?.copyWith(fontFamily: 'Outfit'),
      displaySmall: base.displaySmall?.copyWith(fontFamily: 'Outfit'),
      headlineLarge: base.headlineLarge?.copyWith(fontFamily: 'Outfit'),
      headlineMedium: base.headlineMedium?.copyWith(fontFamily: 'Outfit'),
      headlineSmall: base.headlineSmall?.copyWith(fontFamily: 'Outfit'),
      titleLarge: base.titleLarge?.copyWith(fontFamily: 'Outfit'),
      titleMedium: base.titleMedium?.copyWith(fontFamily: 'Outfit'),
      titleSmall: base.titleSmall?.copyWith(fontFamily: 'Outfit'),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryLight,
        brightness: Brightness.light,
        surface: creamBackground,
      ),
      textTheme: _buildTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: primaryDark,
        elevation: 0,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryLight,
        brightness: Brightness.dark,
        surface: primaryDark,
      ),
      textTheme: _buildTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}
