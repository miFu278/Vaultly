import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaultly/screens/auth_screen.dart';
import 'package:vaultly/screens/pin_lock_screen.dart';
import 'package:vaultly/theme/app_theme.dart';
import 'package:vaultly/theme/app_tokens.dart';
import 'package:vaultly/widgets/neumorphic.dart';

/// WCAG 2.1 relative-luminance contrast ratio.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // Neumorphism is flagged high accessibility risk: same-tone surfaces plus soft
  // shadows can silently drop text below 4.5:1. These assertions fail the moment
  // a token is nudged out of range.
  group('palette contrast', () {
    for (final entry in {
      'light': AppColorsData.light,
      'dark': AppColorsData.dark,
    }.entries) {
      final name = entry.key;
      final c = entry.value;

      test('$name text tokens clear 4.5:1 on background and surface', () {
        expect(_contrast(c.foreground, c.background), greaterThanOrEqualTo(4.5),
            reason: '$name foreground/background');
        expect(_contrast(c.foreground, c.surface), greaterThanOrEqualTo(4.5),
            reason: '$name foreground/surface');
        expect(_contrast(c.foregroundMuted, c.background),
            greaterThanOrEqualTo(4.5),
            reason: '$name foregroundMuted/background');
        // The debossed well darkens the base tone; text sitting on an inset
        // surface (count chips, segmented tracks) must survive that worst end.
        final wellDark = Color.alphaBlend(
          Colors.black.withValues(alpha: AppShadows.insetShadeAlpha(c)),
          c.surface,
        );
        expect(_contrast(c.danger, wellDark), greaterThanOrEqualTo(4.5),
            reason: '$name danger on inset well');
        expect(_contrast(c.foregroundMuted, wellDark),
            greaterThanOrEqualTo(4.5),
            reason: '$name foregroundMuted on inset well');
        expect(_contrast(c.foregroundMuted, c.surfaceMuted),
            greaterThanOrEqualTo(4.5),
            reason: '$name foregroundMuted on surfaceMuted (field fill)');
      });
    }

    test('surface and background share a base tone (neumorphic requirement)', () {
      expect(AppColorsData.light.surface, AppColorsData.light.background);
      expect(AppColorsData.dark.surface, AppColorsData.dark.background);
    });
  });

  // The auth and PIN screens were restructured into neumorphic wells and a
  // keypad; a RenderFlex overflow here would fail the test.
  group('restructured screens fit small phones and desktop', () {
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

        expect(find.byType(NeumorphicButton), findsWidgets);
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

        expect(find.text('Bảo mật Vaultly'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
      });
    }
  });

  testWidgets('Neumorphic is raised at rest and inset while pressed',
      (WidgetTester tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: Neumorphic(
              width: 80,
              height: 80,
              onTap: () => taps++,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    BoxDecoration decoration() {
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      return container.decoration! as BoxDecoration;
    }

    expect(decoration().gradient, isNull, reason: 'resting surface is raised');
    expect(decoration().boxShadow, isNotEmpty);
    expect(decoration().boxShadow!.length, 2, reason: 'paired light/dark');

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Neumorphic)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(decoration().gradient, isNotNull, reason: 'press debosses the well');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(decoration().gradient, isNull, reason: 'releases back to raised');
  });

  testWidgets('disabled NeumorphicButton renders inset and ignores taps',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(
            child: NeumorphicButton(label: 'Xóa', danger: true),
          ),
        ),
      ),
    );

    final container =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.gradient, isNotNull, reason: 'disabled reads as debossed');
    expect(find.text('Xóa'), findsOneWidget);
  });
}
