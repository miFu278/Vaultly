import 'package:flutter/material.dart';
import 'app_tokens.dart';

/// Neumorphic theme: no elevated Material surfaces, no hairlines on shapes.
/// Depth comes from the paired shadows in [AppShadows], so every component
/// theme here stays flat (elevation 0) and borderless.
class AppTheme {
  static ThemeData get lightTheme => _buildTheme(AppColorsData.light);
  static ThemeData get darkTheme => _buildTheme(AppColorsData.dark);

  static ThemeData _buildTheme(AppColorsData c) {
    final isDark = c.isDark;
    final hairline = BorderRadius.circular(AppRadii.rSm);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: c.primary,
        onPrimary: c.surface,
        secondary: c.foreground,
        onSecondary: c.surface,
        surface: c.surface,
        onSurface: c.foreground,
        onSurfaceVariant: c.foregroundMuted,
        surfaceContainerHighest: c.surfaceMuted,
        surfaceContainerHigh: c.surfaceMuted,
        surfaceContainer: c.surface,
        surfaceContainerLow: c.surface,
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
      ),
      dividerColor: c.border,
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.foreground,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor:
            isDark ? Colors.black : const Color(0x33A3B1C6),
        centerTitle: false,
        titleTextStyle: AppTypography.title.copyWith(color: c.foreground),
        iconTheme: IconThemeData(color: c.foregroundMuted, size: 20),
      ),
      iconTheme: IconThemeData(color: c.foregroundMuted, size: 20),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.md),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTypography.heading.copyWith(color: c.foreground),
        contentTextStyle: AppTypography.body.copyWith(color: c.foreground),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: Colors.transparent,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrimColor: c.scrim.withValues(alpha: 0.32),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.surface,
          disabledBackgroundColor: c.surfaceMuted,
          disabledForegroundColor: c.foregroundMuted,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.md),
          textStyle: AppTypography.label.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.foreground,
          backgroundColor: c.surface,
          side: BorderSide.none,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.md),
          textStyle: AppTypography.label,
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
      // Recessed, borderless fields: the darker fill is the debossed well.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: hairline,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: hairline,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: hairline,
          borderSide: BorderSide(color: c.foreground, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: hairline,
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: hairline,
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
        labelStyle: AppTypography.label.copyWith(color: c.foregroundMuted),
        hintStyle: AppTypography.label.copyWith(color: c.foregroundMuted),
        errorStyle: AppTypography.caption.copyWith(color: c.danger),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
          c.foregroundMuted.withValues(alpha: 0.4),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceMuted,
        linearMinHeight: 3,
        circularTrackColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.foreground,
          borderRadius: AppRadii.sm,
        ),
        textStyle: AppTypography.label.copyWith(color: c.surface),
        waitDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}
