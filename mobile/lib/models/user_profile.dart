class UserProfile {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String? driveFolderId;
  final bool isFolderVerified;
  final String? googleRefreshToken;
  final String? activeWebSessionId;
  final String? activeMobileSessionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.driveFolderId,
    required this.isFolderVerified,
    this.googleRefreshToken,
    this.activeWebSessionId,
    this.activeMobileSessionId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      driveFolderId: json['drive_folder_id'] as String?,
      isFolderVerified: json['is_folder_verified'] as bool? ?? false,
      googleRefreshToken: json['google_refresh_token'] as String?,
      activeWebSessionId: json['active_web_session_id'] as String?,
      activeMobileSessionId: json['active_mobile_session_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'drive_folder_id': driveFolderId,
      'is_folder_verified': isFolderVerified,
      'google_refresh_token': googleRefreshToken,
      'active_web_session_id': activeWebSessionId,
      'active_mobile_session_id': activeMobileSessionId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
