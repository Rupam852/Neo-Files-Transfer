import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({Key? key}) : super(key: key);

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    // If update service hasn't checked or lacks latest version info, trigger a check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final updateService = Provider.of<UpdateService>(context, listen: false);
      if (updateService.latestVersion == null && !updateService.isChecking) {
        updateService.checkForUpdates(context: context);
      }
    });
  }

  Future<void> _handleDownload(UpdateService updateService) async {
    final downloadTarget = updateService.webUrl ?? updateService.downloadUrl;
    if (downloadTarget == null || downloadTarget.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download URL not available. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isDownloading = true);

    try {
      final uri = Uri.parse(downloadTarget);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening update download in browser...'),
              backgroundColor: Colors.indigo,
            ),
          );
        }
      } else {
        throw 'Could not launch $downloadTarget';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open download link: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
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
    final updateService = Provider.of<UpdateService>(context);
    final hasUpdate = updateService.hasUpdate;
    final currentVer = updateService.currentVersion;
    final latestVer = updateService.latestVersion ?? currentVer;
    final description = updateService.description ?? '';
    final isChecking = updateService.isChecking;
    final fileName = updateService.fileName ?? 'NeoFiles-release.apk';
    final formattedSize = _formatFileSize(updateService.fileSize);
    final isLight = Theme.of(context).brightness == Brightness.light;

    final bgColor = isLight ? const Color(0xFFF8FAFC) : const Color(0xFF030712);
    final cardBg = isLight ? Colors.white : const Color(0xFF0F172A).withOpacity(0.6);
    final cardBorder = isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.06);
    final titleColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subtitleColor = isLight ? const Color(0xFF475569) : Colors.white70;
    final cardShadow = isLight
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ]
        : null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isLight ? Colors.white : Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'App Updater',
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Check Again',
            icon: isChecking
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isLight ? const Color(0xFF0F172A) : Colors.white70,
                    ),
                  )
                : Icon(LucideIcons.refreshCw, color: isLight ? const Color(0xFF475569) : Colors.white70, size: 19),
            onPressed: isChecking
                ? null
                : () => updateService.checkForUpdates(context: context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Hero Banner
            Container(
              padding: const EdgeInsets.all(22.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: hasUpdate
                      ? (isLight
                          ? [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)]
                          : [
                              const Color(0xFF4338CA).withOpacity(0.35),
                              const Color(0xFF1E1B4B).withOpacity(0.6),
                            ])
                      : (isLight
                          ? [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)]
                          : [
                              const Color(0xFF065F46).withOpacity(0.35),
                              const Color(0xFF064E3B).withOpacity(0.5),
                            ]),
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasUpdate
                      ? (isLight ? const Color(0xFFC7D2FE) : Colors.indigoAccent.withOpacity(0.3))
                      : (isLight ? const Color(0xFFA7F3D0) : Colors.green.withOpacity(0.3)),
                ),
                boxShadow: cardShadow,
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: (hasUpdate ? Colors.indigoAccent : Colors.green)
                          .withOpacity(isLight ? 0.2 : 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (hasUpdate ? Colors.indigoAccent : Colors.green)
                            .withOpacity(0.4),
                      ),
                    ),
                    child: Icon(
                      hasUpdate ? LucideIcons.sparkles : LucideIcons.checkCircle2,
                      color: hasUpdate
                          ? (isLight ? const Color(0xFF4338CA) : Colors.indigoAccent)
                          : (isLight ? const Color(0xFF059669) : Colors.greenAccent),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    hasUpdate ? 'New Update Available!' : 'Your App is Up to Date',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasUpdate
                        ? 'A new version of Neo Files Transfer is ready for install.'
                        : 'You are currently running the latest version.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subtitleColor, fontSize: 12.5),
                  ),
                  const SizedBox(height: 18),
                  // Version Pills Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.white : Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: isLight ? Border.all(color: const Color(0xFFCBD5E1)) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildVersionPill('Installed', currentVer, isLight ? const Color(0xFF1E293B) : Colors.grey.shade400, isLight: isLight),
                        if (hasUpdate) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(LucideIcons.arrowRight, color: isLight ? const Color(0xFF94A3B8) : Colors.white38, size: 16),
                          ),
                          _buildVersionPill('Latest', latestVer, const Color(0xFF4F46E5), isNew: true, isLight: isLight),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // File Details Card (if update available)
            if (hasUpdate) ...[
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                  boxShadow: cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.packageCheck, color: Colors.indigoAccent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedSize.isNotEmpty
                                ? 'Android Universal APK • $formattedSize'
                                : 'Android Universal APK Package',
                            style: TextStyle(color: isLight ? const Color(0xFF64748B) : Colors.grey.shade400, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Feature Description / What's New Card
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cardBorder),
                boxShadow: cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.fileText, color: Colors.indigoAccent, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'What\'s New & Release Notes',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (hasUpdate)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.indigoAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            latestVer,
                            style: const TextStyle(
                              color: Colors.indigoAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(color: isLight ? const Color(0xFFE2E8F0) : Colors.white12, height: 1),
                  const SizedBox(height: 14),
                  if (description.trim().isNotEmpty)
                    _buildFormattedDescription(description, isLight: isLight)
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        'No feature notes provided for this version.',
                        style: TextStyle(
                          color: isLight ? const Color(0xFF94A3B8) : Colors.grey.shade500,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            if (hasUpdate) ...[
              ElevatedButton.icon(
                onPressed: _isDownloading ? null : () => _handleDownload(updateService),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5), // Indigo 600
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  shadowColor: const Color(0xFF4F46E5).withOpacity(0.5),
                ),
                icon: _isDownloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(LucideIcons.download, size: 20),
                label: Text(
                  _isDownloading ? 'Opening Download...' : 'Download & Install Update',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Check Again Outlined Button
            OutlinedButton.icon(
              onPressed: isChecking
                  ? null
                  : () => updateService.checkForUpdates(context: context),
              style: OutlinedButton.styleFrom(
                foregroundColor: isLight ? const Color(0xFF334155) : Colors.white70,
                side: BorderSide(color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withOpacity(0.12)),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: Text(
                isChecking ? 'Checking for Updates...' : 'Check for Updates Again',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionPill(String label, String version, Color color, {bool isNew = false, bool isLight = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: isLight ? const Color(0xFF64748B) : Colors.white54,
            fontSize: 11.5,
          ),
        ),
        Text(
          version,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
          ),
        ),
        if (isNew) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'NEW',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormattedDescription(String text, {bool isLight = false}) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          return const SizedBox(height: 8);
        }

        // Check if line is a bullet item (*, -, +, •, numbers)
        final isBullet = RegExp(r'^[\*\-\+•◦▪]\s+').hasMatch(trimmed) ||
            trimmed.startsWith('•') ||
            trimmed.startsWith('*') ||
            trimmed.startsWith('-');

        if (isBullet) {
          final cleanText = trimmed.replaceFirst(RegExp(r'^[\*\-\+•◦▪]\s*'), '');
          return Padding(
            padding: const EdgeInsets.only(bottom: 7.0, left: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5, right: 8),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981), // Emerald bullet point
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    cleanText,
                    style: TextStyle(
                      color: isLight ? const Color(0xFF1E293B) : Colors.white,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Check for Headings (# Heading or **Heading**)
        if (trimmed.startsWith('#') || (trimmed.startsWith('**') && trimmed.endsWith('**'))) {
          final cleanTitle = trimmed.replaceAll(RegExp(r'[#\*]'), '').trim();
          return Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 6.0),
            child: Text(
              cleanTitle,
              style: TextStyle(
                color: isLight ? const Color(0xFF4F46E5) : const Color(0xFF818CF8), // Indigo accent header
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          );
        }

        // Regular Text Line
        return Padding(
          padding: const EdgeInsets.only(bottom: 5.0),
          child: SelectableText(
            line,
            style: TextStyle(
              color: isLight ? const Color(0xFF334155) : Colors.grey.shade200,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        );
      }).toList(),
    );
  }
}

