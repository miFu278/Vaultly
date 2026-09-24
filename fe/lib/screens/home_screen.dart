import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/folder.dart';
import '../models/photo_item.dart';
import '../widgets/folder_sidebar.dart';
import '../widgets/photo_grid.dart';
import 'photo_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode currentThemeMode;

  const HomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.currentThemeMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double kMobileBreakpoint = 680.0;

  late List<Folder> _folders;
  late List<PhotoItem> _photos;
  String _selectedFolderId = 'all';
  int _crossAxisCount = 3; // 2, 3, or 4 columns
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _folders = List.from(MockData.initialFolders);
    _photos = List.from(MockData.allPhotos);
  }

  Folder get _currentFolder {
    return _folders.firstWhere(
      (f) => f.id == _selectedFolderId,
      orElse: () => _folders.first,
    );
  }

  List<PhotoItem> get _displayedPhotos {
    if (_selectedFolderId == 'all') {
      return _photos;
    }
    return _photos.where((p) => p.folderId == _selectedFolderId).toList();
  }

  void _onSelectFolder(Folder folder) {
    setState(() {
      _selectedFolderId = folder.id;
    });
  }

  void _onZoomChanged(int newCount) {
    if (newCount >= 2 && newCount <= 4) {
      setState(() {
        _crossAxisCount = newCount;
      });
    }
  }

  void _onToggleCollapse() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _openPhotoViewer(PhotoItem photo) {
    final index = _displayedPhotos.indexWhere((p) => p.id == photo.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewerScreen(
          photos: _displayedPhotos,
          initialIndex: index >= 0 ? index : 0,
        ),
      ),
    );
  }

  void _showPhotoOptions(PhotoItem photo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(photo.title),
                subtitle: Text('${photo.fileSize} • E2EE Encrypted'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.fullscreen),
                title: const Text('Xem toàn màn hình'),
                onTap: () {
                  Navigator.pop(context);
                  _openPhotoViewer(photo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Xóa khỏi Vault', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _photos.removeWhere((p) => p.id == photo.id);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã xóa ${photo.title}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateFolderDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Tạo thư mục mới', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Tên thư mục (ví dụ: Tài chính cá nhân)',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                final newId = 'folder_${DateTime.now().millisecondsSinceEpoch}';
                setState(() {
                  _folders.add(
                    Folder(
                      id: newId,
                      name: name,
                      icon: Icons.folder_outlined,
                      isSecure: true,
                      photoCount: 0,
                    ),
                  );
                  _selectedFolderId = newId;
                });
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  void _addMockPhotoToCurrentFolder() {
    final newId = 'p_${DateTime.now().millisecondsSinceEpoch}';
    final targetFolderId = _selectedFolderId == 'all' ? 'secret' : _selectedFolderId;

    final newPhoto = PhotoItem(
      id: newId,
      folderId: targetFolderId,
      title: 'Anh_chup_moi_${DateTime.now().second}.jpg',
      thumbnailUrl: 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=500&q=80',
      fullUrl: 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=1400&q=80',
      createdAt: DateTime.now(),
      fileSize: '3.1 MB',
      isEncrypted: true,
    );

    setState(() {
      _photos.insert(0, newPhoto);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm 1 ảnh mẫu vào "${_currentFolder.name}"'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < kMobileBreakpoint;

        if (isMobile) {
          return _buildMobileLayout(context);
        } else {
          return _buildDesktopLayout(context);
        }
      },
    );
  }

  // Mobile layout (narrow screen / Android): Sidebar as Drawer
  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Danh sách thư mục',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            if (_currentFolder.coverUrl != null)
              Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  _currentFolder.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(_currentFolder.icon, size: 18),
                ),
              )
            else ...[
              Icon(
                _currentFolder.icon,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                _currentFolder.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: isDark ? 'Chế độ sáng' : 'Chế độ tối',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Thêm ảnh mẫu',
            onPressed: _addMockPhotoToCurrentFolder,
          ),
        ],
      ),
      drawer: Drawer(
        elevation: 1,
        child: SafeArea(
          child: FolderSidebar(
            folders: _folders,
            selectedFolderId: _selectedFolderId,
            onSelectFolder: _onSelectFolder,
            isDrawer: true,
            onCreateFolder: _showCreateFolderDialog,
          ),
        ),
      ),
      body: PhotoGrid(
        folder: _currentFolder,
        photos: _displayedPhotos,
        crossAxisCount: _crossAxisCount,
        onZoomChanged: _onZoomChanged,
        onPhotoTap: _openPhotoViewer,
        onPhotoLongPress: _showPhotoOptions,
        onUploadMockPhoto: _addMockPhotoToCurrentFolder,
      ),
    );
  }

  // Desktop / Web layout (wide screen): 2-pane with Collapsible Sidebar
  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.dividerColor, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 13,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Vaultly E2EE Storage',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Theme Toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
            ),
            tooltip: isDark ? 'Chuyển sang chế độ sáng' : 'Chuyển sang chế độ tối',
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Pane: Folder Sidebar
          FolderSidebar(
            folders: _folders,
            selectedFolderId: _selectedFolderId,
            onSelectFolder: _onSelectFolder,
            isCollapsed: _isSidebarCollapsed,
            onToggleCollapse: _onToggleCollapse,
            isDrawer: false,
            onCreateFolder: _showCreateFolderDialog,
          ),

          // Right Pane: Photo Grid
          Expanded(
            child: PhotoGrid(
              folder: _currentFolder,
              photos: _displayedPhotos,
              crossAxisCount: _crossAxisCount,
              onZoomChanged: _onZoomChanged,
              onPhotoTap: _openPhotoViewer,
              onPhotoLongPress: _showPhotoOptions,
              onUploadMockPhoto: _addMockPhotoToCurrentFolder,
            ),
          ),
        ],
      ),
    );
  }
}
