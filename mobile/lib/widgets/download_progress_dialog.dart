import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DownloadProgressState {
  final String fileName;
  final double progress;
  final String speed;
  final String downloadedSize;

  const DownloadProgressState({
    required this.fileName,
    required this.progress,
    this.speed = '',
    this.downloadedSize = '',
  });

  DownloadProgressState copyWith({
    String? fileName,
    double? progress,
    String? speed,
    String? downloadedSize,
  }) {
    return DownloadProgressState(
      fileName: fileName ?? this.fileName,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      downloadedSize: downloadedSize ?? this.downloadedSize,
    );
  }
}

class DownloadProgressDialog extends StatelessWidget {
  final ValueNotifier<DownloadProgressState> notifier;
  final VoidCallback onCancel;

  const DownloadProgressDialog({
    super.key,
    required this.notifier,
    required this.onCancel,
  });

  static Future<void> show({
    required BuildContext context,
    required ValueNotifier<DownloadProgressState> notifier,
    required VoidCallback onCancel,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: DownloadProgressDialog(
          notifier: notifier,
          onCancel: onCancel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bgColor = isLight ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.1);
    final titleColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subtitleColor = isLight ? const Color(0xFF64748B) : Colors.white70;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 1),
      ),
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ValueListenableBuilder<DownloadProgressState>(
        valueListenable: notifier,
        builder: (context, state, child) {
          final pct = (state.progress * 100).clamp(0, 100).toInt();

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Icon
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: isLight ? 0.12 : 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: isLight ? 0.25 : 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.download,
                      color: Color(0xFF10B981),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Downloading File',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),

                // Current File Name
                Text(
                  state.fileName.isNotEmpty ? state.fileName : 'Preparing download...',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),

                // Progress Bar & Percentage
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      state.downloadedSize.isNotEmpty ? state.downloadedSize : 'Downloading...',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: state.progress > 0 ? state.progress : null,
                    backgroundColor: isLight
                        ? const Color(0xFFE2E8F0)
                        : Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    minHeight: 8,
                  ),
                ),

                // Speed Pill (if available)
                if (state.speed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLight
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFF10B981).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: isLight ? 0.3 : 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.zap, size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          state.speed,
                          style: TextStyle(
                            color: isLight ? const Color(0xFF047857) : const Color(0xFF34D399),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFFEF4444)),
                    label: const Text(
                      'Cancel Download',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: const Color(0xFFEF4444).withValues(alpha: isLight ? 0.35 : 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
