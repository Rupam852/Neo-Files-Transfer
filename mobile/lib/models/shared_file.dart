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
  final String? apkVersion;
  final String? versionApiKey;
  final String? apkDescription;
  final DateTime? deletedAt;

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
    this.apkVersion,
    this.versionApiKey,
    this.apkDescription,
    this.deletedAt,
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
      apkVersion: json['apk_version'] as String?,
      versionApiKey: json['version_api_key'] as String?,
      apkDescription: json['apk_description'] as String?,
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null,
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
      'apk_version': apkVersion,
      'version_api_key': versionApiKey,
      'apk_description': apkDescription,
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  SharedFile copyWith({
    String? id,
    String? userId,
    String? googleDriveFileId,
    String? fileName,
    int? fileSize,
    String? mimeType,
    int? currentVersionNum,
    String? uniqueShareHash,
    String? sharingStatus,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isFolder,
    String? parentFolderId,
    int? downloadCount,
    String? apkVersion,
    String? versionApiKey,
    String? apkDescription,
    DateTime? deletedAt,
  }) {
    return SharedFile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      googleDriveFileId: googleDriveFileId ?? this.googleDriveFileId,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      currentVersionNum: currentVersionNum ?? this.currentVersionNum,
      uniqueShareHash: uniqueShareHash ?? this.uniqueShareHash,
      sharingStatus: sharingStatus ?? this.sharingStatus,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isFolder: isFolder ?? this.isFolder,
      parentFolderId: parentFolderId ?? this.parentFolderId,
      downloadCount: downloadCount ?? this.downloadCount,
      apkVersion: apkVersion ?? this.apkVersion,
      versionApiKey: versionApiKey ?? this.versionApiKey,
      apkDescription: apkDescription ?? this.apkDescription,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}

