import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Figma theme.css의 --radius: 0.625rem (=10px) 기준
class AppRadius {
  AppRadius._();
  static const double sm = 6; // radius - 4
  static const double md = 8; // radius - 2
  static const double lg = 10; // radius
  static const double xl = 14; // radius + 4
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.primaryForeground,
        secondary: AppColors.secondary,
        onSecondary: AppColors.secondaryForeground,
        surface: AppColors.card,
        onSurface: AppColors.cardForeground,
        error: AppColors.destructive,
        onError: AppColors.destructiveForeground,
        outline: AppColors.border,
      ),

      // h1~h4, label, button, input 폰트 웨이트/크기는
      // theme.css의 @layer base 값을 그대로 옮김
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 24, // text-2xl
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: AppColors.foreground,
        ),
        headlineMedium: TextStyle(
          fontSize: 20, // text-xl
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: AppColors.foreground,
        ),
        headlineSmall: TextStyle(
          fontSize: 18, // text-lg
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: AppColors.foreground,
        ),
        titleMedium: TextStyle(
          fontSize: 16, // text-base
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: AppColors.foreground,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: AppColors.foreground,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
    );
  }
}
