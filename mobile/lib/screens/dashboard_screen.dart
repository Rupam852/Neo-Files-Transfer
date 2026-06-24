import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:intl/intl.dart';
import '../models/shared_file.dart';
import '../services/auth_service.dart';
import '../services/file_service.dart';
import '../config.dart';
import 'settings_screen.dart';
import 'admin_screen.dart';
import '../widgets/file_list_item.dart';
import '../widgets/upload_progress.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  SharedFile? _currentFolder;
  final List<SharedFile> _folderPath = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _renameController = TextEditingController();
  final TextEditingController _folderNameController = TextEditingController();
  String _searchQuery = '';
  int _currentTab = 0;

  // Upload state
  bool _isUploading = false;
  String _uploadingFileName = '';
  double _uploadProgress = 0.0;
  CancelToken? _uploadCancelToken;
  DateTime? _lastUploadProgressUpdate;

  // Download state
  double _downloadProgress = 0.0;
  String _downloadingFileName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshFiles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _renameController.dispose();
    _folderNameController.dispose();
    super.dispose();
  }

  Future<void> _refreshFiles() async {
    final fileService = Provider.of<FileService>(context, listen: false);
    if (_currentTab == 0) {
      await fileService.loadFiles(_currentFolder?.id);
    } else {
      await fileService.loadSharedFiles();
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentTab = index;
    });
    _refreshFiles();
  }

  void _navigateToFolder(SharedFile folder) {
    setState(() {
      _currentFolder = folder;
      _folderPath.add(folder);
      _searchQuery = '';
      _searchController.clear();
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
    });
    _refreshFiles();
  }

  void _navigateBackOneLevel() {
    if (_folderPath.isNotEmpty) {
      _navigateBackTo(_folderPath.length - 2);
    }
  }

  Future<void> _handleUploadFile() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.profile?.isFolderVerified != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure and verify your Google Drive folder in Settings first.')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    final blockedExtensions = ['exe', 'bat', 'cmd', 'msi', 'scr'];

    setState(() {
      _isUploading = true;
      _uploadingFileName = 'Initializing...';
      _uploadProgress = 0.0;
      _uploadCancelToken = CancelToken();
    });

    try {
      final fileService = Provider.of<FileService>(context, listen: false);
      
      int successCount = 0;
      for (int i = 0; i < result.files.length; i++) {
        final picked = result.files[i];
        if (picked.path == null) continue;
        
        final ext = picked.name.split('.').last.toLowerCase();
        if (blockedExtensions.contains(ext)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File ${picked.name} has a blocked extension and was skipped.'),
                backgroundColor: Colors.orangeAccent,
              ),
            );
          }
          continue;
        }

        final uploadLimit = AppConfig.proxyUrl.isNotEmpty ? 250 * 1024 * 1024 : 100 * 1024 * 1024;
        final limitLabel = AppConfig.proxyUrl.isNotEmpty ? '250MB' : '100MB';
        if (picked.size > uploadLimit) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File ${picked.name} exceeds $limitLabel and was skipped.'),
                backgroundColor: Colors.orangeAccent,
              ),
            );
          }
          continue;
        }

        final file = File(picked.path!);

        setState(() {
          _uploadingFileName = 'Uploading ${i + 1} of ${result.files.length}: ${picked.name}';
          _uploadProgress = 0.0;
        });

        _lastUploadProgressUpdate = null;
        await fileService.uploadFile(
          file: file,
          fileName: picked.name,
          parentDbFolderId: _currentFolder?.id,
          parentDriveFolderId: _currentFolder?.googleDriveFileId,
          cancelToken: _uploadCancelToken!,
          onProgress: (pct) {
            final now = DateTime.now();
            if (_lastUploadProgressUpdate == null ||
                now.difference(_lastUploadProgressUpdate!).inMilliseconds > 100 ||
                pct == 1.0) {
              _lastUploadProgressUpdate = now;
              setState(() {
                _uploadProgress = pct;
              });
            }
          },
        );
        successCount++;
      }

      if (mounted && successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uploaded $successCount files!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
      _refreshFiles();
    } catch (e) {
      final errorMsg = _formatError(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: errorMsg.contains('cancel') ? Colors.orangeAccent : Colors.redAccent,
          ),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure and verify your Google Drive folder in Settings first.')),
      );
      return;
    }

    final selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    final rootDir = Directory(selectedDirectory);
    if (!rootDir.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected directory does not exist.')),
      );
      return;
    }

    final rootName = rootDir.path.split(Platform.pathSeparator).last;
    if (rootName.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadingFileName = 'Analyzing folder structure...';
      _uploadProgress = 0.0;
      _uploadCancelToken = CancelToken();
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

        setState(() {
          _uploadingFileName = 'Uploading file ${i + 1} of ${filesToUpload.length}: $fileName';
          _uploadProgress = 0.0;
        });

        _lastUploadProgressUpdate = null;
        await fileService.uploadFile(
          file: fileEntity,
          fileName: fileName,
          parentDbFolderId: parentDbId,
          parentDriveFolderId: parentDriveId,
          cancelToken: _uploadCancelToken!,
          onProgress: (pct) {
            final now = DateTime.now();
            if (_lastUploadProgressUpdate == null ||
                now.difference(_lastUploadProgressUpdate!).inMilliseconds > 100 ||
                pct == 1.0) {
              _lastUploadProgressUpdate = now;
              setState(() {
                _uploadProgress = pct;
              });
            }
          },
        );
        successCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uploaded folder structure with $successCount files!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
      _refreshFiles();
    } catch (e) {
      final errorMsg = _formatError(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: errorMsg.contains('cancel') ? Colors.orangeAccent : Colors.redAccent,
          ),
        );
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
        errString.contains('network') || 
        errString.contains('connection timed out') || 
        errString.contains('failed host lookup') ||
        errString.contains('handshake') ||
        errString.contains('connection closed') ||
        errString.contains('unreachable')) {
      return 'Connection failed. Please check your internet connection.';
    }
    if (errString.contains('quotaexceeded') || errString.contains('storage limit') || (errString.contains('403') && errString.contains('quota'))) {
      return 'Your Google Drive storage limit has been exceeded. Please free up space and try again.';
    }
    if (errString.contains('401') || errString.contains('unauthorized') || errString.contains('google drive connection expired')) {
      return 'Google Drive session expired. Please reconnect in settings.';
    }
    if (errString.contains('permission') || errString.contains('denied') || errString.contains('forbidden')) {
      return 'Permission denied. Please verify your Google Drive settings.';
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

  Future<void> _handleCreateFolder() async {
    _folderNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Folder', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _folderNameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter folder name...',
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.indigoAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Folder $name created successfully'), backgroundColor: const Color(0xFF10B981)),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create folder: ${_formatError(e)}'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade600,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Item', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _renameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter new name...',
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.indigoAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = _renameController.text.trim();
              if (newName.isEmpty || newName == file.fileName) return;
              Navigator.pop(context);

              try {
                final fileService = Provider.of<FileService>(context, listen: false);
                await fileService.renameFile(file, newName);
                _refreshFiles();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to rename: ${_formatError(e)}'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade600,
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

    try {
      if (!isPublic && (file.uniqueShareHash == null || file.uniqueShareHash!.isEmpty)) {
        // Generate a new share hash in Supabase
        final newHash = DateTime.now().millisecondsSinceEpoch.toString() + file.id.substring(0, 8);
        await Supabase.instance.client
            .from('shared_files')
            .update({'unique_share_hash': newHash})
            .eq('id', file.id);
      }

      await fileService.toggleSharing(file, nextStatus);
      _refreshFiles();

      if (!isPublic) {
        final updatedData = await Supabase.instance.client
            .from('shared_files')
            .select()
            .eq('id', file.id)
            .single();
        final updatedFile = SharedFile.fromJson(updatedData);

        _showShareDialog(updatedFile);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sharing disabled. File is now private.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle sharing: ${_formatError(e)}'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String _getDirectDownloadUrl(SharedFile file) {
    final hash = file.uniqueShareHash ?? '';
    if (file.isFolder) {
      return '${AppConfig.proxyUrl}/api/download/folder/$hash';
    }
    final isLargeFile = file.fileSize > 100 * 1024 * 1024;
    if (isLargeFile) {
      return '${AppConfig.proxyUrl}/api/download/stream/$hash';
    } else {
      return '${AppConfig.proxyUrl}/api/download/file/$hash';
    }
  }

  void _showShareDialog(SharedFile file) {
    final hash = file.uniqueShareHash ?? '';
    final webUrl = '${AppConfig.appUrl}/download/$hash';
    final directUrl = _getDirectDownloadUrl(file);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Share File Options', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 18),
              
              // Option A: Web Link
              const Text(
                'OPTION A: WEB DOWNLOAD PAGE LINK',
                style: TextStyle(color: Colors.indigoAccent, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        webUrl,
                        style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.copy, size: 14, color: Colors.indigoAccent),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: webUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Web download link copied!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Opens the beautiful download page with real-time progress bar.',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
              
              const SizedBox(height: 20),
              
              // Option B: Direct API Link
              const Text(
                'OPTION B: DIRECT DOWNLOAD LINK',
                style: TextStyle(color: Colors.pinkAccent, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        directUrl,
                        style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.copy, size: 14, color: Colors.pinkAccent),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: directUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Direct download link copied!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Direct stream connection. Instantly downloads in background.',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Drive folder link copied to clipboard!')),
                        );
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

    setState(() {
      _downloadingFileName = file.fileName;
      _downloadProgress = 0.0;
    });

    try {
      final dio = Dio();
      
      // Request storage permission on Android
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;

        if (sdkInt >= 30) {
          var status = await Permission.manageExternalStorage.status;
          if (!status.isGranted) {
            status = await Permission.manageExternalStorage.request();
          }
          if (!status.isGranted) {
            throw Exception('All files access permission is required to save downloads on this Android version.');
          }
        } else {
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
          if (!status.isGranted) {
            throw Exception('Storage permission is required to save downloads.');
          }
        }
      }

      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getDownloadsDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Could not resolve downloads directory.');
      }

      // Check if downloads directory exists, if not create it
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final savePath = '${downloadsDir.path}/${file.fileName}';

      final tokenVal = Supabase.instance.client.auth.currentSession?.accessToken;
      if (tokenVal == null) {
        throw Exception('No active session. Please sign in again.');
      }

      final downloadUrl = '${AppConfig.proxyUrl}/download/direct/${file.googleDriveFileId}';

      DateTime? lastUpdate;
      await dio.download(
        downloadUrl,
        savePath,
        options: Options(
          headers: {
            'Authorization': 'Bearer $tokenVal',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final now = DateTime.now();
            if (lastUpdate == null ||
                now.difference(lastUpdate!).inMilliseconds > 100 ||
                received == total) {
              lastUpdate = now;
              setState(() {
                _downloadProgress = received / total;
              });
            }
          }
        },
      );

      setState(() {
        _downloadingFileName = '';
      });

      // Scan the file so it shows up in system downloads list / gallery
      if (Platform.isAndroid) {
        try {
          const platform = MethodChannel('com.neofiles.transfer/media_scanner');
          await platform.invokeMethod('scanFile', {'path': savePath});
        } catch (scanError) {
          debugPrint('Media scan failed: $scanError');
        }
      }

      // Increment download count locally
      await Supabase.instance.client
          .from('shared_files')
          .update({'download_count': file.downloadCount + 1})
          .eq('id', file.id);

      _refreshFiles();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) {
            // Auto close after 1.5 seconds (1500 ms)
            Timer(const Duration(milliseconds: 1500), () {
              if (Navigator.canPop(dialogContext)) {
                Navigator.pop(dialogContext);
              }
            });

            return Dialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF10B981),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Download Complete',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${file.fileName} has been saved to your Downloads folder.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        if (Navigator.canPop(dialogContext)) {
                          Navigator.pop(dialogContext);
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.close,
                          color: Colors.white60,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      setState(() {
        _downloadingFileName = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleDelete(SharedFile file) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete ${file.isFolder ? "Folder" : "File"}?', style: const TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete ${file.fileName}? This action is irreversible.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final fileService = Provider.of<FileService>(context, listen: false);
              try {
                await fileService.deleteFile(file);
                _refreshFiles();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: ${_formatError(e)}'), backgroundColor: Colors.redAccent),
                  );
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

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final fileService = Provider.of<FileService>(context);

    // Apply search filter
    final filteredFiles = fileService.files.where((f) {
      return f.fileName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Neo',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Files',
              style: TextStyle(color: Colors.indigo.shade400, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings, color: Colors.white, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isUploading)
            UploadProgressWidget(
              fileName: _uploadingFileName,
              progress: _uploadProgress,
              onCancel: _handleCancelUpload,
            ),
          BottomNavigationBar(
            currentIndex: _currentTab,
            onTap: _onTabTapped,
            backgroundColor: const Color(0xFF0F172A),
            selectedItemColor: Colors.indigoAccent,
            unselectedItemColor: Colors.white60,
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
            ],
          ),
        ],
      ),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              onPressed: () {
                // Bottom options dialog
                showModalBottomSheet(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  context: context,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(LucideIcons.filePlus, color: Colors.indigoAccent),
                          title: const Text('Upload Files', style: TextStyle(color: Colors.white)),
                          onTap: () {
                            Navigator.pop(context);
                            _handleUploadFile();
                          },
                        ),
                        ListTile(
                          leading: const Icon(LucideIcons.folder, color: Colors.teal),
                          title: const Text('Upload Folder', style: TextStyle(color: Colors.white)),
                          onTap: () {
                            Navigator.pop(context);
                            _handleUploadFolder();
                          },
                        ),
                        ListTile(
                          leading: const Icon(LucideIcons.folderPlus, color: Colors.amber),
                          title: const Text('Create Folder', style: TextStyle(color: Colors.white)),
                          onTap: () {
                            Navigator.pop(context);
                            _handleCreateFolder();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              backgroundColor: Colors.indigo.shade600,
              child: const Icon(LucideIcons.plus, color: Colors.white),
            )
          : null,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_currentTab != 0) {
            setState(() {
              _currentTab = 0;
            });
            _refreshFiles();
          } else if (_folderPath.isNotEmpty) {
            _navigateBackOneLevel();
          } else {
            SystemNavigator.pop();
          }
        },
        child: RefreshIndicator(
          onRefresh: _refreshFiles,
          color: Colors.indigoAccent,
          backgroundColor: const Color(0xFF0F172A),
          child: _currentTab == 0
              ? Column(
                  children: [
                    // Search Bar & Info card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: TextFormField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.search, color: Colors.white38, size: 16),
                          hintText: 'Search files and folders...',
                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12.5),
                          filled: true,
                          fillColor: const Color(0xFF0F172A).withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.04)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.04)),
                          ),
                        ),
                      ),
                    ),

                    // Download Progress overlay banner
                    if (_downloadingFileName.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        color: Colors.indigo.shade900.withOpacity(0.8),
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
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Breadcrumb path navigation bar
                    _buildBreadcrumbs(),

                    // Files view list
                    Expanded(
                      child: fileService.isLoading
                          ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
                          : filteredFiles.isEmpty
                              ? _buildEmptyState()
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
                                          _showViewInDriveDialog(file);
                                        }
                                      },
                                      onActionSelected: (action) {
                                        if (action == 'rename') _handleRename(file);
                                        if (action == 'share') _handleToggleSharing(file);
                                        if (action == 'download') _handleDownload(file);
                                        if (action == 'delete') _handleDelete(file);
                                      },
                                    );
                                  },
                                ),
                    ),
                  ],
                )
              : _buildSharedFilesTab(),
        ),
      ),
    ),
  );
  }

  Widget _buildBreadcrumbs() {
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
                  color: _currentFolder == null ? Colors.indigo.shade300 : Colors.white60,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (int i = 0; i < _folderPath.length; i++) ...[
              const Icon(LucideIcons.chevronRight, color: Colors.white30, size: 14),
              GestureDetector(
                onTap: () => _navigateBackTo(i),
                child: Text(
                  _folderPath[i].fileName,
                  style: TextStyle(
                    color: i == _folderPath.length - 1 ? Colors.indigo.shade300 : Colors.white60,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.folderOpen, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          const Text(
            'This folder is empty',
            style: TextStyle(color: Colors.white30, fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedFilesTab() {
    final fileService = Provider.of<FileService>(context);
    final sharedFiles = fileService.sharedFiles;

    if (fileService.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
    }

    if (sharedFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.link2, size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              'No shared files yet',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate public links on files to see them here.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
            color: const Color(0xFF0B1329).withOpacity(0.5),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: Colors.white.withOpacity(0.04),
              width: 1.0,
            ),
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
                      color: Colors.indigoAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Icon(
                      file.isFolder ? LucideIcons.folder : LucideIcons.file,
                      color: Colors.indigoAccent,
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
                          style: const TextStyle(
                            color: Colors.white,
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
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
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
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${AppConfig.appUrl}/download/${file.uniqueShareHash}',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontFamily: 'monospace'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.copy, size: 14, color: Colors.white60),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: '${AppConfig.appUrl}/download/${file.uniqueShareHash}'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Share URL copied to clipboard!')),
                        );
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
                    style: TextButton.styleFrom(foregroundColor: Colors.indigoAccent),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _handleToggleSharing(file),
                    icon: Icon(isPublic ? LucideIcons.lock : LucideIcons.globe, size: 14),
                    label: Text(isPublic ? 'Make Private' : 'Make Public', style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isPublic ? Colors.amber : Colors.green,
                      side: BorderSide(color: isPublic ? Colors.amber.withOpacity(0.3) : Colors.green.withOpacity(0.3)),
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
}
