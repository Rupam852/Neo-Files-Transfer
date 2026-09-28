import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/shared_file.dart';
import '../services/file_service.dart';
import '../config.dart';

class VersionApiDialog extends StatefulWidget {
  final SharedFile file;

  const VersionApiDialog({Key? key, required this.file}) : super(key: key);

  @override
  State<VersionApiDialog> createState() => _VersionApiDialogState();
}

class _VersionApiDialogState extends State<VersionApiDialog> {
  late TextEditingController _versionController;
  late TextEditingController _descriptionController;
  late SharedFile _currentFile;
  bool _isSaving = false;
  bool _isRegenerating = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.file;
    _versionController = TextEditingController(
      text: _currentFile.apkVersion ?? 'v1.0.1',
    );
    _descriptionController = TextEditingController(
      text: _currentFile.apkDescription ?? '',
    );
  }

  @override
  void dispose() {
    _versionController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _getApiUrl() {
    final apiKey = _currentFile.versionApiKey;
    if (apiKey == null || apiKey.isEmpty) return '';

    if (AppConfig.proxyUrl.isNotEmpty) {
      final cleanProxy = AppConfig.proxyUrl.endsWith('/')
          ? AppConfig.proxyUrl.substring(0, AppConfig.proxyUrl.length - 1)
          : AppConfig.proxyUrl;
      return '$cleanProxy/api/version/$apiKey';
    }

    if (AppConfig.supabaseUrl.isNotEmpty) {
      return '${AppConfig.supabaseUrl}/functions/v1/get-version?key=$apiKey';
    }

    return 'https://neofilestransfer.site/api/version/$apiKey';
  }

  Future<void> _handleSaveVersion() async {
    final versionText = _versionController.text.trim();
    final descText = _descriptionController.text; // Preserves newlines, bullet points, and emojis exactly
    if (versionText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid version string')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final fileService = Provider.of<FileService>(context, listen: false);
      final updated = await fileService.updateApkVersion(
        _currentFile,
        versionText,
        newDescription: descText,
      );
      setState(() {
        _currentFile = updated;
        _versionController.text = updated.apkVersion ?? versionText;
        _descriptionController.text = updated.apkDescription ?? descText;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: ${updated.apkVersion} with description!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save version and description: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleRegenerateKey() async {
    setState(() => _isRegenerating = true);
    try {
      final fileService = Provider.of<FileService>(context, listen: false);
      final updated = await fileService.regenerateVersionApiKey(_currentFile);
      setState(() => _currentFile = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New Version API Link generated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to regenerate link: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  void _handleCopyLink() {
    final url = _getApiUrl();
    if (url.isEmpty) return;

    Clipboard.setData(ClipboardData(text: url));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Version API link copied to clipboard!')),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final apiUrl = _getApiUrl();

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
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
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.smartphone,
                      color: Color(0xFF34D399),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Get Version API',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withOpacity(0.3),
                                ),
                              ),
                              child: const Text(
                                'APK',
                                style: TextStyle(
                                  color: Color(0xFF6EE7B7),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currentFile.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(LucideIcons.x, color: Colors.grey.shade400, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Editable Version Section
              Text(
                'APK VERSION (EDITABLE)',
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _versionController,
                style: const TextStyle(
                  color: Color(0xFF6EE7B7),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. v1.0.1',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF34D399)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'This version will be returned when your app calls the API endpoint. Default is v1.0.1.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5),
              ),
              const SizedBox(height: 16),

              // Editable Release Notes / Description Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RELEASE NOTES / DESCRIPTION (EDITABLE)',
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Supports emojis & bullets',
                    style: TextStyle(color: Colors.indigo.shade300, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                minLines: 3,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  height: 1.45,
                ),
                decoration: InputDecoration(
                  hintText: "🚀 What's new in this version:\n• Fast download engine\n• Bug fixes and UI improvements\n• Enjoy the new update!",
                  hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF34D399)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Preserves newlines, emojis, bullet points, and all formatting in the API response.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5),
              ),
              const SizedBox(height: 12),

              // Save Version & Description Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleSaveVersion,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.save, size: 15),
                  label: Text(
                    _isSaving ? 'Saving Changes...' : 'Save Version & Description',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Version API Link Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.code, color: Colors.indigo.shade300, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'VERSION API LINK',
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _isRegenerating ? null : _handleRegenerateKey,
                    icon: _isRegenerating
                        ? const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.grey,
                            ),
                          )
                        : Icon(LucideIcons.refreshCw,
                            color: Colors.grey.shade400, size: 12),
                    label: Text(
                      'Regenerate',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 10.5),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: SelectableText(
                  apiUrl.isNotEmpty ? apiUrl : 'Generating link...',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: apiUrl.isNotEmpty ? _handleCopyLink : null,
                  icon: Icon(_copied ? LucideIcons.check : LucideIcons.copy,
                      size: 14),
                  label: Text(_copied ? 'Copied to Clipboard' : 'Copy Version API Link',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // JSON Preview Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'API RESPONSE PREVIEW (JSON)',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      final jsonMap = {
                        "status": "success",
                        "version": _currentFile.apkVersion ?? 'v1.0.1',
                        "description": _currentFile.apkDescription ?? '',
                        "file_name": _currentFile.fileName,
                        "file_size": _currentFile.fileSize,
                        "download_url": "${AppConfig.cfWorkerUrl}?hash=${_currentFile.uniqueShareHash ?? 'apk_share_link'}",
                        "web_url": "${AppConfig.appUrl}/download/${_currentFile.uniqueShareHash ?? ''}",
                        "sharing_status": _currentFile.sharingStatus,
                        "created_at": _currentFile.createdAt.toIso8601String(),
                        "updated_at": (_currentFile.modifiedAt ?? _currentFile.createdAt).toIso8601String(),
                      };
                      final jsonText = const JsonEncoder.withIndent('  ').convert(jsonMap);
                      Clipboard.setData(ClipboardData(text: jsonText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sample JSON response copied!')),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text(
                              'Copy JSON',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF030712),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert({
                      "status": "success",
                      "version": _currentFile.apkVersion ?? 'v1.0.1',
                      "description": _currentFile.apkDescription ?? '',
                      "file_name": _currentFile.fileName,
                      "file_size": _currentFile.fileSize,
                      "download_url": "${AppConfig.cfWorkerUrl}?hash=${_currentFile.uniqueShareHash ?? 'apk_share_link'}",
                      "web_url": "${AppConfig.appUrl}/download/${_currentFile.uniqueShareHash ?? ''}",
                      "sharing_status": _currentFile.sharingStatus,
                      "created_at": _currentFile.createdAt.toIso8601String(),
                      "updated_at": (_currentFile.modifiedAt ?? _currentFile.createdAt).toIso8601String(),
                    }),
                    style: TextStyle(
                      color: const Color(0xFF34D399).withOpacity(0.9),
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close', style: TextStyle(color: Colors.grey.shade400)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
