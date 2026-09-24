import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/mock_data.dart';
import '../models/folder.dart';
import '../models/photo_item.dart';
import '../services/api_service.dart';
import '../widgets/folder_sidebar.dart';
import '../widgets/photo_grid.dart';
import 'auth_screen.dart';
import 'photo_viewer_screen.dart';
import 'pin_lock_screen.dart';

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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const double kMobileBreakpoint = 680.0;

  final ApiService _api = ApiService();
  bool _isApiConnected = false;
  bool _isLoadingApi = false;
  bool _isShowingPinModal = false;

  late List<Folder> _folders;
  late List<PhotoItem> _photos;
  String _selectedFolderId = 'all';
  int _crossAxisCount = 3; // 2, 3, or 4 columns
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _folders = List.from(MockData.initialFolders);
    _photos = List.from(MockData.allPhotos);

    _bootstrapApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check if 15 minutes of inactivity have elapsed
      if (_api.isAuthenticated && _api.isPinLocked && !_isShowingPinModal) {
        _promptPinUnlock();
      }
    }
  }

  Future<void> _bootstrapApp() async {
    await _api.init();

    final isHealthy = await _api.checkHealth();
    if (mounted) {
      setState(() {
        _isApiConnected = isHealthy;
      });
    }

    if (_api.isAuthenticated) {
      if (_api.isPinLocked && !_isShowingPinModal) {
        // Enforce 6-digit PIN on app start
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _promptPinUnlock();
        });
      } else {
        await _loadApiData();
      }
    }
  }

  void _promptPinUnlock() {
    if (!mounted || _isShowingPinModal) return;
    _isShowingPinModal = true;

    final mode = _api.hasPin ? PinLockMode.unlock : PinLockMode.setup;

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => PinLockScreen(
          mode: mode,
          onSuccess: () {
            _isShowingPinModal = false;
            Navigator.pop(ctx);
            setState(() {});
            _loadApiData();
          },
          onLogout: () async {
            _isShowingPinModal = false;
            await _api.logout();
            if (ctx.mounted) Navigator.pop(ctx);
            setState(() {
              _folders = List.from(MockData.initialFolders);
              _photos = List.from(MockData.allPhotos);
            });
          },
        ),
      ),
    ).then((_) {
      _isShowingPinModal = false;
    });
  }

  void _openAuthScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => AuthScreen(
          onSuccess: () {
            Navigator.pop(ctx);
            if (!_api.hasPin) {
              // Ask to setup PIN right after login/register
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _promptPinUnlock();
              });
            } else {
              _loadApiData();
            }
          },
        ),
      ),
    );
  }

  void _lockVaultManually() {
    _api.lockPin();
    _promptPinUnlock();
  }

  Future<void> _loadApiData() async {
    if (!_api.isAuthenticated) return;

    setState(() => _isLoadingApi = true);
    try {
      final folders = await _api.fetchFolders();
      final photos = await _api.fetchFiles(
        folderId: _selectedFolderId == 'all' ? null : _selectedFolderId,
      );

      if (mounted) {
        setState(() {
          _folders = [
            Folder(
              id: 'all',
              name: 'Tất cả ảnh',
              icon: Icons.photo_library_outlined,
              photoCount: photos.length,
              coverUrl: photos.isNotEmpty ? photos.first.thumbnailUrl : null,
            ),
            ...folders,
          ];

          if (photos.isNotEmpty) {
            _photos = photos;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu Supabase: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingApi = false);
      }
    }
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
    _api.touchActivity();
    setState(() {
      _selectedFolderId = folder.id;
    });
    if (_api.isAuthenticated) {
      _loadApiData();
    }
  }

  void _onZoomChanged(int newCount) {
    _api.touchActivity();
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
    _api.touchActivity();
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
    _api.touchActivity();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
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
                  Navigator.pop(sheetCtx);
                  _openPhotoViewer(photo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Xóa khỏi Vault', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  if (_api.isAuthenticated) {
                    await _api.deleteFile(photo.id);
                  }
                  if (!mounted) return;
                  setState(() {
                    _photos.removeWhere((p) => p.id == photo.id);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã xóa ${photo.title} khỏi Vault'),
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
    _api.touchActivity();
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Tạo thư mục mới', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Tên thư mục (ví dụ: Tài chính, Gia đình)',
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
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(dialogCtx);
                if (_api.isAuthenticated) {
                  try {
                    final created = await _api.createFolder(name);
                    setState(() {
                      _folders.add(created);
                      _selectedFolderId = created.id;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã tạo thư mục "$name" trên Supabase!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi tạo thư mục: $e')),
                      );
                    }
                  }
                } else {
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
                }
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  /// Pick and upload multiple photos from Gallery or Desktop file picker
  Future<void> _pickAndUploadMultiplePhotos() async {
    _api.touchActivity();
    if (!_api.isAuthenticated) {
      _openAuthScreen();
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> pickedImages = await picker.pickMultiImage();

      if (pickedImages.isEmpty) return;

      final total = pickedImages.length;
      setState(() => _isLoadingApi = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đang mã hóa & tải lên $total ảnh...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final List<UploadImageItem> uploadItems = [];
      for (final img in pickedImages) {
        final bytes = await img.readAsBytes();
        uploadItems.add(UploadImageItem(bytes: bytes, fileName: img.name));
      }

      final targetFolderId = _selectedFolderId == 'all' ? null : _selectedFolderId;

      final res = await _api.uploadMultipleImages(
        files: uploadItems,
        folderId: targetFolderId,
        onProgress: (current, total) {
          debugPrint('Upload progress: $current/$total');
        },
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final count = res['uploadedCount'] ?? total;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã mã hóa XChaCha20 và tải thành công $count/$total ảnh lên Vaultly!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadApiData();
      } else {
        final err = (res['errors'] as List?)?.join(', ') ?? 'Lỗi không xác định';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải ảnh: $err'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn ảnh: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingApi = false);
      }
    }
  }

  Widget _buildApiStatusChip(ThemeData theme) {
    Color chipColor;
    String statusText;
    IconData statusIcon;

    if (_api.isAuthenticated) {
      chipColor = Colors.green;
      statusText = _api.userEmail?.split('@').first ?? 'Vault đã mở';
      statusIcon = Icons.lock_open_rounded;
    } else if (_isApiConnected) {
      chipColor = Colors.orange;
      statusText = 'Đăng nhập';
      statusIcon = Icons.login_rounded;
    } else {
      chipColor = Colors.grey;
      statusText = 'Chưa nối DB';
      statusIcon = Icons.cloud_off_rounded;
    }

    return InkWell(
      onTap: _api.isAuthenticated ? _lockVaultManually : _openAuthScreen,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: chipColor.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, size: 12, color: chipColor),
            const SizedBox(width: 6),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: chipColor,
              ),
            ),
          ],
        ),
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
          _buildApiStatusChip(theme),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: isDark ? 'Chế độ sáng' : 'Chế độ tối',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Tải nhiều ảnh lên Vault',
            onPressed: _pickAndUploadMultiplePhotos,
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
      body: Stack(
        children: [
          PhotoGrid(
            folder: _currentFolder,
            photos: _displayedPhotos,
            crossAxisCount: _crossAxisCount,
            onZoomChanged: _onZoomChanged,
            onPhotoTap: _openPhotoViewer,
            onPhotoLongPress: _showPhotoOptions,
            onUploadMockPhoto: _pickAndUploadMultiplePhotos,
          ),
          if (_isLoadingApi)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
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
            const SizedBox(width: 12),
            _buildApiStatusChip(theme),
          ],
        ),
        actions: [
          if (_api.isAuthenticated) ...[
            IconButton(
              icon: const Icon(Icons.lock_outline, size: 20),
              tooltip: 'Khóa Vault bằng PIN',
              onPressed: _lockVaultManually,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Làm mới dữ liệu',
              onPressed: _loadApiData,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, size: 20),
            tooltip: 'Tải nhiều ảnh lên Vault (Desktop / App)',
            onPressed: _pickAndUploadMultiplePhotos,
          ),
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
      body: Stack(
        children: [
          Row(
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
                  onUploadMockPhoto: _pickAndUploadMultiplePhotos,
                ),
              ),
            ],
          ),
          if (_isLoadingApi)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}
