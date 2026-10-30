import 'package:flutter/material.dart';
import '../models/photo_item.dart';
import '../theme/app_tokens.dart';
import '../widgets/flat.dart';
import '../widgets/photo_tile.dart';

enum MediaFilter { all, photos, videos }

/// Gallery timeline: search, media filter, grid density and day sections.
class GalleryView extends StatelessWidget {
  final String subtitle;
  final List<PhotoItem> photos;
  final MediaFilter filter;
  final ValueChanged<MediaFilter> onFilterChanged;
  final int crossAxisCount;
  final ValueChanged<int> onDensityChanged;
  /// Phones keep the filter row for the media types only; the density stepper
  /// is a wide-screen nicety and is hidden below the pane breakpoint.
  final bool showDensity;
  final String searchQuery;
  final ValueChanged<String> onSearchQueryChanged;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final ValueChanged<PhotoItem> onOpenPhoto;
  final ValueChanged<PhotoItem> onPhotoLongPress;
  final ValueChanged<String> onToggleSelect;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final Future<void> Function() onDeleteSelected;
  final Future<void> Function() onAddSelectedToAlbum;
  final VoidCallback onUpload;

  const GalleryView({
    super.key,
    required this.subtitle,
    required this.photos,
    required this.filter,
    required this.onFilterChanged,
    required this.crossAxisCount,
    required this.onDensityChanged,
    this.showDensity = true,
    required this.searchQuery,
    required this.onSearchQueryChanged,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onOpenPhoto,
    required this.onPhotoLongPress,
    required this.onToggleSelect,
    required this.onToggleSelectionMode,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onDeleteSelected,
    required this.onAddSelectedToAlbum,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final groups = _groupByDay(photos);

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.sm,
                AppSpacing.margin,
                0,
              ),
              sliver: SliverToBoxAdapter(child: _header(context, colors)),
            ),
            if (groups.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.photo_library_outlined,
                  title: searchQuery.isEmpty ? 'Chưa có mục nào' : 'Không tìm thấy',
                  message: searchQuery.isEmpty
                      ? 'Tải ảnh hoặc video lên để bắt đầu xây kho riêng của bạn.'
                      : 'Thử từ khóa khác hoặc bỏ bộ lọc đang chọn.',
                  action: searchQuery.isEmpty
                      ? PillButton(
                          label: 'Tải tệp lên',
                          icon: Icons.add_rounded,
                          variant: PillVariant.primary,
                          dense: true,
                          onPressed: onUpload,
                        )
                      : null,
                ),
              )
            else ...[
              for (final entry in groups.entries) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.margin,
                    AppSpacing.lg,
                    AppSpacing.margin,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(
                      title: entry.key,
                      count: entry.value.length,
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.margin,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final photo = entry.value[index];
                        return PhotoTile(
                          photo: photo,
                          selected: selectedIds.contains(photo.id),
                          selectionMode: isSelectionMode,
                          onTap: () => isSelectionMode
                              ? onToggleSelect(photo.id)
                              : onOpenPhoto(photo),
                          onLongPress: () => onPhotoLongPress(photo),
                        );
                      },
                      childCount: entry.value.length,
                    ),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xl + 72),
              ),
            ],
          ],
        ),
        if (isSelectionMode)
          Positioned(
            left: AppSpacing.margin,
            right: AppSpacing.margin,
            bottom: AppSpacing.lg,
            child: _selectionBar(context, colors),
          ),
      ],
    );
  }

  Widget _header(BuildContext context, AppColorsData colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: colors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Flexible(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: colors.foregroundMuted,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          onChanged: onSearchQueryChanged,
          textInputAction: TextInputAction.search,
          style: AppTypography.body.copyWith(color: colors.foreground),
          decoration: InputDecoration(
            hintText: 'Tìm theo tên tệp',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: AppRadii.pill,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadii.pill,
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadii.pill,
              borderSide: BorderSide(color: colors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedPills<MediaFilter>(
                  expand: false,
                  selected: filter,
                  onChanged: onFilterChanged,
                  segments: const [
                    PillSegment(
                      value: MediaFilter.all,
                      label: 'Tất cả',
                      icon: Icons.grid_view_rounded,
                    ),
                    PillSegment(
                      value: MediaFilter.photos,
                      label: 'Ảnh',
                      icon: Icons.image_outlined,
                    ),
                    PillSegment(
                      value: MediaFilter.videos,
                      label: 'Video',
                      icon: Icons.videocam_outlined,
                    ),
                  ],
                ),
              ),
            ),
            if (showDensity) ...[
              const SizedBox(width: AppSpacing.sm),
              // One pill cycles the density; its label always shows the real
              // column count, so it cannot lie about the grid.
              PillButton(
                label: '${crossAxisCount}x',
                icon: Icons.grid_view_rounded,
                dense: true,
                onPressed: () => onDensityChanged(
                  crossAxisCount >= 4 ? 2 : crossAxisCount + 1,
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.sm),
            PillButton(
              label: isSelectionMode ? 'Xong' : 'Chọn',
              dense: true,
              onPressed: onToggleSelectionMode,
            ),
          ],
        ),
      ],
    );
  }

  Widget _selectionBar(BuildContext context, AppColorsData colors) {
    final count = selectedIds.length;
    final allSelected = photos.isNotEmpty && count == photos.length;

    return Material(
      color: colors.surface,
      elevation: 0,
      shape: const StadiumBorder(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          borderRadius: AppRadii.pill,
          boxShadow: AppElevation.floating(colors),
        ),
        child: Row(
          children: [
            RoundIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Thoát chọn',
              bordered: false,
              onPressed: onDeselectAll,
            ),
            Text(
              '$count đã chọn',
              style: AppTypography.label.copyWith(
                color: colors.foreground,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
            const Spacer(),
            RoundIconButton(
              icon: allSelected
                  ? Icons.deselect_rounded
                  : Icons.select_all_rounded,
              tooltip: allSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả',
              bordered: false,
              onPressed: allSelected ? onDeselectAll : onSelectAll,
            ),
            RoundIconButton(
              icon: Icons.library_add_outlined,
              tooltip: 'Thêm vào album',
              bordered: false,
              onPressed: onAddSelectedToAlbum,
            ),
            RoundIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Xóa mục đã chọn',
              bordered: false,
              onPressed: onDeleteSelected,
            ),
          ],
        ),
      ),
    );
  }

  /// Groups photos into day buckets, newest first, labelled the way a person
  /// reads a timeline.
  Map<String, List<PhotoItem>> _groupByDay(List<PhotoItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final sorted = [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final groups = <String, List<PhotoItem>>{};
    for (final photo in sorted) {
      final day = DateTime(
        photo.createdAt.year,
        photo.createdAt.month,
        photo.createdAt.day,
      );
      final String label;
      if (day == today) {
        label = 'Hôm nay';
      } else if (day == yesterday) {
        label = 'Hôm qua';
      } else {
        label =
            '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
      }
      groups.putIfAbsent(label, () => []).add(photo);
    }
    return groups;
  }
}
