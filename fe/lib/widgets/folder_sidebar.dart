import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../theme/app_tokens.dart';

class FolderSidebar extends StatelessWidget {
  final List<Folder> folders;
  final String selectedFolderId;
  final ValueChanged<Folder> onSelectFolder;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;
  final bool isDrawer;
  final VoidCallback? onCreateFolder;

  const FolderSidebar({
    super.key,
    required this.folders,
    required this.selectedFolderId,
    required this.onSelectFolder,
    this.isCollapsed = false,
    this.onToggleCollapse,
    this.isDrawer = false,
    this.onCreateFolder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    // Fixed width when drawer, collapsed or expanded when desktop sidebar
    final double width = isDrawer
        ? 280.0
        : (isCollapsed ? AppSpacing.sidebarCollapsed : AppSpacing.sidebarExpanded);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.surface,
        border: isDrawer
            ? null
            : Border(
                right: BorderSide(
                  color: colors.border,
                  width: 1,
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Brand Title & Collapse Toggle
          _buildHeader(context, colors),

          Divider(height: 1, color: colors.border),

          // Folder List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.sm,
              ),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                final isSelected = folder.id == selectedFolderId;
                return _buildFolderItem(context, folder, isSelected, colors);
              },
            ),
          ),

          Divider(height: 1, color: colors.border),

          // Footer: Add Folder & Toggle Collapse
          _buildFooter(context, colors),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppColorsData colors) {
    if (isCollapsed && !isDrawer) {
      return Container(
        height: 56,
        alignment: Alignment.center,
        child: IconButton(
          icon: const Icon(Icons.menu_open_rounded, size: 20),
          tooltip: 'Mở rộng sidebar',
          onPressed: onToggleCollapse,
        ),
      );
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          // Shield / Vault Mark (Circle is allowed for shield mark)
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              shape: BoxShape.circle,
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 16,
              color: colors.foreground,
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),

          // Brand Title (700 weight only for brand mark)
          Expanded(
            child: Text(
              'Vaultly',
              style: AppTypography.brand.copyWith(
                color: colors.foreground,
              ),
            ),
          ),

          // Collapse button (Desktop only)
          if (!isDrawer && onToggleCollapse != null)
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 20),
              tooltip: 'Thu gọn sidebar',
              onPressed: onToggleCollapse,
            ),

          // Close button (Mobile Drawer only)
          if (isDrawer)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: 'Đóng menu',
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Widget _buildFolderCoverAvatar(Folder folder, double size, AppColorsData colors) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: AppRadii.xs,
        color: colors.surfaceMuted,
        border: Border.all(
          color: colors.border,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: folder.coverUrl != null
          ? Image.network(
              folder.coverUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.photo_outlined,
                size: size * 0.5,
                color: colors.foregroundMuted,
              ),
            )
          : Icon(
              folder.icon,
              size: size * 0.5,
              color: colors.foregroundMuted,
            ),
    );
  }

  Widget _buildFolderItem(
    BuildContext context,
    Folder folder,
    bool isSelected,
    AppColorsData colors,
  ) {
    final itemWidget = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Material(
        color: isSelected ? colors.surfaceMuted : Colors.transparent,
        borderRadius: AppRadii.md,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            onSelectFolder(folder);
            if (isDrawer) {
              Navigator.of(context).pop();
            }
          },
          borderRadius: AppRadii.md,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: (isCollapsed && !isDrawer) ? AppSpacing.xs : AppSpacing.sm + 2,
              vertical: (isCollapsed && !isDrawer) ? AppSpacing.sm : AppSpacing.sm,
            ),
            child: Row(
              children: [
                _buildFolderCoverAvatar(
                  folder,
                  (isCollapsed && !isDrawer) ? 36 : 38,
                  colors,
                ),
                if (!isCollapsed || isDrawer) ...[
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          folder.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? colors.foreground : colors.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${folder.photoCount} ảnh',
                              style: AppTypography.caption.copyWith(
                                color: colors.foregroundMuted,
                                fontFeatures: AppTypography.tabularFigures,
                              ),
                            ),
                            if (folder.isSecure) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Icon(
                                Icons.lock_outline,
                                size: 10,
                                color: colors.foregroundMuted,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (isCollapsed && !isDrawer) {
      return Tooltip(
        message: '${folder.name} (${folder.photoCount})',
        waitDuration: const Duration(milliseconds: 300),
        child: itemWidget,
      );
    }

    return itemWidget;
  }

  Widget _buildFooter(BuildContext context, AppColorsData colors) {
    if (isCollapsed && !isDrawer) {
      return Container(
        height: 56,
        alignment: Alignment.center,
        child: IconButton(
          icon: const Icon(Icons.create_new_folder_outlined, size: 20),
          tooltip: 'Tạo thư mục mới',
          onPressed: onCreateFolder,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: OutlinedButton.icon(
        onPressed: onCreateFolder,
        icon: const Icon(Icons.create_new_folder_outlined, size: 16),
        label: const Text('Thư mục mới'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm + 2,
            horizontal: AppSpacing.md,
          ),
          alignment: Alignment.centerLeft,
          textStyle: AppTypography.body,
        ),
      ),
    );
  }
}
