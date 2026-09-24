import 'package:flutter/material.dart';
import '../models/folder.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Fixed width when drawer, animated width when desktop sidebar
    final double width = isDrawer
        ? 280.0
        : (isCollapsed ? 68.0 : 250.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: width,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: isDrawer
            ? null
            : Border(
                right: BorderSide(
                  color: theme.dividerColor,
                  width: 1,
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Brand Title & Collapse Toggle
          _buildHeader(context, isDark),

          const Divider(height: 1),

          // Folder List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                final isSelected = folder.id == selectedFolderId;
                return _buildFolderItem(context, folder, isSelected, isDark);
              },
            ),
          ),

          const Divider(height: 1),

          // Footer: Add Folder & Toggle Collapse
          _buildFooter(context, isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Secure Vault Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),

          // Brand Title
          const Expanded(
            child: Text(
              'Vaultly',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
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

  Widget _buildFolderCoverAvatar(Folder folder, double size, bool isDark) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size > 40 ? 8 : 6),
        color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 0.8,
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
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            )
          : Icon(
              folder.icon,
              size: size * 0.5,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
    );
  }

  Widget _buildFolderItem(
    BuildContext context,
    Folder folder,
    bool isSelected,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final activeBg = isDark
        ? const Color(0xFF27272A)
        : const Color(0xFFE5E7EB);

    final itemWidget = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isSelected ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: (isCollapsed && !isDrawer) ? 0 : 10,
            vertical: (isCollapsed && !isDrawer) ? 6 : 4,
          ),
          dense: true,
          leading: (isCollapsed && !isDrawer)
              ? null
              : _buildFolderCoverAvatar(folder, 42, isDark),
          title: (isCollapsed && !isDrawer)
              ? Center(child: _buildFolderCoverAvatar(folder, 36, isDark))
              : Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
          subtitle: (isCollapsed && !isDrawer)
              ? null
              : Row(
                  children: [
                    Text(
                      '${folder.photoCount} ảnh',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    if (folder.isSecure) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.lock_outline,
                        size: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ],
                  ],
                ),
          trailing: (isCollapsed && !isDrawer)
              ? null
              : (isSelected
                  ? Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    )
                  : null),
          onTap: () {
            onSelectFolder(folder);
            if (isDrawer) {
              Navigator.of(context).pop();
            }
          },
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

  Widget _buildFooter(BuildContext context, bool isDark) {
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
      padding: const EdgeInsets.all(12),
      child: OutlinedButton.icon(
        onPressed: onCreateFolder,
        icon: const Icon(Icons.create_new_folder_outlined, size: 16),
        label: const Text(
          'Thư mục mới',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}
