import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../models/photo_item.dart';
import '../theme/app_tokens.dart';
import 'photo_tile.dart';
import 'tiles.dart';

/// Album card in the shape of a folder: cover collage, name, item count and the
/// overflow menu. Used by the Albums grid and the overview shelf.
class AlbumFolderCard extends StatelessWidget {
  final Folder album;
  final List<PhotoItem> photos;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const AlbumFolderCard({
    super.key,
    required this.album,
    required this.photos,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final covers = photos.take(4).toList();

    return FolderCard(
      onTap: onTap,
      contentPadding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadii.sm,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CoverCollage(
                    covers: covers,
                    fallbackIcon: album.icon,
                  ),
                  if (album.isSecure)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.94),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 12,
                          color: colors.foreground,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      album.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${photos.length} mục',
                      style: AppTypography.caption.copyWith(
                        color: colors.foregroundMuted,
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                PopupMenuButton<String>(
                  tooltip: 'Tùy chọn album',
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: colors.foregroundMuted,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') onDelete!();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'delete', child: Text('Xoá album')),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One cover fills the tile; two to four covers form a 2x2 collage.
class _CoverCollage extends StatelessWidget {
  final List<PhotoItem> covers;
  final IconData fallbackIcon;

  const _CoverCollage({required this.covers, required this.fallbackIcon});

  @override
  Widget build(BuildContext context) {
    if (covers.isEmpty) {
      return FolderTileArt(icon: fallbackIcon, iconSize: 26);
    }
    if (covers.length == 1) {
      return _cover(context, covers.first);
    }

    return Column(
      children: [
        for (var row = 0; row < 2; row++)
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < 2; column++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(1),
                      child: _coverOrBlank(
                        context,
                        row * 2 + column < covers.length
                            ? covers[row * 2 + column]
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _coverOrBlank(BuildContext context, PhotoItem? photo) {
    if (photo == null) return const ColoredBox(color: Color(0x0A000000));
    return _cover(context, photo);
  }

  Widget _cover(BuildContext context, PhotoItem photo) {
    final colors = AppColors.of(context);
    if (photo.checkIsVideo) {
      return ColoredBox(
        color: colors.surfaceMuted,
        child: Icon(
          Icons.play_arrow_rounded,
          size: 26,
          color: colors.foregroundMuted,
        ),
      );
    }
    return Image.network(
      photo.thumbnailUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => ColoredBox(
        color: colors.surfaceMuted,
        child: Icon(
          Icons.image_outlined,
          size: 22,
          color: colors.foregroundMuted,
        ),
      ),
    );
  }
}
