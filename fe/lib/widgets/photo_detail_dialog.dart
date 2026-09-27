import 'package:flutter/material.dart';
import '../models/photo_item.dart';
import '../theme/app_tokens.dart';

class PhotoDetailDialog extends StatelessWidget {
  final PhotoItem photo;

  const PhotoDetailDialog({super.key, required this.photo});

  static Future<void> show(BuildContext context, PhotoItem photo) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => PhotoDetailDialog(photo: photo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.lg,
        side: BorderSide(color: colors.border, width: 1),
      ),
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSpacing.dialogMax,
          maxHeight: 720,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top title row
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  Icon(
                    photo.isEncrypted ? Icons.lock_outline : Icons.photo_outlined,
                    size: 18,
                    color: colors.foreground,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      photo.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heading.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),

            // Photo preview area
            Expanded(
              child: Container(
                color: colors.mediaCanvas,
                alignment: Alignment.center,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 3.5,
                  child: Image.network(
                    photo.fullUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
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
                              Icons.broken_image_outlined,
                              size: 40,
                              color: colors.foregroundMuted,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Không thể tải ảnh gốc',
                              style: AppTypography.body.copyWith(
                                color: colors.foregroundMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            Divider(height: 1, color: colors.border),

            // Metadata footer carrying the single primary action
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  _MetadataItem(
                    icon: Icons.calendar_today_outlined,
                    text: '${photo.createdAt.day.toString().padLeft(2, '0')}/${photo.createdAt.month.toString().padLeft(2, '0')}/${photo.createdAt.year}',
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  _MetadataItem(
                    icon: Icons.data_usage_outlined,
                    text: photo.fileSize,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  if (photo.isEncrypted)
                    const _MetadataItem(
                      icon: Icons.enhanced_encryption_outlined,
                      text: 'E2EE XChaCha20',
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đang chuẩn bị tải: ${photo.title}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Tải về'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      textStyle: AppTypography.label,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetadataItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.foregroundMuted),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: AppTypography.label.copyWith(
            color: colors.foregroundMuted,
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
      ],
    );
  }
}
