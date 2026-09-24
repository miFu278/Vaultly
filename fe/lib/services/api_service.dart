import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/folder.dart';
import '../models/photo_item.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Configurable base URL (Production Render API)
  String _baseUrl = 'https://vaultly-ghqy.onrender.com';
  String get baseUrl => _baseUrl;
  set baseUrl(String url) {
    _baseUrl = url.replaceAll(RegExp(r'/+$'), '');
  }

  String? _token;
  String? _userEmail;
  String? _userId;
  bool _isOnline = false;

  String? get token => _token;
  String? get userEmail => _userEmail;
  String? get userId => _userId;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isOnline => _isOnline;

  // Set session manually or from login
  void setSession({required String token, String? email, String? userId}) {
    _token = token;
    _userEmail = email;
    _userId = userId;
  }

  void logout() {
    _token = null;
    _userEmail = null;
    _userId = null;
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
        _token = data['token'];
        if (data['user'] != null) {
          _userId = data['user']['id'];
          _userEmail = data['user']['email'];
        }
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
        _token = data['token'];
        if (data['user'] != null) {
          _userId = data['user']['id'];
          _userEmail = data['user']['email'];
        }
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

      // Image view URL with auth token query param for seamless Image.network loading
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

  /// Upload raw image bytes to backend (encrypted server-side with libsodium and saved to R2)
  Future<bool> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String? folderId,
  }) async {
    if (!isAuthenticated) return false;

    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/files/upload'));
    request.headers.addAll({
      if (_token != null) 'Authorization': 'Bearer $_token',
    });

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send();
    final res = await http.Response.fromStream(streamedResponse);
    return res.statusCode == 200 || res.statusCode == 201;
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
