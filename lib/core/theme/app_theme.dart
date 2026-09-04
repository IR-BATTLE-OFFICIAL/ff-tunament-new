import 'package:flutter/material.dart';

class AppColors {
  // Primary Esports Gold / Amber
  static const Color primary = Color(0xFFFFB800);
  static const Color primaryDark = Color(0xFFD49B00);
  static const Color primaryLight = Color(0xFFFFD54F);

  // Background & Surface
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceLight = Color(0xFF21262D);
  static const Color surfaceElevated = Color(0xFF2D333B);
  static const Color secondary = Color(0xFF30363D);

  // Text colors
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF6E7681);

  // Gaming Accent Neons
  static const Color accent = Color(0xFF00E5FF); // Electric Cyan
  static const Color neonGreen = Color(0xFF00E676); // Victory Green
  static const Color neonRed = Color(0xFFFF1744); // Live Red
  static const Color neonPurple = Color(0xFFD500F9); // Special
  static const Color goldGradientStart = Color(0xFFFFD700);
  static const Color goldGradientEnd = Color(0xFFFF8F00);

  // Gradients
  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldGradientStart, goldGradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF0091EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00B248)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1C222B), Color(0xFF12161D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ),
    scaffoldBackgroundColor: AppColors.background,
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF30363D), width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.primary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
      iconTheme: IconThemeData(color: AppColors.primary),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      titleLarge: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      titleMedium: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 15),
      bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 13),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.8),
        elevation: 6,
        shadowColor: AppColors.primary.withValues(alpha: 0.4),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF30363D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF30363D)),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
  );
}
