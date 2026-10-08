import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../models/shared_file.dart';
import '../config.dart';

class MediaPreviewDialog extends StatefulWidget {
  final SharedFile file;
  final VoidCallback onDownload;

  const MediaPreviewDialog({
    super.key,
    required this.file,
    required this.onDownload,
  });

  @override
  State<MediaPreviewDialog> createState() => _MediaPreviewDialogState();
}

class _MediaPreviewDialogState extends State<MediaPreviewDialog> {
  String _textContent = '';
  bool _isLoadingText = false;
  String? _textError;

  @override
  void initState() {
    super.initState();
    if (_isTextOrCodeFile()) {
      _loadTextContent();
    }
  }

  String _getFileExtension() {
    final name = widget.file.fileName;
    if (!name.contains('.')) return '';
    return name.split('.').last.toLowerCase();
  }

  bool _isTextOrCodeFile() {
    final ext = _getFileExtension();
    const textExtensions = [
      'txt', 'json', 'js', 'jsx', 'ts', 'tsx', 'css', 'html', 'py', 'dart',
      'log', 'sql', 'md', 'xml', 'yaml', 'yml', 'env', 'csv', 'sh', 'bat',
      'c', 'cpp', 'h', 'java', 'kt', 'rs', 'go', 'php', 'rb'
    ];
    if (textExtensions.contains(ext)) return true;
    final mime = widget.file.mimeType.toLowerCase();
    return mime.startsWith('text/') || mime.contains('json') || mime.contains('javascript');
  }

