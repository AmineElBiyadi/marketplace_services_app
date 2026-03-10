import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.primaryForeground,
        secondary: AppColors.secondary,
        onSecondary: AppColors.secondaryForeground,
        surface: AppColors.card,
        onSurface: AppColors.foreground,
        background: AppColors.background,
        onBackground: AppColors.foreground,
        error: AppColors.destructive,
        onError: AppColors.destructiveForeground,
        outline: AppColors.border,
      ),
      scaffoldBackgroundColor: AppColors.background,
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.card.withOpacity(0.6),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.mutedForeground,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.foreground,
          side: const BorderSide(color: AppColors.accent, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.foreground),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.foreground),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.foreground),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.foreground),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.foreground),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.foreground),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground),
        titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.foreground),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.foreground),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.foreground),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.foreground),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.foreground),
      ),
    );
  }

  static ThemeData get darkTheme {
    return lightTheme.copyWith(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.primaryForeground,
        secondary: AppColors.secondary,
        onSecondary: AppColors.secondaryForeground,
        surface: AppColors.card,
        onSurface: AppColors.foreground,
        background: AppColors.background,
        onBackground: AppColors.foreground,
        error: AppColors.destructive,
        onError: AppColors.destructiveForeground,
        outline: AppColors.border,
      ),
    );
  }
}
