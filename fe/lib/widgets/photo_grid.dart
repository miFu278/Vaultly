import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../models/photo_item.dart';
import 'photo_grid_item.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Sub-header bar: Folder Info & Zoom Controls
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Folder icon and title
                  Icon(
                    widget.folder.icon,
                    size: 19,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${widget.photos.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  // Zoom Controls: 2x, 3x, 4x buttons
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.dividerColor, width: 0.8),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [2, 3, 4].map((count) {
                        final isSelected = widget.crossAxisCount == count;
                        return InkWell(
                          onTap: () => widget.onZoomChanged(count),
                          borderRadius: BorderRadius.circular(6),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? Colors.white : Colors.black)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${count}x',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? Colors.black : Colors.white)
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Extra controls only on wider screen
                  if (!isCompact) ...[
                    const SizedBox(width: 10),
                    // Mini Slider for zoom control
                    SizedBox(
                      width: 80,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: theme.dividerColor,
                          thumbColor: theme.colorScheme.primary,
                        ),
                        child: Slider(
                          value: widget.crossAxisCount.toDouble(),
                          min: 2,
                          max: 4,
                          divisions: 2,
                          onChanged: (val) => widget.onZoomChanged(val.round()),
                        ),
                      ),
                    ),

                    if (widget.onUploadMockPhoto != null) ...[
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: widget.onUploadMockPhoto,
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 15),
                        label: const Text('Thêm ảnh', style: TextStyle(fontSize: 12)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
        ),

        // Main Grid Area with Pinch-to-zoom detector
        Expanded(
          child: widget.photos.isEmpty
              ? _buildEmptyState(context)
              : GestureDetector(
                  onScaleStart: _handleScaleStart,
                  onScaleUpdate: _handleScaleUpdate,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: widget.photos.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: widget.crossAxisCount,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
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

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 56,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Text(
            'Thư mục trống',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Chưa có ảnh nào được lưu trữ trong thư mục này',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (widget.onUploadMockPhoto != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: widget.onUploadMockPhoto,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Thêm ảnh mẫu'),
            ),
          ],
        ],
      ),
    );
  }
}
