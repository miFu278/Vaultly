import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../models/photo_item.dart';
import '../theme/app_tokens.dart';
import 'photo_grid_item.dart';
import 'segmented_control.dart';

class PhotoGrid extends StatefulWidget {
  final Folder folder;
  final List<PhotoItem> photos;
  final int crossAxisCount;
  final ValueChanged<int> onZoomChanged;
  final ValueChanged<PhotoItem> onPhotoTap;
  final ValueChanged<PhotoItem>? onPhotoLongPress;
  final VoidCallback? onUploadMockPhoto;

  const PhotoGrid({
    super.key,
    required this.folder,
    required this.photos,
    required this.crossAxisCount,
    required this.onZoomChanged,
    required this.onPhotoTap,
    this.onPhotoLongPress,
    this.onUploadMockPhoto,
  });

  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> {
  bool _scaleHandled = false;

  void _handleScaleStart(ScaleStartDetails details) {
    _scaleHandled = false;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_scaleHandled || details.scale == 1.0) return;

    // Pinch-out (zoom in -> fewer columns, larger images)
    if (details.scale > 1.35 && widget.crossAxisCount > 2) {
      widget.onZoomChanged(widget.crossAxisCount - 1);
      _scaleHandled = true;
    }
    // Pinch-in (zoom out -> more columns, smaller images)
    else if (details.scale < 0.75 && widget.crossAxisCount < 4) {
      widget.onZoomChanged(widget.crossAxisCount + 1);
      _scaleHandled = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      children: [
        // Sub-header bar: Folder info & Segmented density control
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              bottom: BorderSide(color: colors.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Folder icon and title
              Icon(
                widget.folder.icon,
                size: 18,
                color: colors.foreground,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.heading.copyWith(
                          color: colors.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs + 2,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: AppRadii.xs,
                        border: Border.all(color: colors.border, width: 1),
                      ),
                      child: Text(
                        '${widget.photos.length}',
                        style: AppTypography.caption.copyWith(
                          color: colors.foregroundMuted,
                          fontFeatures: AppTypography.tabularFigures,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Segmented Density Control: 2x, 3x, 4x (DESIGN.md)
              VaultlySegmentedControl<int>(
                selectedValue: widget.crossAxisCount,
                segments: const [
                  VaultlySegment(value: 2, label: '2x'),
                  VaultlySegment(value: 3, label: '3x'),
                  VaultlySegment(value: 4, label: '4x'),
                ],
                onValueChanged: widget.onZoomChanged,
              ),

              if (widget.onUploadMockPhoto != null) ...[
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: widget.onUploadMockPhoto,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 14),
                  label: const Text('Thêm ảnh'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 2,
                      vertical: AppSpacing.xs + 2,
                    ),
                    visualDensity: VisualDensity.compact,
                    textStyle: AppTypography.label,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Main Grid Area with Pinch-to-zoom detector
        Expanded(
          child: widget.photos.isEmpty
              ? _buildEmptyState(context, colors)
              : GestureDetector(
                  onScaleStart: _handleScaleStart,
                  onScaleUpdate: _handleScaleUpdate,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: widget.photos.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: widget.crossAxisCount,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 1.0,
                    ),
                    itemBuilder: (context, index) {
                      final photo = widget.photos[index];
                      return PhotoGridItem(
                        key: ValueKey(photo.id),
                        photo: photo,
                        onTap: () => widget.onPhotoTap(photo),
                        onLongPress: () => widget.onPhotoLongPress?.call(photo),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, AppColorsData colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: colors.foregroundMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Thư mục trống',
              style: AppTypography.title.copyWith(color: colors.foreground),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Chưa có ảnh nào được lưu trữ trong thư mục này',
              style: AppTypography.body.copyWith(color: colors.foregroundMuted),
              textAlign: TextAlign.center,
            ),
            if (widget.onUploadMockPhoto != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: widget.onUploadMockPhoto,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Thêm ảnh vào Vault'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm + 2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
