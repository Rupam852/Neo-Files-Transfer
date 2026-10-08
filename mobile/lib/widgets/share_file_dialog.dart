import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/shared_file.dart';
import '../models/custom_share_link.dart';
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
  bool _showQr = false;
  bool _isSavingQr = false;
  int _activeTab = 0; // 0 = Direct Link & QR, 1 = PIN & Protected Links
  final GlobalKey _qrBoundaryKey = GlobalKey();

  // Custom link creation form state
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _limitController = TextEditingController();
  String _expiryOption = 'none'; // 'none', '1h', '1d', '7d', '30d'
  bool _isOneTime = false;
  bool _isCreatingCustom = false;

  // Custom links list state
  List<CustomShareLink> _customLinks = [];
  bool _isLoadingCustomLinks = false;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.file;
    _loadCustomLinks();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _labelController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomLinks() async {
    setState(() => _isLoadingCustomLinks = true);
    try {
      final fileService = Provider.of<FileService>(context, listen: false);
      final links = await fileService.loadCustomShareLinks(_currentFile.id);
      if (mounted) {
        setState(() {
          _customLinks = links;
          _isLoadingCustomLinks = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCustomLinks = false);
    }
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
      return '${AppConfig.proxyUrl}/download-file?hash=$hash';
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
            content: Text('Share link generated!'),
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
            content: Text('Failed to generate link: $e'),
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
          content: Text('Sharing has been disabled by administrator.'),
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
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<Uint8List?> _captureQrPng() async {
    try {
      final boundary = _qrBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing QR: $e');
      return null;
    }
  }

  Future<void> _saveQrCode() async {
    if (_isSavingQr) return;
    setState(() => _isSavingQr = true);

    try {
      final pngBytes = await _captureQrPng();
      if (pngBytes == null) throw 'Failed to generate QR image';

      final safeName = _currentFile.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final fileName = 'QR_$safeName.png';

      Directory? downloadDir;
      if (Platform.isAndroid) {
        downloadDir = Directory('/storage/emulated/0/Download');
        if (!downloadDir.existsSync()) {
          downloadDir = await getExternalStorageDirectory();
        }
      } else {
        downloadDir = await getApplicationDocumentsDirectory();
      }

      if (downloadDir == null) throw 'Could not access storage directory';

      final file = File('${downloadDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved QR Code to Downloads: $fileName'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving QR code: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingQr = false);
    }
  }

  Future<void> _shareQrCodeImage() async {
    try {
      final pngBytes = await _captureQrPng();
      if (pngBytes == null) throw 'Failed to generate QR image';

      final tempDir = await getTemporaryDirectory();
      final safeName = _currentFile.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final tempFile = File('${tempDir.path}/QR_$safeName.png');
      await tempFile.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Download link QR code for ${_currentFile.fileName}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing QR: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleCreateCustomLink() async {
    if (_isCreatingCustom) return;
    setState(() => _isCreatingCustom = true);

    try {
      final fileService = Provider.of<FileService>(context, listen: false);
      DateTime? expiresAt;
      final nowUtc = DateTime.now().toUtc();
      if (_expiryOption == '1h') {
        expiresAt = nowUtc.add(const Duration(hours: 1));
      } else if (_expiryOption == '1d') {
        expiresAt = nowUtc.add(const Duration(days: 1));
      } else if (_expiryOption == '7d') {
        expiresAt = nowUtc.add(const Duration(days: 7));
      } else if (_expiryOption == '30d') {
        expiresAt = nowUtc.add(const Duration(days: 30));
      }

      int? maxLimit;
      if (_isOneTime) {
        maxLimit = 1;
      } else if (_limitController.text.trim().isNotEmpty) {
        maxLimit = int.tryParse(_limitController.text.trim());
      }

      final created = await fileService.createCustomShareLink(
        fileId: _currentFile.id,
        pinCode: _pinController.text.trim().isNotEmpty ? _pinController.text.trim() : null,
        expiresAt: expiresAt,
        maxDownloads: maxLimit,
        isOneTime: _isOneTime,
        label: _labelController.text.trim().isNotEmpty ? _labelController.text.trim() : null,
      );

      if (mounted) {
        setState(() {
          _customLinks.insert(0, created);
          _isCreatingCustom = false;
          _pinController.clear();
          _labelController.clear();
          _limitController.clear();
          _expiryOption = 'none';
          _isOneTime = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Protected share link created!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreatingCustom = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create link: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteCustomLink(String linkId) async {
    try {
      final fileService = Provider.of<FileService>(context, listen: false);
      await fileService.deleteCustomShareLink(linkId);
      if (mounted) {
        setState(() {
          _customLinks.removeWhere((l) => l.id == linkId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link deleted'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final authService = Provider.of<AuthService>(context);
    final sharingEnabled = authService.isSharingEnabled;
    final hasShareLink = _currentFile.uniqueShareHash != null &&
        _currentFile.uniqueShareHash!.trim().isNotEmpty;
    final isPublic = _currentFile.sharingStatus == 'public';

    final webUrl = hasShareLink
        ? '${AppConfig.appUrl}/download/${_currentFile.uniqueShareHash}'
        : '';
    final directUrl = hasShareLink ? _getDirectDownloadUrl(_currentFile) : '';

    final dialogBg = isLight ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.08);
    final titleColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subColor = isLight ? const Color(0xFF64748B) : Colors.grey.shade400;
    final tabBg = isLight ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);

    return Dialog(
      backgroundColor: dialogBg,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
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
                    color: const Color(0xFF4F46E5).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.25)),
                  ),
                  child: Icon(_getFileIcon(), color: const Color(0xFF4F46E5), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentFile.isFolder ? 'Share Folder' : 'Share File',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _currentFile.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: subColor, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: tabBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTab == 0 ? const Color(0xFF4F46E5) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.share2,
                              size: 14,
                              color: _activeTab == 0 ? Colors.white : subColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Direct Link & QR',
                              style: TextStyle(
                                color: _activeTab == 0 ? Colors.white : subColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTab == 1 ? const Color(0xFF4F46E5) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.shield,
                              size: 14,
                              color: _activeTab == 1 ? Colors.white : subColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'PIN & Protection',
                              style: TextStyle(
                                color: _activeTab == 1 ? Colors.white : subColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Content
            Expanded(
              child: SingleChildScrollView(
                child: _activeTab == 0
                    ? _buildDirectTab(hasShareLink, isPublic, webUrl, directUrl, sharingEnabled, isLight)
                    : _buildProtectedTab(sharingEnabled, isLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectTab(
    bool hasShareLink,
    bool isPublic,
    String webUrl,
    String directUrl,
    bool sharingEnabled,
    bool isLight,
  ) {
    final titleColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subColor = isLight ? const Color(0xFF64748B) : Colors.grey.shade400;
    final cardBg = isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B).withOpacity(0.5);
    final cardBorder = isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.06);

    if (!hasShareLink) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          children: [
            const Icon(LucideIcons.share2, size: 36, color: Color(0xFF4F46E5)),
            const SizedBox(height: 12),
            Text(
              'No Share Link Yet',
              style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Generate a permanent direct share link. It will never change and is safe for app updates.',
              textAlign: TextAlign.center,
              style: TextStyle(color: subColor, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (sharingEnabled)
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _handleGenerateLink,
                icon: _isGenerating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.share2, size: 14),
                label: Text(_isGenerating ? 'Generating...' : 'Generate Share Link'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )
            else
              const Text('Sharing disabled by administrator', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isPublic ? const Color(0xFF10B981).withOpacity(0.1) : Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isPublic ? const Color(0xFF10B981).withOpacity(0.25) : Colors.amber.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isPublic ? const Color(0xFF10B981) : Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPublic ? 'Public — Link is active' : 'Private — Link is blocked',
                  style: TextStyle(
                    color: isPublic ? (isLight ? const Color(0xFF047857) : const Color(0xFF6EE7B7)) : (isLight ? const Color(0xFFB45309) : Colors.amber.shade300),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _isToggling ? null : () => _handleToggleSharing(sharingEnabled),
                child: Text(
                  isPublic ? 'Make Private' : 'Make Public',
                  style: TextStyle(
                    color: isPublic ? (isLight ? const Color(0xFFB45309) : Colors.amber.shade300) : const Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // QR Code Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'WEB DOWNLOAD PAGE',
              style: TextStyle(color: Color(0xFF4F46E5), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _showQr = !_showQr),
              icon: const Icon(LucideIcons.qrCode, size: 13, color: Color(0xFF4F46E5)),
              label: Text(_showQr ? 'Hide QR' : 'Show QR', style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 4),

        if (_showQr) ...[
          Center(
            child: Column(
              children: [
                RepaintBoundary(
                  key: _qrBoundaryKey,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrImageView(
                          data: webUrl,
                          version: QrVersions.auto,
                          size: 150.0,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _currentFile.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isSavingQr ? null : _saveQrCode,
                      icon: _isSavingQr
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(LucideIcons.download, size: 13),
                      label: Text(_isSavingQr ? 'Saving...' : 'Download QR', style: const TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _shareQrCodeImage,
                      icon: const Icon(LucideIcons.share2, size: 13),
                      label: const Text('Share QR', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(color: Color(0xFF4F46E5)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],

        // Web Link Copy Box
        _buildLinkBox(webUrl, 'Web link copied!', isLight),
        const SizedBox(height: 14),

        // Direct Stream Link
        Text(
          'DIRECT STREAM LINK (FOR APPS/UPDATES)',
          style: TextStyle(
            color: isLight ? const Color(0xFFDB2777) : const Color(0xFFF472B6),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        _buildLinkBox(directUrl, 'Direct link copied!', isLight),
      ],
    );
  }

  Widget _buildProtectedTab(bool sharingEnabled, bool isLight) {
    final titleColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subColor = isLight ? const Color(0xFF64748B) : Colors.grey.shade400;
    final cardBg = isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B).withOpacity(0.5);
    final cardBorder = isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.06);
    final inputBg = isLight ? Colors.white : const Color(0xFF0F172A);
    final inputBorder = isLight ? const Color(0xFFCBD5E1) : Colors.white.withOpacity(0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Create form
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CREATE PROTECTED LINK',
                style: TextStyle(color: Color(0xFF4F46E5), fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // PIN Field
              TextField(
                controller: _pinController,
                decoration: InputDecoration(
                  hintText: 'PIN / Password (e.g. 1234)',
                  hintStyle: TextStyle(color: subColor, fontSize: 12),
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: inputBorder),
                  ),
                  prefixIcon: Icon(LucideIcons.lock, size: 14, color: subColor),
                ),
                style: TextStyle(color: titleColor, fontSize: 12),
              ),
              const SizedBox(height: 8),

              // Expiry & Limit Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: inputBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _expiryOption,
                          isExpanded: true,
                          dropdownColor: inputBg,
                          items: [
                            DropdownMenuItem(value: 'none', child: Text('Never Expire', style: TextStyle(color: titleColor, fontSize: 11))),
                            DropdownMenuItem(value: '1h', child: Text('1 Hour', style: TextStyle(color: titleColor, fontSize: 11))),
                            DropdownMenuItem(value: '1d', child: Text('24 Hours', style: TextStyle(color: titleColor, fontSize: 11))),
                            DropdownMenuItem(value: '7d', child: Text('7 Days', style: TextStyle(color: titleColor, fontSize: 11))),
                            DropdownMenuItem(value: '30d', child: Text('30 Days', style: TextStyle(color: titleColor, fontSize: 11))),
                          ],
                          onChanged: (val) => setState(() => _expiryOption = val ?? 'none'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _limitController,
                      enabled: !_isOneTime,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: _isOneTime ? '1 (One-Time)' : 'Limit (e.g. 5)',
                        hintStyle: TextStyle(color: _isOneTime ? Colors.amber.shade700 : subColor, fontSize: 12),
                        filled: true,
                        fillColor: _isOneTime ? (isLight ? const Color(0xFFFEF3C7) : const Color(0xFF1E293B)) : inputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                        prefixIcon: Icon(LucideIcons.hash, size: 14, color: _isOneTime ? Colors.amber.shade600 : subColor),
                      ),
                      style: TextStyle(color: _isOneTime ? Colors.amber.shade700 : titleColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // One-time toggle
              Row(
                children: [
                  Checkbox(
                    value: _isOneTime,
                    activeColor: const Color(0xFF4F46E5),
                    onChanged: (v) {
                      final checked = v ?? false;
                      setState(() {
                        _isOneTime = checked;
                        if (checked) {
                          _limitController.text = '1';
                        } else {
                          _limitController.clear();
                        }
                      });
                    },
                  ),
                  Text('One-time self-destruct (Locks limit to 1)', style: TextStyle(color: titleColor, fontSize: 11.5)),
                ],
              ),
              const SizedBox(height: 6),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCreatingCustom ? null : _handleCreateCustomLink,
                  icon: _isCreatingCustom
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.shield, size: 14),
                  label: Text(_isCreatingCustom ? 'Creating...' : 'Generate Protected Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Active links
        Text(
          'ACTIVE PROTECTED LINKS (${_customLinks.length})',
          style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        if (_isLoadingCustomLinks)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_customLinks.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cardBorder),
            ),
            child: Text('No custom protected links created yet', style: TextStyle(color: subColor, fontSize: 12)),
          )
        else
          ..._customLinks.map((lnk) {
            final linkUrl = '${AppConfig.appUrl}/download/${lnk.customShareHash}';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (lnk.pinCode != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                children: [
                                  Icon(LucideIcons.lock, size: 10, color: Color(0xFF4F46E5)),
                                  SizedBox(width: 4),
                                  Text('PIN', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (lnk.isOneTime) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('1-Time', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      IconButton(
                        onPressed: () => _handleDeleteCustomLink(lnk.id),
                        icon: const Icon(LucideIcons.trash2, size: 14, color: Colors.redAccent),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildLinkBox(linkUrl, 'Protected link copied!', isLight),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildLinkBox(String url, String copyMsg, bool isLight) {
    final boxBg = isLight ? const Color(0xFFF1F5F9) : const Color(0xFF0B1329);
    final borderColor = isLight ? const Color(0xFFCBD5E1) : Colors.white.withOpacity(0.08);
    final textColor = isLight ? const Color(0xFF1E293B) : Colors.white70;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: boxBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor, fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(copyMsg), backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating),
              );
            },
            icon: const Icon(LucideIcons.copy, size: 14, color: Color(0xFF4F46E5)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Share.share(url),
            icon: Icon(LucideIcons.share2, size: 14, color: isLight ? const Color(0xFF475569) : Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
