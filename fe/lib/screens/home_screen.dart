import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/mock_data.dart';
import '../models/folder.dart';
import '../models/photo_item.dart';
import '../models/storage_usage.dart';
import '../services/api_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/flat.dart';
import 'albums_view.dart';
import 'auth_screen.dart';
import 'files_view.dart';
import 'gallery_view.dart';
import 'overview_view.dart';
import 'photo_viewer_screen.dart';
import 'pin_lock_screen.dart';
import 'settings_view.dart';

/// App shell: header, navigation (rail on wide screens, drawer plus dock on
/// phones) and the three vault views. Data loading, PIN gating and every file
/// action live here so the views stay presentational.
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
  int _crossAxisCount = 3;
  bool _densityTouched = false;

  /// 0 overview, 1 gallery, 2 albums, 3 files, 4 settings.
  int _tabIndex = 0;
  StorageUsage _storage = StorageUsage.empty;
  MediaFilter _filter = MediaFilter.all;
  String _searchQuery = '';

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
            // A fresh login may land on an account that already has a PIN: check
            // the lock state, not just whether a PIN exists, or the vault opens
            // without the PIN being entered.
            if (_api.isPinLocked) {
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
      final storage = await _api.fetchStorage();

      if (!mounted) return;

      setState(() {
        _storage = storage ?? StorageUsage.empty;
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
      _tabIndex = 0;
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
        backgroundColor: isError ? colors.surface : colors.foreground,
      ),
    );
  }

  // --- Derived data ---

  Folder get _currentFolder {
    return _folders.firstWhere(
      (f) => f.id == _selectedFolderId,
      orElse: () => _folders.first,
    );
  }

  List<Folder> get _albums =>
      _folders.where((f) => f.id != 'all').toList(growable: false);

  Map<String, List<PhotoItem>> get _photosByAlbum {
    final map = <String, List<PhotoItem>>{};
    for (final photo in _photos) {
      map.putIfAbsent(photo.folderId, () => []).add(photo);
    }
    return map;
  }

  /// Photos after folder, media-type and search filtering. Selection, counting
  /// and the viewer all read this list so they never disagree.
  List<PhotoItem> get _displayedPhotos {
    final query = _searchQuery.trim().toLowerCase();
    return _photos.where((photo) {
      if (_selectedFolderId != 'all' && photo.folderId != _selectedFolderId) {
        return false;
      }
      switch (_filter) {
        case MediaFilter.photos:
          if (photo.checkIsVideo) return false;
        case MediaFilter.videos:
          if (!photo.checkIsVideo) return false;
        case MediaFilter.all:
          break;
      }
      if (query.isEmpty) return true;
      return photo.displayTitle.toLowerCase().contains(query);
    }).toList();
  }

  // --- Navigation and selection ---

  void _setTab(int index) {
    _api.touchActivity();
    setState(() {
      _tabIndex = index;
      _isSelectionMode = false;
      _selectedPhotoIds.clear();
    });
  }

  void _onSelectFolder(Folder folder) {
    _api.touchActivity();
    setState(() {
      _selectedFolderId = folder.id;
      _tabIndex = 1;
      _selectedPhotoIds.clear();
      _isSelectionMode = false;
    });
  }

  void _onZoomChanged(int newCount) {
    _api.touchActivity();
    if (newCount >= 2 && newCount <= 4) {
      setState(() {
        _crossAxisCount = newCount;
        _densityTouched = true;
      });
    }
  }

  void _openPhotoViewer(PhotoItem photo) {
    _api.touchActivity();
    final list = _displayedPhotos;
    final index = list.indexWhere((p) => p.id == photo.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewerScreen(
          photos: list.isEmpty ? [photo] : list,
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
      elevation: 0,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.rXl)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      photo.checkIsVideo
                          ? Icons.videocam_outlined
                          : Icons.image_outlined,
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
                            style: AppTypography.label.copyWith(
                              color: colors.foreground,
                            ),
                          ),
                          Text(
                            '${photo.fileSize} • ${photo.checkIsVideo ? 'Video' : 'Ảnh'} đã mã hóa',
                            style: AppTypography.caption.copyWith(
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
              SheetAction(
                icon: Icons.fullscreen_rounded,
                title: 'Xem toàn màn hình',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _openPhotoViewer(photo);
                },
              ),
              SheetAction(
                icon: Icons.checklist_rounded,
                title: 'Chọn mục này',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  setState(() {
                    _isSelectionMode = true;
                    _selectedPhotoIds.add(photo.id);
                  });
                },
              ),
              SheetAction(
                icon: Icons.delete_outline_rounded,
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
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

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
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelectedPhotos() async {
    final count = _selectedPhotoIds.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.delete_outline_rounded,
        title: 'Xóa $count mục đã chọn?',
        message:
            'Các tệp đã chọn sẽ bị xóa vĩnh viễn khỏi Vaultly. Hành động này không thể hoàn tác.',
        actions: [
          PillButton(
            label: 'Huỷ',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          PillButton(
            label: 'Xóa',
            variant: PillVariant.danger,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
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

    final targetFolders = _albums;
    if (targetFolders.isEmpty) {
      _showSnackBar('Chưa có album nào. Hãy tạo album mới trước!');
      return;
    }

    final selectedFolder = await showDialog<Folder>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.library_add_outlined,
        title: 'Chọn album đích',
        body: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: targetFolders.length,
            itemBuilder: (context, i) {
              final folder = targetFolders[i];
              return SheetAction(
                icon: folder.icon,
                title: folder.name,
                subtitle: '${folder.photoCount} mục',
                onTap: () => Navigator.pop(ctx, folder),
              );
            },
          ),
        ),
        actions: [
          PillButton(
            label: 'Huỷ',
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );

    if (selectedFolder == null || !mounted) return;

    final bool anyAlreadyInFolder = _selectedPhotoIds.any((id) {
      final p = _photos.cast<PhotoItem?>().firstWhere(
            (item) => item?.id == id,
            orElse: () => null,
          );
      return p != null &&
          p.folderId != 'all' &&
          p.folderId.isNotEmpty &&
          p.folderId != selectedFolder.id;
    });

    String action = 'move';
    if (anyAlreadyInFolder) {
      final chosenAction = await showDialog<String>(
        context: context,
        builder: (ctx) => AppDialog(
          icon: Icons.drive_file_move_outline,
          title: 'Di chuyển hay sao chép?',
          message:
              'Một số mục đã nằm trong album khác. Bạn muốn di chuyển hẳn sang "${selectedFolder.name}" hay tạo thêm bản sao?',
          actions: [
            PillButton(
              label: 'Huỷ',
              onPressed: () => Navigator.pop(ctx),
            ),
            PillButton(
              label: 'Sao chép',
              onPressed: () => Navigator.pop(ctx, 'copy'),
            ),
            PillButton(
              label: 'Di chuyển',
              variant: PillVariant.primary,
              onPressed: () => Navigator.pop(ctx, 'move'),
            ),
          ],
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
        _showSnackBar('Đã di chuyển $count mục vào "${selectedFolder.name}"');
      } else {
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
        _showSnackBar('Đã sao chép $count mục vào "${selectedFolder.name}"');
      }

      setState(() {
        _selectedPhotoIds.clear();
        _isSelectionMode = false;
        _refreshFolderCounts();
      });
    } catch (e) {
      _showSnackBar('Lỗi xử lý album: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingApi = false);
    }
  }

  Future<void> _confirmDeleteFolder(Folder folder) async {
    if (folder.id == 'all') return;
    _api.touchActivity();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.folder_delete_outlined,
        title: 'Xóa album "${folder.name}"?',
        message: folder.photoCount > 0
            ? '${folder.photoCount} mục trong album sẽ được đưa về "Tất cả ảnh" chứ không bị xóa.'
            : 'Album trống sẽ bị xóa vĩnh viễn.',
        actions: [
          PillButton(
            label: 'Huỷ',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          PillButton(
            label: 'Xóa',
            variant: PillVariant.danger,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
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
      _showSnackBar('Đã xóa album "${folder.name}"');
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi xóa album: $e', isError: true);
    }
  }

  void _showCreateFolderDialog() {
    _api.touchActivity();
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AppDialog(
        icon: Icons.create_new_folder_outlined,
        title: 'Album mới',
        body: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Tên album (ví dụ: Gia đình, Hoá đơn)',
          ),
        ),
        actions: [
          PillButton(
            label: 'Huỷ',
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          PillButton(
            label: 'Tạo',
            variant: PillVariant.primary,
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogCtx);
              if (_api.isAuthenticated) {
                try {
                  final created = await _api.createFolder(name);
                  if (!mounted) return;
                  setState(() {
                    _folders.add(created);
                    _selectedFolderId = created.id;
                    _tabIndex = 1;
                  });
                  _showSnackBar('Đã tạo album "$name"!');
                } catch (e) {
                  if (mounted) {
                    _showSnackBar('Lỗi tạo album: $e', isError: true);
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
                  _tabIndex = 1;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // --- Background upload (non-blocking async) for photos & videos ---

  void _showUploadMenu() {
    _api.touchActivity();
    if (!_api.isAuthenticated) {
      _openAuthScreen();
      return;
    }

    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      elevation: 0,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.rXl)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
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
                        'Tải tệp lên Vault',
                        style: AppTypography.label.copyWith(
                          color: colors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SheetAction(
                icon: Icons.photo_library_outlined,
                title: 'Chọn nhiều ảnh',
                subtitle: 'Từ thư viện ảnh trên thiết bị',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickAndUploadMedia(isPhotoOnly: true);
                },
              ),
              SheetAction(
                icon: Icons.videocam_outlined,
                title: 'Chọn video',
                subtitle: 'Video sẽ được mã hóa theo từng đoạn',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickAndUploadVideo();
                },
              ),
              SheetAction(
                icon: Icons.perm_media_outlined,
                title: 'Chọn ảnh & video',
                subtitle: 'Chọn hỗn hợp trong một lần',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickAndUploadMedia(isPhotoOnly: false);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
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

  /// Runs the upload off the UI thread. One file per request: holding an entire
  /// batch of videos in memory is what ran phones out of memory before.
  void _startBackgroundUpload(List<XFile> pickedFiles) {
    final total = pickedFiles.length;
    setState(() {
      _isBackgroundUploading = true;
      _uploadCurrent = 0;
      _uploadTotal = total;
    });

    _showSnackBar('Đang mã hóa & tải $total tệp lên nền...');

    Future(() async {
      try {
        final targetFolderId =
            _selectedFolderId == 'all' ? null : _selectedFolderId;
        var uploaded = 0;
        final errors = <String>[];

        for (var i = 0; i < pickedFiles.length; i++) {
          final file = pickedFiles[i];
          try {
            final bytes = await file.readAsBytes();
            final lower = file.name.toLowerCase();
            final isVid = lower.endsWith('.mp4') ||
                lower.endsWith('.mov') ||
                lower.endsWith('.webm') ||
                lower.endsWith('.mkv');

            final res = await _api.uploadMultipleImages(
              files: [
                UploadImageItem(
                  bytes: bytes,
                  fileName: file.name,
                  isVideo: isVid,
                ),
              ],
              folderId: targetFolderId,
            );

            if (res['success'] == true && (res['uploadedCount'] as int? ?? 0) > 0) {
              uploaded++;
            } else {
              final itemErrors = res['errors'] as List?;
              if (itemErrors != null && itemErrors.isNotEmpty) {
                errors.addAll(itemErrors.map((e) => e.toString()));
              } else {
                errors.add('${file.name}: lỗi không xác định');
              }
            }
          } catch (e) {
            errors.add('${file.name}: $e');
          }

          if (!mounted) return;
          setState(() {
            _uploadCurrent = i + 1;
            _uploadTotal = total;
          });
        }

        if (!mounted) return;

        if (uploaded > 0) {
          _showSnackBar('Đã tải thành công $uploaded/$total tệp lên Vaultly!');
          await _loadApiData();
        } else {
          _showSnackBar('Lỗi tải tệp: ${errors.join(', ')}', isError: true);
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

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    setState(() {
      _folders = List.from(MockData.initialFolders);
      _photos = List.from(MockData.allPhotos);
      _selectedFolderId = 'all';
      _isApiConnected = false;
      _tabIndex = 0;
    });
    _showSnackBar('Đã đăng xuất khỏi Vaultly');
  }

  // --- Shell chrome ---

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppSpacing.paneBreakpoint;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: colors.background,
          drawer: isWide
              ? null
              : Drawer(
                  backgroundColor: colors.surface,
                  shape: const RoundedRectangleBorder(),
                  child: SafeArea(child: _buildRail(isDrawer: true)),
                ),
          floatingActionButton: _tabIndex == 4
              ? null
              : Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: FloatingActionButton(
                    onPressed: _showUploadMenu,
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    elevation: 2,
                    tooltip: 'Tải tệp lên Vault',
                    child: const Icon(Icons.add_rounded, size: 26),
                  ),
                ),
          bottomNavigationBar:
              isWide ? null : _buildBottomDock(context, colors),
          body: SafeArea(
            bottom: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isWide) _buildRail(isDrawer: false),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppSpacing.contentMax,
                      ),
                      child: Column(
                        children: [
                          _buildTopBar(context, colors, isWide: isWide),
                          if (_isLoadingApi || _isBackgroundUploading)
                            LinearProgressIndicator(
                              minHeight: 3,
                              value: _isBackgroundUploading && _uploadTotal > 0
                                  ? (_uploadCurrent / _uploadTotal)
                                  : null,
                            ),
                          Expanded(child: _buildContent(isWide)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(bool isWide) {
    // Wide screens start one column denser; the user's pick wins afterwards.
    final density = (_densityTouched || !isWide) ? _crossAxisCount : 4;

    switch (_tabIndex) {
      case 0:
        return OverviewView(
          usage: _storage,
          isAuthenticated: _api.isAuthenticated,
          albums: _albums,
          photosByAlbum: _photosByAlbum,
          onOpenAlbum: _onSelectFolder,
          onOpenAlbums: () => _setTab(2),
        );
      case 2:
        return AlbumsView(
          albums: _albums,
          photosByAlbum: _photosByAlbum,
          onOpen: _onSelectFolder,
          onDelete: _confirmDeleteFolder,
          onCreate: _showCreateFolderDialog,
        );
      case 3:
        return FilesView(
          folders: _albums,
          files: _photos,
          onOpenFolder: _onSelectFolder,
          onOpenFile: _openPhotoViewer,
          onFileOptions: _showPhotoOptions,
        );
      case 4:
        return SettingsView(
          email: _api.userEmail,
          isAuthenticated: _api.isAuthenticated,
          isConnected: _isApiConnected,
          uploadInProgress: _isBackgroundUploading,
          uploadDone: _uploadCurrent,
          uploadTotal: _uploadTotal,
          themeMode: widget.currentThemeMode,
          baseUrl: _api.baseUrl,
          onToggleTheme: widget.onToggleTheme,
          onLock: _lockVaultManually,
          onLogout: _logout,
          onSignIn: _openAuthScreen,
          onRefresh: _loadApiData,
        );
      default:
        return GalleryView(
          subtitle: '${_displayedPhotos.length} mục',
          photos: _displayedPhotos,
          filter: _filter,
          onFilterChanged: (value) {
            _api.touchActivity();
            setState(() => _filter = value);
          },
          crossAxisCount: density,
          onDensityChanged: _onZoomChanged,
          showDensity: isWide,
          searchQuery: _searchQuery,
          onSearchQueryChanged: (value) => setState(() => _searchQuery = value),
          isSelectionMode: _isSelectionMode,
          selectedIds: _selectedPhotoIds,
          onOpenPhoto: _openPhotoViewer,
          onPhotoLongPress: _showPhotoOptions,
          onToggleSelect: _toggleSelectPhoto,
          onToggleSelectionMode: _toggleSelectionMode,
          onSelectAll: _selectAll,
          onDeselectAll: _deselectAll,
          onDeleteSelected: _deleteSelectedPhotos,
          onAddSelectedToAlbum: _addSelectedToFolder,
          onUpload: _showUploadMenu,
        );
    }
  }

  Widget _buildTopBar(
    BuildContext context,
    AppColorsData colors, {
    required bool isWide,
  }) {
    final title = switch (_tabIndex) {
      0 => 'Tổng quan',
      2 => 'Album',
      3 => 'Tệp',
      4 => 'Cài đặt',
      _ => 'Thư viện',
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isWide ? AppSpacing.lg : AppSpacing.margin,
        AppSpacing.sm,
        AppSpacing.margin,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (!isWide)
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Tooltip(
                message: 'Mở danh sách album',
                child: VaultMark(size: 40),
              ),
            )
          else
            const VaultMark(size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _tabIndex == 1 ? _currentFolder.name : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleLg.copyWith(
                    color: colors.foreground,
                    fontSize: isWide ? 28 : 22,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _isApiConnected
                            ? colors.success
                            : colors.foregroundMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Flexible(
                      child: Text(
                        _isApiConnected ? 'Đã kết nối' : 'Ngoại tuyến',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: colors.foregroundMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isWide) ...[
            if (_api.isAuthenticated)
              RoundIconButton(
                icon: Icons.lock_outline_rounded,
                tooltip: 'Khoá Vault bằng PIN',
                onPressed: _lockVaultManually,
              ),
            const SizedBox(width: AppSpacing.sm),
            RoundIconButton(
              icon: Icons.sync_rounded,
              tooltip: 'Làm mới dữ liệu',
              onPressed: _loadApiData,
            ),
            const SizedBox(width: AppSpacing.sm),

          ],
          RoundIconButton(
            icon: colors.isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            tooltip: colors.isDark ? 'Giao diện sáng' : 'Giao diện tối',
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: () => _setTab(4),
            child: Tooltip(
              message: 'Tài khoản',
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _api.isAuthenticated ? colors.primary : colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.border),
                ),
                alignment: Alignment.center,
                child: _api.isAuthenticated
                    ? Text(
                        (_api.userEmail ?? 'V').substring(0, 1).toUpperCase(),
                        style: AppTypography.label.copyWith(
                          color: colors.onPrimary,
                        ),
                      )
                    : Icon(Icons.person_outline_rounded,
                        size: 20, color: colors.foregroundMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomDock(BuildContext context, AppColorsData colors) {
    const items = [
      (Icons.space_dashboard_outlined, 'Tổng quan'),
      (Icons.photo_library_outlined, 'Thư viện'),
      (Icons.collections_bookmark_outlined, 'Album'),
      (Icons.folder_open_outlined, 'Tệp'),
      (Icons.settings_outlined, 'Cài đặt'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: DecoratedBox(
        key: const Key('bottom-dock'),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.pill,
          border: Border.all(color: colors.border),
          boxShadow: AppElevation.floating(colors),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _DockItem(
                    icon: items[i].$1,
                    label: items[i].$2,
                    active: _tabIndex == i,
                    onTap: () => _setTab(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRail({required bool isDrawer}) {
    final colors = AppColors.of(context);
    const items = [
      (Icons.space_dashboard_outlined, 'Tổng quan'),
      (Icons.photo_library_outlined, 'Thư viện'),
      (Icons.collections_bookmark_outlined, 'Album'),
      (Icons.folder_open_outlined, 'Tệp'),
      (Icons.settings_outlined, 'Cài đặt'),
    ];

    return Container(
      key: const Key('nav-rail'),
      width: isDrawer ? null : AppSpacing.railWidth,
      decoration: BoxDecoration(
        color: colors.surface,
        border: isDrawer
            ? null
            : Border(right: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                const VaultMark(size: 36),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Text(
                    'Vaultly',
                    style: AppTypography.brand.copyWith(
                      color: colors.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _RailItem(
              icon: items[i].$1,
              label: items[i].$2,
              active: _tabIndex == i,
              onTap: () {
                _setTab(i);
                if (isDrawer) Navigator.pop(context);
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Divider(height: 1, color: colors.border),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              children: [
                _RailItem(
                  icon: Icons.grid_view_rounded,
                  label: 'Tất cả ảnh',
                  active: _tabIndex == 1 && _selectedFolderId == 'all',
                  onTap: () {
                    _onSelectFolder(_folders.first);
                    if (isDrawer) Navigator.pop(context);
                  },
                ),
                for (final album in _albums)
                  _RailItem(
                    icon: album.icon,
                    label: album.name,
                    count: album.photoCount,
                    active: _tabIndex == 1 && _selectedFolderId == album.id,
                    onTap: () {
                      _onSelectFolder(album);
                      if (isDrawer) Navigator.pop(context);
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.lg,
                  ),
                  child: PillButton(
                    label: 'Album mới',
                    icon: Icons.add_rounded,
                    dense: true,
                    // Close the drawer first: opening the dialog and then popping
                    // would pop the dialog itself.
                    onPressed: () {
                      if (isDrawer) Navigator.pop(context);
                      _showCreateFolderDialog();
                    },
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                AppBadge(
                  label: _isApiConnected ? 'Đã kết nối' : 'Ngoại tuyến',
                  tone: _isApiConnected ? BadgeTone.success : BadgeTone.neutral,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int? count;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foreground = active ? colors.primary : colors.foregroundMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      child: Material(
        color: active ? colors.primarySoft : Colors.transparent,
        borderRadius: AppRadii.sm,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: active ? colors.primary : colors.foreground,
                    ),
                  ),
                ),
                if (count != null)
                  Text(
                    '$count',
                    style: AppTypography.caption.copyWith(
                      color: colors.foregroundMuted,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One dock destination. The active tab is a filled circle, matching the
/// reference navigation; the rest are plain icons with a tooltip.
class _DockItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DockItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        selected: active,
        button: true,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: active ? colors.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 22,
                color: active ? colors.onPrimary : colors.foregroundMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
