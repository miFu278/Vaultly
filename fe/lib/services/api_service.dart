import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/folder.dart';
import '../models/photo_item.dart';

class UploadImageItem {
  final Uint8List bytes;
  final String fileName;

  const UploadImageItem({required this.bytes, required this.fileName});
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
  DateTime? _lastUnlockedAt;
  bool _isOnline = false;
  bool _isInitialized = false;

  String? get token => _token;
  String? get userEmail => _userEmail;
  String? get userId => _userId;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isOnline => _isOnline;
  bool get hasPin => _savedPin != null && _savedPin!.isNotEmpty;

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
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing ApiService: $e');
    }
  }

  Future<void> _persistBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrlKey, url);
  }

  Future<void> _saveSession(String token, String? email, String? userId) async {
    _token = token;
    _userEmail = email;
    _userId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
    if (email != null) await prefs.setString(_kEmailKey, email);
    if (userId != null) await prefs.setString(_kUserIdKey, userId);
  }

  /// Set up or update the 6-digit PIN
  Future<void> setPin(String pin) async {
    _savedPin = pin;
    _lastUnlockedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPinKey, pin);
  }

  /// Verify entered 6-digit PIN
  bool verifyAndUnlockPin(String pin) {
    if (_savedPin != null && _savedPin == pin) {
      _lastUnlockedAt = DateTime.now();
      return true;
    }
    return false;
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
    _lastUnlockedAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kEmailKey);
    await prefs.remove(_kUserIdKey);
  }

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

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

  /// Register a new account
  Future<Map<String, dynamic>> register(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      );

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final token = data['token'] as String;
        final uId = data['user']?['id']?.toString();
        final uEmail = data['user']?['email']?.toString() ?? email.trim();
        await _saveSession(token, uEmail, uId);
        _isOnline = true;
        return {'success': true, 'data': data};
      } else {
        final errMsg = data['detail'] ?? data['message'] ?? data['error'] ?? 'Registration failed';
        return {'success': false, 'error': errMsg.toString()};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  /// Login with email & password
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      );

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200) {
        final token = data['token'] as String;
        final uId = data['user']?['id']?.toString();
        final uEmail = data['user']?['email']?.toString() ?? email.trim();
        await _saveSession(token, uEmail, uId);
        _isOnline = true;
        return {'success': true, 'data': data};
      } else {
        final errMsg = data['detail'] ?? data['message'] ?? data['error'] ?? 'Login failed';
        return {'success': false, 'error': errMsg.toString()};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
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
      throw Exception('Failed to load folders (${res.statusCode}): ${res.body}');
    }

    final dynamic decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final List<dynamic> folderList = decoded is List ? decoded : (decoded['folders'] ?? []);

    return folderList.map<Folder>((item) {
      final id = item['id'].toString();
      final name = item['name']?.toString() ?? 'Unnamed Folder';
      return Folder(
        id: id,
        name: name,
        icon: Icons.folder_rounded,
        isSecure: name.toLowerCase().contains('secure') || name.toLowerCase().contains('vault'),
        photoCount: item['photo_count'] is int ? item['photo_count'] : 0,
        coverUrl: item['cover_url']?.toString(),
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
      throw Exception('Failed to create folder (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes));
    return Folder(
      id: data['id'].toString(),
      name: data['name']?.toString() ?? name,
      icon: Icons.folder_rounded,
      isSecure: name.toLowerCase().contains('secure'),
      photoCount: 0,
    );
  }

  /// Fetch files (photos) from database
  Future<List<PhotoItem>> fetchFiles({String? folderId}) async {
    if (!isAuthenticated) return [];

    Uri uri;
    if (folderId != null && folderId != 'all' && folderId.isNotEmpty) {
      uri = Uri.parse('$_baseUrl/folders/$folderId/files');
    } else {
      uri = Uri.parse('$_baseUrl/files');
    }

    final res = await http.get(uri, headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception('Failed to load photos (${res.statusCode}): ${res.body}');
    }

    final dynamic decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final List<dynamic> fileList = decoded is List
        ? decoded
        : (decoded['files'] ?? []);

    return fileList.map<PhotoItem>((item) {
      final fileId = item['id'].toString();
      final fId = item['folder_id']?.toString() ?? 'all';
      final r2Key = item['r2_object_key']?.toString() ?? 'photo_$fileId.jpg';
      final cleanTitle = r2Key.contains('/') ? r2Key.split('/').last : r2Key;
      final sizeBytes = item['size'] is int ? item['size'] as int : 0;
      final createdAtStr = item['created_at']?.toString();
      final createdAt = createdAtStr != null
          ? (DateTime.tryParse(createdAtStr) ?? DateTime.now())
          : DateTime.now();

      final viewUrl = '$_baseUrl/files/$fileId/view?token=$_token';

      return PhotoItem(
        id: fileId,
        folderId: fId,
        title: cleanTitle,
        thumbnailUrl: viewUrl,
        fullUrl: viewUrl,
        createdAt: createdAt,
        fileSize: _formatBytes(sizeBytes),
        isEncrypted: true,
      );
    }).toList();
  }

  /// Delete a file from database & storage
  Future<bool> deleteFile(String fileId) async {
    if (!isAuthenticated) return false;

    final res = await http.delete(
      Uri.parse('$_baseUrl/files/$fileId'),
      headers: _authHeaders,
    );
    return res.statusCode == 200;
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
        final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/files/upload'));
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
          final errBody = res.body;
          errors.add('${item.fileName}: $errBody');
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
