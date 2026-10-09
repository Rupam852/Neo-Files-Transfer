import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Headers;
import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import '../models/shared_file.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'file_service.dart';

enum TransferType { upload, download }
enum TransferStatus { queued, running, paused, completed, failed, cancelled }

class TransferTask {
  final String id;
  final String fileName;
  final int totalBytes;
  int transferredBytes;
  final TransferType type;
  TransferStatus status;
  double progress;
  String speed;
  String eta;
  String? error;
  CancelToken? cancelToken;
  String? localPath;
  String? remoteUrl;
  String? resumableSessionUrl;
  String? parentDbFolderId;
  String? parentDriveFolderId;
  bool autoMakePublic;
  SharedFile? fileRecord;
  List<SharedFile>? batchFiles;
  bool isZipBatch;
  DateTime startTime;
  int lastBytes;
  DateTime lastTime;

  TransferTask({
    required this.id,
    required this.fileName,
    required this.totalBytes,
    this.transferredBytes = 0,
    required this.type,
    this.status = TransferStatus.queued,
    this.progress = 0.0,
    this.speed = '',
    this.eta = '',
    this.error,
    this.cancelToken,
    this.localPath,
    this.remoteUrl,
    this.resumableSessionUrl,
    this.parentDbFolderId,
    this.parentDriveFolderId,
    this.autoMakePublic = true,
    this.fileRecord,
    this.batchFiles,
    this.isZipBatch = false,
  })  : startTime = DateTime.now(),
        lastBytes = transferredBytes,
        lastTime = DateTime.now();

  String get formattedTotalSize => _formatBytes(totalBytes);
  String get formattedTransferredSize => _formatBytes(transferredBytes);

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (bytes > 0) ? (bytes.toString().length - 1) ~/ 3 : 0;
    if (i >= suffixes.length) i = suffixes.length - 1;
    double numVal = bytes / (1 << (i * 10));
    return '${numVal.toStringAsFixed(1)} ${suffixes[i]}';
  }
}

class TransferService with ChangeNotifier {
  final List<TransferTask> _tasks = [];
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isNotifInitialized = false;

  AuthService? _authService;
  ApiService? _apiService;
  FileService? _fileService;

  static const String _channelId = 'neo_transfers_channel';
  static const String _channelName = 'File Transfers';
  static const String _channelDesc = 'Ongoing background upload and download progress';

  TransferService([AuthService? auth, ApiService? api, FileService? fileService]) {
    _authService = auth;
    _apiService = api;
    _fileService = fileService;
    _initNotifications();
  }

  void update(AuthService auth, ApiService api, FileService fileService) {
    _authService = auth;
    _apiService = api;
    _fileService = fileService;
  }

  List<TransferTask> get tasks => List.unmodifiable(_tasks);
  List<TransferTask> get activeTasks =>
      _tasks.where((t) => t.status == TransferStatus.running || t.status == TransferStatus.queued).toList();
  bool get hasActiveTransfers => activeTasks.isNotEmpty;

