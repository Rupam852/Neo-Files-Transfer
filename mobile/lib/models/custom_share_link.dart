class CustomShareLink {
  final String id;
  final String fileId;
  final String userId;
  final String customShareHash;
  final String? pinCode;
  final DateTime? expiresAt;
  final int? maxDownloads;
  final int downloadCount;
  final bool isOneTime;
  final String? label;
  final bool isActive;
  final DateTime createdAt;

  CustomShareLink({
    required this.id,
    required this.fileId,
    required this.userId,
    required this.customShareHash,
    this.pinCode,
    this.expiresAt,
    this.maxDownloads,
    this.downloadCount = 0,
    this.isOneTime = false,
    this.label,
    this.isActive = true,
    required this.createdAt,
  });

  factory CustomShareLink.fromJson(Map<String, dynamic> json) {
    return CustomShareLink(
      id: json['id'] as String,
      fileId: json['file_id'] as String,
      userId: json['user_id'] as String,
      customShareHash: json['custom_share_hash'] as String,
      pinCode: json['pin_code'] as String?,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
      maxDownloads: (json['max_downloads'] as num?)?.toInt(),
      downloadCount: (json['download_count'] as num?)?.toInt() ?? 0,
      isOneTime: json['is_one_time'] as bool? ?? false,
      label: json['label'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_id': fileId,
      'user_id': userId,
      'custom_share_hash': customShareHash,
      'pin_code': pinCode,
      'expires_at': expiresAt?.toIso8601String(),
      'max_downloads': maxDownloads,
      'download_count': downloadCount,
      'is_one_time': isOneTime,
      'label': label,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
