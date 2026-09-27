import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/photo_item.dart';
import '../theme/app_tokens.dart';

class PhotoGridItem extends StatefulWidget {
  final PhotoItem photo;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PhotoGridItem({
    super.key,
    required this.photo,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<PhotoGridItem> createState() => _PhotoGridItemState();
}

class _PhotoGridItemState extends State<PhotoGridItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed
              ? 0.97
              : (_isHovered ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: AppRadii.sm,
                border: Border.all(
                  color: _isHovered ? colors.foreground : colors.border,
                  width: 1.0,
                ),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  onLongPress: () {
                    HapticFeedback.lightImpact();
                    widget.onLongPress?.call();
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Thumbnail Image
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

                      // Hover title bar overlay (Flat bar without gradient as per DESIGN.md)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: AnimatedOpacity(
                          opacity: _isHovered ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 150),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs + 2,
                              vertical: AppSpacing.xs,
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
          ),
        ),
      ),
    );
  }
}
