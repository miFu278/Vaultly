import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    const surfaceColor = Color(0xFFFFFFFF);
    const backgroundColor = Color(0xFFF9FAFB);
    const borderColor = Color(0xFFE5E7EB);
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF6B7280);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.light(
        primary: textPrimary,
        onPrimary: surfaceColor,
        surface: surfaceColor,
        onSurface: textPrimary,
        outline: borderColor,
        surfaceContainerHighest: Color(0xFFF3F4F6),
      ),
      dividerColor: borderColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 22),
      ),
      iconTheme: const IconThemeData(color: textSecondary, size: 20),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: textPrimary.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  static ThemeData get darkTheme {
    const surfaceColor = Color(0xFF18181B);
    const backgroundColor = Color(0xFF0F0F11);
    const borderColor = Color(0xFF27272A);
    const textPrimary = Color(0xFFF4F4F5);
    const textSecondary = Color(0xFFA1A1AA);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: textPrimary,
        onPrimary: backgroundColor,
        surface: surfaceColor,
        onSurface: textPrimary,
        outline: borderColor,
        surfaceContainerHighest: Color(0xFF27272A),
      ),
      dividerColor: borderColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 22),
      ),
      iconTheme: const IconThemeData(color: textSecondary, size: 20),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}
