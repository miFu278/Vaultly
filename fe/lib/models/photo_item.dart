class PhotoItem {
  final String id;
  final String folderId;
  final String title;
  final String thumbnailUrl;
  final String fullUrl;
  final DateTime createdAt;
  final String fileSize;
  final bool isEncrypted;
  final bool isVideo;

  const PhotoItem({
    required this.id,
    required this.folderId,
    required this.title,
    required this.thumbnailUrl,
    required this.fullUrl,
    required this.createdAt,
    required this.fileSize,
    this.isEncrypted = true,
    this.isVideo = false,
  });

  bool get checkIsVideo {
    if (isVideo) return true;
    final lower = title.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi');
  }

  String get displayTitle {
    final t = title.trim();
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');
    if (t.contains('_')) {
      final parts = t.split('_');
      if (uuidRegex.hasMatch(parts.first) && parts.length > 1) {
        return parts.sublist(1).join('_');
      }
    }
    if (uuidRegex.hasMatch(t)) {
      final d =
          '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
      return checkIsVideo ? 'Video $d' : 'Ảnh $d';
    }
    return t;
  }

  PhotoItem copyWith({
    String? id,
    String? folderId,
    String? title,
    String? thumbnailUrl,
    String? fullUrl,
    DateTime? createdAt,
    String? fileSize,
    bool? isEncrypted,
    bool? isVideo,
  }) {
    return PhotoItem(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fullUrl: fullUrl ?? this.fullUrl,
      createdAt: createdAt ?? this.createdAt,
      fileSize: fileSize ?? this.fileSize,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      isVideo: isVideo ?? this.isVideo,
    );
  }
}
