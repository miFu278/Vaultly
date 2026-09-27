import 'package:flutter/material.dart';

/// Design tokens from DESIGN.md (monochrome language for Vaultly).
class AppColorsData {
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color mediaCanvas;
  final Color border;
  final Color foreground;
  final Color foregroundMuted;
  final Color primary;
  final Color danger;
  final Color scrim;

  const AppColorsData({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.mediaCanvas,
    required this.border,
    required this.foreground,
    required this.foregroundMuted,
    required this.primary,
    required this.danger,
    required this.scrim,
  });

  static const light = AppColorsData(
    background: Color(0xFFF9FAFB),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF3F4F6),
    mediaCanvas: Color(0xFFF3F4F6),
    border: Color(0xFFE5E7EB),
    foreground: Color(0xFF111827),
    foregroundMuted: Color(0xFF6B7280),
    primary: Color(0xFF111827),
    danger: Color(0xFFFF5252),
    scrim: Color(0xFF000000),
  );

  static const dark = AppColorsData(
    background: Color(0xFF0F0F11),
    surface: Color(0xFF18181B),
    surfaceMuted: Color(0xFF27272A),
    mediaCanvas: Color(0xFF101012),
    border: Color(0xFF27272A),
    foreground: Color(0xFFF4F4F5),
    foregroundMuted: Color(0xFFA1A1AA),
    primary: Color(0xFFF4F4F5),
    danger: Color(0xFFFF5252),
    scrim: Color(0xFF000000),
  );
}

class AppColors {
  static AppColorsData of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColorsData.dark
        : AppColorsData.light;
  }
}

class AppTypography {
  static const brand = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static const titleLg = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const heading = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const body = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  static const micro = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
  );

  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];
}

class AppRadii {
  static const double rXs = 6.0;
  static const double rSm = 8.0;
  static const double rMd = 10.0;
  static const double rLg = 12.0;
  static const double rXl = 16.0;

  static const xs = BorderRadius.all(Radius.circular(rXs));
  static const sm = BorderRadius.all(Radius.circular(rSm));
  static const md = BorderRadius.all(Radius.circular(rMd));
  static const lg = BorderRadius.all(Radius.circular(rLg));
  static const xl = BorderRadius.all(Radius.circular(rXl));

  static const radiusXs = Radius.circular(rXs);
  static const radiusSm = Radius.circular(rSm);
  static const radiusMd = Radius.circular(rMd);
  static const radiusLg = Radius.circular(rLg);
  static const radiusXl = Radius.circular(rXl);
}

class AppSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  static const double paneBreakpoint = 680.0;
  static const double sidebarCollapsed = 68.0;
  static const double sidebarExpanded = 250.0;
  static const double formMax = 440.0;
  static const double dialogMax = 800.0;
}
