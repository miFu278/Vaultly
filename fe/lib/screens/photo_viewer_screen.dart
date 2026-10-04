import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/photo_item.dart';
import '../theme/app_tokens.dart';
import '../widgets/neumorphic.dart';
import '../widgets/video_player_view.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<PhotoItem> photos;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  /// Filmstrip overlay metrics, also used to keep page content clear of it.
  static const double _filmstripHeight = 52;
  static const double _filmstripItemSize = 48;

  static double _filmstripReserve(BuildContext context) =>
      _filmstripHeight +
      AppSpacing.md * 2 +
      MediaQuery.of(context).padding.bottom;

  late int _currentIndex;
  late PageController _pageController;
  final ScrollController _thumbScrollController = ScrollController();
  bool _showChrome = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToThumbnail(_currentIndex, animate: false);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbScrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _scrollToThumbnail(index, animate: true);
  }

  void _scrollToThumbnail(int index, {bool animate = true}) {
    if (!_thumbScrollController.hasClients) return;
    final itemWidth = _filmstripItemSize + AppSpacing.xs * 2;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset = (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
    final clampedOffset = targetOffset.clamp(
      0.0,
      _thumbScrollController.position.maxScrollExtent,
    );

    if (animate) {
      _thumbScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _thumbScrollController.jumpTo(clampedOffset);
    }
  }

  void _toggleChrome() {
    setState(() {
      _showChrome = !_showChrome;
    });
  }

  void _showInfoSheet(PhotoItem photo) {
    final colors = AppColors.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) {
        return Neumorphic(
          depth: 1.4,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.rXl),
          ),
          clipContent: true,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Neumorphic(
                      width: 40,
                      height: 4,
                      inset: true,
                      radius: AppRadii.rPill,
                      color: colors.surfaceMuted,
                      child: const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: colors.foreground),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Thông tin ảnh',
                        style: AppTypography.heading
                            .copyWith(color: colors.foreground),
                      ),
                      const Spacer(),
                      Neumorphic(
                        inset: true,
                        radius: AppRadii.rPill,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline,
                                size: 11, color: colors.foregroundMuted),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'E2EE Encrypted',
                              style: AppTypography.caption.copyWith(
                                color: colors.foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Divider(height: 1, color: colors.border),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'Tên tệp', value: photo.title),
                  _InfoRow(
                    label: 'Loại tệp',
                    value: photo.checkIsVideo ? 'Video' : 'Ảnh',
                  ),
                  _InfoRow(
                    label: 'Ngày lưu',
                    value:
                        '${photo.createdAt.hour.toString().padLeft(2, '0')}:${photo.createdAt.minute.toString().padLeft(2, '0')} • ${photo.createdAt.day.toString().padLeft(2, '0')}/${photo.createdAt.month.toString().padLeft(2, '0')}/${photo.createdAt.year}',
                  ),
                  _InfoRow(label: 'Dung lượng', value: photo.fileSize),
                  _InfoRow(label: 'Thuật toán', value: 'XChaCha20-Poly1305'),
                  _InfoRow(
                      label: 'Trạng thái',
                      value: 'Mã hóa đầu cuối (Client E2EE)'),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currentPhoto = widget.photos[_currentIndex];

    return Scaffold(
      backgroundColor: colors.mediaCanvas,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft && _currentIndex > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                _currentIndex < widget.photos.length - 1) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.pop(context);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Center Main Photo Swiper (PageView)
            PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final photo = widget.photos[index];

                // Video plays through its own controls; a tap toggles playback
                // instead of the image-viewer chrome.
                if (photo.checkIsVideo) {
                  return Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top +
                          kToolbarHeight,
                      bottom: _filmstripReserve(context),
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
                    ),
                    child: VideoPlayerView(url: photo.fullUrl),
                  );
                }

                return GestureDetector(
                  onTap: _toggleChrome,
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    clipBehavior: Clip.none,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Hero(
                            tag: 'photo_${photo.id}',
                            child: Image.network(
                              photo.fullUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.foregroundMuted,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 48,
                                  color: colors.foregroundMuted,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Top AppBar with scrim gradient
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                opacity: _showChrome ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showChrome,
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + AppSpacing.xs,
                      bottom: AppSpacing.md,
                      left: AppSpacing.sm,
                      right: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.scrim.withValues(alpha: 0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          tooltip: 'Trở về',
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currentPhoto.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.heading.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${_currentIndex + 1} / ${widget.photos.length}',
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white70,
                                  fontFeatures: AppTypography.tabularFigures,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline, color: Colors.white, size: 20),
                          tooltip: 'Thông tin ảnh',
                          onPressed: () => _showInfoSheet(currentPhoto),
                        ),
                        IconButton(
                          icon: const Icon(Icons.download_outlined, color: Colors.white, size: 20),
                          tooltip: 'Tải về',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đang tải: ${currentPhoto.title}'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Thumbnail Filmstrip with scrim gradient
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                opacity: _showChrome ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showChrome,
                  child: Container(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
                      top: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          colors.scrim.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SizedBox(
                      height: _filmstripHeight,
                      child: ListView.builder(
                        controller: _thumbScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        itemCount: widget.photos.length,
                        itemBuilder: (context, index) {
                          final photo = widget.photos[index];
                          final isSelected = index == _currentIndex;

                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: AppMotion.fast,
                              width: _filmstripItemSize,
                              height: _filmstripItemSize,
                              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                              decoration: BoxDecoration(
                                borderRadius: AppRadii.xs,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: isSelected ? 1.5 : 0,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Opacity(
                                opacity: isSelected ? 1.0 : 0.45,
                                // Videos have no server-side poster frame, so a
                                // deliberate icon beats a failed image decode.
                                child: photo.checkIsVideo
                                    ? const ColoredBox(
                                        color: Colors.white12,
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          size: 22,
                                          color: Colors.white70,
                                        ),
                                      )
                                    : Image.network(
                                        photo.thumbnailUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const ColoredBox(
                                          color: Colors.white12,
                                          child: Icon(Icons.image,
                                              size: 20, color: Colors.white38),
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                color: colors.foregroundMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body.copyWith(
                color: colors.foreground,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
