import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/main.dart';

void main() {
  testWidgets('VaultlyApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VaultlyApp());
    await tester.pumpAndSettle();

    // Verify brand or folder is rendered.
    expect(find.text('Tất cả ảnh'), findsWidgets);
  });
}
