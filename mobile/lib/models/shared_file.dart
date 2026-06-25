class SharedFile {
  final String id;
  final String userId;
  final String googleDriveFileId;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final int currentVersionNum;
  final String? uniqueShareHash;
  final String sharingStatus; // 'public' or 'private'
  final DateTime createdAt;
  final DateTime? modifiedAt;
  final bool isFolder;
  final String? parentFolderId;
  final int downloadCount;

  SharedFile({
    required this.id,
    required this.userId,
    required this.googleDriveFileId,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.currentVersionNum,
    this.uniqueShareHash,
    required this.sharingStatus,
    required this.createdAt,
    this.modifiedAt,
    this.isFolder = false,
    this.parentFolderId,
    this.downloadCount = 0,
  });

  factory SharedFile.fromJson(Map<String, dynamic> json) {
    return SharedFile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      googleDriveFileId: json['google_drive_file_id'] as String,
      fileName: json['file_name'] as String,
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type'] as String? ?? '',
      currentVersionNum: (json['current_version_num'] as num?)?.toInt() ?? 1,
      uniqueShareHash: json['unique_share_hash'] as String?,
      sharingStatus: json['sharing_status'] as String? ?? 'private',
      createdAt: DateTime.parse(json['created_at'] as String),
      modifiedAt: json['modified_at'] != null ? DateTime.parse(json['modified_at'] as String) : null,
      isFolder: json['is_folder'] as bool? ?? false,
      parentFolderId: json['parent_folder_id'] as String?,
      downloadCount: (json['download_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'google_drive_file_id': googleDriveFileId,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'current_version_num': currentVersionNum,
      'unique_share_hash': uniqueShareHash,
      'sharing_status': sharingStatus,
      'created_at': createdAt.toIso8601String(),
      'modified_at': modifiedAt?.toIso8601String(),
      'is_folder': isFolder,
      'parent_folder_id': parentFolderId,
      'download_count': downloadCount,
    };
  }
}
