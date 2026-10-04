import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/mock_data.dart';
import '../models/folder.dart';
import '../models/photo_item.dart';
import '../services/api_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/folder_sidebar.dart';
import '../widgets/neumorphic.dart';
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

  // Background async upload state (non-blocking)
  bool _isBackgroundUploading = false;
  int _uploadCurrent = 0;
  int _uploadTotal = 0;

  // Multi-select state
  bool _isSelectionMode = false;
  Set<String> _selectedPhotoIds = {};

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
      _isSelectionMode = false;
      _selectedPhotoIds.clear();
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
      _selectedPhotoIds.clear();
      _isSelectionMode = false;
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetCtx) {
        return Neumorphic(
          depth: 1.4,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.rXl),
          ),
          clipContent: true,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        photo.checkIsVideo
                            ? Icons.videocam_outlined
                            : Icons.info_outline,
                        size: 18,
                        color: colors.foreground,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              photo.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.heading
                                  .copyWith(color: colors.foreground),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${photo.fileSize} • ${photo.checkIsVideo ? 'Video E2EE' : 'E2EE Encrypted'}',
                              style: AppTypography.label.copyWith(
                                color: colors.foregroundMuted,
                                fontFeatures: AppTypography.tabularFigures,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _sheetRow(
                  colors,
                  icon: Icons.fullscreen,
                  title: 'Xem toàn màn hình',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _openPhotoViewer(photo);
                  },
                ),
                _sheetRow(
                  colors,
                  icon: Icons.checklist_rounded,
                  title: 'Chọn ảnh này',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    setState(() {
                      _isSelectionMode = true;
                      _selectedPhotoIds.add(photo.id);
                    });
                  },
                ),
                _sheetRow(
                  colors,
                  icon: Icons.delete_outline,
                  title: 'Xóa khỏi Vault',
                  danger: true,
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
                    _showSnackBar('Đã xóa ${photo.displayTitle} khỏi Vault');
                  } catch (e) {
                    if (mounted) _showSnackBar('Lỗi xóa tệp: $e', isError: true);
                  }
                },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Multi-select actions ---

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedPhotoIds.clear();
      }
    });
  }

  void _toggleSelectPhoto(String id) {
    setState(() {
      if (_selectedPhotoIds.contains(id)) {
        _selectedPhotoIds.remove(id);
      } else {
        _selectedPhotoIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedPhotoIds = _displayedPhotos.map((p) => p.id).toSet();
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedPhotoIds.clear();
    });
  }

  Future<void> _deleteSelectedPhotos() async {
    final count = _selectedPhotoIds.length;
    if (count == 0) return;

    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => NeumorphicDialog(
        maxWidth: 380,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Xóa $count mục đã chọn?',
                style: AppTypography.heading.copyWith(color: colors.foreground),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Các tệp đã chọn sẽ bị xóa vĩnh viễn khỏi Vaultly. Hành động này không thể hoàn tác.',
                style: AppTypography.body.copyWith(color: colors.foregroundMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NeumorphicButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    label: 'Hủy',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  NeumorphicButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    label: 'Xóa',
                    danger: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final idsToDelete = _selectedPhotoIds.toList();
    setState(() => _isLoadingApi = true);

    try {
      if (_api.isAuthenticated) {
        await _api.batchDeleteFiles(idsToDelete);
      }
      setState(() {
        _photos.removeWhere((p) => idsToDelete.contains(p.id));
        _selectedPhotoIds.clear();
        _isSelectionMode = false;
        _refreshFolderCounts();
      });
      _showSnackBar('Đã xóa $count mục khỏi Vault');
    } catch (e) {
      _showSnackBar('Lỗi xóa mục: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingApi = false);
    }
  }

  Future<void> _addSelectedToFolder() async {
    final count = _selectedPhotoIds.length;
    if (count == 0) return;

    final targetFolders = _folders.where((f) => f.id != 'all').toList();
    if (targetFolders.isEmpty) {
      _showSnackBar('Chưa có thư mục nào để chuyển vào. Hãy tạo thư mục mới trước!');
      return;
    }

    final colors = AppColors.of(context);
    final selectedFolder = await showDialog<Folder>(
      context: context,
      builder: (ctx) => NeumorphicDialog(
        maxWidth: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Chọn thư mục đích',
                style: AppTypography.heading.copyWith(color: colors.foreground),
              ),
            ),
            Divider(height: 1, color: colors.border),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: targetFolders.length,
                itemBuilder: (context, i) {
                  final folder = targetFolders[i];
                  return _sheetRow(
                    colors,
                    icon: folder.icon,
                    title: folder.name,
                    subtitle: '${folder.photoCount} tệp',
                    onTap: () => Navigator.pop(ctx, folder),
                  );
                },
              ),
            ),
            Divider(height: 1, color: colors.border),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NeumorphicButton(
                    onPressed: () => Navigator.pop(ctx),
                    label: 'Hủy',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedFolder == null || !mounted) return;

    // Check if any of the selected photos already belong to another folder
    final bool anyAlreadyInFolder = _selectedPhotoIds.any((id) {
      final p = _photos.cast<PhotoItem?>().firstWhere((item) => item?.id == id, orElse: () => null);
      return p != null && p.folderId != 'all' && p.folderId.isNotEmpty && p.folderId != selectedFolder.id;
    });

    String action = 'move';
    if (anyAlreadyInFolder) {
      final chosenAction = await showDialog<String>(
        context: context,
        builder: (ctx) => NeumorphicDialog(
          maxWidth: 420,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Di chuyển hay Sao chép?',
                  style: AppTypography.heading.copyWith(color: colors.foreground),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Một số ảnh/video bạn chọn đã nằm trong thư mục khác. Bạn muốn di chuyển hẳn sang "${selectedFolder.name}" hay tạo thêm bản sao chép vào thư mục này?',
                  style: AppTypography.body.copyWith(color: colors.foregroundMuted),
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    NeumorphicButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      label: 'Hủy',
                    ),
                    NeumorphicButton(
                      onPressed: () => Navigator.pop(ctx, 'copy'),
                      label: 'Sao chép',
                    ),
                    NeumorphicButton(
                      onPressed: () => Navigator.pop(ctx, 'move'),
                      label: 'Di chuyển',
                      primary: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (chosenAction == null || !mounted) return;
      action = chosenAction;
    }

    setState(() => _isLoadingApi = true);
    final ids = _selectedPhotoIds.toList();

    try {
      if (action == 'move') {
        for (final id in ids) {
          if (_api.isAuthenticated) {
            await _api.moveFileToFolder(id, selectedFolder.id);
          }
          final idx = _photos.indexWhere((p) => p.id == id);
          if (idx != -1) {
            _photos[idx] = _photos[idx].copyWith(folderId: selectedFolder.id);
          }
        }
        _showSnackBar('Đã di chuyển $count mục vào thư mục "${selectedFolder.name}"');
      } else {
        // Copy action
        for (final id in ids) {
          if (_api.isAuthenticated) {
            await _api.copyFileToFolder(id, selectedFolder.id);
          }
          final original = _photos.firstWhere((p) => p.id == id);
          final copied = original.copyWith(
            id: 'copy_${DateTime.now().millisecondsSinceEpoch}_${original.id}',
            folderId: selectedFolder.id,
            createdAt: DateTime.now(),
          );
          _photos.add(copied);
        }
        _showSnackBar('Đã sao chép $count mục vào thư mục "${selectedFolder.name}"');
      }

      setState(() {
        _selectedPhotoIds.clear();
        _isSelectionMode = false;
        _refreshFolderCounts();
      });
    } catch (e) {
      _showSnackBar('Lỗi xử lý thư mục: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingApi = false);
    }
  }

  Future<void> _confirmDeleteFolder(Folder folder) async {
    if (folder.id == 'all') return;
    _api.touchActivity();

    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => NeumorphicDialog(
        maxWidth: 380,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Xóa thư mục "${folder.name}"?',
                style: AppTypography.heading.copyWith(color: colors.foreground),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                folder.photoCount > 0
                    ? '${folder.photoCount} ảnh/video trong thư mục sẽ được đưa về mục "Tất cả ảnh" chứ không bị xóa.'
                    : 'Thư mục trống sẽ bị xóa vĩnh viễn.',
                style: AppTypography.body.copyWith(color: colors.foregroundMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NeumorphicButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    label: 'Hủy',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  NeumorphicButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    label: 'Xóa',
                    danger: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      if (_api.isAuthenticated) {
        await _api.deleteFolder(folder.id);
      }
      setState(() {
        _folders.removeWhere((f) => f.id == folder.id);
        // Files stay in the vault, so they surface under "Tất cả ảnh".
        for (var i = 0; i < _photos.length; i++) {
          if (_photos[i].folderId == folder.id) {
            _photos[i] = _photos[i].copyWith(folderId: 'all');
          }
        }
        if (_selectedFolderId == folder.id) _selectedFolderId = 'all';
        _refreshFolderCounts();
      });
      _showSnackBar('Đã xóa thư mục "${folder.name}"');
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi xóa thư mục: $e', isError: true);
    }
  }

  void _showCreateFolderDialog() {
    _api.touchActivity();
    final colors = AppColors.of(context);
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => NeumorphicDialog(
        maxWidth: 400,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TextField(
                  controller: textController,
                  autofocus: true,
                  style: AppTypography.body.copyWith(color: colors.foreground),
                  decoration: const InputDecoration(
                    hintText: 'Tên thư mục (ví dụ: Tài chính, Video riêng tư)',
                  ),
                ),
              ),
              Divider(height: 1, color: colors.border),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    NeumorphicButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      label: 'Hủy',
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    NeumorphicButton(
                      primary: true,
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
                      label: 'Tạo',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  // --- Background Upload (Non-blocking async) for photos & videos ---

  void _showUploadMenu() {
    _api.touchActivity();
    if (!_api.isAuthenticated) {
      _openAuthScreen();
      return;
    }

    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetCtx) {
        return Neumorphic(
          depth: 1.4,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.rXl),
          ),
          clipContent: true,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined,
                          size: 18, color: colors.foreground),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Tải tệp lên Vault (Mã hóa nền E2EE)',
                          style: AppTypography.heading
                              .copyWith(color: colors.foreground),
                        ),
                      ),
                    ],
                  ),
                ),
                _sheetRow(
                  colors,
                  icon: Icons.photo_library_outlined,
                  title: 'Chọn nhiều ảnh từ thư viện',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickAndUploadMedia(isPhotoOnly: true);
                  },
                ),
                _sheetRow(
                  colors,
                  icon: Icons.videocam_outlined,
                  title: 'Chọn video từ thư viện',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickAndUploadVideo();
                  },
                ),
                _sheetRow(
                  colors,
                  icon: Icons.perm_media_outlined,
                  title: 'Chọn ảnh & video (hỗn hợp)',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickAndUploadMedia(isPhotoOnly: false);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;
      _startBackgroundUpload([video]);
    } catch (e) {
      _showSnackBar('Lỗi chọn video: $e', isError: true);
    }
  }

  Future<void> _pickAndUploadMedia({bool isPhotoOnly = true}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> pickedFiles;
      if (isPhotoOnly) {
        pickedFiles = await picker.pickMultiImage();
      } else {
        pickedFiles = await picker.pickMultipleMedia();
      }
      if (pickedFiles.isEmpty) return;
      _startBackgroundUpload(pickedFiles);
    } catch (e) {
      _showSnackBar('Lỗi chọn tệp: $e', isError: true);
    }
  }

  // Runs upload in the background asynchronously without locking the UI
  void _startBackgroundUpload(List<XFile> pickedFiles) {
    final total = pickedFiles.length;
    setState(() {
      _isBackgroundUploading = true;
      _uploadCurrent = 0;
      _uploadTotal = total;
    });

    _showSnackBar('Đang mã hóa & tải $total tệp lên nền (bạn vẫn có thể sử dụng app)...');

    // Launch async background task
    Future(() async {
      try {
        final List<UploadImageItem> uploadItems = [];
        for (final file in pickedFiles) {
          final bytes = await file.readAsBytes();
          final lower = file.name.toLowerCase();
          final isVid = lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.webm') || lower.endsWith('.mkv');
          uploadItems.add(UploadImageItem(bytes: bytes, fileName: file.name, isVideo: isVid));
        }

        final targetFolderId = _selectedFolderId == 'all' ? null : _selectedFolderId;

        final res = await _api.uploadMultipleImages(
          files: uploadItems,
          folderId: targetFolderId,
          onProgress: (current, total) {
            if (mounted) {
              setState(() {
                _uploadCurrent = current;
                _uploadTotal = total;
              });
            }
          },
        );

        if (!mounted) return;

        if (res['success'] == true) {
          final count = res['uploadedCount'] ?? total;
          _showSnackBar('Đã tải thành công $count/$total tệp lên Vaultly!');
          await _loadApiData();
        } else {
          final err = (res['errors'] as List?)?.join(', ') ?? 'Lỗi không xác định';
          _showSnackBar('Lỗi tải tệp: $err', isError: true);
        }
      } catch (e) {
        if (mounted) _showSnackBar('Lỗi tải tệp lên nền: $e', isError: true);
      } finally {
        if (mounted) {
          setState(() {
            _isBackgroundUploading = false;
          });
        }
      }
    });
  }

  /// One row of a bottom sheet, as a raised neumorphic tile.
  Widget _sheetRow(
    AppColorsData colors, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final tint = danger ? colors.danger : colors.foreground;
    return Neumorphic(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      radius: AppRadii.rMd,
      depth: 0.7,
      onTap: onTap,
      semanticLabel: title,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    color: tint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.label.copyWith(
                      color: colors.foregroundMuted,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

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

    return Neumorphic(
      radius: AppRadii.rPill,
      depth: 0.6,
      onTap: _api.isAuthenticated ? _lockVaultManually : _openAuthScreen,
      semanticLabel: statusText,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 14, color: colors.foreground),
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
          builder: (ctx) => Center(
            child: NeumorphicIconButton(
              icon: Icons.menu_rounded,
              tooltip: 'Danh sách thư mục',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: _buildApiStatusChip(colors),
          ),
          NeumorphicIconButton(
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            tooltip: isDark ? 'Chế độ sáng' : 'Chế độ tối',
            onPressed: widget.onToggleTheme,
          ),
          NeumorphicIconButton(
            icon: Icons.add_photo_alternate_outlined,
            tooltip: 'Tải ảnh & video lên Vault',
            onPressed: _showUploadMenu,
          ),
          const SizedBox(width: AppSpacing.sm),
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
            onDeleteFolder: _confirmDeleteFolder,
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
            onUploadMockPhoto: _showUploadMenu,
            isSelectionMode: _isSelectionMode,
            selectedPhotoIds: _selectedPhotoIds,
            onToggleSelectPhoto: _toggleSelectPhoto,
            onToggleSelectionMode: _toggleSelectionMode,
            onSelectAll: _selectAll,
            onDeselectAll: _deselectAll,
            onDeleteSelected: _deleteSelectedPhotos,
            onAddSelectedToFolder: _addSelectedToFolder,
          ),
          if (_isLoadingApi || _isBackgroundUploading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 3,
                value: _isBackgroundUploading && _uploadTotal > 0
                    ? (_uploadCurrent / _uploadTotal)
                    : null,
              ),
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
            Neumorphic(
              inset: true,
              radius: AppRadii.rPill,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs + 2,
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
            if (_isBackgroundUploading) ...[
              const SizedBox(width: AppSpacing.md),
              Neumorphic(
                inset: true,
                radius: AppRadii.rPill,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Text(
                      'Đang tải lên: $_uploadCurrent/$_uploadTotal',
                      style: AppTypography.caption.copyWith(
                        color: colors.foreground,
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_api.isAuthenticated) ...[
            NeumorphicIconButton(
              icon: Icons.lock_outline,
              tooltip: 'Khóa Vault bằng PIN',
              onPressed: _lockVaultManually,
            ),
            NeumorphicIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Làm mới dữ liệu',
              onPressed: _loadApiData,
            ),
          ],
          NeumorphicIconButton(
            icon: Icons.cloud_upload_outlined,
            tooltip: 'Tải nhiều ảnh & video lên Vault (Desktop / App)',
            onPressed: _showUploadMenu,
          ),
          NeumorphicIconButton(
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            tooltip: isDark
                ? 'Chuyển sang chế độ sáng'
                : 'Chuyển sang chế độ tối',
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
                onDeleteFolder: _confirmDeleteFolder,
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
                  onUploadMockPhoto: _showUploadMenu,
                  isSelectionMode: _isSelectionMode,
                  selectedPhotoIds: _selectedPhotoIds,
                  onToggleSelectPhoto: _toggleSelectPhoto,
                  onToggleSelectionMode: _toggleSelectionMode,
                  onSelectAll: _selectAll,
                  onDeselectAll: _deselectAll,
                  onDeleteSelected: _deleteSelectedPhotos,
                  onAddSelectedToFolder: _addSelectedToFolder,
                ),
              ),
            ],
          ),
          if (_isLoadingApi || _isBackgroundUploading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                value: _isBackgroundUploading && _uploadTotal > 0
                    ? (_uploadCurrent / _uploadTotal)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
