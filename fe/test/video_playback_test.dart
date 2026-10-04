import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/models/photo_item.dart';
import 'package:vaultly/screens/photo_viewer_screen.dart';
import 'package:vaultly/theme/app_theme.dart';
import 'package:vaultly/widgets/neumorphic.dart';
import 'package:vaultly/widgets/photo_grid_item.dart';
import 'package:vaultly/widgets/video_player_view.dart';

PhotoItem _item(String id, {required bool isVideo, String? title}) {
  return PhotoItem(
    id: id,
    folderId: 'all',
    title: title ?? (isVideo ? 'clip.mp4' : 'photo.jpg'),
    thumbnailUrl: 'https://example.test/files/$id/view',
    fullUrl: 'https://example.test/files/$id/view?token=t',
    createdAt: DateTime(2026, 1, 1),
    fileSize: '1.2 MB',
    isVideo: isVideo,
  );
}

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  // Videos must not go through Image.network: the endpoint returns the decrypted
  // video stream, so the tile would download the entire file to fail decoding.
  group('video grid tile', () {
    testWidgets('renders a video card without any Image fetch',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 200,
            height: 200,
            child: PhotoGridItem(photo: _item('v1', isVideo: true)),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('clip.mp4'), findsOneWidget);
    });

    testWidgets('image tile still uses a network image',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 200,
            height: 200,
            child: PhotoGridItem(photo: _item('p1', isVideo: false)),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('photo viewer routing', () {
    testWidgets('video opens the player, not the image viewer',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          PhotoViewerScreen(
            photos: [_item('v1', isVideo: true)],
            initialIndex: 0,
          ),
        ),
      );
      // No pumpAndSettle: the player shows a spinner while (not) initializing.
      await tester.pump();
      await tester.pump();

      expect(find.byType(VideoPlayerView), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('image opens the image viewer, not the player',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          PhotoViewerScreen(
            photos: [_item('p1', isVideo: false)],
            initialIndex: 0,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(VideoPlayerView), findsNothing);
      expect(find.byType(Image), findsWidgets);
    });
  });

  // The plugin is unavailable in a widget test, which is exactly the failure
  // mode the UI has to survive: a clear message plus a retry, never a crash.
  testWidgets('video player degrades to an error state with retry',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(const VideoPlayerView(url: 'https://example.test/files/v1/view')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Không phát được'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NeumorphicButton),
        matching: find.text('Thử lại'),
      ),
      findsOneWidget,
    );
  });
}
