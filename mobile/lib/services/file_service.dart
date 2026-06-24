import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shared_file.dart';
import 'auth_service.dart';
import 'api_service.dart';

class FileService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  AuthService _authService;
  ApiService _apiService;

  List<SharedFile> _files = [];
  List<SharedFile> _sharedFiles = [];
  bool _isLoading = false;

  List<SharedFile> get files => _files;
  List<SharedFile> get sharedFiles => _sharedFiles;
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

      var query = _client.from('shared_files').select('*, file_versions(*)').eq('user_id', userId);

      if (parentFolderId != null) {
        query = query.eq('parent_folder_id', parentFolderId);
      } else {
        query = query.filter('parent_folder_id', 'is', null);
      }

      final response = await query.order('created_at', ascending: false);

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
          .not('unique_share_hash', 'is', null)
          .order('created_at', ascending: false);

      _sharedFiles = (response as List).map((json) => SharedFile.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading shared files: $e');
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
  Future<void> createFolder(String name, String? parentDbFolderId) async {
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

    final driveFileId = await _apiService.createDriveFolder(name, parentDriveFolderId);

    await _client.from('shared_files').insert({
      'user_id': userId,
      'google_drive_file_id': driveFileId,
      'file_name': name,
      'mime_type': 'application/vnd.google-apps.folder',
      'is_folder': true,
      'current_version_num': 1,
      'sharing_status': 'private',
      'parent_folder_id': parentDbFolderId,
    });

    await _client.from('activity_logs').insert({
      'user_id': userId,
      'action': 'create_folder',
      'details': 'Created folder: $name',
    });
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

    // Step 1: Request resumable session from Google Drive
    String googleToken = await _authService.getGoogleAccessToken() ?? '';
    String uploadUrl = '';

    final dio = Dio();

    Future<Response> startUploadSession(String token) async {
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

    // Step 3: Insert shared_files and file_versions
    final insertResponse = await _client.from('shared_files').insert({
      'user_id': userId,
      'google_drive_file_id': driveFileId,
      'file_name': fileName,
      'file_size': len,
      'mime_type': driveData['mimeType'] ?? '',
      'current_version_num': 1,
      'sharing_status': 'private',
      'parent_folder_id': parentDbFolderId,
    }).select('id').single();

    final dbFileId = insertResponse['id'] as String;

    await _client.from('file_versions').insert({
      'file_id': dbFileId,
      'google_drive_file_id': driveFileId,
      'version_number': 1,
    });

    await _client.from('activity_logs').insert({
      'user_id': userId,
      'action': 'upload',
      'details': 'Uploaded file: $fileName',
    });
  }

  // Delete Single File / Folder
  Future<void> deleteFile(SharedFile file) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    if (!file.isFolder) {
      try {
        await _apiService.deleteDriveFile(file.googleDriveFileId);
      } catch (e) {
        debugPrint('Failed to delete file from Google Drive: $e');
      }
      await _client.from('file_versions').delete().eq('file_id', file.id);
    } else {
      // Recursively delete children files
      final children = await _client
          .from('shared_files')
          .select()
          .eq('parent_folder_id', file.id);
      
      for (final childJson in (children as List)) {
        final child = SharedFile.fromJson(childJson);
        await deleteFile(child);
      }
    }

    await _client.from('shared_files').delete().eq('id', file.id);

    await _client.from('activity_logs').insert({
      'user_id': userId,
      'action': 'delete',
      'details': 'Deleted item: ${file.fileName}',
    });
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

  // Update sharing status
  Future<void> toggleSharing(SharedFile file, String status) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('shared_files')
        .update({'sharing_status': status})
        .eq('id', file.id);

    await _client.from('activity_logs').insert({
      'user_id': userId,
      'action': 'sharing',
      'details': 'Changed sharing of ${file.fileName} to $status',
    });
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
}
