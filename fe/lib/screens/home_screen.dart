import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/mock_data.dart';
import '../models/folder.dart';
import '../models/photo_item.dart';
import '../services/api_service.dart';
import '../theme/app_tokens.dart';
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

    if (!_api.isAuthenticated) return;

    try {
      await _api.fetchCurrentUser();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _handleSessionExpired();
        return;
      }
    } catch (_) {
      // Offline fallback
    }
    if (!mounted) return;

    if (_api.isPinLocked && !_isShowingPinModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptPinUnlock();
      });
    } else {
      await _loadApiData();
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
      await _api.fetchCurrentUser();
      final folders = await _api.fetchFolders();
      final allPhotos = await _api.fetchFiles();

      if (!mounted) return;

      setState(() {
        _photos = allPhotos;
        _folders = _buildFoldersWithCounts(folders, allPhotos);
        if (!_folders.any((f) => f.id == _selectedFolderId)) {
          _selectedFolderId = 'all';
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized) {
        await _handleSessionExpired();
      } else {
        _showSnackBar(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Lỗi tải dữ liệu: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingApi = false);
      }
    }
  }

  List<Folder> _buildFoldersWithCounts(
    List<Folder> folders,
    List<PhotoItem> photos,
  ) {
    PhotoItem? coverFor(String folderId) {
      for (final photo in photos) {
        if (photo.folderId == folderId) return photo;
      }
      return null;
    }

    int countFor(String folderId) =>
        photos.where((p) => p.folderId == folderId).length;

    return [
      Folder(
        id: 'all',
        name: 'Tất cả ảnh',
        icon: Icons.photo_library_outlined,
        photoCount: photos.length,
        coverUrl: photos.isNotEmpty ? photos.first.thumbnailUrl : null,
      ),
      for (final folder in folders)
        folder.copyWith(
          photoCount: countFor(folder.id),
          coverUrl: coverFor(folder.id)?.thumbnailUrl,
        ),
    ];
  }

  void _refreshFolderCounts() {
    if (!_api.isAuthenticated) return;
    final realFolders = _folders.where((f) => f.id != 'all').toList();
    _folders = _buildFoldersWithCounts(realFolders, _photos);
  }

  Future<void> _handleSessionExpired() async {
    await _api.logout();
    if (!mounted) return;
    setState(() {
      _folders = List.from(MockData.initialFolders);
      _photos = List.from(MockData.allPhotos);
      _selectedFolderId = 'all';
      _isApiConnected = false;
    });
    _showSnackBar('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final colors = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.body.copyWith(
            color: isError ? colors.danger : colors.surface,
          ),
        ),
        backgroundColor: colors.foreground,
      ),
    );
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
    final colors = AppColors.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.radiusLg),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.info_outline, color: colors.foreground),
                title: Text(
                  photo.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.heading.copyWith(color: colors.foreground),
                ),
                subtitle: Text(
                  '${photo.fileSize} • E2EE Encrypted',
                  style: AppTypography.label.copyWith(
                    color: colors.foregroundMuted,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ),
              Divider(height: 1, color: colors.border),
              ListTile(
                leading: Icon(Icons.fullscreen, color: colors.foreground),
                title: Text(
                  'Xem toàn màn hình',
                  style: AppTypography.body.copyWith(color: colors.foreground),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _openPhotoViewer(photo);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: colors.danger),
                title: Text(
                  'Xóa khỏi Vault',
                  style: AppTypography.body.copyWith(color: colors.danger),
                ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  try {
                    if (_api.isAuthenticated) {
                      await _api.deleteFile(photo.id);
                    }
                    if (!mounted) return;
                    setState(() {
                      _photos.removeWhere((p) => p.id == photo.id);
                      _refreshFolderCounts();
                    });
                    _showSnackBar('Đã xóa ${photo.title} khỏi Vault');
                  } catch (e) {
                    if (mounted) _showSnackBar('Lỗi xóa ảnh: $e', isError: true);
                  }
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
    final colors = AppColors.of(context);
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.lg,
          side: BorderSide(color: colors.border, width: 1),
        ),
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Icon(Icons.create_new_folder_outlined,
                        size: 18, color: colors.foreground),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Tạo thư mục mới',
                      style: AppTypography.heading.copyWith(color: colors.foreground),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.border),

              // Content
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TextField(
                  controller: textController,
                  autofocus: true,
                  style: AppTypography.body.copyWith(color: colors.foreground),
                  decoration: const InputDecoration(
                    hintText: 'Tên thư mục (ví dụ: Tài chính, Gia đình)',
                  ),
                ),
              ),
              Divider(height: 1, color: colors.border),

              // Action footer
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
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
                                _showSnackBar('Đã tạo thư mục "$name"!');
                              }
                            } catch (e) {
                              if (mounted) {
                                _showSnackBar('Lỗi tạo thư mục: $e', isError: true);
                              }
                            }
                          } else {
                            final newId =
                                'folder_${DateTime.now().millisecondsSinceEpoch}';
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
              ),
            ],
          ),
        ),
      ),
    );
  }

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
        _showSnackBar('Đang mã hóa & tải lên $total ảnh...');
      }

      final List<UploadImageItem> uploadItems = [];
      for (final img in pickedImages) {
        final bytes = await img.readAsBytes();
        uploadItems.add(UploadImageItem(bytes: bytes, fileName: img.name));
      }

      final targetFolderId =
          _selectedFolderId == 'all' ? null : _selectedFolderId;

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
        _showSnackBar(
          'Đã mã hóa XChaCha20 và tải thành công $count/$total ảnh lên Vaultly!',
        );
        await _loadApiData();
      } else {
        final err =
            (res['errors'] as List?)?.join(', ') ?? 'Lỗi không xác định';
        _showSnackBar('Lỗi tải ảnh: $err', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Lỗi chọn ảnh: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingApi = false);
      }
    }
  }

  // Monochrome status chip as defined in DESIGN.md (no saturated chromatic hues)
  Widget _buildApiStatusChip(AppColorsData colors) {
    String statusText;
    IconData statusIcon;

    if (_api.isAuthenticated) {
      statusText = _api.userEmail?.split('@').first ?? 'Vault mở';
      statusIcon = Icons.lock_open_outlined;
    } else if (_isApiConnected) {
      statusText = 'Đăng nhập';
      statusIcon = Icons.login_outlined;
    } else {
      statusText = 'Chưa kết nối';
      statusIcon = Icons.cloud_off_outlined;
    }

    return InkWell(
      onTap: _api.isAuthenticated ? _lockVaultManually : _openAuthScreen,
      borderRadius: AppRadii.sm,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: AppRadii.sm,
          border: Border.all(color: colors.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, size: 13, color: colors.foreground),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              statusText,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.foreground,
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
        final isMobile = constraints.maxWidth < AppSpacing.paneBreakpoint;

        if (isMobile) {
          return _buildMobileLayout(context);
        } else {
          return _buildDesktopLayout(context);
        }
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: const BoxDecoration(
                  borderRadius: AppRadii.xs,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  _currentFolder.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(_currentFolder.icon, size: 16),
                ),
              )
            else ...[
              Icon(
                _currentFolder.icon,
                size: 18,
                color: colors.foreground,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                _currentFolder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.title.copyWith(color: colors.foreground),
              ),
            ),
          ],
        ),
        actions: [
          _buildApiStatusChip(colors),
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
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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

  Widget _buildDesktopLayout(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 2,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: AppRadii.xs,
                border: Border.all(color: colors.border, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 13,
                    color: colors.foreground,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    'Vaultly E2EE Storage',
                    style: AppTypography.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _buildApiStatusChip(colors),
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
          const SizedBox(width: AppSpacing.sm),
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
