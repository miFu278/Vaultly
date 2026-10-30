import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../models/photo_item.dart';
import '../theme/app_tokens.dart';
import 'photo_tile.dart';
import 'tiles.dart';

/// Album card in the shape of a folder: cover image (custom or latest photo),
/// name, item count and the overflow menu.
class AlbumFolderCard extends StatelessWidget {
  final Folder album;
  final List<PhotoItem> photos;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onChooseCover;
  final VoidCallback? onResetCover;

  const AlbumFolderCard({
    super.key,
    required this.album,
    required this.photos,
    required this.onTap,
    this.onDelete,
    this.onChooseCover,
    this.onResetCover,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

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
                  _AlbumCover(
                    coverUrl: album.coverUrl,
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
                  if (album.customCoverPhotoId != null)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.88),
                          borderRadius: AppRadii.pill,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 10, color: Colors.white),
                            SizedBox(width: 2),
                            Text(
                              'Bìa',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
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
              if (onDelete != null || onChooseCover != null || onResetCover != null)
                PopupMenuButton<String>(
                  tooltip: 'Tùy chọn album',
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: colors.foregroundMuted,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') onDelete?.call();
                    if (value == 'choose_cover') onChooseCover?.call();
                    if (value == 'reset_cover') onResetCover?.call();
                  },
                  itemBuilder: (context) => [
                    if (onChooseCover != null && photos.isNotEmpty)
                      const PopupMenuItem(
                        value: 'choose_cover',
                        child: Row(
                          children: [
                            Icon(Icons.photo_size_select_actual_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Chọn ảnh bìa'),
                          ],
                        ),
                      ),
                    if (onResetCover != null && album.customCoverPhotoId != null)
                      const PopupMenuItem(
                        value: 'reset_cover',
                        child: Row(
                          children: [
                            Icon(Icons.restore_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Dùng ảnh mới nhất'),
                          ],
                        ),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Xoá album', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlbumCover extends StatelessWidget {
  final String? coverUrl;
  final IconData fallbackIcon;

  const _AlbumCover({required this.coverUrl, required this.fallbackIcon});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (coverUrl == null || coverUrl!.isEmpty) {
      return FolderTileArt(icon: fallbackIcon, iconSize: 28);
    }

    return Image.network(
      coverUrl!,
      fit: BoxFit.cover,
      cacheWidth: 400,
      filterQuality: FilterQuality.low,
      errorBuilder: (context, error, stackTrace) =>
          FolderTileArt(icon: fallbackIcon, iconSize: 28),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return ColoredBox(
          color: colors.surfaceMuted,
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}
