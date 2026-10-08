import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class UploadProgressWidget extends StatelessWidget {
  final String fileName;
  final double progress;
  final String? speed;
  final VoidCallback onCancel;

  const UploadProgressWidget({
    super.key,
    required this.fileName,
    required this.progress,
    this.speed,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).round();
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bgColor = isLight ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.08);
    final titleColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final cancelColor = isLight ? const Color(0xFF64748B) : Colors.white60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Uploading $fileName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$percentage%',
                        style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      backgroundColor: isLight
                          ? const Color(0xFFE2E8F0)
                          : Colors.white.withValues(alpha: 0.05),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                      minHeight: 6,
                    ),
                  ),
                  if (speed != null && speed!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isLight
                              ? const Color(0xFFEEF2FF)
                              : const Color(0xFF4F46E5).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF818CF8).withValues(alpha: isLight ? 0.3 : 0.25),
                          ),
                        ),
                        child: Text(
                          '⚡ $speed',
                          style: TextStyle(
                            color: isLight ? const Color(0xFF4338CA) : const Color(0xFF818CF8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: Icon(LucideIcons.x, color: cancelColor, size: 20),
              onPressed: onCancel,
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}
