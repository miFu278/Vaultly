import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/main.dart';
import 'package:vaultly/widgets/folder_sidebar.dart';
import 'package:vaultly/widgets/photo_grid.dart';
import 'package:vaultly/widgets/photo_grid_item.dart';

void main() {
  testWidgets('Desktop / Wide screen shows 2-pane layout with FolderSidebar',
      (WidgetTester tester) async {
    // Set a wide screen size (1024x768)
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const VaultlyApp());
    await tester.pumpAndSettle();

    // Verify 2-pane layout
    expect(find.byType(FolderSidebar), findsOneWidget);
    expect(find.byType(PhotoGrid), findsOneWidget);

    // Verify collapse toggle button exists on wide screen
    final collapseBtn = find.byTooltip('Thu gọn sidebar');
    expect(collapseBtn, findsOneWidget);

    // Tap collapse
    await tester.tap(collapseBtn);
    await tester.pumpAndSettle();

    // Now expand button should be visible
    expect(find.byTooltip('Mở rộng sidebar'), findsOneWidget);
  });

  testWidgets('Mobile screen (< 680px) switches to Drawer',
      (WidgetTester tester) async {
    // Set mobile screen size (400x800)
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const VaultlyApp());
    await tester.pumpAndSettle();

    // In mobile layout, FolderSidebar is inside the Drawer, not directly in body
    expect(find.byTooltip('Danh sách thư mục'), findsOneWidget);

    // Open drawer
    await tester.tap(find.byTooltip('Danh sách thư mục'));
    await tester.pumpAndSettle();

    // FolderSidebar should now be visible in Drawer
    expect(find.byType(FolderSidebar), findsOneWidget);
  });

  testWidgets('Zoom controls switch grid columns between 2x, 3x, 4x',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const VaultlyApp());
    await tester.pumpAndSettle();

    // Find 2x and 4x buttons
    final btn2x = find.text('2x');
    final btn4x = find.text('4x');

    expect(btn2x, findsOneWidget);
    expect(btn4x, findsOneWidget);

    // Tap 2x
    await tester.tap(btn2x);
    await tester.pumpAndSettle();

    final gridFinder = find.byType(GridView);
    final grid = tester.widget<GridView>(gridFinder);
    final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);

    // Tap 4x
    await tester.tap(btn4x);
    await tester.pumpAndSettle();

    final grid4x = tester.widget<GridView>(gridFinder);
    final delegate4x = grid4x.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate4x.crossAxisCount, 4);
  });

  testWidgets('Folder selection filters photos', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const VaultlyApp());
    await tester.pumpAndSettle();

    // Click on 'Tài liệu bảo mật'
    await tester.tap(find.text('Tài liệu bảo mật'));
    await tester.pumpAndSettle();

    // Verify 6 photo items are shown for 'Tài liệu bảo mật'
    expect(find.byType(PhotoGridItem), findsNWidgets(6));
  });

  testWidgets('Tapping photo opens full-screen PhotoViewerScreen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const VaultlyApp());
    await tester.pumpAndSettle();

    // Tap on first PhotoGridItem
    final firstItem = find.byType(PhotoGridItem).first;
    expect(firstItem, findsOneWidget);
    await tester.tap(firstItem);
    await tester.pumpAndSettle();

    // Verify PageView is present in PhotoViewerScreen
    expect(find.byType(PageView), findsOneWidget);
    // Verify back button is present
    expect(find.byTooltip('Trở về'), findsOneWidget);
  });
}
