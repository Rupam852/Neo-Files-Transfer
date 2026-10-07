import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class UploadProgressWidget extends StatelessWidget {
  final String fileName;
  final double progress;
  final String? speed;
  final VoidCallback onCancel;

  const UploadProgressWidget({
    Key? key,
    required this.fileName,
    required this.progress,
    this.speed,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.08),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          color: Colors.indigo.shade300,
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
                      value: progress,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade400),
                      minHeight: 6,
                    ),
                  ),
                  if (speed != null && speed!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.25)),
                        ),
                        child: Text(
                          '⚡ $speed',
                          style: const TextStyle(
                            color: Color(0xFF818CF8),
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
              icon: const Icon(LucideIcons.x, color: Colors.white60, size: 20),
              onPressed: onCancel,
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}
