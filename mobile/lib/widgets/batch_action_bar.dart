import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BatchActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onMove;
  final VoidCallback onTrash;
  final VoidCallback onDownloadZip;
  final VoidCallback onCancel;

  const BatchActionBar({
    super.key,
    required this.selectedCount,
    required this.onMove,
    required this.onTrash,
    required this.onDownloadZip,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedCount == 0) return const SizedBox.shrink();

    final isLight = Theme.of(context).brightness == Brightness.light;
    final bgColor = isLight ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.12);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      offset: Offset.zero,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: isLight ? 0.96 : 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Move button
              _buildActionButton(
                context: context,
                icon: LucideIcons.folderInput,
                label: 'Move',
                color: const Color(0xFF3B82F6),
                onTap: onMove,
                isLight: isLight,
              ),

              // Move to Trash button
              _buildActionButton(
                context: context,
                icon: LucideIcons.trash2,
                label: 'Trash',
                color: const Color(0xFFEF4444),
                onTap: onTrash,
                isLight: isLight,
              ),

              // Download ZIP button
              _buildActionButton(
                context: context,
                icon: LucideIcons.fileArchive,
                label: 'ZIP Download',
                color: const Color(0xFF10B981),
                onTap: onDownloadZip,
                isLight: isLight,
                isPrimary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isLight,
    bool isPrimary = false,
  }) {
    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isLight ? 0.12 : 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isLight ? const Color(0xFF1E293B) : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
