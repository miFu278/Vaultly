import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../models/photo_item.dart';
import '../theme/app_tokens.dart';
import 'photo_grid_item.dart';
import 'neumorphic.dart';
import 'segmented_control.dart';

class PhotoGrid extends StatefulWidget {
  final Folder folder;
  final List<PhotoItem> photos;
  final int crossAxisCount;
  final ValueChanged<int> onZoomChanged;
  final ValueChanged<PhotoItem> onPhotoTap;
  final ValueChanged<PhotoItem>? onPhotoLongPress;
  final VoidCallback? onUploadMockPhoto;
  final bool isSelectionMode;
  final Set<String> selectedPhotoIds;
  final ValueChanged<String>? onToggleSelectPhoto;
  final VoidCallback? onToggleSelectionMode;
  final VoidCallback? onSelectAll;
  final VoidCallback? onDeselectAll;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onAddSelectedToFolder;

  const PhotoGrid({
    super.key,
    required this.folder,
    required this.photos,
    required this.crossAxisCount,
    required this.onZoomChanged,
    required this.onPhotoTap,
    this.onPhotoLongPress,
    this.onUploadMockPhoto,
    this.isSelectionMode = false,
    this.selectedPhotoIds = const {},
    this.onToggleSelectPhoto,
    this.onToggleSelectionMode,
    this.onSelectAll,
    this.onDeselectAll,
    this.onDeleteSelected,
    this.onAddSelectedToFolder,
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

    if (details.scale > 1.35 && widget.crossAxisCount > 2) {
      widget.onZoomChanged(widget.crossAxisCount - 1);
      _scaleHandled = true;
    } else if (details.scale < 0.75 && widget.crossAxisCount < 4) {
      widget.onZoomChanged(widget.crossAxisCount + 1);
      _scaleHandled = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      children: [
        // Sub-header bar
        // Floating neumorphic toolbar
        Neumorphic(
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          radius: AppRadii.rMd,
          depth: 0.7,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: widget.isSelectionMode
              ? _buildSelectionHeader(context, colors)
              : _buildStandardHeader(context, colors),
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
                      final isSelected = widget.selectedPhotoIds.contains(photo.id);

                      return PhotoGridItem(
                        key: ValueKey(photo.id),
                        photo: photo,
                        isSelectionMode: widget.isSelectionMode,
                        isSelected: isSelected,
                        onSelectToggle: () => widget.onToggleSelectPhoto?.call(photo.id),
                        onTap: () {
                          if (widget.isSelectionMode) {
                            widget.onToggleSelectPhoto?.call(photo.id);
                          } else {
                            widget.onPhotoTap(photo);
                          }
                        },
                        onLongPress: () {
                          if (widget.isSelectionMode) {
                            widget.onToggleSelectPhoto?.call(photo.id);
                          } else if (widget.onPhotoLongPress != null) {
                            widget.onPhotoLongPress!(photo);
                          } else {
                            widget.onToggleSelectionMode?.call();
                            widget.onToggleSelectPhoto?.call(photo.id);
                          }
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStandardHeader(BuildContext context, AppColorsData colors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 560;

        return Row(
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
                  Neumorphic(
                    inset: true,
                    radius: AppRadii.rXs,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs + 2,
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

            // Multi-select toggle button
            if (widget.photos.isNotEmpty && widget.onToggleSelectionMode != null) ...[
              if (isCompact)
                NeumorphicIconButton(
                  onPressed: widget.onToggleSelectionMode,
                  icon: Icons.checklist_rounded,
                  tooltip: 'Chọn',
                )
              else
                NeumorphicButton(
                  onPressed: widget.onToggleSelectionMode,
                  icon: Icons.checklist_rounded,
                  label: 'Chọn',
                  compact: true,
                ),
              const SizedBox(width: AppSpacing.sm),
            ],

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

            if (!isCompact && widget.onUploadMockPhoto != null) ...[
              const SizedBox(width: AppSpacing.sm),
              NeumorphicButton(
                onPressed: widget.onUploadMockPhoto,
                icon: Icons.add_photo_alternate_outlined,
                label: 'Thêm tệp',
                compact: true,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSelectionHeader(BuildContext context, AppColorsData colors) {
    final count = widget.selectedPhotoIds.length;
    final allSelected = widget.photos.isNotEmpty && count == widget.photos.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 560;

        return Row(
          children: [
            NeumorphicIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Hủy chế độ chọn',
              onPressed: widget.onToggleSelectionMode,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              isCompact ? '$count' : 'Đã chọn $count',
              style: AppTypography.heading.copyWith(
                color: colors.foreground,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
            const Spacer(),

            // Select All / Deselect All
            if (isCompact)
              NeumorphicIconButton(
                onPressed: allSelected ? widget.onDeselectAll : widget.onSelectAll,
                icon: allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                tooltip: allSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả',
              )
            else
              NeumorphicButton(
                onPressed: allSelected ? widget.onDeselectAll : widget.onSelectAll,
                label: allSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả',
                compact: true,
              ),
            const SizedBox(width: AppSpacing.sm),

            // Add / Move / Copy to folder action
            if (isCompact)
              NeumorphicIconButton(
                onPressed: count > 0 ? widget.onAddSelectedToFolder : null,
                icon: Icons.drive_file_move_outlined,
                tooltip: 'Vào thư mục',
              )
            else
              NeumorphicButton(
                onPressed: count > 0 ? widget.onAddSelectedToFolder : null,
                icon: Icons.drive_file_move_outlined,
                label: 'Vào thư mục',
                compact: true,
              ),
            const SizedBox(width: AppSpacing.sm),

            // Delete selected action
            if (isCompact)
              NeumorphicIconButton(
                onPressed: count > 0 ? widget.onDeleteSelected : null,
                icon: Icons.delete_outline,
                tooltip: 'Xóa ($count)',
                iconColor: count > 0 ? colors.danger : colors.foregroundMuted,
              )
            else
              NeumorphicButton(
                onPressed: count > 0 ? widget.onDeleteSelected : null,
                icon: Icons.delete_outline,
                label: 'Xóa ($count)',
                compact: true,
                danger: count > 0,
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, AppColorsData colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Neumorphic(
              width: 96,
              height: 96,
              inset: true,
              radius: AppRadii.rPill,
              color: colors.surfaceMuted,
              child: Icon(
                Icons.photo_library_outlined,
                size: 40,
                color: colors.foregroundMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Thư mục trống',
              style: AppTypography.title.copyWith(color: colors.foreground),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Chưa có ảnh hoặc video nào được lưu trữ trong thư mục này',
              style: AppTypography.body.copyWith(color: colors.foregroundMuted),
              textAlign: TextAlign.center,
            ),
            if (widget.onUploadMockPhoto != null) ...[
              const SizedBox(height: AppSpacing.lg),
              NeumorphicButton(
                onPressed: widget.onUploadMockPhoto,
                icon: Icons.add,
                label: 'Thêm tệp vào Vault',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
