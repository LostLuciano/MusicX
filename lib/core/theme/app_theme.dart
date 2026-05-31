import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme => getDarkTheme(const Color(0xFF9D4EDD));

  static ThemeData getDarkTheme(Color primaryColor) {
    final Color secondaryColor = primaryColor.withValues(alpha: 0.25);
    final Color surfaceColor = const Color(0xFF131022); 
    final Color backgroundColor = const Color(0xFF0F0C1B);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,

      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: Colors.redAccent,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),

      textTheme: TextTheme(
        headlineMedium: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
        titleLarge: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(
          color: Colors.white.withValues(alpha: 0.90),
          fontSize: 16,
        ),
        bodyMedium: const TextStyle(color: Colors.white60, fontSize: 14),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: Colors.white10,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withValues(alpha: 0.2),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
