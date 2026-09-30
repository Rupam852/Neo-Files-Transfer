import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/shared_file.dart';
import '../services/file_service.dart';
import '../services/auth_service.dart';
import '../config.dart';

class ShareFileDialog extends StatefulWidget {
  final SharedFile file;
  final ValueChanged<SharedFile>? onFileUpdated;

  const ShareFileDialog({
    super.key,
    required this.file,
    this.onFileUpdated,
  });

  @override
  State<ShareFileDialog> createState() => _ShareFileDialogState();
}

class _ShareFileDialogState extends State<ShareFileDialog> {
  late SharedFile _currentFile;
  bool _isGenerating = false;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.file;
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  IconData _getFileIcon() {
    if (_currentFile.isFolder) return LucideIcons.folder;
    final mime = _currentFile.mimeType.toLowerCase();
    if (mime.contains('pdf')) return LucideIcons.fileText;
    if (mime.contains('image')) return LucideIcons.image;
    if (mime.contains('video')) return LucideIcons.video;
    if (mime.contains('zip') || mime.contains('tar') || mime.contains('rar')) {
      return LucideIcons.archive;
    }
    return LucideIcons.file;
  }

  String _getDirectDownloadUrl(SharedFile file) {
    final hash = file.uniqueShareHash ?? '';
    if (file.isFolder) {
      return '${AppConfig.proxyUrl}/api/download/folder/$hash';
    }
    return '${AppConfig.cfWorkerUrl}?hash=$hash';
  }

  Future<void> _handleGenerateLink() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      final fileService = Provider.of<FileService>(context, listen: false);
      final updated = await fileService.generateShareHash(_currentFile);

      if (mounted) {
        setState(() {
          _currentFile = updated;
          _isGenerating = false;
        });
        widget.onFileUpdated?.call(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Share links generated successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate share link: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleToggleSharing(bool isSharingEnabled) async {
    if (_isToggling) return;
    if (!isSharingEnabled && _currentFile.sharingStatus == 'private') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sharing features have been disabled by the administrator.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isToggling = true);
    final nextStatus = _currentFile.sharingStatus == 'public' ? 'private' : 'public';

    try {
      final fileService = Provider.of<FileService>(context, listen: false);
      final updated = await fileService.toggleSharing(_currentFile, nextStatus);

      if (mounted) {
        setState(() {
          _currentFile = updated;
          _isToggling = false;
        });
        widget.onFileUpdated?.call(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Link is now $nextStatus'),
            backgroundColor: nextStatus == 'public' ? const Color(0xFF10B981) : Colors.amber.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isToggling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update sharing status: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final sharingEnabled = authService.isSharingEnabled;
    final hasShareLink = _currentFile.uniqueShareHash != null &&
        _currentFile.uniqueShareHash!.trim().isNotEmpty;
    final isPublic = _currentFile.sharingStatus == 'public';

    final webUrl = hasShareLink
        ? '${AppConfig.appUrl}/download/${_currentFile.uniqueShareHash}'
        : '';
    final directUrl = hasShareLink ? _getDirectDownloadUrl(_currentFile) : '';

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.indigoAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.indigoAccent.withOpacity(0.25)),
                    ),
                    child: Icon(_getFileIcon(), color: const Color(0xFF818CF8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentFile.isFolder ? 'Share Folder' : 'Share File',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_currentFile.fileName} • ${_currentFile.isFolder ? 'Folder' : _formatFileSize(_currentFile.fileSize)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // If No Link Generated Yet (Similar to Web dashboard)
              if (!hasShareLink) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.indigoAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.indigoAccent.withOpacity(0.25)),
                        ),
                        child: const Icon(LucideIcons.share2, color: Color(0xFF818CF8), size: 22),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No share link yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Generate a permanent share link for this ${_currentFile.isFolder ? 'folder' : 'file'}.\nThe link will be stored and can be copied anytime from this menu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (!sharingEnabled)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: const Text(
                      'Generating new sharing links has been disabled by the administrator.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11.5),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _handleGenerateLink,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(LucideIcons.sparkles, size: 16),
                      label: Text(
                        _isGenerating ? 'Generating Share Links...' : 'Generate Share Links',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF6366F1).withOpacity(0.6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
              ] else ...[
                // Status Row: Public vs Private Badge + Toggle
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isPublic
                              ? const Color(0xFF10B981).withOpacity(0.1)
                              : Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isPublic
                                ? const Color(0xFF10B981).withOpacity(0.25)
                                : Colors.amber.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isPublic ? const Color(0xFF34D399) : Colors.amber,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isPublic ? 'Public — link is active' : 'Private — link is blocked',
                                style: TextStyle(
                                  color: isPublic ? const Color(0xFF34D399) : Colors.amber,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _isToggling ? null : () => _handleToggleSharing(sharingEnabled),
                      icon: _isToggling
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(
                              isPublic ? LucideIcons.lock : LucideIcons.globe,
                              size: 13,
                            ),
                      label: Text(
                        isPublic ? 'Make Private' : 'Make Public',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isPublic ? Colors.amber : const Color(0xFF34D399),
                        side: BorderSide(
                          color: isPublic
                              ? Colors.amber.withOpacity(0.3)
                              : const Color(0xFF10B981).withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ],
                ),

                if (!sharingEnabled) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: const Text(
                      '⚠️ Sharing features are temporarily disabled by the administrator.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11),
                    ),
                  ),
                ],

                if (!isPublic && sharingEnabled) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.2)),
                    ),
                    child: const Text(
                      '⚠️ Link is currently blocked. Anyone visiting will see "Access Denied". Tap Make Public to activate.',
                      style: TextStyle(color: Colors.amber, fontSize: 11),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Option 1: Web Download Page Link
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.indigoAccent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.indigoAccent.withOpacity(0.35)),
                      ),
                      child: const Text(
                        'OPTION 1',
                        style: TextStyle(
                          color: Color(0xFF818CF8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'WEB DOWNLOAD PAGE LINK',
                      style: TextStyle(
                        color: Color(0xFF818CF8),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          webUrl,
                          style: TextStyle(
                            color: isPublic ? Colors.white70 : Colors.white38,
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.copy, size: 15, color: Color(0xFF818CF8)),
                        tooltip: 'Copy Web Download Link',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: webUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Web download link copied!'),
                              backgroundColor: Color(0xFF6366F1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(LucideIcons.share2, size: 15, color: Color(0xFF818CF8)),
                        tooltip: 'Share via Apps',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Share.share(
                            'Download ${_currentFile.fileName} securely: $webUrl',
                            subject: _currentFile.fileName,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Opens web browser download page with live progress bar.',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10.5),
                ),

                const SizedBox(height: 18),

                // Option 2: Direct Download Link
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
                      ),
                      child: const Text(
                        'OPTION 2',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'DIRECT DOWNLOAD LINK',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          directUrl,
                          style: TextStyle(
                            color: isPublic ? Colors.white70 : Colors.white38,
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.copy, size: 15, color: Color(0xFF34D399)),
                        tooltip: 'Copy Direct Download Link',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: directUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Direct download link copied!'),
                              backgroundColor: Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Direct Cloudflare edge stream. Instantly downloads file without preview.',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10.5),
                ),

                const SizedBox(height: 20),

                // Quick Share via Apps Button
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Share.share(
                        'Download ${_currentFile.fileName} securely: $webUrl',
                        subject: _currentFile.fileName,
                      );
                    },
                    icon: const Icon(LucideIcons.share2, size: 15),
                    label: const Text('Share to WhatsApp / Apps', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFFC7D2FE),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.indigoAccent.withOpacity(0.3)),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Colors.white60)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
