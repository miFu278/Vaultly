/// Vault usage against the account's quota, as returned by `GET /storage`.
class StorageUsage {
  final int usedBytes;
  final int quotaBytes;
  final int photoBytes;
  final int videoBytes;
  final int fileCount;
  final double usedPercent;

  const StorageUsage({
    required this.usedBytes,
    required this.quotaBytes,
    required this.photoBytes,
    required this.videoBytes,
    required this.fileCount,
    required this.usedPercent,
  });

  static const empty = StorageUsage(
    usedBytes: 0,
    quotaBytes: 0,
    photoBytes: 0,
    videoBytes: 0,
    fileCount: 0,
    usedPercent: 0,
  );

  bool get hasQuota => quotaBytes > 0;

  /// Share of the used space held by one kind, 0 when nothing is stored yet.
  double share(int bytes) => usedBytes <= 0 ? 0 : bytes / usedBytes * 100;

  factory StorageUsage.fromJson(Map<String, dynamic> json) {
    int asInt(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.round();
      return 0;
    }

    double asDouble(String key) {
      final value = json[key];
      if (value is num) return value.toDouble();
      return 0;
    }

    return StorageUsage(
      usedBytes: asInt('used_bytes'),
      quotaBytes: asInt('quota_bytes'),
      photoBytes: asInt('photo_bytes'),
      videoBytes: asInt('video_bytes'),
      fileCount: asInt('file_count'),
      usedPercent: asDouble('used_percent'),
    );
  }
}
