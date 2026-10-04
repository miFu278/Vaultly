import 'package:flutter/material.dart';
import '../models/photo_item.dart';
import '../theme/app_tokens.dart';
import 'neumorphic.dart';

class PhotoDetailDialog extends StatelessWidget {
  final PhotoItem photo;

  const PhotoDetailDialog({super.key, required this.photo});

  static Future<void> show(BuildContext context, PhotoItem photo) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => PhotoDetailDialog(photo: photo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return NeumorphicDialog(
      maxWidth: AppSpacing.dialogMax,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top title row
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
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
                  NeumorphicIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),

            // Debossed media well
            Expanded(
              child: Neumorphic(
                inset: true,
                radius: AppRadii.rMd,
                color: colors.mediaCanvas,
                margin: const EdgeInsets.all(AppSpacing.md),
                clipContent: true,
                child: Center(
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
            ),

            Divider(height: 1, color: colors.border),

            // Metadata footer carrying the single primary action
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.lg,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _MetadataItem(
                          icon: Icons.calendar_today_outlined,
                          text:
                              '${photo.createdAt.day.toString().padLeft(2, '0')}/${photo.createdAt.month.toString().padLeft(2, '0')}/${photo.createdAt.year}',
                        ),
                        _MetadataItem(
                          icon: Icons.data_usage_outlined,
                          text: photo.fileSize,
                        ),
                        if (photo.isEncrypted)
                          const _MetadataItem(
                            icon: Icons.enhanced_encryption_outlined,
                            text: 'E2EE XChaCha20',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  NeumorphicButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đang chuẩn bị tải: ${photo.title}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: Icons.download_outlined,
                    label: 'Tải về',
                    primary: true,
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
