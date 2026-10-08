import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class IncomingSharedFile {
  final String name;
  final String path;
  final int size;
  final String mimeType;

  IncomingSharedFile({
    required this.name,
    required this.path,
    required this.size,
    required this.mimeType,
  });

  factory IncomingSharedFile.fromMap(Map<dynamic, dynamic> map) {
    return IncomingSharedFile(
      name: map['name'] as String? ?? 'Shared File',
      path: map['path'] as String? ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
      mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
    );
  }
}

class ShareReceiverService with ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.neofiles.transfer/share_receiver');

  final StreamController<List<IncomingSharedFile>> _sharedFilesStreamController =
      StreamController<List<IncomingSharedFile>>.broadcast();

  Stream<List<IncomingSharedFile>> get onSharedFilesReceived =>
      _sharedFilesStreamController.stream;

  List<IncomingSharedFile> _pendingFiles = [];
  List<IncomingSharedFile> get pendingFiles => List.unmodifiable(_pendingFiles);

  ShareReceiverService() {
    _initChannel();
  }

  void _initChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedFilesReceived') {
        final rawList = call.arguments as List<dynamic>?;
        if (rawList != null && rawList.isNotEmpty) {
          final files = rawList
              .map((item) => IncomingSharedFile.fromMap(item as Map<dynamic, dynamic>))
              .where((f) => f.path.isNotEmpty)
              .toList();

          if (files.isNotEmpty) {
            _pendingFiles = files;
            _sharedFilesStreamController.add(files);
            notifyListeners();
          }
        }
      }
    });
  }

  Future<List<IncomingSharedFile>> checkInitialSharedFiles() async {
    try {
      final rawList = await _channel.invokeMethod<List<dynamic>>('getInitialSharedFiles');
      if (rawList != null && rawList.isNotEmpty) {
        final files = rawList
            .map((item) => IncomingSharedFile.fromMap(item as Map<dynamic, dynamic>))
            .where((f) => f.path.isNotEmpty)
            .toList();

        if (files.isNotEmpty) {
          _pendingFiles = files;
          _sharedFilesStreamController.add(files);
          notifyListeners();
          return files;
        }
      }
    } catch (e) {
      debugPrint('ShareReceiverService: Failed to get initial shared files: $e');
    }
    return [];
  }

  void clearPendingFiles() {
    _pendingFiles = [];
    try {
      _channel.invokeMethod('clearSharedFiles');
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _sharedFilesStreamController.close();
    super.dispose();
  }
}
