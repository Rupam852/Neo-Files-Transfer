import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/shared_file.dart';
import '../services/auth_service.dart';
import '../services/file_service.dart';
import '../services/share_receiver_service.dart';

class ShareUploadDialog extends StatefulWidget {
  final List<IncomingSharedFile> files;
  final VoidCallback onDismiss;

  const ShareUploadDialog({
    super.key,
    required this.files,
    required this.onDismiss,
  });

  static Future<void> show({
    required BuildContext context,
    required List<IncomingSharedFile> files,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => ShareUploadDialog(
        files: files,
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  State<ShareUploadDialog> createState() => _ShareUploadDialogState();
}

class _ShareUploadDialogState extends State<ShareUploadDialog> {
  bool _isUploading = false;
  bool _isFinished = false;
  double _progress = 0.0;
  String _uploadSpeed = '';
  String _statusText = 'Ready to upload';
  String _generatedShareUrl = '';
  String? _selectedFolderId;
  bool _autoMakePublic = true;
  CancelToken? _cancelToken;

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (bytes > 0) ? (bytes.toString().length - 1) ~/ 3 : 0;
    if (i >= suffixes.length) i = suffixes.length - 1;
    double numVal = bytes / (1 << (i * 10));
    return '${numVal.toStringAsFixed(1)} ${suffixes[i]}';
  }

  IconData _getFileIcon(String fileName, String mimeType) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp'].contains(ext) || mimeType.startsWith('image/')) {
      return LucideIcons.image;
    }
    if (['mp4', 'mkv', 'mov', 'avi', 'webm'].contains(ext) || mimeType.startsWith('video/')) {
      return LucideIcons.video;
    }
    if (['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac'].contains(ext) || mimeType.startsWith('audio/')) {
      return LucideIcons.music;
    }
    if (ext == 'pdf' || mimeType.contains('pdf')) {
      return LucideIcons.fileText;
    }
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext) || mimeType.contains('zip')) {
      return LucideIcons.archive;
    }
    if (ext == 'apk') {
      return LucideIcons.box;
    }
    return LucideIcons.file;
  }

  Future<void> _startUpload() async {
    final fileService = Provider.of<FileService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    if (authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to upload files.')),
      );
      return;
    }

    _cancelToken = CancelToken();
    setState(() {
      _isUploading = true;
      _statusText = 'Preparing files...';
      _progress = 0.05;
    });

    try {
      final totalFiles = widget.files.length;
      String lastShareUrl = '';

      for (int i = 0; i < totalFiles; i++) {
        final incoming = widget.files[i];
        final ioFile = File(incoming.path);

        if (!await ioFile.exists()) {
          throw Exception('File not found at ${incoming.path}');
        }

        setState(() {
          _statusText = 'Uploading ${i + 1} of $totalFiles: ${incoming.name}';
        });

        final uploadedFile = await fileService.uploadFile(
          file: ioFile,
          fileName: incoming.name,
          parentDbFolderId: _selectedFolderId,
          parentDriveFolderId: null,
          onProgress: (double p, [String? speed]) {
            setState(() {
              _progress = ((i + p) / totalFiles).clamp(0.0, 1.0);
              _uploadSpeed = speed ?? '';
            });
          },
          cancelToken: _cancelToken!,
        );

        if (_autoMakePublic) {
          SharedFile targetFile = uploadedFile;
          if (targetFile.sharingStatus != 'public' || targetFile.uniqueShareHash == null) {
            targetFile = await fileService.generateShareHash(targetFile);
          }
          if (targetFile.uniqueShareHash != null) {
            lastShareUrl = '${AppConfig.appUrl}/download/${targetFile.uniqueShareHash}';
          }
        }
      }

      setState(() {
        _isUploading = false;
        _isFinished = true;
        _progress = 1.0;
        _generatedShareUrl = lastShareUrl;
        _statusText = 'Upload Successful! 🎉';
      });

      if (lastShareUrl.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: lastShareUrl));
        HapticFeedback.mediumImpact();
      }

      if (mounted) {
        Provider.of<ShareReceiverService>(context, listen: false).clearPendingFiles();
      }

    } catch (e) {
      setState(() {
        _isUploading = false;
        _statusText = 'Upload failed: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final totalBytes = widget.files.fold<int>(0, (sum, f) => sum + f.size);

    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF0B132B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            spreadRadius: 5,
          )
        ],
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFCBD5E1) : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Row
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.share2,
                      color: Color(0xFF818CF8),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isFinished
                            ? 'Upload Complete!'
                            : 'Upload to Neo Files',
                        style: TextStyle(
                          color: isLight ? const Color(0xFF0F172A) : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Space_Grotesk',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isFinished
                            ? 'Share link copied to clipboard 📋'
                            : '${widget.files.length} item(s) • ${_formatSize(totalBytes)}',
                        style: TextStyle(
                          color: isLight ? const Color(0xFF64748B) : Colors.white70,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isUploading)
                  IconButton(
                    onPressed: widget.onDismiss,
                    icon: Icon(
                      LucideIcons.x,
                      color: isLight ? const Color(0xFF94A3B8) : Colors.white54,
                      size: 20,
                    ),
                    splashRadius: 20,
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // File items preview list
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF030712),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                itemCount: widget.files.length,
                separatorBuilder: (context, index) => Divider(
                  color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.06),
                  height: 12,
                ),
                itemBuilder: (ctx, i) {
                  final f = widget.files[i];
                  final iconData = _getFileIcon(f.name, f.mimeType);

                  return Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(iconData, color: const Color(0xFF818CF8), size: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _formatSize(f.size),
                              style: TextStyle(
                                color: isLight ? const Color(0xFF64748B) : Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // If Finished: Show Share Link & Copy Option
            if (_isFinished) ...[
              if (_generatedShareUrl.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: isLight ? 0.08 : 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.checkCircle2, color: Color(0xFF10B981), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Share Link Ready & Copied!',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isLight ? Colors.white : const Color(0xFF030712),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isLight ? const Color(0xFFCBD5E1) : Colors.white12,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _generatedShareUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF818CF8),
                                  fontSize: 12,
                                  fontFamily: 'Space_Grotesk',
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _generatedShareUrl));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Link copied to clipboard!')),
                                );
                              },
                              icon: const Icon(LucideIcons.copy, size: 16, color: Color(0xFF818CF8)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              splashRadius: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              ElevatedButton(
                onPressed: widget.onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ] else if (_isUploading) ...[
              // Uploading state with Progress Bar & Speed
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isLight ? const Color(0xFF0F172A) : Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Color(0xFF818CF8),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: isLight ? const Color(0xFFE2E8F0) : Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                      minHeight: 8,
                    ),
                  ),
                  if (_uploadSpeed.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _uploadSpeed,
                        style: TextStyle(
                          color: isLight ? const Color(0xFF64748B) : Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              // Options & Upload Trigger Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.globe,
                        size: 16,
                        color: _autoMakePublic ? const Color(0xFF10B981) : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Generate Public Share Link',
                        style: TextStyle(
                          color: isLight ? const Color(0xFF0F172A) : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _autoMakePublic,
                    onChanged: (v) => setState(() => _autoMakePublic = v),
                    activeTrackColor: const Color(0xFF4F46E5),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              ElevatedButton.icon(
                onPressed: _startUpload,
                icon: const Icon(LucideIcons.uploadCloud, size: 18),
                label: const Text(
                  'Upload & Copy Share Link',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
