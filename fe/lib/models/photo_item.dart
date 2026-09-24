class PhotoItem {
  final String id;
  final String folderId;
  final String title;
  final String thumbnailUrl;
  final String fullUrl;
  final DateTime createdAt;
  final String fileSize;
  final bool isEncrypted;

  const PhotoItem({
    required this.id,
    required this.folderId,
    required this.title,
    required this.thumbnailUrl,
    required this.fullUrl,
    required this.createdAt,
    required this.fileSize,
    this.isEncrypted = true,
  });
}
