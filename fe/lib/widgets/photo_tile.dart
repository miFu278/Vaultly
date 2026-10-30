import 'package:flutter/material.dart';
import '../models/photo_item.dart';
import '../theme/app_tokens.dart';

/// Square media tile used by the gallery timeline and album collages.
///
/// Videos never go through [Image.network]: the endpoint streams the decrypted
/// video, so fetching it just to render a poster would download the whole file.
class PhotoTile extends StatelessWidget {
  final PhotoItem photo;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const PhotoTile({
    super.key,
    required this.photo,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isVideo = photo.checkIsVideo;

    return Semantics(
      label: photo.displayTitle,
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ClipRRect(
          borderRadius: AppRadii.sm,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isVideo)
                ColoredBox(
                  color: colors.surfaceMuted,
                  child: Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 34,
                      color: colors.foregroundMuted,
                    ),
                  ),
                )
              else
                Image.network(
                  photo.thumbnailUrl,
                  fit: BoxFit.cover,
                  // The stored preview is 512px; decoding it at that width instead
                  // of the screen density keeps a 100-tile grid cheap.
                  cacheWidth: 512,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (context, error, stackTrace) => ColoredBox(
                    color: colors.surfaceMuted,
                    child: Icon(
                      Icons.image_outlined,
                      size: 24,
                      color: colors.foregroundMuted,
                    ),
                  ),
                ),
              if (isVideo)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: AppRadii.pill,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_rounded,
                            size: 10, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          'Video',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (selectionMode)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: selected ? colors.primary : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? colors.primary : colors.border,
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? Icon(Icons.check_rounded,
                            size: 14, color: colors.onPrimary)
                        : null,
                  ),
                ),
              if (selected && !selectionMode)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.primary, width: 2),
                    borderRadius: AppRadii.sm,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Square placeholder showing a folder icon, used where a cover is missing.
class FolderTileArt extends StatelessWidget {
  final IconData icon;
  final Color? tint;
  final double iconSize;

  const FolderTileArt({
    super.key,
    required this.icon,
    this.tint,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ColoredBox(
      color: colors.surfaceMuted,
      child: Center(
        child: Icon(icon, size: iconSize, color: tint ?? colors.foregroundMuted),
      ),
    );
  }
}
