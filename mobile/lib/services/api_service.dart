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

  void _checkAndReportError(dynamic e) {
    final errStr = e.toString().toLowerCase();
    if (errStr.contains('403') || errStr.contains('401') || errStr.contains('permission') || errStr.contains('unauthorized')) {
      _authService.setGoogleConnectionError(true);
    }
  }

  // Refresh Google Access Token via Proxy
  Future<String> refreshGoogleAccessToken() async {
    final tokenVal = _token;
    if (tokenVal == null) throw Exception('No active Supabase session.');

    try {
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
        _authService.setGoogleConnectionError(false);
        return newAccessToken;
      } else {
        _authService.setGoogleConnectionError(true);
        throw Exception('Failed to refresh Google Drive connection.');
      }
    } catch (e) {
      _checkAndReportError(e);
      rethrow;
    }
  }

  // Create Folder on Google Drive via Supabase Edge Function
  Future<String> createDriveFolder(String folderName, String parentDriveFolderId) async {
    final tokenVal = _token;
    if (tokenVal == null) throw Exception('No active session.');

    try {
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
        _authService.setGoogleConnectionError(false);
        return response.data['file_id'] as String;
      } else {
        throw Exception(response.data['error'] ?? 'Failed to create folder.');
      }
    } catch (e) {
      _checkAndReportError(e);
      rethrow;
    }
  }

  // Verify Drive Folder via Supabase Edge Function
  Future<bool> verifyDriveFolder(String folderId) async {
    final tokenVal = _token;
    if (tokenVal == null) throw Exception('No active session.');

    try {
      final response = await _dio.post(
        '${AppConfig.supabaseUrl}/functions/v1/validate-folder',
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
        final success = response.data['success'] == true;
        if (success) {
          _authService.setGoogleConnectionError(false);
        }
        return success;
      } else {
        throw Exception(response.data['error'] ?? 'Failed to verify folder.');
      }
    } catch (e) {
      _checkAndReportError(e);
      rethrow;
    }
  }

  // Delete File on Google Drive via Edge Function
  Future<void> deleteDriveFile(String driveFileId) async {
    final tokenVal = _token;
    if (tokenVal == null) throw Exception('No active session.');

    final googleToken = await _authService.getGoogleAccessToken() ?? '';

    try {
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
      } else {
        _authService.setGoogleConnectionError(false);
      }
    } catch (e) {
      _checkAndReportError(e);
      rethrow;
    }
  }

  // Rename File on Google Drive via Edge Function
  Future<void> renameDriveFile(String driveFileId, String newName) async {
    final tokenVal = _token;
    if (tokenVal == null) throw Exception('No active session.');

    final googleToken = await _authService.getGoogleAccessToken() ?? '';

    try {
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
      } else {
        _authService.setGoogleConnectionError(false);
      }
    } catch (e) {
      _checkAndReportError(e);
      rethrow;
    }
  }
}
