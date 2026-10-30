import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../models/photo_item.dart';
import '../models/storage_usage.dart';
import '../theme/app_tokens.dart';
import '../widgets/album_card.dart';
import '../widgets/flat.dart';
import '../widgets/tiles.dart';

/// Overview: how much of the vault is in use and the albums inside it.
///
/// The figures appear once. An earlier version repeated them in four stat cards
/// and again in the gauge legend, which is the classic dashboard slop of saying
/// the same number three times in three containers.
class OverviewView extends StatelessWidget {
  final StorageUsage usage;
  final bool isAuthenticated;
  final List<Folder> albums;
  final Map<String, List<PhotoItem>> photosByAlbum;
  final ValueChanged<Folder> onOpenAlbum;
  final VoidCallback onOpenAlbums;

  const OverviewView({
    super.key,
    required this.usage,
    required this.isAuthenticated,
    required this.albums,
    required this.photosByAlbum,
    required this.onOpenAlbum,
    required this.onOpenAlbums,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final shelf = albums.take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.margin,
        0,
        AppSpacing.margin,
        AppSpacing.xl + 80,
      ),
      children: [
        if (!isAuthenticated) ...[
          const InfoBanner(
            icon: Icons.cloud_off_outlined,
            title: 'Chưa đăng nhập',
            message: 'Đăng nhập để xem dung lượng thật của kho.',
            tone: BadgeTone.neutral,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _UsageCard(usage: usage),
        if (albums.isNotEmpty) ...[
          SectionHeader(
            title: 'Album',
            count: albums.length,
            trailing: TextButton(
              onPressed: onOpenAlbums,
              child: Text(
                'Xem tất cả',
                style: AppTypography.label.copyWith(color: colors.primary),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: constraints.maxWidth >= 720 ? 4 : 2,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.86,
              ),
              itemCount: shelf.length,
              itemBuilder: (context, index) {
                final album = shelf[index];
                return AlbumFolderCard(
                  album: album,
                  photos: photosByAlbum[album.id] ?? const [],
                  onTap: () => onOpenAlbum(album),
                );
              },
            ),
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.lg),
          EmptyState(
            icon: Icons.collections_bookmark_outlined,
            title: 'Kho đang trống',
            message: 'Tạo album rồi tải ảnh hoặc video lên để bắt đầu.',
            action: PillButton(
              label: 'Tạo album',
              icon: Icons.add_rounded,
              variant: PillVariant.primary,
              dense: true,
              onPressed: onOpenAlbums,
            ),
          ),
        ],
      ],
    );
  }
}

class _UsageCard extends StatelessWidget {
  final StorageUsage usage;

  const _UsageCard({required this.usage});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gauge = StorageGauge(
            percent: usage.usedPercent,
            photoBytes: usage.photoBytes,
            videoBytes: usage.videoBytes,
            usedBytes: usage.usedBytes,
            quotaBytes: usage.quotaBytes,
          );

          final figures = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Figure(
                icon: Icons.image_outlined,
                kind: AppTintKind.amber,
                label: 'Ảnh',
                bytes: usage.photoBytes,
                share: usage.share(usage.photoBytes),
              ),
              const SizedBox(height: AppSpacing.sm),
              _Figure(
                icon: Icons.videocam_outlined,
                kind: AppTintKind.blue,
                label: 'Video',
                bytes: usage.videoBytes,
                share: usage.share(usage.videoBytes),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                usage.hasQuota
                    ? '${formatBytes(usage.usedBytes)} trên ${formatBytes(usage.quotaBytes)}'
                    : '${formatBytes(usage.usedBytes)} đã dùng',
                style: AppTypography.caption.copyWith(
                  color: colors.foregroundMuted,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
            ],
          );

          if (constraints.maxWidth >= 520) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                gauge,
                const SizedBox(width: AppSpacing.xl),
                // Capped so a label and its number never drift to opposite ends
                // of a wide card.
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: figures,
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: gauge),
              const SizedBox(height: AppSpacing.lg),
              figures,
            ],
          );
        },
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final IconData icon;
  final AppTintKind kind;
  final String label;
  final int bytes;
  final double share;

  const _Figure({
    required this.icon,
    required this.kind,
    required this.label,
    required this.bytes,
    required this.share,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Row(
      children: [
        TintedIconTile(icon: icon, kind: kind, size: 36),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Text(
            label,
            style: AppTypography.body.copyWith(color: colors.foreground),
          ),
        ),
        Text(
          '${formatBytes(bytes)} • ${share.round()}%',
          style: AppTypography.caption.copyWith(
            color: colors.foregroundMuted,
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
      ],
    );
  }
}
