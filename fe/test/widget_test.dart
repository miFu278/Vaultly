import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaultly/main.dart';
import 'package:vaultly/screens/home_screen.dart';
import 'package:vaultly/screens/onboarding_screen.dart';

void main() {
  testWidgets('VaultlyApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'vaultly_onboarding_done': true});

    await tester.pumpWidget(const VaultlyApp());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Tổng quan'), findsWidgets);
  });

  // A first run shows the introduction, and skipping it must not show again.
  testWidgets('First run shows the intro once, then the shell',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const VaultlyApp());
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Bỏ qua'), findsOneWidget);

    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('vaultly_onboarding_done'), isTrue);
  });

  testWidgets('Intro advances to the last page and finishes with the check button',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const VaultlyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tiếp tục'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Bắt đầu'), findsOneWidget);
    await tester.tap(find.byTooltip('Bắt đầu'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
