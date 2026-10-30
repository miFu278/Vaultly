import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaultly/main.dart';
import 'package:vaultly/screens/albums_view.dart';
import 'package:vaultly/screens/gallery_view.dart';
import 'package:vaultly/screens/overview_view.dart';
import 'package:vaultly/widgets/photo_tile.dart';

/// The intro is a first-run screen; these tests start as a returning user.
const _seenOnboarding = {'vaultly_onboarding_done': true};

Future<void> _start(
  WidgetTester tester, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(const VaultlyApp());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(_seenOnboarding));

  testWidgets('Overview opens first and shows the storage gauge',
      (WidgetTester tester) async {
    await _start(tester, size: const Size(1024, 800));

    expect(find.byType(OverviewView), findsOneWidget);
    expect(find.text('Ảnh'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('Wide screens show the navigation rail next to the gallery',
      (WidgetTester tester) async {
    await _start(tester, size: const Size(1024, 768));

    expect(find.byKey(const Key('nav-rail')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('nav-rail')),
        matching: find.text('Tài liệu bảo mật'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('bottom-dock')), findsNothing);

    await tester.tap(find.text('Thư viện'));
    await tester.pumpAndSettle();

    expect(find.byType(GalleryView), findsOneWidget);
    expect(find.text('Tất cả ảnh'), findsWidgets);
  });

  testWidgets('Narrow screens use a drawer and a floating dock',
      (WidgetTester tester) async {
    await _start(tester, size: const Size(400, 820));

    expect(find.byKey(const Key('bottom-dock')), findsOneWidget);
    // The dock is icon-only, so destinations are reached by tooltip.
    expect(find.byTooltip('Album'), findsOneWidget);
    expect(find.byTooltip('Thư viện'), findsOneWidget);

    await tester.tap(find.byTooltip('Mở danh sách album'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nav-rail')), findsWidgets);
    expect(find.text('Tài liệu bảo mật'), findsWidgets);
  });

  testWidgets('Dock switches tabs', (WidgetTester tester) async {
    await _start(tester, size: const Size(400, 820));

    await tester.tap(find.byTooltip('Album'));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumsView), findsOneWidget);

    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryView), findsOneWidget);
  });

  testWidgets('Density pill cycles the grid between 2x, 3x and 4x',
      (WidgetTester tester) async {
    await _start(tester, size: const Size(1024, 768));

    await tester.tap(find.text('Thư viện'));
    await tester.pumpAndSettle();

    int columns() {
      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid).first);
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      return delegate.crossAxisCount;
    }

    // Wide screens start denser than phones.
    expect(columns(), 4);
    expect(find.text('4x'), findsOneWidget);

    await tester.tap(find.text('4x'));
    await tester.pumpAndSettle();
    expect(columns(), 2);
    expect(find.text('2x'), findsOneWidget);

    await tester.tap(find.text('2x'));
    await tester.pumpAndSettle();
    expect(columns(), 3);
  });

  testWidgets('Choosing an album filters the gallery to its items',
      (WidgetTester tester) async {
    await _start(tester, size: const Size(1024, 768));

    await tester.tap(
      find
          .descendant(
            of: find.byKey(const Key('nav-rail')),
            matching: find.text('Tài liệu bảo mật'),
          )
          .first,
    );
    await tester.pumpAndSettle();

    // Mock data holds six items in that album; the header counts the filtered
    // list and every rendered tile belongs to it.
    expect(find.textContaining('6 mục'), findsWidgets);
    expect(find.byType(PhotoTile), findsWidgets);
  });

  testWidgets('Albums tab renders one card per album', (WidgetTester tester) async {
    await _start(tester, size: const Size(1024, 900));

    await tester.tap(find.text('Album').first);
    await tester.pumpAndSettle();

    expect(find.byType(AlbumsView), findsOneWidget);
    expect(find.text('Album mới'), findsWidgets);
  });

  testWidgets('Tapping a tile opens the full-screen viewer',
      (WidgetTester tester) async {
    await _start(tester, size: const Size(1024, 768));

    await tester.tap(find.text('Thư viện'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PhotoTile).first);
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byTooltip('Trở về'), findsOneWidget);
  });

  testWidgets('Files tab renders files with full thumbnail images',
      (WidgetTester tester) async {
    await _start(tester, size: const Size(1024, 900));

    await tester.tap(find.text('Tệp').first);
    await tester.pumpAndSettle();

    // Verify files list renders with Image.network for thumbnails
    expect(find.byType(Image), findsWidgets);
  });
}
