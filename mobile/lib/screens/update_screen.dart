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
        // Clear red dot badge since user proceeded to download
        updateService.clearBadge();
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

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'App Updater',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Check Again',
            icon: isChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                  )
                : const Icon(LucideIcons.refreshCw, color: Colors.white70, size: 19),
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
                      ? [
                          const Color(0xFF4338CA).withOpacity(0.35),
                          const Color(0xFF1E1B4B).withOpacity(0.6),
                        ]
                      : [
                          const Color(0xFF065F46).withOpacity(0.35),
                          const Color(0xFF064E3B).withOpacity(0.5),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasUpdate
                      ? Colors.indigoAccent.withOpacity(0.3)
                      : Colors.green.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: (hasUpdate ? Colors.indigoAccent : Colors.green).withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (hasUpdate ? Colors.indigoAccent : Colors.green).withOpacity(0.4),
                      ),
                    ),
                    child: Icon(
                      hasUpdate ? LucideIcons.sparkles : LucideIcons.checkCircle2,
                      color: hasUpdate ? Colors.indigoAccent : Colors.greenAccent,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    hasUpdate ? 'New Update Available!' : 'Your App is Up to Date',
                    style: const TextStyle(
                      color: Colors.white,
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
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                  const SizedBox(height: 18),
                  // Version Pills Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildVersionPill('Installed', currentVer, Colors.grey.shade400),
                        if (hasUpdate) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(LucideIcons.arrowRight, color: Colors.white38, size: 16),
                          ),
                          _buildVersionPill('Latest', latestVer, Colors.indigoAccent, isNew: true),
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
                  color: const Color(0xFF0F172A).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedSize.isNotEmpty
                                ? 'Android Universal APK • $formattedSize'
                                : 'Android Universal APK Package',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 11.5),
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
                color: const Color(0xFF0F172A).withOpacity(0.6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.fileText, color: Colors.indigoAccent, size: 18),
                      const SizedBox(width: 10),
                      const Text(
                        'What\'s New & Release Notes',
                        style: TextStyle(
                          color: Colors.white,
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
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 14),
                  if (description.trim().isNotEmpty)
                    SelectableText(
                      description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        height: 1.6,
                        letterSpacing: 0.2,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        'No feature notes provided for this version.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontStyle: FontStyle.italic),
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
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withOpacity(0.12)),
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

  Widget _buildVersionPill(String label, String version, Color color, {bool isNew = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white54, fontSize: 11.5),
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
}
