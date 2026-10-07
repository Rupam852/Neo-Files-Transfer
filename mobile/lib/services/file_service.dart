import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shared_file.dart';
import '../models/custom_share_link.dart';
import 'auth_service.dart';
import 'api_service.dart';

class FileService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  AuthService _authService;
  ApiService _apiService;

  List<SharedFile> _files = [];
  List<SharedFile> _sharedFiles = [];
  List<SharedFile> _trashFiles = [];
  bool _isLoading = false;

  List<SharedFile> get files => _files;
  List<SharedFile> get sharedFiles => _sharedFiles;
  List<SharedFile> get trashFiles => _trashFiles;
  bool get isLoading => _isLoading;

  FileService(this._authService, this._apiService);

  void update(AuthService authService, ApiService apiService) {
    _authService = authService;
    _apiService = apiService;
  }

  // Load files for specific folder id (null if root folder)
  Future<void> loadFiles(String? parentFolderId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      var query = _client.from('shared_files')
          .select('*, file_versions(*)')
          .eq('user_id', userId)
          .filter('deleted_at', 'is', null);

      if (parentFolderId != null) {
        query = query.eq('parent_folder_id', parentFolderId);
      } else {
        query = query.filter('parent_folder_id', 'is', null);
      }

      final response = await query.order('file_name', ascending: true);

      _files = (response as List).map((json) => SharedFile.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading files: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSharedFiles() async {
    try {
      _isLoading = true;
      notifyListeners();

      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final response = await _client
          .from('shared_files')
          .select('*, file_versions(*)')
          .eq('user_id', userId)
          .filter('deleted_at', 'is', null)
          .not('unique_share_hash', 'is', null)
          .order('file_name', ascending: true);

      _sharedFiles = (response as List).map((json) => SharedFile.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading shared files: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTrashFiles() async {
    try {
      _isLoading = true;
      notifyListeners();

      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final response = await _client
          .from('shared_files')
          .select('*, file_versions(*)')
          .eq('user_id', userId)
          .not('deleted_at', 'is', null)
          .order('deleted_at', ascending: false);

      _trashFiles = (response as List).map((json) => SharedFile.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading trash files: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get all folders for move dialog
  Future<List<SharedFile>> getAllFolders() async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return [];
    final response = await _client
        .from('shared_files')
        .select()
        .eq('user_id', userId)
        .eq('is_folder', true);
    return (response as List).map((json) => SharedFile.fromJson(json)).toList();
  }

  // Create standard DB folder
  Future<Map<String, String>> createFolder(String name, String? parentDbFolderId) async {
    final userId = _authService.currentUser?.id;
    final driveFolderId = _authService.profile?.driveFolderId;
    if (userId == null || driveFolderId == null) throw Exception('Drive folder or user profile not loaded.');

    String parentDriveFolderId = driveFolderId;
    if (parentDbFolderId != null) {
      final parentFolder = await _client
          .from('shared_files')
          .select('google_drive_file_id')
          .eq('id', parentDbFolderId)
          .single();
      parentDriveFolderId = parentFolder['google_drive_file_id'] as String;
    }

    // Resolve duplicate folder name in target folder
    String finalFolderName = name.trim();
    var nameQuery = _client.from('shared_files').select('file_name').eq('user_id', userId).eq('is_folder', true);
    if (parentDbFolderId != null) {
      nameQuery = nameQuery.eq('parent_folder_id', parentDbFolderId);
    } else {
      nameQuery = nameQuery.filter('parent_folder_id', 'is', null);
    }
    
    final nameResponse = await nameQuery;
    final existingFolderNames = (nameResponse as List)
        .map((f) => (f['file_name'] as String).toLowerCase())
        .toSet();

    if (existingFolderNames.contains(finalFolderName.toLowerCase())) {
      int counter = 1;
      while (existingFolderNames.contains('${name.trim()} ($counter)'.toLowerCase())) {
        counter++;
      }
      finalFolderName = '${name.trim()} ($counter)';
    }

    final driveFileId = await _apiService.createDriveFolder(finalFolderName, parentDriveFolderId);

    final insertResponse = await _client.from('shared_files').insert({
      'user_id': userId,
      'google_drive_file_id': driveFileId,
      'file_name': finalFolderName,
      'mime_type': 'application/vnd.google-apps.folder',
      'is_folder': true,
      'current_version_num': 1,
      'sharing_status': 'private',
      'parent_folder_id': parentDbFolderId,
    }).select('id').single();

    final dbFolderId = insertResponse['id'] as String;

    await _client.from('activity_logs').insert({
      'user_id': userId,
      'action': 'create_folder',
      'details': 'Created folder: $finalFolderName',
    });

    return {
      'dbId': dbFolderId,
      'driveId': driveFileId,
    };
  }

  // Upload file (resumable connection with progress callback)
  Future<void> uploadFile({
    required File file,
    required String fileName,
    required String? parentDbFolderId,
    required String? parentDriveFolderId,
    required Function(double) onProgress,
    required CancelToken cancelToken,
  }) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) throw Exception('User not logged in.');

    final targetDriveFolderId = parentDriveFolderId ?? _authService.profile?.driveFolderId;
    if (targetDriveFolderId == null) throw Exception('Drive folder not configured.');

    // Resolve duplicate name in target folder
    String finalFileName = fileName;
    var nameQuery = _client.from('shared_files').select('file_name').eq('user_id', userId);
    if (parentDbFolderId != null) {
      nameQuery = nameQuery.eq('parent_folder_id', parentDbFolderId);
    } else {
      nameQuery = nameQuery.filter('parent_folder_id', 'is', null);
    }
    
    final nameResponse = await nameQuery;
    final existingNames = (nameResponse as List)
        .map((f) => (f['file_name'] as String).toLowerCase())
        .toSet();

    if (existingNames.contains(finalFileName.toLowerCase())) {
      final lastDotIndex = fileName.lastIndexOf('.');
      String baseName = fileName;
      String ext = '';
      if (lastDotIndex != -1) {
        baseName = fileName.substring(0, lastDotIndex);
        ext = fileName.substring(lastDotIndex);
      }
      int counter = 1;
      while (existingNames.contains('${baseName} ($counter)$ext'.toLowerCase())) {
        counter++;
      }
      finalFileName = '${baseName} ($counter)$ext';
    }

    // Step 1: Request resumable session from Google Drive
    String googleToken = await _authService.getGoogleAccessToken() ?? '';
    String uploadUrl = '';

    final dio = Dio();

    Future<Response> startUploadSession(String token) async {
      return await dio.post(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable',
        data: {
          'name': finalFileName,
          'parents': [targetDriveFolderId]
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json; charset=UTF-8',
            'X-Upload-Content-Type': 'application/octet-stream',
          },
        ),
      );
    }

    try {
      if (googleToken.isEmpty) {
        googleToken = await _apiService.refreshGoogleAccessToken();
      }

      Response startSessionResponse;
      try {
        startSessionResponse = await startUploadSession(googleToken);
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          googleToken = await _apiService.refreshGoogleAccessToken();
          startSessionResponse = await startUploadSession(googleToken);
        } else {
          rethrow;
        }
      }

      uploadUrl = startSessionResponse.headers.value('Location') ?? '';
      if (uploadUrl.isEmpty) throw Exception('Google did not return upload URI.');
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('403') || errStr.contains('401') || errStr.contains('permission') || errStr.contains('unauthorized')) {
        _authService.setGoogleConnectionError(true);
      }
      throw Exception('Initiating Google upload session failed: $e');
    }

    // Step 2: Upload raw file stream via PUT request
    final len = await file.length();
    final response = await dio.put(
      uploadUrl,
      data: file.openRead(),
      cancelToken: cancelToken,
      options: Options(
        headers: {
          'Content-Length': len,
        },
      ),
      onSendProgress: (sent, total) {
        if (total > 0) {
          onProgress(sent / total);
        }
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Google Drive upload failed with status ${response.statusCode}');
    }

    final driveData = response.data;
    final driveFileId = driveData['id'] as String;

    final isApk = finalFileName.toLowerCase().endsWith('.apk') || (driveData['mimeType'] as String? ?? '').contains('android.package-archive');

    final insertPayload = <String, dynamic>{
      'user_id': userId,
      'google_drive_file_id': driveFileId,
      'file_name': finalFileName,
      'file_size': len,
      'mime_type': driveData['mimeType'] ?? '',
      'current_version_num': 1,
      'sharing_status': 'private',
      'parent_folder_id': parentDbFolderId,
    };

    if (isApk) {
      insertPayload['apk_version'] = 'v1.0.1';
      insertPayload['version_api_key'] = _generateApiKey();
    }

    // Step 3: Insert shared_files and file_versions
    final insertResponse = await _client.from('shared_files').insert(insertPayload).select('id').single();

    final dbFileId = insertResponse['id'] as String;

    await _client.from('file_versions').insert({
      'file_id': dbFileId,
      'google_drive_file_id': driveFileId,
      'version_number': 1,
    });

    await _client.from('activity_logs').insert({
      'user_id': userId,
      'action': 'upload',
      'details': 'Uploaded file: $finalFileName',
    });
  }

  String _generateApiKey() {
    final now = DateTime.now();
    final random = now.microsecondsSinceEpoch.toRadixString(36);
    final rand2 = (100000 + (now.millisecond * 7919)).toRadixString(36);
    return 'apk_${random}$rand2';
  }

  // Get or generate Version API Key for APK file
  Future<SharedFile> getOrGenerateVersionApiKey(SharedFile file) async {
    String? newKey = file.versionApiKey;
    String? shareHash = file.uniqueShareHash;
    final defaultVersion = file.apkVersion ?? 'v1.0.1';

    Map<String, dynamic> updates = {};
    if (newKey == null || newKey.isEmpty) {
      newKey = _generateApiKey();
      updates['version_api_key'] = newKey;
      updates['apk_version'] = defaultVersion;
    }
    if (shareHash == null || shareHash.isEmpty) {
      shareHash = DateTime.now().millisecondsSinceEpoch.toRadixString(36) + file.id.substring(0, 6);
      updates['unique_share_hash'] = shareHash;
      updates['sharing_status'] = 'public';
    }

    if (updates.isNotEmpty) {
      updates['modified_at'] = DateTime.now().toUtc().toIso8601String();
      await _client.from('shared_files').update(updates).eq('id', file.id);
    }

    return SharedFile(
      id: file.id,
      userId: file.userId,
      googleDriveFileId: file.googleDriveFileId,
      fileName: file.fileName,
      fileSize: file.fileSize,
      mimeType: file.mimeType,
      currentVersionNum: file.currentVersionNum,
      uniqueShareHash: shareHash ?? file.uniqueShareHash,
      sharingStatus: updates.containsKey('sharing_status') ? 'public' : file.sharingStatus,
      createdAt: file.createdAt,
      modifiedAt: DateTime.now(),
      isFolder: file.isFolder,
      parentFolderId: file.parentFolderId,
      downloadCount: file.downloadCount,
      apkVersion: defaultVersion,
      versionApiKey: newKey ?? file.versionApiKey,
    );
  }


  // Update APK Version and Description in DB
  Future<SharedFile> updateApkVersion(SharedFile file, String newVersion, {String? newDescription}) async {
    final formatted = newVersion.trim().startsWith('v') ? newVersion.trim() : 'v${newVersion.trim()}';
    final desc = newDescription ?? file.apkDescription ?? '';

    await _client.from('shared_files').update({
      'apk_version': formatted,
      'apk_description': desc,
      'modified_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', file.id);

    return SharedFile(
      id: file.id,
      userId: file.userId,
      googleDriveFileId: file.googleDriveFileId,
      fileName: file.fileName,
      fileSize: file.fileSize,
      mimeType: file.mimeType,
      currentVersionNum: file.currentVersionNum,
      uniqueShareHash: file.uniqueShareHash,
      sharingStatus: file.sharingStatus,
      createdAt: file.createdAt,
      modifiedAt: DateTime.now(),
      isFolder: file.isFolder,
      parentFolderId: file.parentFolderId,
      downloadCount: file.downloadCount,
      apkVersion: formatted,
      versionApiKey: file.versionApiKey,
      apkDescription: desc,
    );
  }

  // Regenerate Version API Key
  Future<SharedFile> regenerateVersionApiKey(SharedFile file) async {
    final newKey = _generateApiKey();
    final defaultVersion = file.apkVersion ?? 'v1.0.1';

    await _client.from('shared_files').update({
      'version_api_key': newKey,
      'apk_version': defaultVersion,
      'modified_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', file.id);

    return SharedFile(
      id: file.id,
      userId: file.userId,
      googleDriveFileId: file.googleDriveFileId,
      fileName: file.fileName,
      fileSize: file.fileSize,
      mimeType: file.mimeType,
      currentVersionNum: file.currentVersionNum,
      uniqueShareHash: file.uniqueShareHash,
      sharingStatus: file.sharingStatus,
      createdAt: file.createdAt,
      modifiedAt: DateTime.now(),
      isFolder: file.isFolder,
      parentFolderId: file.parentFolderId,
      downloadCount: file.downloadCount,
      apkVersion: defaultVersion,
      versionApiKey: newKey,
      apkDescription: file.apkDescription,
    );
  }

  // Fetch Version History List for File
  Future<List<Map<String, dynamic>>> getFileVersions(String fileId) async {
    final response = await _client
        .from('file_versions')
        .select('*')
        .eq('file_id', fileId)
        .order('version_number', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }

  // Upload New Version of Existing File
  Future<void> uploadFileVersion({
    required SharedFile fileRecord,
    required File newFile,
    required String fileName,
    required Function(double) onProgress,
    required CancelToken cancelToken,
  }) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) throw Exception('User not logged in.');

    String? targetDriveFolderId;
    if (fileRecord.parentFolderId != null) {
      final parentFolder = await _client
          .from('shared_files')
          .select('google_drive_file_id')
          .eq('id', fileRecord.parentFolderId!)
          .single();
      targetDriveFolderId = parentFolder['google_drive_file_id'] as String;
    } else {
      targetDriveFolderId = _authService.profile?.driveFolderId;
    }

    if (targetDriveFolderId == null || targetDriveFolderId.isEmpty) {
      throw Exception('Google Drive folder is not configured. Please connect folder in Settings.');
    }

    // Step 1: Request resumable session from Google Drive
    String googleToken = await _authService.getGoogleAccessToken() ?? '';
    final dio = Dio();

    Future<Response> startVersionUploadSession(String token) async {
      return await dio.post(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable',
        data: {
          'name': fileName,
          'parents': [targetDriveFolderId]
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json; charset=UTF-8',
            'X-Upload-Content-Type': 'application/octet-stream',
          },
        ),
      );
    }

    String uploadUrl = '';
    try {
      if (googleToken.isEmpty) {
        googleToken = await _apiService.refreshGoogleAccessToken();
      }

      Response startSessionResponse;
      try {
        startSessionResponse = await startVersionUploadSession(googleToken);
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          googleToken = await _apiService.refreshGoogleAccessToken();
          startSessionResponse = await startVersionUploadSession(googleToken);
        } else {
          rethrow;
        }
      }

      uploadUrl = startSessionResponse.headers.value('Location') ?? '';
      if (uploadUrl.isEmpty) throw Exception('Google did not return upload URI.');
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('403') || errStr.contains('401') || errStr.contains('permission') || errStr.contains('unauthorized')) {
        _authService.setGoogleConnectionError(true);
      }
      throw Exception('Initiating Google version upload failed: $e');
    }

    // Step 2: Upload raw file stream via PUT request
    final len = await newFile.length();
    final response = await dio.put(
      uploadUrl,
      data: newFile.openRead(),
      cancelToken: cancelToken,
      options: Options(
        headers: {
          'Content-Length': len,
        },
      ),
      onSendProgress: (sent, total) {
        if (total > 0) {
          onProgress(sent / total);
        }
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Google Drive upload failed with status ${response.statusCode}');
    }

    dynamic driveData = response.data;
    if (driveData is String) {
      driveData = jsonDecode(driveData);
    }
    final newDriveId = driveData['id'] as String;
    // Fetch latest version from DB
    final currentFileRes = await _client
        .from('shared_files')
        .select('current_version_num')
        .eq('id', fileRecord.id)
        .maybeSingle();

    final currentNum = (currentFileRes?['current_version_num'] as int?) ?? fileRecord.currentVersionNum;
    final nextVersionNum = currentNum + 1;

    // Optional: Clean up old drive file if needed
    if (fileRecord.googleDriveFileId.isNotEmpty) {
      try {
        await _apiService.deleteDriveFile(fileRecord.googleDriveFileId);
      } catch (e) {
        debugPrint('Old version cleanup notice: $e');
      }
    }

    // Step 3: Delete old version records (same as Web) to prevent DB bloating / stale history
    await _client.from('file_versions').delete().eq('file_id', fileRecord.id);

    // Insert new single active version
    await _client.from('file_versions').insert({
      'file_id': fileRecord.id,
      'google_drive_file_id': newDriveId,
      'version_number': nextVersionNum,
    });

    await _client.from('shared_files').update({
      'current_version_num': nextVersionNum,
      'google_drive_file_id': newDriveId,
      'file_size': len,
      'modified_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', fileRecord.id);

    await _client.from('activity_logs').insert({
      'user_id': userId,
      'action': 'version_upload',
      'details': 'Uploaded version $nextVersionNum for: ${fileRecord.fileName}',
    });

    await loadFiles(fileRecord.parentFolderId);
    notifyListeners();
  }


  // Delete Single File / Folder (Moves to Recycle Bin)
  Future<void> deleteFile(SharedFile file) async {
    await moveToTrash(file);
  }

  // Rename File / Folder
  Future<void> renameFile(SharedFile file, String newName) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    if (!file.isFolder) {
      await _apiService.renameDriveFile(file.googleDriveFileId, newName);
    }

    await _client
        .from('shared_files')
        .update({'file_name': newName})
        .eq('id', file.id);

    await _client.from('activity_logs').insert({
      'user_id': userId,
      'action': 'rename',
      'details': 'Renamed ${file.fileName} to $newName',
    });
  }

  // Generate a unique 12-char alphanumeric share hash and make file public
  Future<SharedFile> generateShareHash(SharedFile file) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    final newHash = List.generate(12, (index) => chars[rnd.nextInt(chars.length)]).join();

    await _client.from('shared_files').update({
      'unique_share_hash': newHash,
      'sharing_status': 'public',
    }).eq('id', file.id);

    await _client.from('activity_logs').insert({
      'user_id': userId,
      'action': 'share_generate',
      'details': 'Generated share link for: ${file.fileName}',
    });

    final updated = file.copyWith(
      uniqueShareHash: newHash,
      sharingStatus: 'public',
      modifiedAt: DateTime.now(),
    );

    final index = _files.indexWhere((f) => f.id == file.id);
    if (index != -1) {
      _files[index] = updated;
    }
    final sharedIndex = _sharedFiles.indexWhere((f) => f.id == file.id);
    if (sharedIndex != -1) {
      _sharedFiles[sharedIndex] = updated;
    } else {
      _sharedFiles.insert(0, updated);
    }
    notifyListeners();

    return updated;
  }

  // Update sharing status
  Future<SharedFile> toggleSharing(SharedFile file, String status) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    String? hash = file.uniqueShareHash;
    final updates = <String, dynamic>{'sharing_status': status};

    // If making public and has no share hash yet, generate it
    if (status == 'public' && (hash == null || hash.isEmpty)) {
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      final rnd = Random.secure();
      hash = List.generate(12, (index) => chars[rnd.nextInt(chars.length)]).join();
      updates['unique_share_hash'] = hash;
    }

    await _client
        .from('shared_files')
        .update(updates)
        .eq('id', file.id);

    await _client.from('activity_logs').insert({
      'user_id': userId,
      'action': 'sharing',
      'details': 'Changed sharing of ${file.fileName} to $status',
    });

    final updated = file.copyWith(
      sharingStatus: status,
      uniqueShareHash: hash,
      modifiedAt: DateTime.now(),
    );

    final index = _files.indexWhere((f) => f.id == file.id);
    if (index != -1) {
      _files[index] = updated;
    }
    final sharedIndex = _sharedFiles.indexWhere((f) => f.id == file.id);
    if (sharedIndex != -1) {
      _sharedFiles[sharedIndex] = updated;
    } else if (status == 'public' && hash != null) {
      _sharedFiles.insert(0, updated);
    }
    notifyListeners();

    return updated;
  }

  // Bulk move files to another folder
  Future<void> bulkMove(List<String> fileIds, String? targetFolderId) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('shared_files')
        .update({'parent_folder_id': targetFolderId})
        .filter('id', 'in', fileIds);

    await _client.from('activity_logs').insert({
      'user_id': userId,
      'action': 'bulk_move',
      'details': 'Moved ${fileIds.length} items',
    });
  }

  // Move a file to Recycle Bin / Trash
  Future<void> moveToTrash(SharedFile file) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('shared_files')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', file.id);

    await _client.from('activity_logs').insert({
      'user_id': userId,
      'action': 'trash_file',
      'details': 'Moved to Trash: ${file.fileName}',
    });

    _files.removeWhere((f) => f.id == file.id);
    _sharedFiles.removeWhere((f) => f.id == file.id);
    notifyListeners();
  }

  // Restore a file from Recycle Bin
  Future<void> restoreFromTrash(SharedFile file) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('shared_files')
        .update({'deleted_at': null})
        .eq('id', file.id);

    await _client.from('activity_logs').insert({
      'user_id': userId,
      'action': 'restore_file',
      'details': 'Restored file: ${file.fileName}',
    });

    _trashFiles.removeWhere((f) => f.id == file.id);
    notifyListeners();
  }

  // Permanently delete a file (Google Drive + DB records)
  Future<void> deletePermanently(SharedFile file) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    try {
      await _apiService.deleteDriveFile(file.googleDriveFileId);
    } catch (e) {
      debugPrint('Warning: Google Drive delete failed: $e');
    }

    await _client.from('file_versions').delete().eq('file_id', file.id);
    await _client.from('custom_share_links').delete().eq('file_id', file.id);
    await _client.from('file_download_logs').delete().eq('file_id', file.id);
    await _client.from('shared_files').delete().eq('id', file.id);

    await _client.from('activity_logs').insert({
      'user_id': userId,
      'action': 'delete_permanently',
      'details': 'Permanently deleted: ${file.fileName}',
    });

    _trashFiles.removeWhere((f) => f.id == file.id);
    _files.removeWhere((f) => f.id == file.id);
    _sharedFiles.removeWhere((f) => f.id == file.id);
    notifyListeners();
  }

  // Load custom share links for a file
  Future<List<CustomShareLink>> loadCustomShareLinks(String fileId) async {
    final response = await _client
        .from('custom_share_links')
        .select()
        .eq('file_id', fileId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => CustomShareLink.fromJson(json)).toList();
  }

  // Create a new custom protected share link
  Future<CustomShareLink> createCustomShareLink({
    required String fileId,
    String? pinCode,
    DateTime? expiresAt,
    int? maxDownloads,
    bool isOneTime = false,
    String? label,
  }) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    final customHash = 'sec_' + List.generate(14, (index) => chars[rnd.nextInt(chars.length)]).join();

    final response = await _client.from('custom_share_links').insert({
      'file_id': fileId,
      'user_id': userId,
      'custom_share_hash': customHash,
      'pin_code': pinCode != null && pinCode.trim().isNotEmpty ? pinCode.trim() : null,
      'expires_at': expiresAt?.toIso8601String(),
      'max_downloads': maxDownloads,
      'is_one_time': isOneTime,
      'label': label != null && label.trim().isNotEmpty ? label.trim() : null,
      'is_active': true,
    }).select().single();

    return CustomShareLink.fromJson(response);
  }

  // Delete a custom share link
  Future<void> deleteCustomShareLink(String linkId) async {
    await _client.from('custom_share_links').delete().eq('id', linkId);
  }
}
