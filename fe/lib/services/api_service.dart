import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/folder.dart';
import '../models/photo_item.dart';

/// Error thrown by [ApiService] for non-successful HTTP responses.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

class UploadImageItem {
  final Uint8List bytes;
  final String fileName;
  final bool isVideo;

  const UploadImageItem({
    required this.bytes,
    required this.fileName,
    this.isVideo = false,
  });
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String _kBaseUrlKey = 'vaultly_base_url';
  static const String _kTokenKey = 'vaultly_jwt_token';
  static const String _kEmailKey = 'vaultly_user_email';
  static const String _kUserIdKey = 'vaultly_user_id';
  static const String _kPinKey = 'vaultly_vault_pin';
  static const String _kHasPinKey = 'vaultly_has_server_pin';

  // Timeout for PIN lock (15 minutes)
  static const int kPinTimeoutMinutes = 15;

  // Configurable base URL (Production Render API)
  String _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://vaultly-ghqy.onrender.com',
  );
  String get baseUrl => _baseUrl;
  set baseUrl(String url) {
    _baseUrl = url.replaceAll(RegExp(r'/+$'), '');
    _persistBaseUrl(_baseUrl);
  }

  String? _token;
  String? _userEmail;
  String? _userId;
  String? _savedPin;
  bool _hasServerPin = false;
  DateTime? _lastUnlockedAt;
  bool _isOnline = false;
  bool _isInitialized = false;

  String? get token => _token;
  String? get userEmail => _userEmail;
  String? get userId => _userId;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isOnline => _isOnline;

  /// True when a PIN is known either locally or on the server.
  bool get hasPin => (_savedPin != null && _savedPin!.isNotEmpty) || _hasServerPin;

  /// Whether the account has a PIN configured server-side (synced across devices).
  bool get hasServerPin => _hasServerPin;

  /// Check whether the 6-digit PIN screen must be shown
  bool get isPinLocked {
    if (!isAuthenticated) return false;
    if (!hasPin) return true; // Need to set up PIN
    if (_lastUnlockedAt == null) return true; // Process was fresh / killed
    final diff = DateTime.now().difference(_lastUnlockedAt!);
    return diff.inMinutes >= kPinTimeoutMinutes;
  }

  /// Initialize and restore stored credentials & PIN from SharedPreferences
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_kBaseUrlKey);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _baseUrl = savedUrl;
      }
      _token = prefs.getString(_kTokenKey);
      _userEmail = prefs.getString(_kEmailKey);
      _userId = prefs.getString(_kUserIdKey);
      _savedPin = prefs.getString(_kPinKey);
      _hasServerPin = prefs.getBool(_kHasPinKey) ?? false;
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing ApiService: $e');
    }
  }

  Future<void> _persistBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrlKey, url);
  }

  Future<void> _saveSession(
    String token,
    String? email,
    String? userId, {
    bool? hasPin,
  }) async {
    _token = token;
    _userEmail = email;
    _userId = userId;
    if (hasPin != null) {
      _hasServerPin = hasPin;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
    if (email != null) await prefs.setString(_kEmailKey, email);
    if (userId != null) await prefs.setString(_kUserIdKey, userId);
    await prefs.setBool(_kHasPinKey, _hasServerPin);
  }

  Future<void> _persistHasPin(bool value) async {
    _hasServerPin = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHasPinKey, value);
    } catch (e) {
      debugPrint('Error persisting hasPin: $e');
    }
  }

  /// Set up or update the 6-digit PIN locally and (best-effort) sync it to the server.
  Future<bool> setPin(String pin) async {
    _savedPin = pin;
    _lastUnlockedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPinKey, pin);

    if (!isAuthenticated) return true;

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/auth/pin/set'),
            headers: _authHeaders,
            body: jsonEncode({'pin': pin}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _persistHasPin(true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to sync PIN to server: $e');
      return false;
    }
  }

  /// Verify a PIN purely against the locally cached value (synchronous).
  bool verifyAndUnlockPin(String pin) {
    if (_savedPin != null && _savedPin == pin) {
      _lastUnlockedAt = DateTime.now();
      return true;
    }
    return false;
  }

  /// Verify the PIN locally first, then fall back to server verification
  /// (covers new devices that have a server-side PIN but no local cache).
  Future<bool> unlockWithPin(String pin) async {
    if (verifyAndUnlockPin(pin)) return true;
    if (!isAuthenticated) return false;

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/auth/pin/verify'),
            headers: _authHeaders,
            body: jsonEncode({'pin': pin}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return false;

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final valid = data is Map && data['valid'] == true;
      if (valid) {
        // Cache the verified PIN locally for fast subsequent unlocks.
        _savedPin = pin;
        _lastUnlockedAt = DateTime.now();
        await _persistHasPin(true);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kPinKey, pin);
      }
      return valid;
    } catch (e) {
      debugPrint('PIN server verification failed: $e');
      return false;
    }
  }

  /// Explicitly lock the vault (e.g. user taps lock or 15 mins passed)
  void lockPin() {
    _lastUnlockedAt = null;
  }

  /// Reset unlock timer on user interaction
  void touchActivity() {
    if (_lastUnlockedAt != null) {
      _lastUnlockedAt = DateTime.now();
    }
  }

  /// Log out and clear session credentials
  Future<void> logout() async {
    _token = null;
    _userEmail = null;
    _userId = null;
    _savedPin = null;
    _hasServerPin = false;
    _lastUnlockedAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kEmailKey);
    await prefs.remove(_kUserIdKey);
    await prefs.remove(_kPinKey);
    await prefs.remove(_kHasPinKey);
  }

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// Extract a human-readable error message from a failed response body.
  String _extractError(http.Response res, String fallback) {
    try {
      final dynamic data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is Map) {
        final dynamic msg = data['detail'] ?? data['error'] ?? data['message'];
        if (msg != null) {
          if (msg is List && msg.isNotEmpty) return msg.first.toString();
          return msg.toString();
        }
      } else if (data is String && data.isNotEmpty) {
        return data;
      }
    } catch (_) {
      // fall through
    }
    return res.body.isNotEmpty ? res.body : fallback;
  }

  /// Check backend health
  Future<bool> checkHealth() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 4));
      _isOnline = res.statusCode == 200;
      return _isOnline;
    } catch (_) {
      _isOnline = false;
      return false;
    }
  }

  /// Fetch the current user profile (also refreshes `has_pin` state).
  Future<void> fetchCurrentUser() async {
    if (!isAuthenticated) return;
    final res = await http.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: _authHeaders,
    );
    if (res.statusCode == 200) {
      final dynamic data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is Map) {
        _userEmail = data['email']?.toString() ?? _userEmail;
        await _persistHasPin(data['has_pin'] == true);
      }
    } else if (res.statusCode == 401) {
      throw ApiException(401, 'Phiên đăng nhập đã hết hạn');
    }
  }

  /// Register a new account
  Future<Map<String, dynamic>> register(String email, String password) async {
    return _authenticate('/auth/register', email, password, 'Đăng ký thất bại');
  }

  /// Login with email & password
  Future<Map<String, dynamic>> login(String email, String password) async {
    return _authenticate('/auth/login', email, password, 'Đăng nhập thất bại');
  }

  Future<Map<String, dynamic>> _authenticate(
    String path,
    String email,
    String password,
    String fallbackError,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      );

      final dynamic data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final token = data['token'] as String;
        final uId = data['user']?['id']?.toString();
        final uEmail = data['user']?['email']?.toString() ?? email.trim();
        final hasPin = data['user']?['has_pin'] == true;
        await _saveSession(token, uEmail, uId, hasPin: hasPin);
        _isOnline = true;
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': _extractError(res, fallbackError),
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Không thể kết nối máy chủ: $e'};
    }
  }

  /// Fetch user folders from database
  Future<List<Folder>> fetchFolders() async {
    if (!isAuthenticated) return [];

    final res = await http.get(
      Uri.parse('$_baseUrl/folders'),
      headers: _authHeaders,
    );

    if (res.statusCode != 200) {
      throw ApiException(
        res.statusCode,
        _extractError(res, 'Không tải được danh sách thư mục'),
      );
    }

    final dynamic decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final List<dynamic> folderList = decoded is List
        ? decoded
        : (decoded['folders'] ?? []);

    return folderList.map<Folder>((item) {
      final id = item['id'].toString();
      final name = item['name']?.toString() ?? 'Unnamed Folder';
      return Folder(
        id: id,
        name: name,
        icon: Icons.folder_rounded,
        isSecure: _looksSecure(name),
      );
    }).toList();
  }

  /// Create a new folder in database
  Future<Folder> createFolder(String name) async {
    if (!isAuthenticated) throw Exception('Must be logged in to create a folder');

    final res = await http.post(
      Uri.parse('$_baseUrl/folders'),
      headers: _authHeaders,
      body: jsonEncode({'name': name.trim()}),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException(
        res.statusCode,
        _extractError(res, 'Không tạo được thư mục'),
      );
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes));
    return Folder(
      id: data['id'].toString(),
      name: data['name']?.toString() ?? name,
      icon: Icons.folder_rounded,
      isSecure: _looksSecure(name),
      photoCount: 0,
    );
  }

  /// Fetch files (photos) from database.
  ///
  /// When [folderId] is null/`all` the full set for the user is returned from
  /// `/files`; otherwise the folder-scoped collection is requested. The caller
  /// is responsible for filtering per folder so folder counts stay accurate.
  Future<List<PhotoItem>> fetchFiles({String? folderId, int limit = 100}) async {
    if (!isAuthenticated) return [];

    final Uri uri;
    if (folderId != null && folderId != 'all' && folderId.isNotEmpty) {
      uri = Uri.parse('$_baseUrl/folders/$folderId/files').replace(
        queryParameters: {'limit': '$limit'},
      );
    } else {
      uri = Uri.parse('$_baseUrl/files');
    }

    final res = await http.get(uri, headers: _authHeaders);
    if (res.statusCode != 200) {
      throw ApiException(
        res.statusCode,
        _extractError(res, 'Không tải được danh sách ảnh'),
      );
    }

    final dynamic decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final List<dynamic> fileList = decoded is List
        ? decoded
        : (decoded['files'] ?? []);

    return fileList.map<PhotoItem>(_mapFile).toList();
  }

  PhotoItem _mapFile(dynamic item) {
    final fileId = item['id'].toString();
    final fId = item['folder_id']?.toString() ?? 'all';
    final r2Key = item['r2_object_key']?.toString() ?? 'photo_$fileId.jpg';
    final cleanTitle = r2Key.contains('/') ? r2Key.split('/').last : r2Key;
    final sizeBytes = item['size'] is int ? item['size'] as int : 0;
    final createdAtStr = item['created_at']?.toString();
    final createdAt = createdAtStr != null
        ? (DateTime.tryParse(createdAtStr) ?? DateTime.now())
        : DateTime.now();

    // The backend decrypts and streams the image at `/files/{id}/view`.
    final viewUrl = '$_baseUrl/files/$fileId/view?token=$_token';

    final isVid = cleanTitle.toLowerCase().endsWith('.mp4') ||
        cleanTitle.toLowerCase().endsWith('.mov') ||
        cleanTitle.toLowerCase().endsWith('.webm') ||
        cleanTitle.toLowerCase().endsWith('.mkv') ||
        (item['content_type']?.toString().startsWith('video/') ?? false);

    return PhotoItem(
      id: fileId,
      folderId: fId,
      title: cleanTitle,
      thumbnailUrl: viewUrl,
      fullUrl: viewUrl,
      createdAt: createdAt,
      fileSize: _formatBytes(sizeBytes),
      isEncrypted: true,
      isVideo: isVid,
    );
  }

  /// Delete a file from database & storage
  Future<bool> deleteFile(String fileId) async {
    if (!isAuthenticated) return false;

    final res = await http.delete(
      Uri.parse('$_baseUrl/files/$fileId'),
      headers: _authHeaders,
    );
    if (res.statusCode == 401) {
      throw ApiException(401, 'Phiên đăng nhập đã hết hạn');
    }
    return res.statusCode == 200;
  }

  /// Batch delete multiple files
  Future<bool> batchDeleteFiles(List<String> fileIds) async {
    if (!isAuthenticated) return false;
    if (fileIds.isEmpty) return true;

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/files/batch-delete'),
        headers: _authHeaders,
        body: jsonEncode({'file_ids': fileIds}),
      );
      if (res.statusCode == 200 || res.statusCode == 201) return true;
    } catch (_) {}

    // Fallback: delete one by one
    bool allSuccess = true;
    for (final id in fileIds) {
      final ok = await deleteFile(id);
      if (!ok) allSuccess = false;
    }
    return allSuccess;
  }

  /// Move a file into another folder (or remove it from any folder).
  Future<bool> moveFileToFolder(String fileId, String? folderId) async {
    if (!isAuthenticated) return false;

    final res = await http.patch(
      Uri.parse('$_baseUrl/files/$fileId/folder'),
      headers: _authHeaders,
      body: jsonEncode({'folder_id': folderId}),
    );
    return res.statusCode == 200;
  }

  /// Copy a file into another folder.
  Future<bool> copyFileToFolder(String fileId, String? folderId) async {
    if (!isAuthenticated) return false;

    final res = await http.post(
      Uri.parse('$_baseUrl/files/$fileId/copy'),
      headers: _authHeaders,
      body: jsonEncode({'folder_id': folderId}),
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }

  /// Upload a single image
  Future<bool> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String? folderId,
  }) async {
    final result = await uploadMultipleImages(
      files: [UploadImageItem(bytes: bytes, fileName: fileName)],
      folderId: folderId,
    );
    return result['success'] == true && (result['uploadedCount'] as int? ?? 0) > 0;
  }

  /// Upload multiple images (supports batch upload with progress notification)
  Future<Map<String, dynamic>> uploadMultipleImages({
    required List<UploadImageItem> files,
    String? folderId,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (!isAuthenticated) {
      return {'success': false, 'error': 'Not authenticated'};
    }
    if (files.isEmpty) {
      return {'success': true, 'uploadedCount': 0};
    }

    int successCount = 0;
    final List<String> errors = [];

    for (int i = 0; i < files.length; i++) {
      final item = files[i];
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/files/upload'),
        );
        request.headers.addAll({
          if (_token != null) 'Authorization': 'Bearer $_token',
        });

        if (folderId != null && folderId != 'all') {
          request.fields['folder_id'] = folderId;
        }

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            item.bytes,
            filename: item.fileName,
          ),
        );

        final streamedResponse = await request.send();
        final res = await http.Response.fromStream(streamedResponse);

        if (res.statusCode == 200 || res.statusCode == 201) {
          successCount++;
        } else {
          errors.add('${item.fileName}: ${_extractError(res, 'tải lên thất bại')}');
        }
      } catch (e) {
        errors.add('${item.fileName}: $e');
      }

      onProgress?.call(i + 1, files.length);
    }

    return {
      'success': successCount > 0,
      'uploadedCount': successCount,
      'total': files.length,
      'errors': errors,
    };
  }

  static bool _looksSecure(String name) {
    final lower = name.toLowerCase();
    return lower.contains('secure') ||
        lower.contains('vault') ||
        lower.contains('bảo mật') ||
        lower.contains('riêng tư');
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
