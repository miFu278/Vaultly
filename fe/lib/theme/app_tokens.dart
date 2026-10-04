import 'package:flutter/material.dart';

/// Design tokens for Vaultly's Neumorphic language (see DESIGN.md).
///
/// Neumorphism only reads correctly when `surface` and `background` are the
/// same base tone: shapes are not separated by borders, they are extruded from
/// the canvas by a paired light/dark shadow (light source: top-left).
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

  /// Light theme reads as soft, cool ceramic. `surface == background` so the
  /// extrusion shadows do the separating (Neumorphism requires same-tone base).
  static const light = AppColorsData(
    background: Color(0xFFE8EDF3),
    surface: Color(0xFFE8EDF3),
    surfaceMuted: Color(0xFFE0E6ED),
    mediaCanvas: Color(0xFFDDE4EC),
    border: Color(0xFFD5DDE6),
    foreground: Color(0xFF2C333D),
    foregroundMuted: Color(0xFF555F6B),
    primary: Color(0xFF2C333D),
    danger: Color(0xFFAE2F2A),
    scrim: Color(0xFF000000),
  );

  /// Dark theme inverts the light source: dark shadow stays black, the
  /// highlight becomes a faint white sheen on the same base tone.
  static const dark = AppColorsData(
    background: Color(0xFF23262B),
    surface: Color(0xFF23262B),
    surfaceMuted: Color(0xFF1E2126),
    mediaCanvas: Color(0xFF191B1F),
    border: Color(0xFF2E3238),
    foreground: Color(0xFFE8EAED),
    foregroundMuted: Color(0xFF9BA3AE),
    primary: Color(0xFFE8EAED),
    danger: Color(0xFFFF6B6B),
    scrim: Color(0xFF000000),
  );

  bool get isDark => background.computeLuminance() < 0.5;
}

class AppColors {
  static AppColorsData of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColorsData.dark
        : AppColorsData.light;
  }
}

/// Neumorphic extrusion shadows. Raised = two offsets away from the light
/// source; inset = a diagonal gradient that reads as a debossed well.
class AppShadows {
  static const Color _lightDark = Color(0x4DA3B1C6);
  static const Color _lightHighlight = Color(0xCCFFFFFF);
  static const Color _darkDark = Color(0x66000000);
  static const Color _darkHighlight = Color(0x14FFFFFF);

  /// Outer extrusion. `depth` scales the offset/blur for hierarchy
  /// (1 = resting card, 1.4 = dialog/overlay).
  static List<BoxShadow> raised(AppColorsData c, {double depth = 1.0}) {
    final dark = c.isDark ? _darkDark : _lightDark;
    final light = c.isDark ? _darkHighlight : _lightHighlight;
    final d = 5.0 * depth;
    final b = 10.0 * depth;
    return [
      BoxShadow(color: dark, offset: Offset(d, d), blurRadius: b),
      BoxShadow(color: light, offset: Offset(-d, -d), blurRadius: b),
    ];
  }

  /// Recessed well: no outer shadow, just a hairline inner edge so the shape
  /// never disappears at low contrast.
  static List<BoxShadow> inset(AppColorsData c) {
    return [
      BoxShadow(
        color: (c.isDark ? Colors.black : const Color(0xFFA3B1C6))
            .withValues(alpha: c.isDark ? 0.45 : 0.28),
        offset: const Offset(2, 2),
        blurRadius: 4,
        spreadRadius: -2,
      ),
    ];
  }

  /// Darkness of the debossed shade. Also the worst case for text contrast on
  /// an inset well, so the contrast guard reads it from here.
  static double insetShadeAlpha(AppColorsData c) => c.isDark ? 0.32 : 0.07;
  static double insetSheenAlpha(AppColorsData c) => c.isDark ? 0.05 : 0.70;

  /// Debossed background for wells, tracks and pressed states.
  static LinearGradient insetGradient(AppColorsData c, [Color? baseColor]) {
    final base = baseColor ?? c.surface;
    final shade = Colors.black.withValues(alpha: insetShadeAlpha(c));
    final sheen = Colors.white.withValues(alpha: insetSheenAlpha(c));
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.alphaBlend(shade, base), Color.alphaBlend(sheen, base)],
    );
  }
}

class AppMotion {
  /// Press/tap feedback must land inside the 80-150ms window.
  static const Duration fast = Duration(milliseconds: 130);
  /// Surface state changes (raised -> inset, selection).
  static const Duration medium = Duration(milliseconds: 200);
  static const Curve ease = Curves.easeOut;
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

/// Neumorphism wants generous corners: a 10-14px range is the "soft ceramic"
/// band, larger surfaces step up from there.
class AppRadii {
  static const double rXs = 10.0;
  static const double rSm = 12.0;
  static const double rMd = 14.0;
  static const double rLg = 18.0;
  static const double rXl = 24.0;
  static const double rPill = 999.0;

  static const xs = BorderRadius.all(Radius.circular(rXs));
  static const sm = BorderRadius.all(Radius.circular(rSm));
  static const md = BorderRadius.all(Radius.circular(rMd));
  static const lg = BorderRadius.all(Radius.circular(rLg));
  static const xl = BorderRadius.all(Radius.circular(rXl));
  static const pill = BorderRadius.all(Radius.circular(rPill));

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

  /// Minimum hit target (44pt iOS / 48dp Android).
  static const double touchTarget = 44.0;

  static const double paneBreakpoint = 680.0;
  static const double sidebarCollapsed = 68.0;
  static const double sidebarExpanded = 250.0;
  static const double formMax = 440.0;
  static const double dialogMax = 800.0;
}
