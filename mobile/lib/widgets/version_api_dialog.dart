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
  bool _isInitializing = false;
  bool _copied = false;
  bool _previewMode = false;
  bool _showJsonPreview = false;

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

    if (_currentFile.versionApiKey == null || _currentFile.versionApiKey!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initApiKey();
      });
    }
  }

  Future<void> _initApiKey() async {
    if (!mounted) return;
    setState(() => _isInitializing = true);
    try {
      final fileService = Provider.of<FileService>(context, listen: false);
      final updated = await fileService.getOrGenerateVersionApiKey(_currentFile);
      if (mounted) {
        setState(() {
          _currentFile = updated;
          if (_versionController.text.isEmpty || _versionController.text == 'v1.0.1') {
            _versionController.text = updated.apkVersion ?? 'v1.0.1';
          }
          if (_descriptionController.text.isEmpty) {
            _descriptionController.text = updated.apkDescription ?? '';
          }
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  void _formatBullets() {
    final text = _descriptionController.text;
    if (text.isEmpty) return;

    final lines = text.split('\n');
    final formattedLines = lines.map((line) {
      if (RegExp(r'^\s*[\*\-\+]\s+').hasMatch(line)) {
        return line.replaceFirst(RegExp(r'^\s*[\*\-\+]\s+'), '• ');
      }
      return line;
    }).toList();

    setState(() {
      _descriptionController.text = formattedLines.join('\n');
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✨ Cleaned & converted * / - into bullet points (•)!'),
        backgroundColor: Color(0xFF4F46E5),
        duration: Duration(seconds: 2),
      ),
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
    final descText = _descriptionController.text;
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
          SnackBar(content: Text('Failed to save: $e')),
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
          SnackBar(content: Text('Failed to regenerate: $e')),
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final apiUrl = _getApiUrl();

    return Dialog(
      backgroundColor: isLight ? Colors.white : const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.08),
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
          maxWidth: 480,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.smartphone,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Get Version API',
                              style: TextStyle(
                                color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'APK',
                                style: TextStyle(
                                  color: isLight ? const Color(0xFF059669) : const Color(0xFF6EE7B7),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _currentFile.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isLight ? Colors.grey.shade600 : Colors.grey.shade400,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(LucideIcons.x, color: isLight ? Colors.grey.shade700 : Colors.grey.shade400, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.08)),
              const SizedBox(height: 12),

              // Scrollable Body Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Compact Version API Link Box
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'VERSION API ENDPOINT',
                            style: TextStyle(
                              color: isLight ? Colors.grey.shade700 : Colors.grey.shade300,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          InkWell(
                            onTap: _isRegenerating ? null : _handleRegenerateKey,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                children: [
                                  _isRegenerating
                                      ? const SizedBox(
                                          width: 10,
                                          height: 10,
                                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey),
                                        )
                                      : Icon(LucideIcons.refreshCw, color: const Color(0xFF6366F1), size: 11),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Regenerate',
                                    style: TextStyle(
                                      color: isLight ? const Color(0xFF4F46E5) : const Color(0xFF818CF8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Sleek Combined Link & Copy Container
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_isInitializing) ...[
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF10B981)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                _isInitializing
                                    ? 'Generating secure link...'
                                    : (apiUrl.isNotEmpty ? apiUrl : 'Generating link...'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isLight ? const Color(0xFF0F172A) : Colors.grey.shade300,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton.icon(
                              onPressed: apiUrl.isNotEmpty ? _handleCopyLink : null,
                              icon: Icon(_copied ? LucideIcons.check : LucideIcons.copy, size: 12),
                              label: Text(_copied ? 'Copied' : 'Copy', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Section 2: Editable Version Field
                      Text(
                        'APK VERSION',
                        style: TextStyle(
                          color: isLight ? Colors.grey.shade700 : Colors.grey.shade300,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        controller: _versionController,
                        style: TextStyle(
                          color: isLight ? const Color(0xFF059669) : const Color(0xFF6EE7B7),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. v1.0.1',
                          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          filled: true,
                          isDense: true,
                          fillColor: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Section 3: Release Notes Box
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RELEASE NOTES / DESCRIPTION',
                            style: TextStyle(
                              color: isLight ? Colors.grey.shade700 : Colors.grey.shade300,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Row(
                            children: [
                              // Format bullets button
                              InkWell(
                                onTap: _formatBullets,
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(LucideIcons.sparkles, size: 10, color: Color(0xFF6366F1)),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Format (•)',
                                        style: TextStyle(
                                          color: isLight ? const Color(0xFF4F46E5) : const Color(0xFF818CF8),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Edit / Preview Toggle
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isLight ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () => setState(() => _previewMode = false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: !_previewMode ? const Color(0xFF4F46E5) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          'Edit',
                                          style: TextStyle(
                                            color: !_previewMode ? Colors.white : (isLight ? Colors.grey.shade700 : Colors.grey.shade400),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => setState(() => _previewMode = true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _previewMode ? const Color(0xFF4F46E5) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          'Preview',
                                          style: TextStyle(
                                            color: _previewMode ? Colors.white : (isLight ? Colors.grey.shade700 : Colors.grey.shade400),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Compact Scrollable Description Box (height ~85px)
                      Container(
                        height: 85,
                        decoration: BoxDecoration(
                          color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: !_previewMode
                            ? TextField(
                                controller: _descriptionController,
                                keyboardType: TextInputType.multiline,
                                maxLines: null,
                                expands: true,
                                style: TextStyle(
                                  color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                                decoration: InputDecoration(
                                  hintText: "🚀 What's new:\n• Fast download engine\n• Bug fixes and UI improvements",
                                  hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                  contentPadding: const EdgeInsets.all(8),
                                  border: InputBorder.none,
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(8),
                                child: _descriptionController.text.trim().isEmpty
                                    ? Text(
                                        'No release notes entered yet.',
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontStyle: FontStyle.italic),
                                      )
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: _descriptionController.text.split('\n').map((line) {
                                          final trimmed = line.trim();
                                          if (trimmed.isEmpty) return const SizedBox(height: 3);
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 2.0),
                                            child: Text(
                                              trimmed,
                                              style: TextStyle(
                                                color: isLight ? const Color(0xFF1E293B) : Colors.white,
                                                fontSize: 11,
                                                height: 1.3,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              ),
                      ),
                      const SizedBox(height: 10),

                      // Save Button (Compact)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _handleSaveVersion,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                )
                              : const Icon(LucideIcons.save, size: 13),
                          label: Text(
                            _isSaving ? 'Saving Changes...' : 'Save Version & Notes',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Section 4: Collapsible / Compact JSON Preview
                      InkWell(
                        onTap: () => setState(() => _showJsonPreview = !_showJsonPreview),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _showJsonPreview ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                                    size: 14,
                                    color: const Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Live JSON Response Preview',
                                    style: TextStyle(
                                      color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (_showJsonPreview)
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
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Row(
                                      children: [
                                        Icon(LucideIcons.copy, size: 10, color: isLight ? Colors.grey.shade700 : Colors.grey.shade400),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Copy JSON',
                                          style: TextStyle(
                                            color: isLight ? Colors.grey.shade700 : Colors.grey.shade400,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      if (_showJsonPreview) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          height: 100,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF030712),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
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
                                  color: isLight ? const Color(0xFF059669) : const Color(0xFF34D399).withOpacity(0.9),
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Divider(height: 1, color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.08)),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: isLight ? Colors.grey.shade700 : Colors.grey.shade400,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
