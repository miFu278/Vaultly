import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaultly/main.dart';
import 'package:vaultly/screens/auth_screen.dart';
import 'package:vaultly/screens/pin_lock_screen.dart';
import 'package:vaultly/theme/app_theme.dart';
import 'package:vaultly/theme/app_tokens.dart';
import 'package:vaultly/widgets/flat.dart';

/// WCAG 2.1 relative-luminance contrast ratio.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // A flat palette separates surfaces with fills and hairlines instead of
  // shadows, so a tone nudged out of range has nothing left to hide behind.
  // These assertions fail the moment a token drops below 4.5:1.
  group('palette contrast', () {
    for (final entry in {
      'light': AppColorsData.light,
      'dark': AppColorsData.dark,
    }.entries) {
      final name = entry.key;
      final c = entry.value;

      test('$name text tokens clear 4.5:1 on every surface they sit on', () {
        expect(_contrast(c.foreground, c.background), greaterThanOrEqualTo(4.5),
            reason: '$name foreground/background');
        expect(_contrast(c.foreground, c.surface), greaterThanOrEqualTo(4.5),
            reason: '$name foreground/surface');
        expect(_contrast(c.foregroundMuted, c.background),
            greaterThanOrEqualTo(4.5),
            reason: '$name foregroundMuted/background');
        expect(_contrast(c.foregroundMuted, c.surface), greaterThanOrEqualTo(4.5),
            reason: '$name foregroundMuted/surface');
        expect(_contrast(c.foregroundMuted, c.surfaceMuted),
            greaterThanOrEqualTo(4.5),
            reason: '$name foregroundMuted/surfaceMuted (field fill)');
        expect(_contrast(c.danger, c.surface), greaterThanOrEqualTo(4.5),
            reason: '$name danger/surface');
        expect(_contrast(c.primary, c.surface), greaterThanOrEqualTo(4.5),
            reason: '$name primary/surface (accent text)');
      });

      test('$name filled primary button keeps its label readable', () {
        expect(_contrast(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5),
            reason: '$name onPrimary/primary');
      });
    }
  });

  // The reference design is the light variant, so the app must not follow a
  // phone that happens to be in dark mode.
  testWidgets('app opens in light mode even when the system is dark',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const VaultlyApp());
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.light,
    );
  });

  group('flat surfaces', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('cards have no elevation and are separated by a hairline',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(child: SurfaceCard(child: Text('Nội dung'))),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(SurfaceCard),
              matching: find.byType(Material),
            )
            .first,
      );

      expect(material.elevation, 0, reason: 'flat cards cast no shadow');
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.style, BorderStyle.solid,
          reason: 'the hairline is what separates a card from the canvas');
    });
  });

  // The unlock and auth screens are the tallest fixed layouts in the app; a
  // RenderFlex overflow on a small phone fails here.
  group('screens fit small phones and desktop', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    for (final size in const [Size(320, 568), Size(360, 640), Size(1024, 768)]) {
      testWidgets('auth screen at ${size.width}x${size.height}',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: AuthScreen(onSuccess: () {}),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(PillButton), findsWidgets);
        expect(find.text('Kho ảnh riêng tư, mã hóa đầu cuối'), findsOneWidget);
      });

      testWidgets('pin lock screen at ${size.width}x${size.height}',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: PinLockScreen(
            mode: PinLockMode.unlock,
            onSuccess: () {},
            onLogout: () {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('VAULTLY'), findsWidgets);
        expect(find.text('5'), findsOneWidget);
        expect(find.text('Đăng nhập bằng mật khẩu'), findsOneWidget);
      });
    }
  });

  // The PIN screen must accept digits from the keypad and show the filled dots.
  testWidgets('keypad fills the PIN dots and clears on backspace',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: PinLockScreen(
        mode: PinLockMode.unlock,
        onSuccess: () {},
        onLogout: () {},
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();

    // Two of six dots are filled: the primary fill is the only coloured dot.
    final dots = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((widget) => widget.decoration as BoxDecoration)
        .where((decoration) => decoration.shape == BoxShape.circle)
        .toList();
    final filled = dots.where(
      (decoration) => decoration.color == AppColorsData.light.primary,
    );
    expect(filled.length, 2);

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    final afterBackspace = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((widget) => widget.decoration as BoxDecoration)
        .where(
          (decoration) =>
              decoration.shape == BoxShape.circle &&
              decoration.color == AppColorsData.light.primary,
        );
    expect(afterBackspace.length, 1);
  });
}
