import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../models/shared_file.dart';
import '../services/file_service.dart';

class ManageVersionsDialog extends StatefulWidget {
  final SharedFile file;

  const ManageVersionsDialog({Key? key, required this.file}) : super(key: key);

  @override
  State<ManageVersionsDialog> createState() => _ManageVersionsDialogState();
}

class _ManageVersionsDialogState extends State<ManageVersionsDialog> {
  List<Map<String, dynamic>> _versions = [];
  bool _isLoading = true;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() => _isLoading = true);
    try {
      final fileService = Provider.of<FileService>(context, listen: false);
      final list = await fileService.getFileVersions(widget.file.id);
      setState(() {
        _versions = list;
      });
    } catch (e) {
      debugPrint('Failed to load file versions: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUploadNewVersion() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;

    final picked = result.files.single;
    final file = File(picked.path!);

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _cancelToken = CancelToken();
    });

    try {
      final fileService = Provider.of<FileService>(context, listen: false);
      await fileService.uploadFileVersion(
        fileRecord: widget.file,
        newFile: file,
        fileName: picked.name,
        cancelToken: _cancelToken!,
        onProgress: (pct, [speed]) {
          if (mounted) {
            setState(() => _uploadProgress = pct);
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New version uploaded successfully!')),
        );
      }
      _loadVersions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload version: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double dBytes = bytes.toDouble();
    while (dBytes >= 1024 && i < suffixes.length - 1) {
      dBytes /= 1024;
      i++;
    }
    return '${dBytes.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final titleColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subColor = isLight ? const Color(0xFF64748B) : Colors.grey.shade400;

    return Dialog(
      backgroundColor: isLight ? Colors.white : const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(isLight ? 0.12 : 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF4F46E5).withOpacity(isLight ? 0.25 : 0.3),
                    ),
                  ),
                  child: const Icon(
                    LucideIcons.history,
                    color: Color(0xFF4F46E5),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Versions',
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.file.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subColor,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(LucideIcons.x, color: isLight ? const Color(0xFF94A3B8) : Colors.grey.shade400, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Upload New Version Button / Progress
            if (_isUploading) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFEEF2FF) : Colors.indigo.shade500.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4F46E5).withOpacity(isLight ? 0.25 : 0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Uploading New Version...',
                          style: TextStyle(
                            color: isLight ? const Color(0xFF4338CA) : Colors.indigo.shade200,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: isLight ? const Color(0xFF4F46E5) : Colors.indigo.shade300,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: isLight ? const Color(0xFFCBD5E1) : Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleUploadNewVersion,
                  icon: const Icon(LucideIcons.upload, size: 14),
                  label: const Text('Upload New Version',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            Text(
              'VERSION HISTORY',
              style: TextStyle(
                color: isLight ? const Color(0xFF475569) : Colors.grey.shade400,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),

            // Versions List
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                      ),
                    )
                  : _versions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'No past versions available',
                              style: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.grey.shade500, fontSize: 12),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _versions.length,
                          itemBuilder: (context, index) {
                            final ver = _versions[index];
                            final verNum = ver['version_number'] as int? ?? 1;
                            final isLatest = index == 0;
                            final dateStr = ver['uploaded_at'] != null
                                ? DateFormat('MMM dd, yyyy, hh:mm a')
                                    .format(DateTime.parse(ver['uploaded_at'] as String).toLocal())
                                : '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isLatest
                                      ? const Color(0xFF4F46E5).withOpacity(isLight ? 0.35 : 0.3)
                                      : (isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.04)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isLatest
                                          ? const Color(0xFF4F46E5).withOpacity(isLight ? 0.12 : 0.2)
                                          : (isLight ? const Color(0xFFE2E8F0) : Colors.grey.shade800),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'v$verNum',
                                        style: TextStyle(
                                          color: isLatest
                                              ? const Color(0xFF4F46E5)
                                              : (isLight ? const Color(0xFF64748B) : Colors.grey.shade400),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Version $verNum',
                                              style: TextStyle(
                                                color: titleColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            if (isLatest) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981).withOpacity(isLight ? 0.15 : 0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'LATEST',
                                                  style: TextStyle(
                                                    color: isLight ? const Color(0xFF059669) : const Color(0xFF6EE7B7),
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (dateStr.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            dateStr,
                                            style: TextStyle(
                                              color: subColor,
                                              fontSize: 10.5,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close', style: TextStyle(color: subColor)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
