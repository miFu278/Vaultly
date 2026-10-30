import 'package:flutter/material.dart';
import 'app_tokens.dart';

/// Flat Material 3 theme: no surface tint, no gradient wells. Cards are white
/// with a hairline, fields are a sunken fill, controls are pill shaped.
class AppTheme {
  static ThemeData get lightTheme => _buildTheme(AppColorsData.light);
  static ThemeData get darkTheme => _buildTheme(AppColorsData.dark);

  static ThemeData _buildTheme(AppColorsData c) {
    final isDark = c.isDark;
    final scheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.foreground,
      secondary: c.foreground,
      onSecondary: c.surface,
      tertiary: c.success,
      onTertiary: c.surface,
      surface: c.surface,
      onSurface: c.foreground,
      onSurfaceVariant: c.foregroundMuted,
      surfaceContainerHighest: c.surfaceMuted,
      surfaceContainerHigh: c.surfaceMuted,
      surfaceContainer: c.surface,
      surfaceContainerLow: c.background,
      surfaceContainerLowest: c.surface,
      surfaceDim: c.background,
      surfaceBright: c.surface,
      outline: c.border,
      outlineVariant: c.border,
      surfaceTint: Colors.transparent,
      shadow: Colors.black,
      scrim: c.scrim,
      inverseSurface: c.foreground,
      onInverseSurface: c.surface,
      error: c.danger,
      onError: isDark ? c.background : Colors.white,
      errorContainer: c.danger.withValues(alpha: 0.12),
      onErrorContainer: c.danger,
    );

    final pill = const RoundedRectangleBorder(borderRadius: AppRadii.pill);
    final field = OutlineInputBorder(
      borderRadius: AppRadii.md,
      borderSide: BorderSide.none,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      splashFactory: InkSparkle.splashFactory,
      dividerColor: c.border,
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      textTheme: Typography.material2021().black.apply(
            bodyColor: c.foreground,
            displayColor: c.foreground,
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.title.copyWith(color: c.foreground),
        iconTheme: IconThemeData(color: c.foregroundMuted, size: 20),
      ),
      iconTheme: IconThemeData(color: c.foregroundMuted, size: 20),
      focusColor: c.primary.withValues(alpha: 0.24),
      hoverColor: c.primary.withValues(alpha: 0.06),
      highlightColor: c.primary.withValues(alpha: 0.10),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.lg,
          side: BorderSide(color: c.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.xl),
        titleTextStyle: AppTypography.heading.copyWith(color: c.foreground),
        contentTextStyle: AppTypography.body.copyWith(color: c.foreground),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.rXl)),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(),
        scrimColor: c.scrim.withValues(alpha: 0.38),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.surfaceMuted,
          disabledForegroundColor: c.foregroundMuted,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: pill,
          textStyle: AppTypography.label,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.foreground,
          backgroundColor: c.surface,
          side: BorderSide(color: c.border),
          elevation: 0,
          shape: pill,
          textStyle: AppTypography.label,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          shape: pill,
          textStyle: AppTypography.label,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          // 44px tall so a text link is a legal touch target on its own.
          minimumSize: const Size(44, 44),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceMuted,
        border: field,
        enabledBorder: field,
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.md,
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.md,
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.md,
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
        labelStyle: AppTypography.label.copyWith(color: c.foregroundMuted),
        hintStyle: AppTypography.body.copyWith(color: c.foregroundMuted),
        errorStyle: AppTypography.caption.copyWith(color: c.danger),
        prefixIconColor: c.foregroundMuted,
        suffixIconColor: c.foregroundMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.foreground,
        contentTextStyle: AppTypography.body.copyWith(color: c.surface),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.md),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(4),
        radius: const Radius.circular(AppRadii.rXs),
        thumbColor: WidgetStatePropertyAll(
          c.foregroundMuted.withValues(alpha: 0.35),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceMuted,
        linearMinHeight: 3,
        circularTrackColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.foreground, borderRadius: AppRadii.sm),
        textStyle: AppTypography.label.copyWith(color: c.surface),
        waitDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}