  Future<void> _initNotifications() async {
    if (_isNotifInitialized) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
      const initSettings = InitializationSettings(android: androidInit);
      await _notificationsPlugin.initialize(settings: initSettings);
      _isNotifInitialized = true;
    } catch (e) {
      debugPrint('[TransferService] Notification init error: $e');
    }
  }

  Future<void> _updateNotification(TransferTask task) async {
    if (!_isNotifInitialized) return;
    try {
      final notifId = task.id.hashCode & 0x7FFFFFFF;

      if (task.status == TransferStatus.running) {
        final pct = (task.progress * 100).toInt().clamp(0, 100);
        final isDl = task.type == TransferType.download;
        final title = isDl ? '📥 Downloading ${task.fileName}' : '📤 Uploading ${task.fileName}';
        final body = '$pct% • ${task.formattedTransferredSize} / ${task.formattedTotalSize} ${task.speed.isNotEmpty ? '• ${task.speed}' : ''}';

        final androidDetails = AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          showProgress: true,
          maxProgress: 100,
          progress: pct,
          onlyAlertOnce: true,
        );

        await _notificationsPlugin.show(
          id: notifId,
          title: title,
          body: body,
          notificationDetails: NotificationDetails(android: androidDetails),
        );
      } else if (task.status == TransferStatus.completed) {
        final isDl = task.type == TransferType.download;
        final title = isDl ? '✅ Download Complete' : '✅ Upload Complete';
        final body = '${task.fileName} (${task.formattedTotalSize})';

        final androidDetails = const AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ongoing: false,
          autoCancel: true,
        );

        await _notificationsPlugin.show(
          id: notifId,
          title: title,
          body: body,
          notificationDetails: NotificationDetails(android: androidDetails),
        );
      } else if (task.status == TransferStatus.paused) {
        final androidDetails = AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
        );

        await _notificationsPlugin.show(
          id: notifId,
          title: '⏸️ Transfer Paused: ${task.fileName}',
          body: 'Paused at ${(task.progress * 100).toInt()}% • Tap in app to resume',
          notificationDetails: NotificationDetails(android: androidDetails),
        );
      } else if (task.status == TransferStatus.cancelled || task.status == TransferStatus.failed) {
        await _notificationsPlugin.cancel(id: notifId);
      }
    } catch (e) {
      debugPrint('[TransferService] Notif update failed: $e');
    }
  }

  String _buildDownloadUrl(SharedFile file) {
    final hash = file.uniqueShareHash;
    if (AppConfig.cfWorkerUrl.isNotEmpty) {
      final cleanWorker = AppConfig.cfWorkerUrl.endsWith('/')
          ? AppConfig.cfWorkerUrl.substring(0, AppConfig.cfWorkerUrl.length - 1)
          : AppConfig.cfWorkerUrl;
      return hash != null && hash.isNotEmpty
          ? '$cleanWorker?hash=$hash&skip_increment=true'
          : '$cleanWorker?file_id=${file.id}&skip_increment=true';
    } else if (AppConfig.proxyUrl.isNotEmpty) {
      final cleanProxy = AppConfig.proxyUrl.endsWith('/')
          ? AppConfig.proxyUrl.substring(0, AppConfig.proxyUrl.length - 1)
          : AppConfig.proxyUrl;
      return hash != null && hash.isNotEmpty
          ? '$cleanProxy/download-file?hash=$hash&skip_increment=true'
          : '$cleanProxy/download-file?file_id=${file.id}&skip_increment=true';
    } else {
      final cleanSb = AppConfig.supabaseUrl.endsWith('/')
          ? AppConfig.supabaseUrl.substring(0, AppConfig.supabaseUrl.length - 1)
          : AppConfig.supabaseUrl;
      return hash != null && hash.isNotEmpty
          ? '$cleanSb/functions/v1/download-file?hash=$hash&skip_increment=true'
          : '$cleanSb/functions/v1/download-file?file_id=${file.id}&skip_increment=true';
    }
  }

  // --- START RESUMABLE DOWNLOAD ---
  Future<String> startDownload(SharedFile file) async {
    Directory? downloadsDir;
    if (Platform.isAndroid) {
      downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        downloadsDir = await getExternalStorageDirectory();
      }
    } else {
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    if (downloadsDir == null) throw Exception('Storage directory inaccessible');

    final savePath = '${downloadsDir.path}/${file.fileName}';
    final taskId = 'dl_${file.id}_${DateTime.now().millisecondsSinceEpoch}';
    final downloadUrl = _buildDownloadUrl(file);

    final task = TransferTask(
      id: taskId,
      fileName: file.fileName,
      totalBytes: file.fileSize,
      type: TransferType.download,
      status: TransferStatus.queued,
      localPath: savePath,
      remoteUrl: downloadUrl,
      fileRecord: file,
    );

    _tasks.insert(0, task);
    notifyListeners();

    _executeDownload(task);
    return taskId;
  }

  // --- START BATCH DOWNLOAD AS ZIP ARCHIVE ---
  Future<String> startBatchDownloadZip({
    required List<SharedFile> files,
    String? zipName,
  }) async {
    final validFiles = files.where((f) => !f.isFolder).toList();
    if (validFiles.isEmpty) {
      throw Exception('No downloadable files selected');
    }

    Directory? downloadsDir;
    if (Platform.isAndroid) {
      downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        downloadsDir = await getExternalStorageDirectory();
      }
    } else {
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    if (downloadsDir == null) throw Exception('Storage directory inaccessible');

    final timeStampStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final finalZipName = zipName?.isNotEmpty == true
        ? (zipName!.endsWith('.zip') ? zipName : '$zipName.zip')
        : 'NeoFiles_Batch_$timeStampStr.zip';

    final savePath = '${downloadsDir.path}/$finalZipName';
    final totalSize = validFiles.fold<int>(0, (sum, f) => sum + f.fileSize);
    final taskId = 'zip_${DateTime.now().millisecondsSinceEpoch}';

    final task = TransferTask(
      id: taskId,
      fileName: finalZipName,
      totalBytes: totalSize,
      type: TransferType.download,
      status: TransferStatus.queued,
      localPath: savePath,
      batchFiles: validFiles,
      isZipBatch: true,
    );

    _tasks.insert(0, task);
    notifyListeners();

    _executeBatchDownloadZip(task);
    return taskId;
  }

  Future<void> _executeBatchDownloadZip(TransferTask task) async {
    task.status = TransferStatus.running;
    task.cancelToken = CancelToken();
    task.error = null;
    notifyListeners();
    _updateNotification(task);

    final dio = Dio();
    final tempDir = await getTemporaryDirectory();
    final stagingDir = Directory('${tempDir.path}/${task.id}');
    if (!await stagingDir.exists()) {
      await stagingDir.create(recursive: true);
    }

    final validFiles = task.batchFiles ?? [];
    int overallReceived = 0;
    final totalBytes = task.totalBytes;
    task.lastTime = DateTime.now();
    task.lastBytes = 0;

    final List<File> downloadedTempFiles = [];

    try {
      for (int i = 0; i < validFiles.length; i++) {
        if (task.cancelToken?.isCancelled == true) {
          throw DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.cancel,
          );
        }

        final file = validFiles[i];
        final url = _buildDownloadUrl(file);
        final tempFilePath = '${stagingDir.path}/${file.fileName}';
        final tempFile = File(tempFilePath);

        final response = await dio.get<ResponseBody>(
          url,
          options: Options(responseType: ResponseType.stream),
          cancelToken: task.cancelToken,
        );

        final sink = tempFile.openWrite();

        await for (final chunk in response.data!.stream) {
          sink.add(chunk);
          overallReceived += chunk.length;
          task.transferredBytes = overallReceived;

          if (totalBytes > 0) {
            task.progress = (overallReceived / totalBytes).clamp(0.0, 0.90);
          }

          final now = DateTime.now();
          final ms = now.difference(task.lastTime).inMilliseconds;
          if (ms >= 400) {
            final diff = overallReceived - task.lastBytes;
            if (diff > 0) {
              final bps = diff / (ms / 1000.0);
              if (bps >= 1024 * 1024) {
                task.speed = '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
              } else if (bps >= 1024) {
                task.speed = '${(bps / 1024).toStringAsFixed(0)} KB/s';
              }

              if (totalBytes > overallReceived && bps > 0) {
                final remainingSec = (totalBytes - overallReceived) / bps;
                task.eta = remainingSec < 60
                    ? '${remainingSec.toInt()}s remaining'
                    : '${(remainingSec / 60).toInt()}m remaining';
              }
            }
            task.lastTime = now;
            task.lastBytes = overallReceived;
            _updateNotification(task);
            notifyListeners();
          }
        }

        await sink.flush();
        await sink.close();
        downloadedTempFiles.add(tempFile);
      }

      task.speed = 'Packaging ZIP...';
      task.progress = 0.95;
      notifyListeners();
      _updateNotification(task);

      final encoder = ZipFileEncoder();
      encoder.create(task.localPath!);
      for (final f in downloadedTempFiles) {
        encoder.addFile(f);
      }
      encoder.close();

      try {
        if (await stagingDir.exists()) {
          await stagingDir.delete(recursive: true);
        }
      } catch (_) {}

      task.status = TransferStatus.completed;
      task.progress = 1.0;
      task.transferredBytes = totalBytes;
      task.speed = '';
      task.eta = '';
      notifyListeners();
      _updateNotification(task);

      if (Platform.isAndroid && task.localPath != null) {
        try {
          const platform = MethodChannel('com.neofiles.transfer/media_scanner');
          await platform.invokeMethod('scanFile', {'path': task.localPath});
        } catch (_) {}
      }

    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || task.status == TransferStatus.paused) {
        task.status = TransferStatus.paused;
      } else {
        task.status = TransferStatus.failed;
        task.error = e.message;
      }
      notifyListeners();
      _updateNotification(task);
    } catch (e) {
      task.status = TransferStatus.failed;
      task.error = e.toString();
      notifyListeners();
      _updateNotification(task);
    }
  }

  Future<void> _executeDownload(TransferTask task) async {
    task.status = TransferStatus.running;
    task.cancelToken = CancelToken();
    task.error = null;
    notifyListeners();
    _updateNotification(task);

    final dio = Dio();
    final localFile = File(task.localPath!);
    int existingBytes = 0;

    if (await localFile.exists()) {
      existingBytes = await localFile.length();
      task.transferredBytes = existingBytes;
    }

    // If already fully downloaded
    if (task.totalBytes > 0 && existingBytes >= task.totalBytes) {
      task.status = TransferStatus.completed;
      task.progress = 1.0;
      notifyListeners();
      _updateNotification(task);
      return;
    }

    try {
      final tokenVal = Supabase.instance.client.auth.currentSession?.accessToken;
      final headers = <String, dynamic>{
        if (tokenVal != null) 'Authorization': 'Bearer $tokenVal',
      };

      // Resumable HTTP Range Header
      if (existingBytes > 0) {
        headers['Range'] = 'bytes=$existingBytes-';
      }

      final response = await dio.get<ResponseBody>(
        task.remoteUrl!,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
        ),
        cancelToken: task.cancelToken,
      );

      final isPartial = response.statusCode == 206 || existingBytes > 0;
      final sink = localFile.openWrite(mode: isPartial ? FileMode.append : FileMode.write);

      final stream = response.data!.stream;
      int received = existingBytes;
      int total = task.totalBytes;

      final contentLengthHeader = response.headers.value('content-length');
      if (contentLengthHeader != null) {
        final incomingLength = int.tryParse(contentLengthHeader) ?? 0;
        if (total <= 0 || !isPartial) {
          total = incomingLength + existingBytes;
        }
      }

      task.lastTime = DateTime.now();
      task.lastBytes = received;

      await for (final chunk in stream) {
        sink.add(chunk);
        received += chunk.length;
        task.transferredBytes = received;

        if (total > 0) {
          task.progress = (received / total).clamp(0.0, 1.0);
        }

        // Calculate Speed & ETA
        final now = DateTime.now();
        final ms = now.difference(task.lastTime).inMilliseconds;
        if (ms >= 400 || received == total) {
          final diff = received - task.lastBytes;
          if (ms > 0 && diff > 0) {
            final bps = diff / (ms / 1000.0);
            if (bps >= 1024 * 1024) {
              task.speed = '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
            } else if (bps >= 1024) {
              task.speed = '${(bps / 1024).toStringAsFixed(0)} KB/s';
            }

            if (total > received && bps > 0) {
              final remainingSec = (total - received) / bps;
              if (remainingSec < 60) {
                task.eta = '${remainingSec.toInt()}s remaining';
              } else {
                task.eta = '${(remainingSec / 60).toInt()}m remaining';
              }
            }
          }
          task.lastTime = now;
          task.lastBytes = received;
          _updateNotification(task);
          notifyListeners();
        }
      }

      await sink.flush();
      await sink.close();

      task.status = TransferStatus.completed;
      task.progress = 1.0;
      task.speed = '';
      task.eta = '';
      notifyListeners();
      _updateNotification(task);

      // Trigger Android media scanner
      if (Platform.isAndroid && task.localPath != null) {
        try {
          const platform = MethodChannel('com.neofiles.transfer/media_scanner');
          await platform.invokeMethod('scanFile', {'path': task.localPath});
        } catch (_) {}
      }

    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || task.status == TransferStatus.paused) {
        task.status = TransferStatus.paused;
      } else {
        task.status = TransferStatus.failed;
        task.error = e.message;
      }
      notifyListeners();
      _updateNotification(task);
    } catch (e) {
      task.status = TransferStatus.failed;
      task.error = e.toString();
      notifyListeners();
      _updateNotification(task);
    }
  }

  // --- START RESUMABLE UPLOAD ---
  Future<String> startUpload({
    required File file,
    String? fileName,
    String? parentDbFolderId,
    String? parentDriveFolderId,
    bool autoMakePublic = true,
  }) async {
    final finalFileName = fileName ?? file.path.split(Platform.pathSeparator).last;
    final len = await file.length();
    final taskId = 'up_${DateTime.now().millisecondsSinceEpoch}_${finalFileName.hashCode.abs()}';

    final task = TransferTask(
      id: taskId,
      fileName: finalFileName,
      totalBytes: len,
      type: TransferType.upload,
      status: TransferStatus.queued,
      localPath: file.path,
      parentDbFolderId: parentDbFolderId,
      parentDriveFolderId: parentDriveFolderId,
      autoMakePublic: autoMakePublic,
    );

    _tasks.insert(0, task);
    notifyListeners();

    _executeUpload(task);
    return taskId;
  }

  Future<void> _executeUpload(TransferTask task) async {
    task.status = TransferStatus.running;
    task.cancelToken = CancelToken();
    task.error = null;
    notifyListeners();
    _updateNotification(task);

    final auth = _authService;
    final api = _apiService;
    final file = File(task.localPath!);

    if (auth == null || api == null || !await file.exists()) {
      task.status = TransferStatus.failed;
      task.error = 'Upload dependencies or local file missing';
      notifyListeners();
      return;
    }

    try {
      final targetDriveFolderId = task.parentDriveFolderId ?? auth.profile?.driveFolderId;
      if (targetDriveFolderId == null || targetDriveFolderId.isEmpty) {
        throw Exception('Google Drive folder is not connected.');
      }

      String googleToken = await auth.getGoogleAccessToken() ?? '';
      if (googleToken.isEmpty) {
        googleToken = await api.refreshGoogleAccessToken();
      }

      final dio = Dio();

      // Step 1: Create or resume session URL
      if (task.resumableSessionUrl == null || task.resumableSessionUrl!.isEmpty) {
        final sessionRes = await dio.post(
          'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable',
          data: {
            'name': task.fileName,
            'parents': [targetDriveFolderId]
          },
          options: Options(
            headers: {
              'Authorization': 'Bearer $googleToken',
              'Content-Type': 'application/json; charset=UTF-8',
              'X-Upload-Content-Type': 'application/octet-stream',
            },
          ),
        );

        task.resumableSessionUrl = sessionRes.headers.value('Location') ?? '';
        if (task.resumableSessionUrl!.isEmpty) {
          throw Exception('Google Drive did not return resumable upload session');
        }
      }

      // Step 2: Upload Stream
      final totalLength = task.totalBytes;
      task.lastTime = DateTime.now();
      task.lastBytes = 0;

      final uploadResponse = await dio.put(
        task.resumableSessionUrl!,
        data: file.openRead(),
        cancelToken: task.cancelToken,
        options: Options(
          headers: {
            'Content-Length': totalLength,
          },
        ),
        onSendProgress: (sent, total) {
          task.transferredBytes = sent;
          if (total > 0) {
            task.progress = (sent / total).clamp(0.0, 1.0);
          }

          final now = DateTime.now();
          final ms = now.difference(task.lastTime).inMilliseconds;
          if (ms >= 400 || sent == total) {
            final diff = sent - task.lastBytes;
            if (ms > 0 && diff > 0) {
              final bps = diff / (ms / 1000.0);
              if (bps >= 1024 * 1024) {
                task.speed = '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
              } else if (bps >= 1024) {
                task.speed = '${(bps / 1024).toStringAsFixed(0)} KB/s';
              }

              if (total > sent && bps > 0) {
                final remainingSec = (total - sent) / bps;
                if (remainingSec < 60) {
                  task.eta = '${remainingSec.toInt()}s remaining';
                } else {
                  task.eta = '${(remainingSec / 60).toInt()}m remaining';
                }
              }
            }
            task.lastTime = now;
            task.lastBytes = sent;
            _updateNotification(task);
            notifyListeners();
          }
        },
      );

      if (uploadResponse.statusCode == 200 || uploadResponse.statusCode == 201) {
        final driveData = uploadResponse.data;
        final driveFileId = driveData['id'] as String;

        // Insert database record
        final userId = auth.currentUser?.id;
        if (userId != null) {
          final insertPayload = <String, dynamic>{
            'user_id': userId,
            'google_drive_file_id': driveFileId,
            'file_name': task.fileName,
            'file_size': totalLength,
            'mime_type': driveData['mimeType'] ?? '',
            'current_version_num': 1,
            'sharing_status': 'private',
            'parent_folder_id': task.parentDbFolderId,
          };

          final isApk = task.fileName.toLowerCase().endsWith('.apk');
          if (isApk) {
            insertPayload['apk_version'] = 'v1.0.1';
            insertPayload['version_api_key'] = 'apk_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
          }

          final insertRes = await Supabase.instance.client.from('shared_files').insert(insertPayload).select().single();
          var createdFile = SharedFile.fromJson(insertRes);

          await Supabase.instance.client.from('file_versions').insert({
            'file_id': createdFile.id,
            'google_drive_file_id': driveFileId,
            'version_number': 1,
          });

          if (task.autoMakePublic && _fileService != null) {
            createdFile = await _fileService!.generateShareHash(createdFile);
          }

          task.fileRecord = createdFile;
        }

        task.status = TransferStatus.completed;
        task.progress = 1.0;
        task.speed = '';
        task.eta = '';
        notifyListeners();
        _updateNotification(task);
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || task.status == TransferStatus.paused) {
        task.status = TransferStatus.paused;
      } else {
        task.status = TransferStatus.failed;
        task.error = e.message;
      }
      notifyListeners();
      _updateNotification(task);
    } catch (e) {
      task.status = TransferStatus.failed;
      task.error = e.toString();
      notifyListeners();
      _updateNotification(task);
    }
  }

  // --- PAUSE / RESUME / CANCEL CONTROLS ---
  void pauseTask(String taskId) {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      final task = _tasks[idx];
      task.status = TransferStatus.paused;
      task.cancelToken?.cancel('Paused by user');
      notifyListeners();
      _updateNotification(task);
    }
  }

  void resumeTask(String taskId) {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      final task = _tasks[idx];
      if (task.status == TransferStatus.paused || task.status == TransferStatus.failed) {
        if (task.isZipBatch) {
          _executeBatchDownloadZip(task);
        } else if (task.type == TransferType.download) {
          _executeDownload(task);
        } else {
          _executeUpload(task);
        }
      }
    }
  }

  void cancelTask(String taskId) {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      final task = _tasks[idx];
      task.status = TransferStatus.cancelled;
      task.cancelToken?.cancel('Cancelled by user');
      _updateNotification(task);
      _tasks.removeAt(idx);
      notifyListeners();
    }
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == TransferStatus.completed || t.status == TransferStatus.cancelled);
    notifyListeners();
  }
}
