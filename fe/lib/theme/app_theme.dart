import 'package:flutter/material.dart';
import 'app_tokens.dart';

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(AppColorsData.light);
  static ThemeData get darkTheme => _buildTheme(AppColorsData.dark);

  static ThemeData _buildTheme(AppColorsData c) {
    final isDark = c.background.computeLuminance() < 0.5;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: c.primary,
        onPrimary: c.surface,
        secondary: c.foreground,
        onSecondary: c.surface,
        surface: c.surface,
        onSurface: c.foreground,
        surfaceContainerHighest: c.surfaceMuted,
        outline: c.border,
        error: c.danger,
        onError: Colors.white,
      ),
      dividerColor: c.border,
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.title.copyWith(color: c.foreground),
        iconTheme: IconThemeData(color: c.foreground, size: 20),
        shape: Border(
          bottom: BorderSide(color: c.border, width: 1),
        ),
      ),
      iconTheme: IconThemeData(color: c.foregroundMuted, size: 20),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.md,
          side: BorderSide(color: c.border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.lg,
          side: BorderSide(color: c.border, width: 1),
        ),
        titleTextStyle: AppTypography.heading.copyWith(color: c.foreground),
        contentTextStyle: AppTypography.body.copyWith(color: c.foreground),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.surface,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.sm),
          textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.foreground,
          side: BorderSide(color: c.border, width: 1),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.sm),
          textStyle: AppTypography.body,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.foregroundMuted,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.sm),
          textStyle: AppTypography.body,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: AppRadii.sm,
          borderSide: BorderSide(color: c.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.sm,
          borderSide: BorderSide(color: c.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.sm,
          borderSide: BorderSide(color: c.foreground, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.sm,
          borderSide: BorderSide(color: c.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.sm,
          borderSide: BorderSide(color: c.danger, width: 1),
        ),
        labelStyle: AppTypography.label.copyWith(color: c.foregroundMuted),
        hintStyle: AppTypography.label.copyWith(color: c.foregroundMuted),
        errorStyle: AppTypography.caption.copyWith(color: c.danger),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.foreground,
        contentTextStyle: AppTypography.body.copyWith(color: c.surface),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sm),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.border,
        linearMinHeight: 2,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.foreground,
          borderRadius: AppRadii.xs,
        ),
        textStyle: AppTypography.label.copyWith(color: c.surface),
        waitDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}
