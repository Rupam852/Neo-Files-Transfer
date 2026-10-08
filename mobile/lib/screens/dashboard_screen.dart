import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/rendering.dart';

import 'package:intl/intl.dart';
import '../models/shared_file.dart';
import '../services/auth_service.dart';
import '../services/file_service.dart';
import '../services/notification_service.dart';
import '../config.dart';
import 'settings_screen.dart';
import '../services/update_service.dart';
import '../widgets/file_list_item.dart';
import '../widgets/upload_progress.dart';
import '../widgets/upload_progress_dialog.dart';
import '../widgets/download_progress_dialog.dart';
import '../widgets/version_api_dialog.dart';
import '../widgets/manage_versions_dialog.dart';
import '../widgets/share_file_dialog.dart';
import '../widgets/media_preview_dialog.dart';
import '../widgets/notification_bell.dart';
import '../services/transfer_service.dart';
import '../widgets/transfer_manager_sheet.dart';
import '../widgets/floating_transfer_bar.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  SharedFile? _currentFolder;
  final List<SharedFile> _folderPath = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _renameController = TextEditingController();
  final TextEditingController _folderNameController = TextEditingController();
  String _searchQuery = '';
  int _currentTab = 0;
  bool _isFabVisible = true;


  // Upload state
  bool _isUploading = false;
  String _uploadingFileName = '';
  double _uploadProgress = 0.0;
  String _uploadSpeed = '';
  CancelToken? _uploadCancelToken;
  DateTime? _lastUploadProgressUpdate;

  // Download state
  double _downloadProgress = 0.0;
  String _downloadingFileName = '';

  // Action loading state (Rename, Share/Public, Private, Delete)
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshFiles();
      try {
        final notifService = Provider.of<NotificationService>(context, listen: false);
        notifService.onNewNotification = (notif) {
          if (mounted) {
            _showCustomSnackBar(
              message: '${notif.title}: ${notif.message}',
              backgroundColor: const Color(0xFF4F46E5),
              icon: LucideIcons.bellRing,
            );
          }
        };
      } catch (e) {
        debugPrint('[DashboardScreen] Could not bind NotificationService: $e');
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _renameController.dispose();
    _folderNameController.dispose();
    super.dispose();
  }

  Future<void> _refreshFiles() async {
    final fileService = Provider.of<FileService>(context, listen: false);
    if (mounted && !_isFabVisible) {
      setState(() => _isFabVisible = true);
    }
    if (_currentTab == 0) {
      await fileService.loadFiles(_currentFolder?.id);
    } else if (_currentTab == 1) {
      await fileService.loadSharedFiles();
    } else if (_currentTab == 2) {
      await fileService.loadTrashFiles();
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentTab = index;
      _isFabVisible = true;
    });
    _refreshFiles();
  }

  void _navigateToFolder(SharedFile folder) {
    setState(() {
      _currentFolder = folder;
      _folderPath.add(folder);
      _searchQuery = '';
      _searchController.clear();
      _isFabVisible = true;
    });
    _refreshFiles();
  }

  void _navigateBackTo(int index) {
    setState(() {
      if (index == -1) {
        _currentFolder = null;
        _folderPath.clear();
      } else {
        _currentFolder = _folderPath[index];
        _folderPath.removeRange(index + 1, _folderPath.length);
      }
      _searchQuery = '';
      _searchController.clear();
      _isFabVisible = true;
    });
    _refreshFiles();
  }

  void _navigateBackOneLevel() {
    if (_folderPath.isNotEmpty) {
      _navigateBackTo(_folderPath.length - 2);
    }
  }

  void _showUploadCompleteDialog({
    required String title,
    required String message,
  }) {
    if (!mounted) return;
    final isLight = Theme.of(context).brightness == Brightness.light;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        Timer(const Duration(milliseconds: 2500), () {
          if (Navigator.canPop(dialogContext)) {
            Navigator.pop(dialogContext);
          }
        });

        return Dialog(
          backgroundColor: isLight ? Colors.white : const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          elevation: 12,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: isLight ? 0.12 : 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: isLight ? 0.25 : 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.checkCheck,
                          color: Color(0xFF10B981),
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: TextStyle(
                        color: isLight ? const Color(0xFF0F172A) : Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isLight ? const Color(0xFF64748B) : Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (Navigator.canPop(dialogContext)) {
                            Navigator.pop(dialogContext);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: Icon(
                    LucideIcons.x,
                    color: isLight ? const Color(0xFF94A3B8) : Colors.white54,
                    size: 18,
                  ),
                  onPressed: () {
                    if (Navigator.canPop(dialogContext)) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  splashRadius: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleUploadFile() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.profile?.isFolderVerified != true) {
      _showWarningSnackBar('Please configure and verify your Google Drive folder in Settings first.');
      return;
    }

    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    final blockedExtensions = ['exe', 'bat', 'cmd', 'msi', 'scr'];

    final uploadNotifier = ValueNotifier<UploadProgressState>(
      const UploadProgressState(fileName: 'Initializing upload...', progress: 0.0),
    );

    setState(() {
      _isUploading = true;
      _uploadingFileName = 'Initializing...';
      _uploadProgress = 0.0;
      _uploadCancelToken = CancelToken();
    });

    bool dialogOpen = true;
    UploadProgressDialog.show(
      context: context,
      notifier: uploadNotifier,
      onCancel: _handleCancelUpload,
    ).then((_) {
      dialogOpen = false;
    });

    try {
      final fileService = Provider.of<FileService>(context, listen: false);
      
      int successCount = 0;
      for (int i = 0; i < result.files.length; i++) {
        final picked = result.files[i];
        if (picked.path == null) continue;
        
        final ext = picked.name.split('.').last.toLowerCase();
        if (blockedExtensions.contains(ext)) {
          _showWarningSnackBar('File ${picked.name} has a blocked extension and was skipped.');
          continue;
        }

        final uploadLimit = AppConfig.proxyUrl.isNotEmpty ? 250 * 1024 * 1024 : 100 * 1024 * 1024;
        final limitLabel = AppConfig.proxyUrl.isNotEmpty ? '250MB' : '100MB';
        if (picked.size > uploadLimit) {
          _showWarningSnackBar('File ${picked.name} exceeds $limitLabel and was skipped.');
          continue;
        }

        final file = File(picked.path!);
        final currentFileDesc = result.files.length > 1
            ? 'Uploading ${i + 1} of ${result.files.length}: ${picked.name}'
            : 'Uploading ${picked.name}';

        uploadNotifier.value = uploadNotifier.value.copyWith(
          fileName: currentFileDesc,
          progress: 0.0,
          speed: '',
        );

        setState(() {
          _uploadingFileName = currentFileDesc;
          _uploadProgress = 0.0;
          _uploadSpeed = '';
        });

        _lastUploadProgressUpdate = null;
        await fileService.uploadFile(
          file: file,
          fileName: picked.name,
          parentDbFolderId: _currentFolder?.id,
          parentDriveFolderId: _currentFolder?.googleDriveFileId,
          cancelToken: _uploadCancelToken!,
          onProgress: (pct, [speed]) {
            final now = DateTime.now();
            if (_lastUploadProgressUpdate == null ||
                now.difference(_lastUploadProgressUpdate!).inMilliseconds > 100 ||
                pct == 1.0) {
              _lastUploadProgressUpdate = now;
              uploadNotifier.value = uploadNotifier.value.copyWith(
                progress: pct,
                speed: speed ?? '',
              );
              setState(() {
                _uploadProgress = pct;
                if (speed != null) _uploadSpeed = speed;
              });
            }
          },
        );
        successCount++;
      }

      if (dialogOpen && Navigator.canPop(context)) {
        Navigator.pop(context);
        dialogOpen = false;
      }

      if (mounted && successCount > 0) {
        _showUploadCompleteDialog(
          title: 'Upload Successful',
          message: successCount == 1
              ? 'File uploaded successfully to your Google Drive!'
              : '$successCount files uploaded successfully to your Google Drive!',
        );
      }
      _refreshFiles();
    } catch (e) {
      if (dialogOpen && Navigator.canPop(context)) {
        Navigator.pop(context);
        dialogOpen = false;
      }
      final errorMsg = _formatError(e);
      if (mounted) {
        if (errorMsg.contains('cancel')) {
          _showWarningSnackBar(errorMsg);
        } else {
          _showErrorSnackBar(errorMsg);
        }
      }
    } finally {
      setState(() {
        _isUploading = false;
        _uploadCancelToken = null;
      });
    }
  }

  Future<void> _handleUploadFolder() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.profile?.isFolderVerified != true) {
      _showWarningSnackBar('Please configure and verify your Google Drive folder in Settings first.');
      return;
    }

    final selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    final rootDir = Directory(selectedDirectory);
    if (!rootDir.existsSync()) {
      _showWarningSnackBar('Selected directory does not exist.');
      return;
    }

    final rootName = rootDir.path.split(Platform.pathSeparator).last;
    if (rootName.isEmpty) return;

    final uploadNotifier = ValueNotifier<UploadProgressState>(
      const UploadProgressState(fileName: 'Analyzing folder structure...', progress: 0.0),
    );

    setState(() {
      _isUploading = true;
      _uploadingFileName = 'Analyzing folder structure...';
      _uploadProgress = 0.0;
      _uploadCancelToken = CancelToken();
    });

    bool dialogOpen = true;
    UploadProgressDialog.show(
      context: context,
      notifier: uploadNotifier,
      onCancel: _handleCancelUpload,
    ).then((_) {
      dialogOpen = false;
    });

    try {
      final fileService = Provider.of<FileService>(context, listen: false);
      
      // 1. List files and directories recursively
      List<FileSystemEntity> entities = [];
      try {
        entities = rootDir.listSync(recursive: true);
      } catch (e) {
        throw Exception('Failed to read folder contents: $e');
      }

      // 2. Resolve duplicate name for root folder
      String uniqueRootName = rootName;
      final userId = authService.currentUser?.id;
      if (userId == null) throw Exception('User not logged in.');

      final supabase = Supabase.instance.client;
      var rootNameQuery = supabase.from('shared_files').select('file_name').eq('user_id', userId).eq('is_folder', true);
      if (_currentFolder?.id != null) {
        rootNameQuery = rootNameQuery.eq('parent_folder_id', _currentFolder!.id);
      } else {
        rootNameQuery = rootNameQuery.filter('parent_folder_id', 'is', null);
      }

      final rootNameResponse = await rootNameQuery;
      final existingFolderNames = (rootNameResponse as List)
          .map((f) => (f['file_name'] as String).toLowerCase())
          .toSet();

      if (existingFolderNames.contains(uniqueRootName.toLowerCase())) {
        int counter = 1;
        while (existingFolderNames.contains('${rootName} ($counter)'.toLowerCase())) {
          counter++;
        }
        uniqueRootName = '${rootName} ($counter)';
      }

      // 3. Helper to get normalized relative path starting with uniqueRootName
      final parentPath = rootDir.parent.path;
      String getRelativePath(String path) {
        String relPath = path.substring(parentPath.length);
        if (relPath.startsWith(Platform.pathSeparator)) {
          relPath = relPath.substring(1);
        }
        relPath = relPath.replaceAll(Platform.pathSeparator, '/');
        if (uniqueRootName != rootName) {
          final firstSlash = relPath.indexOf('/');
          if (firstSlash != -1) {
            relPath = uniqueRootName + relPath.substring(firstSlash);
          } else {
            relPath = uniqueRootName;
          }
        }
        return relPath;
      }

      // 4. Gather subfolder paths and sort them by hierarchy depth
      final List<String> folderPaths = [uniqueRootName];
      for (final entity in entities) {
        if (entity is Directory) {
          folderPaths.add(getRelativePath(entity.path));
        }
      }
      folderPaths.sort((a, b) => a.split('/').length.compareTo(b.split('/').length));

      // 5. Create folders sequentially
      final Map<String, Map<String, String>> pathLookup = {};
      final driveFolderId = authService.profile?.driveFolderId;
      if (driveFolderId == null) throw Exception('Drive folder not configured.');

      for (final path in folderPaths) {
        if (_uploadCancelToken?.isCancelled == true) {
          throw DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.cancel,
          );
        }

        final parts = path.split('/');
        final fName = parts.last;

        String? parentDbId = _currentFolder?.id;

        if (parts.length > 1) {
          parts.removeLast();
          final parentPathStr = parts.join('/');
          final parentInfo = pathLookup[parentPathStr];
          if (parentInfo != null) {
            parentDbId = parentInfo['dbId'];
          }
        }

        uploadNotifier.value = uploadNotifier.value.copyWith(
          fileName: 'Creating folder: $path',
          progress: 0.0,
          speed: '',
        );

        setState(() {
          _uploadingFileName = 'Creating folder: $path';
          _uploadProgress = 0.0;
        });

        final folderResult = await fileService.createFolder(fName, parentDbId);
        pathLookup[path] = folderResult;
      }

      // 6. Gather all files and upload them sequentially
      final List<File> filesToUpload = entities.whereType<File>().toList();
      final blockedExtensions = ['exe', 'bat', 'cmd', 'msi', 'scr'];
      int successCount = 0;

      for (int i = 0; i < filesToUpload.length; i++) {
        if (_uploadCancelToken?.isCancelled == true) {
          throw DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.cancel,
          );
        }

        final fileEntity = filesToUpload[i];
        final fileName = fileEntity.path.split(Platform.pathSeparator).last;

        final ext = fileName.split('.').last.toLowerCase();
        if (blockedExtensions.contains(ext)) {
          continue;
        }

        final len = await fileEntity.length();
        final uploadLimit = AppConfig.proxyUrl.isNotEmpty ? 250 * 1024 * 1024 : 100 * 1024 * 1024;
        if (len > uploadLimit) {
          continue;
        }

        // Get relative folder path of parent
        final relFilePath = getRelativePath(fileEntity.path);
        final parts = relFilePath.split('/');
        parts.removeLast();
        final parentPathStr = parts.join('/');

        final parentInfo = pathLookup[parentPathStr];
        final parentDbId = parentInfo?['dbId'];
        final parentDriveId = parentInfo?['driveId'];

        final currentFileDesc = 'Uploading ${i + 1} of ${filesToUpload.length}: $fileName';
        uploadNotifier.value = uploadNotifier.value.copyWith(
          fileName: currentFileDesc,
          progress: 0.0,
          speed: '',
        );

        setState(() {
          _uploadingFileName = currentFileDesc;
          _uploadProgress = 0.0;
          _uploadSpeed = '';
        });

        _lastUploadProgressUpdate = null;
        await fileService.uploadFile(
          file: fileEntity,
          fileName: fileName,
          parentDbFolderId: parentDbId,
          parentDriveFolderId: parentDriveId,
          cancelToken: _uploadCancelToken!,
          onProgress: (pct, [speed]) {
            final now = DateTime.now();
            if (_lastUploadProgressUpdate == null ||
                now.difference(_lastUploadProgressUpdate!).inMilliseconds > 100 ||
                pct == 1.0) {
              _lastUploadProgressUpdate = now;
              uploadNotifier.value = uploadNotifier.value.copyWith(
                progress: pct,
                speed: speed ?? '',
              );
              setState(() {
                _uploadProgress = pct;
                if (speed != null) _uploadSpeed = speed;
              });
            }
          },
        );
        successCount++;
      }

      if (dialogOpen && Navigator.canPop(context)) {
        Navigator.pop(context);
        dialogOpen = false;
      }

      if (mounted) {
        _showUploadCompleteDialog(
          title: 'Folder Uploaded Successfully',
          message: 'Folder structure with $successCount files was uploaded to your Google Drive.',
        );
      }
      _refreshFiles();
    } catch (e) {
      if (dialogOpen && Navigator.canPop(context)) {
        Navigator.pop(context);
        dialogOpen = false;
      }
      final errorMsg = _formatError(e);
      if (mounted) {
        if (errorMsg.contains('cancel')) {
          _showWarningSnackBar(errorMsg);
        } else {
          _showErrorSnackBar(errorMsg);
        }
      }
    } finally {
      setState(() {
        _isUploading = false;
        _uploadCancelToken = null;
      });
    }
  }

  void _handleCancelUpload() {
    _uploadCancelToken?.cancel('Upload cancelled by user.');
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    setState(() {
      _isUploading = false;
      _uploadCancelToken = null;
    });
  }

  String _formatError(dynamic e) {
    final errString = e.toString().toLowerCase();
    
    if (errString.contains('cancel') || errString.contains('cancelled')) {
      return 'Upload cancelled by user.';
    }
    if (errString.contains('socketexception') || 
        errString.contains('connection timed out') || 
        errString.contains('failed host lookup') ||
        errString.contains('handshake') ||
        errString.contains('connection closed') ||
        errString.contains('connection reset') ||
        errString.contains('connection refused') ||
        errString.contains('clientexception') ||
        errString.contains('network') ||
        errString.contains('unreachable')) {
      return 'Network/Firewall Block: Connection dropped. If you are on College/Campus Wi-Fi, the firewall is blocking Google Drive upload. Please switch to Mobile Data or Personal Hotspot.';
    }
    if (errString.contains('quotaexceeded') || errString.contains('storage limit') || (errString.contains('403') && errString.contains('quota'))) {
      return 'Your Google Drive storage limit has been exceeded. Please free up space and try again.';
    }
    if (errString.contains('401') || errString.contains('unauthorized') || errString.contains('google drive connection expired')) {
      return 'Google Drive session expired. Please reconnect in settings.';
    }
    if (errString.contains('permission') || errString.contains('denied') || errString.contains('forbidden') || errString.contains('403')) {
      return 'Google Drive Permission Error (403): Make sure you have edit/write access to the configured folder, your Google Drive storage is not full, and you granted Google Drive permissions during login.';
    }

    String msg = e.toString();
    if (msg.startsWith('Exception: ')) {
      msg = msg.substring('Exception: '.length);
    }
    if (msg.startsWith('Initiating Google upload session failed: ')) {
      msg = msg.substring('Initiating Google upload session failed: '.length);
    }
    if (msg.startsWith('Exception: Initiating Google upload session failed: ')) {
      msg = msg.substring('Exception: Initiating Google upload session failed: '.length);
    }
    if (msg.startsWith('Failed to create folder: ')) {
      msg = msg.substring('Failed to create folder: '.length);
    }
    if (msg.startsWith('Failed to rename: ')) {
      msg = msg.substring('Failed to rename: '.length);
    }
    if (msg.startsWith('Failed to toggle sharing: ')) {
      msg = msg.substring('Failed to toggle sharing: '.length);
    }
    if (msg.startsWith('Failed to delete: ')) {
      msg = msg.substring('Failed to delete: '.length);
    }
    return msg;
  }

  void _showCustomSnackBar({
    required String message,
    required Color backgroundColor,
    required IconData icon,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(Icons.close, color: Colors.white70, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    _showCustomSnackBar(
      message: message,
      backgroundColor: const Color(0xFF10B981),
      icon: Icons.check_circle_outline,
    );
  }

  void _showErrorSnackBar(String message) {
    _showCustomSnackBar(
      message: message,
      backgroundColor: Colors.redAccent,
      icon: Icons.error_outline,
    );
  }

  void _showWarningSnackBar(String message) {
    _showCustomSnackBar(
      message: message,
      backgroundColor: Colors.orangeAccent,
      icon: Icons.warning_amber_outlined,
    );
  }

  Future<void> _handleCreateFolder() async {
    _folderNameController.clear();
    final isLight = Theme.of(context).brightness == Brightness.light;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isLight ? Colors.white : const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Create Folder',
          style: TextStyle(
            color: isLight ? const Color(0xFF0F172A) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: _folderNameController,
          autofocus: true,
          style: TextStyle(color: isLight ? const Color(0xFF0F172A) : Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter folder name...',
            hintStyle: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white24),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4F46E5))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isLight ? const Color(0xFF64748B) : Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _folderNameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);

              try {
                final fileService = Provider.of<FileService>(context, listen: false);
                await fileService.createFolder(name, _currentFolder?.id);
                _refreshFiles();
                if (context.mounted) {
                  _showSuccessSnackBar('Folder "$name" created successfully.');
                }
              } catch (e) {
                if (context.mounted) {
                  _showErrorSnackBar('Failed to create folder: ${_formatError(e)}');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRename(SharedFile file) async {
    _renameController.text = file.fileName;
    final isLight = Theme.of(context).brightness == Brightness.light;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isLight ? Colors.white : const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Rename Item',
          style: TextStyle(
            color: isLight ? const Color(0xFF0F172A) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: _renameController,
          autofocus: true,
          style: TextStyle(color: isLight ? const Color(0xFF0F172A) : Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter new name...',
            hintStyle: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white24),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4F46E5))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: isLight ? const Color(0xFF64748B) : Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = _renameController.text.trim();
              if (newName.isEmpty || newName == file.fileName) return;
              Navigator.pop(dialogContext);

              setState(() {
                _isActionLoading = true;
              });

              try {
                final fileService = Provider.of<FileService>(context, listen: false);
                await fileService.renameFile(file, newName);
                await _refreshFiles();
                if (mounted) {
                  _showSuccessSnackBar('Renamed successfully to "$newName"');
                }
              } catch (e) {
                if (mounted) {
                  _showErrorSnackBar('Failed to rename: ${_formatError(e)}');
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isActionLoading = false;
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Rename', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleToggleSharing(SharedFile file) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final fileService = Provider.of<FileService>(context, listen: false);
    final isPublic = file.sharingStatus == 'public';
    final nextStatus = isPublic ? 'private' : 'public';

    if (!isPublic && !authService.isSharingEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sharing features have been disabled by the administrator.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    setState(() {
      _isActionLoading = true;
    });

    try {
      final updatedFile = await fileService.toggleSharing(file, nextStatus);
      await _refreshFiles();

      if (mounted) {
        if (!isPublic) {
          _showSuccessSnackBar('"${file.fileName}" is now public and ready for sharing.');
          _showShareDialog(updatedFile);
        } else {
          _showSuccessSnackBar('"${file.fileName}" is now private.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to toggle sharing: ${_formatError(e)}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  void _handleShareFile(SharedFile file) {
    _showShareDialog(file);
  }

  void _showShareDialog(SharedFile file) {
    showDialog(
      context: context,
      builder: (context) => ShareFileDialog(
        file: file,
        onFileUpdated: (updatedFile) {
          _refreshFiles();
        },
      ),
    );
  }

  void _showViewInDriveDialog(SharedFile file) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final folderId = authService.profile?.driveFolderId;
    final folderUrl = folderId != null && folderId.isNotEmpty
        ? 'https://drive.google.com/drive/folders/$folderId'
        : null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(LucideIcons.alertCircle, color: Colors.indigoAccent, size: 20),
            SizedBox(width: 10),
            Text('View File', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You can see files here. View your Drive folder.',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (folderUrl != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Google Drive Folder Link:',
                style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        folderUrl,
                        style: const TextStyle(color: Colors.indigoAccent, fontSize: 11, fontFamily: 'monospace'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(LucideIcons.copy, size: 14, color: Colors.indigoAccent),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: folderUrl));
                        _showSuccessSnackBar('Drive folder link copied to clipboard!');
                      },
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDownload(SharedFile file) async {
    if (file.isFolder) return;

  Future<void> _handleDownload(SharedFile file) async {
    try {
      final transferService = Provider.of<TransferService>(context, listen: false);
      await transferService.startDownload(file);
      if (mounted) {
        TransferManagerSheet.show(context);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Download failed: ${_formatError(e)}');
      }
    }
  }

  Future<void> _handleDelete(SharedFile file) async {
    final isLight = Theme.of(context).brightness == Brightness.light;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isLight ? Colors.white : const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete ${file.isFolder ? "Folder" : "File"}?',
          style: TextStyle(
            color: isLight ? const Color(0xFF0F172A) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete ${file.fileName}? This action is irreversible.',
          style: TextStyle(
            color: isLight ? const Color(0xFF475569) : Colors.white70,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: isLight ? const Color(0xFF64748B) : Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              setState(() {
                _isActionLoading = true;
              });

              try {
                final fileService = Provider.of<FileService>(context, listen: false);
                await fileService.deleteFile(file);
                await _refreshFiles();
                if (mounted) {
                  _showSuccessSnackBar('"${file.fileName}" deleted successfully.');
                }
              } catch (e) {
                if (mounted) {
                  _showErrorSnackBar('Failed to delete: ${_formatError(e)}');
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isActionLoading = false;
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleGetVersionApi(SharedFile file) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'VersionApi',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, anim1, anim2) {
        return VersionApiDialog(file: file);
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curvedValue = Curves.easeOutCubic.transform(anim1.value);
        return Transform.scale(
          scale: 0.94 + (0.06 * curvedValue),
          child: Opacity(
            opacity: anim1.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
    );
  }

  void _handlePreview(SharedFile file) {
    showDialog(
      context: context,
      builder: (context) => MediaPreviewDialog(
        file: file,
        onDownload: () => _handleDownload(file),
      ),
    );
  }

  void _handleManageVersions(SharedFile file) {
    showDialog(
      context: context,
      builder: (context) => ManageVersionsDialog(file: file),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final fileService = Provider.of<FileService>(context);

    final bgColor = isLight ? const Color(0xFFF8FAFC) : const Color(0xFF030712);
    final navBgColor = isLight ? Colors.white : const Color(0xFF0F172A);
    final navBorderColor = isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.08);
    final searchBg = isLight ? Colors.white : const Color(0xFF0F172A).withOpacity(0.5);
    final searchBorder = isLight ? const Color(0xFFCBD5E1) : Colors.white.withOpacity(0.06);
    final titleTextColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final iconColor = isLight ? const Color(0xFF475569) : Colors.white;

    // Apply search filter
    final filteredFiles = fileService.files.where((f) {
      return f.fileName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              backgroundColor: isLight ? Colors.white : Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Row(
                children: [
                  Text(
                    'Neo',
                    style: TextStyle(
                      color: titleTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const Text(
                    'Files',
                    style: TextStyle(
                      color: Color(0xFF4F46E5),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              actions: [
                Consumer<TransferService>(
                  builder: (context, transferService, _) {
                    final activeCount = transferService.activeTasks.length;
                    return IconButton(
                      tooltip: 'Background Transfers',
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(LucideIcons.arrowUpDown, color: iconColor, size: 20),
                          if (activeCount > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.all(3.5),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4F46E5),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$activeCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      onPressed: () => TransferManagerSheet.show(context),
                    );
                  },
                ),
                const NotificationBellButton(),
                Consumer<UpdateService>(
                  builder: (context, updateService, _) {
                    return IconButton(
                      tooltip: updateService.hasUpdate ? 'Update Available!' : 'Settings',
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(LucideIcons.settings, color: iconColor, size: 20),
                          if (updateService.hasUpdate)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: bgColor, width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      ),
                    );
                  },
                ),
              ],
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: navBorderColor, width: 1)),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentTab,
                onTap: _onTabTapped,
                backgroundColor: navBgColor,
                selectedItemColor: const Color(0xFF4F46E5),
                unselectedItemColor: isLight ? const Color(0xFF64748B) : Colors.white60,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(LucideIcons.folder),
                    label: 'My Files',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(LucideIcons.share2),
                    label: 'Shared Links',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(LucideIcons.trash2),
                    label: 'Recycle Bin',
                  ),
                ],
              ),
            ),
            floatingActionButton: _currentTab == 0
                ? AnimatedSlide(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    offset: _isFabVisible ? Offset.zero : const Offset(0, 2),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      opacity: _isFabVisible ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !_isFabVisible,
                        child: FloatingActionButton(
                          onPressed: () {
                            final bottomBg = isLight ? Colors.white : const Color(0xFF0F172A);
                            final bottomItemColor = isLight ? const Color(0xFF0F172A) : Colors.white;
                            final subtitleColor = isLight ? const Color(0xFF64748B) : Colors.white60;
                            final dragBarColor = isLight ? const Color(0xFFCBD5E1) : Colors.white24;

                            showModalBottomSheet(
                              backgroundColor: bottomBg,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              context: context,
                              builder: (context) => SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 10, bottom: 12),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: dragBarColor,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4F46E5).withValues(alpha: isLight ? 0.12 : 0.2),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(LucideIcons.filePlus, color: Color(0xFF4F46E5), size: 20),
                                        ),
                                        title: Text('Upload Files', style: TextStyle(color: bottomItemColor, fontWeight: FontWeight.w600, fontSize: 14.5)),
                                        subtitle: Text('Upload single or multiple files', style: TextStyle(color: subtitleColor, fontSize: 12)),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _handleUploadFile();
                                        },
                                      ),
                                      ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.withValues(alpha: isLight ? 0.12 : 0.2),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(LucideIcons.folderUp, color: Colors.teal, size: 20),
                                        ),
                                        title: Text('Upload Folder', style: TextStyle(color: bottomItemColor, fontWeight: FontWeight.w600, fontSize: 14.5)),
                                        subtitle: Text('Upload an entire folder structure', style: TextStyle(color: subtitleColor, fontSize: 12)),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _handleUploadFolder();
                                        },
                                      ),
                                      ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: isLight ? 0.12 : 0.2),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(LucideIcons.folderPlus, color: Colors.amber, size: 20),
                                        ),
                                        title: Text('Create Folder', style: TextStyle(color: bottomItemColor, fontWeight: FontWeight.w600, fontSize: 14.5)),
                                        subtitle: Text('Create a new folder in this directory', style: TextStyle(color: subtitleColor, fontSize: 12)),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _handleCreateFolder();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          backgroundColor: const Color(0xFF4F46E5),
                          child: const Icon(LucideIcons.plus, color: Colors.white),
                        ),
                      ),
                    ),
                  )
                : null,
            body: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;

                if (_searchQuery.isNotEmpty || _searchFocusNode.hasFocus) {
                  _searchFocusNode.unfocus();
                  if (_searchQuery.isNotEmpty) {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _isFabVisible = true;
                    });
                  }
                  return;
                }

                if (_folderPath.isNotEmpty) {
                  _navigateBackOneLevel();
                  return;
                }

                if (_currentTab != 0) {
                  setState(() {
                    _currentTab = 0;
                    _isFabVisible = true;
                  });
                  _refreshFiles();
                  return;
                }

                SystemNavigator.pop();
              },
              child: Column(
                children: [
                  Expanded(
                    child: NotificationListener<UserScrollNotification>(
                onNotification: (notification) {
                  if (notification.direction == ScrollDirection.reverse) {
                    if (_isFabVisible) {
                      setState(() => _isFabVisible = false);
                    }
                  } else if (notification.direction == ScrollDirection.forward) {
                    if (!_isFabVisible) {
                      setState(() => _isFabVisible = true);
                    }
                  }
                  return false;
                },
                child: RefreshIndicator(
                  onRefresh: _refreshFiles,
                  color: const Color(0xFF4F46E5),
                  backgroundColor: isLight ? Colors.white : const Color(0xFF0F172A),
                  child: _currentTab == 0
                      ? Column(
                          children: [
                            // Search Bar & Info card
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                              child: TextFormField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                style: TextStyle(color: titleTextColor, fontSize: 13.5),
                                textInputAction: TextInputAction.search,
                                onFieldSubmitted: (_) => _searchFocusNode.unfocus(),
                                onChanged: (val) => setState(() => _searchQuery = val),
                                decoration: InputDecoration(
                                  prefixIcon: Icon(LucideIcons.search, color: isLight ? const Color(0xFF94A3B8) : Colors.white38, size: 16),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(LucideIcons.x, color: isLight ? const Color(0xFF64748B) : Colors.white54, size: 16),
                                          tooltip: 'Clear search',
                                          splashRadius: 18,
                                          onPressed: () {
                                            setState(() {
                                              _searchController.clear();
                                              _searchQuery = '';
                                            });
                                            _searchFocusNode.unfocus();
                                          },
                                        )
                                      : null,
                                  hintText: 'Search files and folders...',
                                  hintStyle: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white30, fontSize: 12.5),
                                  filled: true,
                                  fillColor: searchBg,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: searchBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: searchBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                                  ),
                                ),
                              ),
                            ),

                            // Download Progress overlay banner
                            if (_downloadingFileName.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                color: const Color(0xFF4F46E5),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Downloading $_downloadingFileName (${(_downloadProgress * 100).round()}%)...',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Breadcrumb path navigation bar
                            _buildBreadcrumbs(isLight),

                            // Files view list
                            Expanded(
                              child: fileService.isLoading
                                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
                                  : filteredFiles.isEmpty
                                      ? _buildEmptyState(isLight)
                                      : ListView.builder(
                                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                          itemCount: filteredFiles.length,
                                          itemBuilder: (context, index) {
                                            final file = filteredFiles[index];
                                            return FileListItem(
                                              file: file,
                                              onTap: () {
                                                if (file.isFolder) {
                                                  _navigateToFolder(file);
                                                } else {
                                                  _handlePreview(file);
                                                }
                                              },
                                              onActionSelected: (action) {
                                                if (action == 'preview') _handlePreview(file);
                                                if (action == 'share_file') _handleShareFile(file);
                                                if (action == 'rename') _handleRename(file);
                                                if (action == 'share') _handleToggleSharing(file);
                                                if (action == 'download') _handleDownload(file);
                                                if (action == 'manage_versions') _handleManageVersions(file);
                                                if (action == 'version_api') _handleGetVersionApi(file);
                                                if (action == 'delete') _handleDelete(file);
                                              },
                                            );
                                          },
                                        ),
                            ),
                          ],
                        )
                      : _currentTab == 1
                          ? _buildSharedFilesTab(isLight)
                          : _buildTrashTab(isLight),
                ),
              ),
              const FloatingTransferBar(),
            ],
          ),
        ),
      ),
          if (_isActionLoading)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  child: Center(
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isLight ? Colors.white : const Color(0xFF0F172A).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Color(0xFF4F46E5)),
                            const SizedBox(height: 16),
                            Text(
                              'Please wait...',
                              style: TextStyle(
                                color: titleTextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs(bool isLight) {
    final activeColor = const Color(0xFF4F46E5);
    final inactiveColor = isLight ? const Color(0xFF64748B) : Colors.white60;
    final chevronColor = isLight ? const Color(0xFF94A3B8) : Colors.white30;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _navigateBackTo(-1),
              child: Text(
                'Root',
                style: TextStyle(
                  color: _currentFolder == null ? activeColor : inactiveColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (int i = 0; i < _folderPath.length; i++) ...[
              Icon(LucideIcons.chevronRight, color: chevronColor, size: 14),
              GestureDetector(
                onTap: () => _navigateBackTo(i),
                child: Text(
                  _folderPath[i].fileName,
                  style: TextStyle(
                    color: i == _folderPath.length - 1 ? activeColor : inactiveColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isLight) {
    final titleColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subColor = isLight ? const Color(0xFF64748B) : Colors.white38;

    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.searchX, color: subColor, size: 48),
              const SizedBox(height: 12),
              Text(
                'No results found for "$_searchQuery"',
                style: TextStyle(color: titleColor, fontSize: 14, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Check for spelling errors or try different keywords',
                style: TextStyle(color: subColor, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                  _searchFocusNode.unfocus();
                },
                icon: const Icon(LucideIcons.x, size: 14),
                label: const Text('Clear Search', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.folderOpen, color: subColor, size: 48),
            const SizedBox(height: 12),
            Text(
              _currentFolder != null ? 'This folder is empty' : 'No files found',
              style: TextStyle(color: titleColor, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              _currentFolder != null
                  ? 'Upload files or create subfolders inside "${_currentFolder!.fileName}"'
                  : 'Start by uploading your first file or creating a folder',
              style: TextStyle(color: subColor, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _handleUploadFile,
                  icon: const Icon(LucideIcons.filePlus, size: 14),
                  label: const Text('Upload Files', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _handleCreateFolder,
                  icon: const Icon(LucideIcons.folderPlus, size: 14),
                  label: const Text('New Folder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    side: const BorderSide(color: Color(0xFF4F46E5)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedFilesTab(bool isLight) {
    final fileService = Provider.of<FileService>(context);
    final sharedFiles = fileService.sharedFiles;

    final cardBg = isLight ? Colors.white : const Color(0xFF0B1329).withOpacity(0.5);
    final cardBorder = isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.04);
    final titleColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subColor = isLight ? const Color(0xFF64748B) : Colors.grey.shade400;
    final linkBoxBg = isLight ? const Color(0xFFF1F5F9) : Colors.black.withOpacity(0.2);

    if (fileService.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
    }

    if (sharedFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.link2, size: 48, color: isLight ? const Color(0xFFCBD5E1) : Colors.white24),
            const SizedBox(height: 16),
            Text(
              'No shared files yet',
              style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate public links on files to see them here.',
              style: TextStyle(color: subColor, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      itemCount: sharedFiles.length,
      itemBuilder: (context, index) {
        final file = sharedFiles[index];
        final formattedDate = DateFormat('MMM dd, yyyy').format(file.createdAt);
        final isPublic = file.sharingStatus == 'public';

        return Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: cardBorder, width: 1.0),
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Icon(
                      file.isFolder ? LucideIcons.folder : LucideIcons.file,
                      color: const Color(0xFF4F46E5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPublic
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isPublic
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.amber.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isPublic ? LucideIcons.globe : LucideIcons.lock,
                                    color: isPublic ? Colors.green : Colors.amber,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    file.sharingStatus.toUpperCase(),
                                    style: TextStyle(
                                      color: isPublic ? Colors.green : Colors.amber,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'v${file.currentVersionNum} · $formattedDate',
                              style: TextStyle(color: subColor, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: linkBoxBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        file.uniqueShareHash != null && file.uniqueShareHash!.isNotEmpty
                            ? '${AppConfig.appUrl}/download/${file.uniqueShareHash}'
                            : 'No share link generated yet',
                        style: TextStyle(
                          color: file.uniqueShareHash != null && file.uniqueShareHash!.isNotEmpty
                              ? (isLight ? const Color(0xFF1E293B) : Colors.grey.shade400)
                              : Colors.grey.shade500,
                          fontSize: 11,
                          fontFamily: file.uniqueShareHash != null && file.uniqueShareHash!.isNotEmpty
                              ? 'monospace'
                              : null,
                          fontStyle: file.uniqueShareHash != null && file.uniqueShareHash!.isNotEmpty
                              ? null
                              : FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (file.uniqueShareHash != null && file.uniqueShareHash!.isNotEmpty)
                      IconButton(
                        icon: Icon(LucideIcons.copy, size: 14, color: isLight ? const Color(0xFF4F46E5) : Colors.white60),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: '${AppConfig.appUrl}/download/${file.uniqueShareHash}'));
                          _showSuccessSnackBar('Share URL copied to clipboard!');
                        },
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showShareDialog(file),
                    icon: const Icon(LucideIcons.copy, size: 14),
                    label: const Text('Get Links', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _handleToggleSharing(file),
                    icon: Icon(isPublic ? LucideIcons.lock : LucideIcons.globe, size: 14),
                    label: Text(isPublic ? 'Make Private' : 'Make Public', style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isPublic ? Colors.amber.shade700 : Colors.green,
                      side: BorderSide(color: isPublic ? Colors.amber.withOpacity(0.4) : Colors.green.withOpacity(0.4)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrashTab(bool isLight) {
    final fileService = Provider.of<FileService>(context);
    final trashFiles = fileService.trashFiles;

    final cardBg = isLight ? Colors.white : const Color(0xFF0B1329).withOpacity(0.5);
    final titleColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subColor = isLight ? const Color(0xFF64748B) : Colors.grey.shade400;

    if (fileService.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
    }

    if (trashFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.trash2, size: 48, color: isLight ? const Color(0xFFCBD5E1) : Colors.white24),
            const SizedBox(height: 16),
            Text(
              'Recycle Bin is Empty',
              style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Deleted files are stored safely until permanently removed.',
              style: TextStyle(color: subColor, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      itemCount: trashFiles.length,
      itemBuilder: (context, index) {
        final file = trashFiles[index];
        final deletedDate = file.deletedAt != null
            ? DateFormat('MMM dd, yyyy').format(file.deletedAt!)
            : 'Recently';

        return Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.18),
              width: 1.0,
            ),
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Icon(
                  file.isFolder ? LucideIcons.folder : LucideIcons.file,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Deleted: $deletedDate',
                      style: TextStyle(
                        color: subColor,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Restore File',
                icon: const Icon(LucideIcons.rotateCcw, color: Color(0xFF10B981), size: 18),
                onPressed: () async {
                  setState(() => _isActionLoading = true);
                  try {
                    await fileService.restoreFromTrash(file);
                    if (mounted) _showSuccessSnackBar('Restored "${file.fileName}"');
                  } catch (e) {
                    if (mounted) _showErrorSnackBar('Restore failed: $e');
                  } finally {
                    if (mounted) setState(() => _isActionLoading = false);
                  }
                },
              ),
              IconButton(
                tooltip: 'Delete Permanently',
                icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 18),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: isLight ? Colors.white : const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('Delete Permanently?', style: TextStyle(color: titleColor)),
                      content: Text(
                        'Permanently delete "${file.fileName}" from Google Drive and DB? This cannot be undone.',
                        style: TextStyle(color: subColor, fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel', style: TextStyle(color: subColor)),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            setState(() => _isActionLoading = true);
                            try {
                              await fileService.deletePermanently(file);
                              if (mounted) _showSuccessSnackBar('Permanently deleted "${file.fileName}"');
                            } catch (e) {
                              if (mounted) _showErrorSnackBar('Delete failed: $e');
                            } finally {
                              if (mounted) setState(() => _isActionLoading = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                          child: const Text('Delete Forever', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
