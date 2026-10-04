import 'package:flutter/material.dart';
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

/// Poster-less video tile: a debossed well, an extruded play disc and the file
/// name. Cheap to build and it never touches the video stream.
class _VideoTilePlaceholder extends StatelessWidget {
  final AppColorsData colors;
  final String title;
  final String fileSize;

  const _VideoTilePlaceholder({
    required this.colors,
    required this.title,
    required this.fileSize,
  });

  @override
  Widget build(BuildContext context) {
    return Neumorphic(
      inset: true,
      radius: AppRadii.rXs,
      color: colors.mediaCanvas,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Neumorphic(
              width: 40,
              height: 40,
              radius: AppRadii.rPill,
              depth: 0.8,
              child: Icon(
                Icons.play_arrow_rounded,
                size: 24,
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.micro.copyWith(color: colors.foreground),
            ),
            Text(
              fileSize,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.micro.copyWith(
                color: colors.foregroundMuted,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
          ],
        ),
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
                // Videos have no server-side poster frame yet, and fetching the
                // stream through Image.network would decrypt and download the
                // whole video only to fail decoding. Render a video card instead.
                if (widget.photo.checkIsVideo)
                  _VideoTilePlaceholder(
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
                          widget.photo.title,
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
