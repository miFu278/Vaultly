import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../theme/app_tokens.dart';
import 'neumorphic.dart';

class FolderSidebar extends StatelessWidget {
  final List<Folder> folders;
  final String selectedFolderId;
  final ValueChanged<Folder> onSelectFolder;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;
  final bool isDrawer;
  final VoidCallback? onCreateFolder;
  final ValueChanged<Folder>? onDeleteFolder;

  const FolderSidebar({
    super.key,
    required this.folders,
    required this.selectedFolderId,
    required this.onSelectFolder,
    this.isCollapsed = false,
    this.onToggleCollapse,
    this.isDrawer = false,
    this.onCreateFolder,
    this.onDeleteFolder,
  });

  bool get _compact => isCollapsed && !isDrawer;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final double width =
        isDrawer ? 280.0 : (isCollapsed ? AppSpacing.sidebarCollapsed : AppSpacing.sidebarExpanded);

    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, colors),
        Divider(height: 1, color: colors.border),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.sm,
            ),
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              return _FolderTile(
                folder: folder,
                isSelected: folder.id == selectedFolderId,
                compact: _compact,
                onTap: () {
                  onSelectFolder(folder);
                  if (isDrawer) Navigator.of(context).pop();
                },
                onDelete: onDeleteFolder == null || folder.id == 'all'
                    ? null
                    : () => onDeleteFolder!(folder),
              );
            },
          ),
        ),
        Divider(height: 1, color: colors.border),
        _buildFooter(context, colors),
      ],
    );

    // The drawer is edge-to-edge; the desktop pane is a raised panel floating on
    // the canvas so the same base tone still reads as a separate surface.
    if (isDrawer) {
      return SizedBox(width: width, child: panel);
    }

    return Neumorphic(
      width: width,
      margin: const EdgeInsets.all(AppSpacing.sm),
      radius: AppRadii.rLg,
      clipContent: true,
      child: panel,
    );
  }

  Widget _buildHeader(BuildContext context, AppColorsData colors) {
    if (_compact) {
      return SizedBox(
        height: 60,
        child: Center(
          child: NeumorphicIconButton(
            icon: Icons.menu_open_rounded,
            tooltip: 'Mở rộng sidebar',
            onPressed: onToggleCollapse,
          ),
        ),
      );
    }

    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            // Shield mark lives in a debossed well.
            Neumorphic(
              width: 36,
              height: 36,
              inset: true,
              radius: AppRadii.rPill,
              color: colors.surfaceMuted,
              child: Icon(
                Icons.shield_outlined,
                size: 17,
                color: colors.foreground,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Text(
                'Vaultly',
                style: AppTypography.brand.copyWith(color: colors.foreground),
              ),
            ),
            if (!isDrawer && onToggleCollapse != null)
              NeumorphicIconButton(
                icon: Icons.menu_rounded,
                tooltip: 'Thu gọn sidebar',
                onPressed: onToggleCollapse,
              ),
            if (isDrawer)
              NeumorphicIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Đóng menu',
                onPressed: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, AppColorsData colors) {
    if (_compact) {
      return SizedBox(
        height: 60,
        child: Center(
          child: NeumorphicIconButton(
            icon: Icons.create_new_folder_outlined,
            tooltip: 'Tạo thư mục mới',
            onPressed: onCreateFolder,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: NeumorphicButton(
        width: double.infinity,
        icon: Icons.create_new_folder_outlined,
        label: 'Thư mục mới',
        onPressed: onCreateFolder,
      ),
    );
  }
}

/// One folder row. Hover reveals a delete action on desktop; long-press works
/// everywhere (touch + mouse) as the discoverable alternative.
class _FolderTile extends StatefulWidget {
  final Folder folder;
  final bool isSelected;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _FolderTile({
    required this.folder,
    required this.isSelected,
    required this.compact,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<_FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<_FolderTile> {
  bool _hovered = false;

  Widget _coverAvatar(double size, AppColorsData colors) {
    final folder = widget.folder;
    return Neumorphic(
      width: size,
      height: size,
      inset: true,
      radius: AppRadii.rXs,
      color: colors.surfaceMuted,
      clipContent: true,
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final folder = widget.folder;
    final isSelected = widget.isSelected;
    final compact = widget.compact;

    final showDelete =
        widget.onDelete != null && (_hovered || isSelected);

    final itemWidget = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Neumorphic(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        radius: AppRadii.rMd,
        depth: 0.55,
        inset: isSelected,
        color: isSelected ? colors.surfaceMuted : colors.surface,
        onTap: widget.onTap,
        onLongPress: widget.onDelete,
        semanticLabel: '${folder.name}, ${folder.photoCount} ảnh',
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.xs : AppSpacing.sm + 2,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            _coverAvatar(compact ? 36.0 : 38.0, colors),
            if (!compact) ...[
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
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: colors.foreground,
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
            if (showDelete)
              NeumorphicIconButton(
                icon: Icons.delete_outline_rounded,
                iconSize: 16,
                tooltip: 'Xóa thư mục "${folder.name}"',
                onPressed: widget.onDelete,
              ),
          ],
        ),
      ),
    );

    if (compact) {
      return Tooltip(
        message: '${folder.name} (${folder.photoCount})',
        waitDuration: const Duration(milliseconds: 300),
        child: itemWidget,
      );
    }

    return itemWidget;
  }
}
