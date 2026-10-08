import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/shared_file.dart';
import '../config.dart';

class MediaPreviewDialog extends StatefulWidget {
  final SharedFile file;
  final VoidCallback onDownload;

  const MediaPreviewDialog({
    Key? key,
    required this.file,
    required this.onDownload,
  }) : super(key: key);

  @override
  State<MediaPreviewDialog> createState() => _MediaPreviewDialogState();
}

class _MediaPreviewDialogState extends State<MediaPreviewDialog> {
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
    if (hash.isEmpty) {
      return '${AppConfig.cfWorkerUrl}/download/direct/${widget.file.googleDriveFileId}';
    }
    return '${AppConfig.cfWorkerUrl}?hash=$hash&stream=true';
  }

  String _getWebDownloadUrl() {
    final hash = widget.file.uniqueShareHash ?? '';
    if (hash.isEmpty) {
      return '${AppConfig.appUrl}';
    }
    return '${AppConfig.appUrl}/download/$hash';
  }

  Future<void> _launchInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open preview: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final file = widget.file;
    final mime = file.mimeType.toLowerCase();
    final isImage = mime.startsWith('image/');
    final isVideo = mime.startsWith('video/');
    final isAudio = mime.startsWith('audio/');
    final isPdf = mime.contains('pdf');
    final isApk = mime.contains('android.package-archive') || file.fileName.toLowerCase().endsWith('.apk');

    final streamUrl = _getStreamUrl();
    final webUrl = _getWebDownloadUrl();

    return Dialog(
      backgroundColor: isLight ? Colors.white : const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B).withOpacity(0.6),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(
                    color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.06),
                  ),
                ),
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
                                      : Colors.indigo.withOpacity(0.15),
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
                                      : LucideIcons.file,
                      color: isImage
                          ? Colors.green
                          : isVideo
                              ? Colors.purpleAccent
                              : isAudio
                                  ? Colors.cyan
                                  : isPdf
                                      ? Colors.redAccent
                                      : Colors.indigoAccent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'File Preview',
                          style: TextStyle(
                            color: isLight ? const Color(0xFF0F172A) : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          file.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isLight ? Colors.grey.shade600 : Colors.grey.shade400,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      LucideIcons.x,
                      color: isLight ? Colors.grey.shade700 : Colors.grey.shade400,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),

            // Preview Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    if (isImage) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 300),
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
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                      color: Colors.indigoAccent,
                                    ),
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
                                        'Image preview loading failed. Use Direct Download or Open.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: isLight ? Colors.grey.shade600 : Colors.grey.shade400,
                                          fontSize: 11.5,
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
                    ] else if (isVideo) ...[
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF030712),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.06),
                          ),
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
                              style: TextStyle(
                                color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Watch instantly via external media player or browser stream.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isLight ? Colors.grey.shade600 : Colors.grey.shade400,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _launchInBrowser(streamUrl),
                              icon: const Icon(LucideIcons.play, size: 15),
                              label: const Text('Play Video Stream'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isAudio) ...[
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF030712),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.06),
                          ),
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
                              'Audio Stream Track',
                              style: TextStyle(
                                color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Stream lossless audio with instant playback.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isLight ? Colors.grey.shade600 : Colors.grey.shade400,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _launchInBrowser(streamUrl),
                              icon: const Icon(LucideIcons.play, size: 15),
                              label: const Text('Play Audio Track'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0891B2),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isPdf) ...[
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF030712),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.06),
                          ),
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
                              style: TextStyle(
                                color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'View PDF document directly in your browser.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isLight ? Colors.grey.shade600 : Colors.grey.shade400,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _launchInBrowser(streamUrl),
                              icon: const Icon(LucideIcons.externalLink, size: 15),
                              label: const Text('Open PDF in Browser'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF030712),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.06),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isApk ? LucideIcons.smartphone : LucideIcons.fileCode,
                                color: Colors.indigoAccent,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              isApk ? 'Android APK Package' : 'File Package',
                              style: TextStyle(
                                color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Size: ${_formatFileSize(file.fileSize)}',
                              style: TextStyle(
                                color: isLight ? Colors.grey.shade600 : Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // File Metadata Info Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'File Size:',
                                style: TextStyle(
                                  color: isLight ? Colors.grey.shade600 : Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _formatFileSize(file.fileSize),
                                style: TextStyle(
                                  color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sharing Status:',
                                style: TextStyle(
                                  color: isLight ? Colors.grey.shade600 : Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: file.sharingStatus == 'public'
                                      ? Colors.green.withOpacity(0.15)
                                      : Colors.amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  file.sharingStatus.toUpperCase(),
                                  style: TextStyle(
                                    color: file.sharingStatus == 'public' ? Colors.green : Colors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dialog Actions Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B).withOpacity(0.6),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(
                  top: BorderSide(
                    color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _launchInBrowser(webUrl),
                      icon: const Icon(LucideIcons.externalLink, size: 14),
                      label: const Text('Web Page'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isLight ? const Color(0xFF4F46E5) : const Color(0xFF818CF8),
                        side: BorderSide(
                          color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withOpacity(0.12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onDownload();
                      },
                      icon: const Icon(LucideIcons.download, size: 14),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
