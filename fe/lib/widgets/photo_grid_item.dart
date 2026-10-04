import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/photo_item.dart';
import '../theme/app_tokens.dart';
import 'neumorphic.dart';

class PhotoGridItem extends StatefulWidget {
  final PhotoItem photo;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelectToggle;

  const PhotoGridItem({
    super.key,
    required this.photo,
    this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectToggle,
  });

  @override
  State<PhotoGridItem> createState() => _PhotoGridItemState();
}

/// Video preview tile: attempts to initialize a lightweight video controller
/// to display the first frame (poster) of the video with range-stream support,
/// overlayed with an extruded play disc, formatted title, and duration badge.
/// Gracefully falls back to a clean Neumorphic well if uninitialized or on error.
class VideoThumbnailTile extends StatefulWidget {
  final PhotoItem photo;
  final AppColorsData colors;
  final String title;
  final String fileSize;

  const VideoThumbnailTile({
    super.key,
    required this.photo,
    required this.colors,
    required this.title,
    required this.fileSize,
  });

  @override
  State<VideoThumbnailTile> createState() => _VideoThumbnailTileState();
}

class _VideoThumbnailTileState extends State<VideoThumbnailTile> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPreview();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.thumbnailUrl != widget.photo.thumbnailUrl) {
      _releaseController();
      _initPreview();
    }
  }

  @override
  void dispose() {
    _releaseController();
    super.dispose();
  }

  void _releaseController() {
    final c = _controller;
    _controller = null;
    if (c != null) {
      c.dispose().catchError((_) {});
    }
  }

  Future<void> _initPreview() async {
    final url = widget.photo.thumbnailUrl;
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted || _controller != controller) return;
      await controller.setVolume(0.0);
      await controller.pause();
      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (_) {
      if (!mounted || _controller != controller) return;
      setState(() => _hasError = true);
    }
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return 'VIDEO';
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.photo.displayTitle.isNotEmpty
        ? widget.photo.displayTitle
        : widget.title;

    final controller = _controller;
    final showVideo = _isInitialized &&
        !_hasError &&
        controller != null &&
        controller.value.isInitialized;

    return Neumorphic(
      inset: true,
      radius: AppRadii.rXs,
      color: widget.colors.mediaCanvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video preview layer (First frame)
          if (showVideo) ...[
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller.value.size.width > 0
                      ? controller.value.size.width
                      : 200,
                  height: controller.value.size.height > 0
                      ? controller.value.size.height
                      : 200,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            // Gradient scrim for contrast
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Centered Neumorphic Play Disc
          Center(
            child: Neumorphic(
              width: 38,
              height: 38,
              radius: AppRadii.rPill,
              depth: 0.8,
              color: showVideo ? Colors.black.withValues(alpha: 0.45) : null,
              child: Icon(
                Icons.play_arrow_rounded,
                size: 24,
                color: showVideo ? Colors.white : widget.colors.foreground,
              ),
            ),
          ),

          // Duration / Video badge
          Positioned(
            top: AppSpacing.xs,
            right: AppSpacing.xs,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                showVideo
                    ? _formatDuration(controller.value.duration)
                    : 'VIDEO',
                style: AppTypography.micro.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 9,
                ),
              ),
            ),
          ),

          // Title & file size bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              color: showVideo
                  ? Colors.transparent
                  : widget.colors.surface.withValues(alpha: 0.92),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.micro.copyWith(
                      color: showVideo
                          ? Colors.white
                          : widget.colors.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.fileSize,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.micro.copyWith(
                      color: showVideo
                          ? Colors.white.withValues(alpha: 0.85)
                          : widget.colors.foregroundMuted,
                      fontFeatures: AppTypography.tabularFigures,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoGridItemState extends State<PhotoGridItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Neumorphic(
          radius: AppRadii.rSm,
          depth: 0.8,
          hoverLift: true,
          inset: widget.isSelected,
          clipContent: true,
          padding: const EdgeInsets.all(3),
          semanticLabel: widget.photo.title,
          onTap: () {
            if (widget.isSelectionMode) {
              widget.onSelectToggle?.call();
            } else {
              widget.onTap?.call();
            }
          },
          onLongPress: () {
            if (widget.isSelectionMode) {
              widget.onSelectToggle?.call();
            } else if (widget.onLongPress != null) {
              widget.onLongPress!();
            } else {
              widget.onSelectToggle?.call();
            }
          },
          child: ClipRRect(
            borderRadius: AppRadii.xs,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video preview tile (stream range thumbnail or graceful fallback)
                if (widget.photo.checkIsVideo)
                  VideoThumbnailTile(
                    photo: widget.photo,
                    colors: colors,
                    title: widget.photo.title,
                    fileSize: widget.photo.fileSize,
                  )
                else
                  Hero(
                    tag: 'photo_${widget.photo.id}',
                    child: Image.network(
                      widget.photo.thumbnailUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      (loadingProgress.expectedTotalBytes ?? 1)
                                  : null,
                              color: colors.foregroundMuted,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 28,
                                color: colors.foregroundMuted,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                widget.photo.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.micro.copyWith(
                                  color: colors.foregroundMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                // Selection checkbox badge
                if (widget.isSelectionMode)
                  Positioned(
                    top: AppSpacing.xs + 2,
                    right: AppSpacing.xs + 2,
                    child: Neumorphic(
                      width: 26,
                      height: 26,
                      inset: widget.isSelected,
                      radius: AppRadii.rPill,
                      depth: 0.5,
                      onTap: widget.onSelectToggle,
                      semanticLabel: widget.isSelected
                          ? 'Bỏ chọn ${widget.photo.title}'
                          : 'Chọn ${widget.photo.title}',
                      child: Icon(
                        widget.isSelected
                            ? Icons.check_rounded
                            : Icons.circle_outlined,
                        size: widget.isSelected ? 15 : 12,
                        color: widget.isSelected
                            ? colors.foreground
                            : colors.foregroundMuted,
                      ),
                    ),
                  ),

                // Hover title bar (pointer devices only)
                if (!widget.isSelectionMode && !widget.photo.checkIsVideo)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.0,
                      duration: AppMotion.fast,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs + 2,
                        ),
                        color: colors.surface.withValues(alpha: 0.92),
                        child: Text(
                          widget.photo.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: colors.foreground,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
