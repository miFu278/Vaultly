import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/folder.dart';
import '../models/photo_item.dart';
import '../services/api_service.dart';
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

  final ApiService _api = ApiService();
  bool _isApiConnected = false;
  bool _isLoadingApi = false;

  late List<Folder> _folders;
  late List<PhotoItem> _photos;
  String _selectedFolderId = 'all';
  int _crossAxisCount = 3; // 2, 3, or 4 columns
  bool _isSidebarCollapsed = false;

  // Valid minimal JPEG bytes (for sample photo upload to Supabase + Cloudflare R2)
  static const List<int> _sampleJpegBytes = [
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x01, 0x00, 0x60,
    0x00, 0x60, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43, 0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08,
    0x07, 0x07, 0x07, 0x09, 0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
    0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20, 0x24, 0x2E, 0x27, 0x20,
    0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29, 0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27,
    0x39, 0x3D, 0x38, 0x32, 0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
    0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01,
    0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04,
    0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F,
    0x00, 0x37, 0xFF, 0xD9
  ];

  @override
  void initState() {
    super.initState();
    _folders = List.from(MockData.initialFolders);
    _photos = List.from(MockData.allPhotos);

    // Check backend health asynchronously
    _checkBackendAndAutoConnect();
  }

  Future<void> _checkBackendAndAutoConnect() async {
    final isHealthy = await _api.checkHealth();
    if (mounted) {
      setState(() {
        _isApiConnected = isHealthy;
      });
    }

    if (isHealthy && _api.isAuthenticated) {
      await _loadApiData();
    }
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
          // Keep root 'all' folder at top
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
    setState(() {
      _selectedFolderId = folder.id;
    });
    if (_api.isAuthenticated) {
      _loadApiData();
    }
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
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Tạo thư mục mới', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Tên thư mục (ví dụ: Tài chính, Riêng tư)',
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

  Future<void> _uploadSamplePhotoToSupabase() async {
    if (!_api.isAuthenticated) {
      _showAuthDialog();
      return;
    }

    setState(() => _isLoadingApi = true);
    try {
      final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ok = await _api.uploadImage(
        bytes: Uint8List.fromList(_sampleJpegBytes),
        fileName: fileName,
        folderId: _selectedFolderId == 'all' ? null : _selectedFolderId,
      );

      if (ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã mã hóa XChaCha20 & tải ảnh lên Cloudflare R2 / Supabase thành công!'),
            ),
          );
        }
        await _loadApiData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tải ảnh thất bại')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi upload: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingApi = false);
      }
    }
  }

  void _addMockPhotoToCurrentFolder() {
    if (_api.isAuthenticated) {
      _uploadSamplePhotoToSupabase();
      return;
    }

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

  void _showAuthDialog() {
    final emailController = TextEditingController(text: _api.userEmail ?? 'demo@vaultly.com');
    final passwordController = TextEditingController(text: 'Password123!');
    final urlController = TextEditingController(text: _api.baseUrl);
    bool isDialogLoading = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogBuilderCtx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.cloud_sync_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text('Kết nối Supabase API', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'Backend URL',
                      hintText: 'http://localhost:8080',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      dialogError!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                  if (isDialogLoading) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                  if (_api.isAuthenticated) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Đang đăng nhập: ${_api.userEmail}',
                        style: const TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (_api.isAuthenticated)
                TextButton(
                  onPressed: () {
                    _api.logout();
                    Navigator.pop(dialogCtx);
                    setState(() {
                      _folders = List.from(MockData.initialFolders);
                      _photos = List.from(MockData.allPhotos);
                    });
                  },
                  child: const Text('Đăng xuất', style: TextStyle(color: Colors.redAccent)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Đóng'),
              ),
              FilledButton.tonal(
                onPressed: isDialogLoading
                    ? null
                    : () async {
                        setDialogState(() {
                          isDialogLoading = true;
                          dialogError = null;
                        });
                        _api.baseUrl = urlController.text.trim();

                        // Try login first
                        var res = await _api.login(emailController.text, passwordController.text);
                        // If not found, try register
                        if (!res['success'] && res['error']?.toString().contains('user not found') == true) {
                          res = await _api.register(emailController.text, passwordController.text);
                        }

                        if (res['success']) {
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                          setState(() {
                            _isApiConnected = true;
                          });
                          await _loadApiData();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Đã kết nối Supabase thành công! (${_api.userEmail})')),
                          );
                        } else {
                          setDialogState(() {
                            isDialogLoading = false;
                            dialogError = res['error'];
                          });
                        }
                      },
                child: const Text('Đăng nhập / Đăng ký'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildApiStatusChip(ThemeData theme) {
    Color chipColor;
    String statusText;

    if (_api.isAuthenticated) {
      chipColor = Colors.green;
      statusText = _api.userEmail?.split('@').first ?? 'Supabase';
    } else if (_isApiConnected) {
      chipColor = Colors.orange;
      statusText = 'Supabase sẵn sàng';
    } else {
      chipColor = Colors.grey;
      statusText = 'Chưa nối DB';
    }

    return InkWell(
      onTap: _showAuthDialog,
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
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: chipColor,
                shape: BoxShape.circle,
              ),
            ),
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
            tooltip: 'Thêm ảnh vào Vault',
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
      body: Stack(
        children: [
          PhotoGrid(
            folder: _currentFolder,
            photos: _displayedPhotos,
            crossAxisCount: _crossAxisCount,
            onZoomChanged: _onZoomChanged,
            onPhotoTap: _openPhotoViewer,
            onPhotoLongPress: _showPhotoOptions,
            onUploadMockPhoto: _addMockPhotoToCurrentFolder,
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
          if (_api.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Làm mới dữ liệu Supabase',
              onPressed: _loadApiData,
            ),
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, size: 20),
            tooltip: 'Tải ảnh lên Supabase / R2',
            onPressed: _uploadSamplePhotoToSupabase,
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
                  onUploadMockPhoto: _addMockPhotoToCurrentFolder,
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
