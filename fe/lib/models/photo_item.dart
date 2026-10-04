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