  String _formatFileSize(int bytes) {
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

  String _getStreamUrl() {
    final hash = widget.file.uniqueShareHash ?? '';
    if (hash.isNotEmpty) {
      if (AppConfig.cfWorkerUrl.isNotEmpty) {
        return '${AppConfig.cfWorkerUrl}?hash=$hash&stream=true';
      }
      if (AppConfig.proxyUrl.isNotEmpty) {
        return '${AppConfig.proxyUrl}/download-file?hash=$hash&preview=true&inline=true';
      }
    }
    if (AppConfig.proxyUrl.isNotEmpty && widget.file.id.isNotEmpty) {
      return '${AppConfig.proxyUrl}/download-file?file_id=${widget.file.id}&preview=true&inline=true';
    }
    return 'https://drive.google.com/uc?id=${widget.file.googleDriveFileId}&export=download';
  }

  String _getGoogleDriveViewUrl() {
    return 'https://drive.google.com/file/d/${widget.file.googleDriveFileId}/view';
  }

  Future<void> _loadTextContent() async {
    setState(() {
      _isLoadingText = true;
      _textError = null;
    });

    try {
      final streamUrl = _getStreamUrl();
      final response = await http.get(Uri.parse(streamUrl)).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String decoded = '';
        try {
          decoded = utf8.decode(response.bodyBytes);
        } catch (_) {
          decoded = String.fromCharCodes(response.bodyBytes);
        }

        if (decoded.length > 60000) {
          decoded = decoded.substring(0, 60000) + '\n\n...[Content truncated for fast preview]...';
        }

        if (mounted) {
          setState(() {
            _textContent = decoded;
            _isLoadingText = false;
          });
        }
      } else {
        throw 'HTTP ${response.statusCode}';
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _textError = 'Could not load text preview ($e).\nUse "Open in Google Drive" or "Download" to view.';
          _isLoadingText = false;
        });
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open URL: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final file = widget.file;
    final ext = _getFileExtension();
    final mime = file.mimeType.toLowerCase();

    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(ext) || mime.startsWith('image/');
    final isVideo = ['mp4', 'mkv', 'mov', 'avi', 'webm', '3gp', 'flv'].contains(ext) || mime.startsWith('video/');
    final isAudio = ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac', 'opus'].contains(ext) || mime.startsWith('audio/');
    final isPdf = ext == 'pdf' || mime.contains('pdf');
    final isText = _isTextOrCodeFile();
    final isApk = ext == 'apk' || mime.contains('android.package-archive');

    final streamUrl = _getStreamUrl();
    final driveViewUrl = _getGoogleDriveViewUrl();

    final dialogBg = isLight ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.08);
    final headerBg = isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B).withOpacity(0.6);
    final titleColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subColor = isLight ? const Color(0xFF64748B) : Colors.grey.shade400;
    final cardBg = isLight ? const Color(0xFFF8FAFC) : const Color(0xFF0B1329);

    return Dialog(
      backgroundColor: dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: headerBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isImage
                          ? Colors.green.withOpacity(0.15)
                          : isVideo
                              ? Colors.purple.withOpacity(0.15)
                              : isAudio
                                  ? Colors.cyan.withOpacity(0.15)
                                  : isPdf
                                      ? Colors.red.withOpacity(0.15)
                                      : isText
                                          ? Colors.amber.withOpacity(0.15)
                                          : const Color(0xFF4F46E5).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isImage
                          ? LucideIcons.image
                          : isVideo
                              ? LucideIcons.video
                              : isAudio
                                  ? LucideIcons.music
                                  : isPdf
                                      ? LucideIcons.fileText
                                      : isText
                                          ? LucideIcons.code
                                          : LucideIcons.file,
                      color: isImage
                          ? Colors.green
                          : isVideo
                              ? Colors.purpleAccent
                              : isAudio
                                  ? Colors.cyan
                                  : isPdf
                                      ? Colors.redAccent
                                      : isText
                                          ? Colors.amber.shade600
                                          : const Color(0xFF4F46E5),
                      size: 18,
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
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_formatFileSize(file.fileSize)} • ${ext.toUpperCase()}',
                          style: TextStyle(color: subColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(LucideIcons.x, color: subColor, size: 18),
                  ),
                ],
              ),
            ),

            // Preview Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // --- 1. IMAGE PREVIEW ---
                    if (isImage) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 320),
                          color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF030712),
                          child: InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: Image.network(
                              streamUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  padding: const EdgeInsets.all(24),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.imageOff, size: 40, color: Colors.grey),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Image preview could not load directly.',
                                        style: TextStyle(color: subColor, fontSize: 12),
                                      ),
                                      const SizedBox(height: 10),
                                      OutlinedButton.icon(
                                        onPressed: () => _launchUrl(driveViewUrl),
                                        icon: const Icon(LucideIcons.externalLink, size: 13),
                                        label: const Text('View in Google Drive', style: TextStyle(fontSize: 11)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Pinch to zoom & drag to pan', style: TextStyle(color: subColor, fontSize: 11)),
                    ]

                    // --- 2. VIDEO PREVIEW ---
                    else if (isVideo) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.playCircle, color: Colors.purpleAccent, size: 36),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'High-Speed Streamable Video',
                              style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Watch instantly via external media player, Google Drive, or browser.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: subColor, fontSize: 11.5),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _launchUrl(streamUrl),
                                  icon: const Icon(LucideIcons.play, size: 14),
                                  label: const Text('Play Video Stream', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C3AED),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _launchUrl(driveViewUrl),
                                  icon: const Icon(LucideIcons.externalLink, size: 14),
                                  label: const Text('Google Drive', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF7C3AED),
                                    side: const BorderSide(color: Color(0xFF7C3AED)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ]

                    // --- 3. AUDIO PREVIEW ---
                    else if (isAudio) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.cyan.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.music, color: Colors.cyan, size: 36),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Lossless Audio Track',
                              style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Stream lossless audio with instant playback.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: subColor, fontSize: 11.5),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _launchUrl(streamUrl),
                                  icon: const Icon(LucideIcons.play, size: 14),
                                  label: const Text('Play Audio', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0891B2),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _launchUrl(driveViewUrl),
                                  icon: const Icon(LucideIcons.externalLink, size: 14),
                                  label: const Text('Drive Player', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0891B2),
                                    side: const BorderSide(color: Color(0xFF0891B2)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ]

                    // --- 4. TEXT / CODE PREVIEW ---
                    else if (isText) ...[
                      if (_isLoadingText) ...[
                        Container(
                          padding: const EdgeInsets.all(36),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const CircularProgressIndicator(color: Color(0xFF4F46E5)),
                              const SizedBox(height: 12),
                              Text('Loading text content...', style: TextStyle(color: subColor, fontSize: 12)),
                            ],
                          ),
                        ),
                      ] else if (_textError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              const Icon(LucideIcons.alertCircle, color: Colors.amber, size: 32),
                              const SizedBox(height: 8),
                              Text(_textError!, textAlign: TextAlign.center, style: TextStyle(color: subColor, fontSize: 12)),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => _launchUrl(driveViewUrl),
                                icon: const Icon(LucideIcons.externalLink, size: 13),
                                label: const Text('Open in Google Drive', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF4F46E5)),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 300),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF030712),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _textContent,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11.5,
                                color: isLight ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _textContent));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Text copied to clipboard!'), behavior: SnackBarBehavior.floating),
                                );
                              },
                              icon: const Icon(LucideIcons.copy, size: 13),
                              label: const Text('Copy Text', style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF4F46E5)),
                            ),
                          ],
                        ),
                      ],
                    ]

                    // --- 5. PDF & DOCUMENTS ---
                    else if (isPdf) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.fileText, color: Colors.redAccent, size: 36),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'PDF Document',
                              style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'View PDF document directly in Google Drive or your default PDF viewer.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: subColor, fontSize: 11.5),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _launchUrl(driveViewUrl),
                                  icon: const Icon(LucideIcons.externalLink, size: 14),
                                  label: const Text('Open in Google Drive', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _launchUrl(streamUrl),
                                  icon: const Icon(LucideIcons.globe, size: 14),
                                  label: const Text('Browser View', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    side: const BorderSide(color: Color(0xFFDC2626)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ]

                    // --- 6. OTHER FILES (APK, ZIP, ETC.) ---
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isApk ? LucideIcons.smartphone : LucideIcons.file,
                                color: const Color(0xFF4F46E5),
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              isApk ? 'Android Package (APK)' : 'Binary File (${ext.toUpperCase()})',
                              style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Download file to install or open with compatible application.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: subColor, fontSize: 11.5),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _launchUrl(driveViewUrl),
                              icon: const Icon(LucideIcons.externalLink, size: 14),
                              label: const Text('Open in Google Drive', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Universal Action Row: Download & Drive Links
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onDownload();
                            },
                            icon: const Icon(LucideIcons.download, size: 14),
                            label: const Text('Download File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _launchUrl(driveViewUrl),
                          icon: const Icon(LucideIcons.externalLink, size: 14),
                          label: const Text('Drive', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
            ),
          ],
        ),
      ),
    );
  }
}
