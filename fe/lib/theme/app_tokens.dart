import 'package:flutter/material.dart';

/// Design tokens for Vaultly's flat UI, derived from the Nimbus Soft system in
/// `docs/nimbus_soft_file_system/DESIGN.md`.
///
/// Flat means separation comes from fills and hairlines, not from paired
/// light/dark shadows: one canvas tone, white cards, a sunken field fill, and a
/// single soft shadow only on things that float (dock, FAB, sheets).
class AppColorsData {
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color mediaCanvas;
  final Color border;
  final Color foreground;
  final Color foregroundMuted;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color success;
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
    required this.onPrimary,
    required this.primarySoft,
    required this.success,
    required this.danger,
    required this.scrim,
  });

  /// Cool mist canvas with pure white cards. `foregroundMuted` is a step darker
  /// than the design's #64748B so it still clears 4.5:1 inside the sunken
  /// field fill (#EDF2F7).
  static const light = AppColorsData(
    background: Color(0xFFF4F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEDF2F7),
    mediaCanvas: Color(0xFFE2E8F0),
    border: Color(0xFFE2E8F0),
    foreground: Color(0xFF0F172A),
    foregroundMuted: Color(0xFF475569),
    primary: Color(0xFF2563EB),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFDBE7FE),
    success: Color(0xFF047857),
    danger: Color(0xFFB3261E),
    scrim: Color(0xFF0F172A),
  );

  /// Dark variant of the same system: the canvas goes near-black, cards lift one
  /// step, and the primary becomes a lighter blue so white text stays legible.
  static const dark = AppColorsData(
    background: Color(0xFF0B1220),
    surface: Color(0xFF131C2B),
    surfaceMuted: Color(0xFF1B2637),
    mediaCanvas: Color(0xFF070D16),
    border: Color(0xFF263349),
    foreground: Color(0xFFE7EDF7),
    foregroundMuted: Color(0xFF9FB0C7),
    primary: Color(0xFF7FA8FF),
    onPrimary: Color(0xFF06122B),
    primarySoft: Color(0xFF1E2C46),
    success: Color(0xFF34D399),
    danger: Color(0xFFFF8A80),
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

class AppElevation {
  /// Floating chrome: bottom dock, FAB, selection bar.
  static List<BoxShadow> floating(AppColorsData c) {
    return [
      BoxShadow(
        color: (c.isDark ? Colors.black : const Color(0xFF0F172A))
            .withValues(alpha: c.isDark ? 0.55 : 0.10),
        offset: const Offset(0, 10),
        blurRadius: 24,
        spreadRadius: -6,
      ),
    ];
  }
}

/// Pastel accents from the reference design: one tint per media category used by
/// the icon tiles, the storage gauge and the album covers.
enum AppTintKind { amber, blue, green, pink, violet }

class AppTint {
  final Color background;
  final Color foreground;

  const AppTint(this.background, this.foreground);

  static AppTint of(BuildContext context, AppTintKind kind) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    switch (kind) {
      case AppTintKind.amber:
        return dark
            ? const AppTint(Color(0x33F59E0B), Color(0xFFFBBF24))
            : const AppTint(Color(0xFFFEF3C7), Color(0xFFB45309));
      case AppTintKind.blue:
        return dark
            ? const AppTint(Color(0x332563EB), Color(0xFF93B4FD))
            : const AppTint(Color(0xFFDBEAFE), Color(0xFF1D4ED8));
      case AppTintKind.green:
        return dark
            ? const AppTint(Color(0x3310B981), Color(0xFF6EE7B7))
            : const AppTint(Color(0xFFD1FAE5), Color(0xFF047857));
      case AppTintKind.pink:
        return dark
            ? const AppTint(Color(0x33EC4899), Color(0xFFF9A8D4))
            : const AppTint(Color(0xFFFCE7F3), Color(0xFFBE185D));
      case AppTintKind.violet:
        return dark
            ? const AppTint(Color(0x338B5CF6), Color(0xFFC4B5FD))
            : const AppTint(Color(0xFFEDE9FE), Color(0xFF6D28D9));
    }
  }
}

class AppMotion {
  /// Press/tap feedback must land inside the 80-150ms window.
  static const Duration fast = Duration(milliseconds: 130);
  /// Surface state changes (selection, tab switch).
  static const Duration medium = Duration(milliseconds: 200);
  static const Curve ease = Curves.easeOut;
}

class AppTypography {
  static const brand = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static const titleLg = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );

  static const title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const heading = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const micro = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];
}

/// Corner scale from the design: cards sit at 20-28, controls are pills.
class AppRadii {
  static const double rXs = 8.0;
  static const double rSm = 12.0;
  static const double rMd = 16.0;
  static const double rLg = 20.0;
  static const double rXl = 28.0;
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

  /// Screen margin from the design (`1.25rem`).
  static const double margin = 20.0;

  /// Minimum hit target (44pt iOS / 48dp Android).
  static const double touchTarget = 44.0;

  /// Below this width the shell uses a drawer, a dock and a single column.
  static const double paneBreakpoint = 680.0;
  static const double railWidth = 248.0;
  static const double contentMax = 1040.0;
  static const double formMax = 460.0;
  static const double dialogMax = 420.0;
}
