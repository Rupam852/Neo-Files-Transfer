import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import 'auth_service.dart';

class ApiService {
  final Dio _dio = Dio();
  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _authService;

  ApiService(this._authService);

  String? get _token => _client.auth.currentSession?.accessToken;

  // Refresh Google Access Token via Proxy
  Future<String> refreshGoogleAccessToken() async {
    final tokenVal = _token;
    if (tokenVal == null) throw Exception('No active Supabase session.');

    final response = await _dio.get(
      '${AppConfig.proxyUrl}/refresh-token',
      options: Options(
        headers: {
          'Authorization': 'Bearer $tokenVal',
        },
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data;
      final newAccessToken = data['google_access_token'] as String;
      await _authService.setGoogleAccessToken(newAccessToken);
      return newAccessToken;
    } else {
      throw Exception('Failed to refresh Google Drive connection.');
    }
  }

  // Create Folder on Google Drive via Supabase Edge Function
  Future<String> createDriveFolder(String folderName, String parentDriveFolderId) async {
    final tokenVal = _token;
    if (tokenVal == null) throw Exception('No active session.');

    final response = await _dio.post(
      '${AppConfig.supabaseUrl}/functions/v1/create-folder',
      data: {
        'name': folderName,
        'parent_drive_folder_id': parentDriveFolderId,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $tokenVal',
          'Content-Type': 'application/json',
        },
      ),
    );

    if (response.statusCode == 200) {
      return response.data['file_id'] as String;
    } else {
      throw Exception(response.data['error'] ?? 'Failed to create folder.');
    }
  }

  // Verify Drive Folder via Supabase Edge Function
  Future<bool> verifyDriveFolder(String folderId) async {
    final tokenVal = _token;
    if (tokenVal == null) throw Exception('No active session.');

    final response = await _dio.post(
      '${AppConfig.supabaseUrl}/functions/v1/verify-folder',
      data: {
        'folder_id': folderId,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $tokenVal',
          'Content-Type': 'application/json',
        },
      ),
    );

    if (response.statusCode == 200) {
      return response.data['verified'] == true;
    } else {
      throw Exception(response.data['error'] ?? 'Failed to verify folder.');
    }
  }

  // Delete File on Google Drive via Edge Function
  Future<void> deleteDriveFile(String driveFileId) async {
    final tokenVal = _token;
    if (tokenVal == null) throw Exception('No active session.');

    final googleToken = await _authService.getGoogleAccessToken() ?? '';

    final response = await _dio.post(
      '${AppConfig.supabaseUrl}/functions/v1/delete-file',
      data: {
        'file_id': driveFileId,
        'provider_token': googleToken,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $tokenVal',
          'Content-Type': 'application/json',
        },
      ),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(response.data['error'] ?? 'Failed to delete file from Drive.');
    }
  }

  // Rename File on Google Drive via Edge Function
  Future<void> renameDriveFile(String driveFileId, String newName) async {
    final tokenVal = _token;
    if (tokenVal == null) throw Exception('No active session.');

    final googleToken = await _authService.getGoogleAccessToken() ?? '';

    final response = await _dio.post(
      '${AppConfig.supabaseUrl}/functions/v1/rename-file',
      data: {
        'file_id': driveFileId,
        'new_name': newName,
        'provider_token': googleToken,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $tokenVal',
          'Content-Type': 'application/json',
        },
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(response.data['error'] ?? 'Failed to rename file on Drive.');
    }
  }
}
