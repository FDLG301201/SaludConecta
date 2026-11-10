import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema Material 3 de la app (sin modo oscuro).
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      background: AppColors.background,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
    );
    final text = base.textTheme;
    return base.copyWith(
      // Títulos en azul marino y negrita.
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(color: AppColors.navy, fontWeight: FontWeight.bold),
        headlineSmall: text.headlineSmall?.copyWith(color: AppColors.navy, fontWeight: FontWeight.bold),
        titleLarge: text.titleLarge?.copyWith(color: AppColors.navy, fontWeight: FontWeight.bold),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
