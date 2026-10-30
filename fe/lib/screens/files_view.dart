import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../models/photo_item.dart';
import '../theme/app_tokens.dart';
import '../widgets/flat.dart';

/// Files view: folders as drawers plus a flat list of recent files, which is the
/// fastest way to reach a single item when you already know its name.
class FilesView extends StatelessWidget {
  final List<Folder> folders;
  final List<PhotoItem> files;
  final ValueChanged<Folder> onOpenFolder;
  final ValueChanged<PhotoItem> onOpenFile;
  final ValueChanged<PhotoItem> onFileOptions;

  const FilesView({
    super.key,
    required this.folders,
    required this.files,
    required this.onOpenFolder,
    required this.onOpenFile,
    required this.onFileOptions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final recent = [...files]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.margin,
        AppSpacing.sm,
        AppSpacing.margin,
        AppSpacing.xl + 80,
      ),
      children: [
        Row(
          children: [
            Icon(Icons.folder_open_outlined,
                size: 14, color: colors.foregroundMuted),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              'VAULTLY',
              style: AppTypography.caption.copyWith(
                color: colors.foregroundMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 14, color: colors.foregroundMuted),
            Text(
              'Tất cả tệp',
              style: AppTypography.caption.copyWith(color: colors.foreground),
            ),
          ],
        ),
        _SectionTitle(label: 'Album', count: folders.length),
        if (folders.isEmpty)
          Text(
            'Chưa có album nào.',
            style: AppTypography.body.copyWith(color: colors.foregroundMuted),
          )
        else
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (var i = 0; i < folders.length; i++) ...[
                  _FolderRow(
                    folder: folders[i],
                    onTap: () => onOpenFolder(folders[i]),
                  ),
                  if (i != folders.length - 1)
                    Divider(height: 1, color: colors.border, indent: 68),
                ],
              ],
            ),
          ),
        _SectionTitle(label: 'Tệp gần đây', count: recent.length),
        if (recent.isEmpty)
          Text(
            'Chưa có tệp nào trong kho.',
            style: AppTypography.body.copyWith(color: colors.foregroundMuted),
          )
        else
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (var i = 0; i < recent.length; i++) ...[
                  _FileRow(
                    photo: recent[i],
                    onTap: () => onOpenFile(recent[i]),
                    onOptions: () => onFileOptions(recent[i]),
                  ),
                  if (i != recent.length - 1)
                    Divider(height: 1, color: colors.border, indent: 76),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final int count;

  const _SectionTitle({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return SectionHeader(
      title: label,
      count: count,
      padding: const EdgeInsets.only(
        top: AppSpacing.xl,
        bottom: AppSpacing.md,
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  final Folder folder;
  final VoidCallback onTap;

  const _FolderRow({required this.folder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadii.sm,
              child: SizedBox(
                width: 52,
                height: 52,
                child: folder.coverUrl != null && folder.coverUrl!.isNotEmpty
                    ? Image.network(
                        folder.coverUrl!,
                        fit: BoxFit.cover,
                        cacheWidth: 160,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: colors.primarySoft,
                          child: Icon(folder.icon, size: 24, color: colors.primary),
                        ),
                      )
                    : Container(
                        color: colors.primarySoft,
                        child: Icon(folder.icon, size: 24, color: colors.primary),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          folder.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: colors.foreground,
                          ),
                        ),
                      ),
                      if (folder.isSecure) ...[
                        const SizedBox(width: AppSpacing.xs + 2),
                        Icon(Icons.lock_outline_rounded,
                            size: 13, color: colors.success),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${folder.photoCount} mục',
                    style: AppTypography.caption.copyWith(
                      color: colors.foregroundMuted,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: colors.foregroundMuted),
          ],
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final PhotoItem photo;
  final VoidCallback onTap;
  final VoidCallback onOptions;

  const _FileRow({
    required this.photo,
    required this.onTap,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isVideo = photo.checkIsVideo;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadii.sm,
              child: SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      photo.thumbnailUrl,
                      fit: BoxFit.cover,
                      cacheWidth: 160,
                      filterQuality: FilterQuality.low,
                      errorBuilder: (context, error, stackTrace) => ColoredBox(
                        color: colors.surfaceMuted,
                        child: Icon(
                          isVideo
                              ? Icons.videocam_outlined
                              : Icons.image_outlined,
                          size: 24,
                          color: colors.foregroundMuted,
                        ),
                      ),
                    ),
                    if (isVideo)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    photo.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${photo.fileSize} • ${_formatDate(photo.createdAt)} • ${isVideo ? 'Video' : 'Ảnh'}',
                    style: AppTypography.caption.copyWith(
                      color: colors.foregroundMuted,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Tùy chọn tệp',
              onPressed: onOptions,
              icon: Icon(Icons.more_vert_rounded,
                  size: 18, color: colors.foregroundMuted),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}
