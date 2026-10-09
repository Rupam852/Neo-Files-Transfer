import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../models/shared_file.dart';

class FileListItem extends StatelessWidget {
  final SharedFile file;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Function(String) onActionSelected;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectChanged;

  const FileListItem({
    Key? key,
    required this.file,
    required this.onTap,
    this.onLongPress,
    required this.onActionSelected,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectChanged,
  }) : super(key: key);

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double dBytes = bytes.toDouble();
    while (dBytes >= 1024 && i < suffixes.length - 1) {
      dBytes /= 1024;
      i++;
    }
    return '${dBytes.toStringAsFixed(1)} ${suffixes[i]}';
  }

  IconData _getIcon() {
    if (file.isFolder) return LucideIcons.folder;
    final mime = file.mimeType.toLowerCase();
    if (mime.contains('pdf')) return LucideIcons.fileText;
    if (mime.contains('image')) return LucideIcons.image;
    if (mime.contains('video')) return LucideIcons.video;
    if (mime.contains('zip') || mime.contains('tar') || mime.contains('rar')) {
      return LucideIcons.archive;
    }
    if (mime.contains('spreadsheet') || mime.contains('excel')) return LucideIcons.table;
    if (mime.contains('presentation') || mime.contains('powerpoint')) return LucideIcons.presentation;
    return LucideIcons.file;
  }

  Color _getIconColor() {
    if (file.isFolder) return Colors.amber.shade400;
    final mime = file.mimeType.toLowerCase();
    if (mime.contains('pdf')) return Colors.red.shade400;
    if (mime.contains('image')) return Colors.green.shade400;
    if (mime.contains('video')) return Colors.purple.shade400;
    if (mime.contains('zip') || mime.contains('tar')) return Colors.cyan.shade400;
    return Colors.indigo.shade300;
  }

  void _showActionBottomSheet(BuildContext context, bool isLight) {
    final formattedDate = DateFormat('MMM dd, yyyy, hh:mm a').format(file.createdAt);
    final isApk = !file.isFolder &&
        (file.fileName.toLowerCase().endsWith('.apk') || file.mimeType.contains('android.package-archive'));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isLight ? Colors.white : const Color(0xFF0F172A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: 12,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isLight ? Colors.grey.shade300 : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // File preview header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _getIconColor().withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getIconColor().withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(_getIcon(), color: _getIconColor(), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isLight ? const Color(0xFF0F172A) : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              file.isFolder ? 'Folder' : _formatFileSize(file.fileSize),
                              style: TextStyle(
                                color: isLight ? Colors.grey.shade600 : Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                            if (file.currentVersionNum > 1) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade500.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'v${file.currentVersionNum}',
                                  style: TextStyle(
                                    color: isLight ? Colors.indigo.shade700 : Colors.indigo.shade300,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            if (file.sharingStatus == 'public') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Shared',
                                  style: TextStyle(
                                    color: isLight ? const Color(0xFF059669) : const Color(0xFF34D399),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Created $formattedDate',
                          style: TextStyle(
                            color: isLight ? Colors.grey.shade500 : Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(
                color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.08),
                height: 1,
              ),
              const SizedBox(height: 16),

              // Quick Actions Row (for files: Download, Share, Preview, Rename)
              if (!file.isFolder)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickActionButton(
                      ctx,
                      icon: LucideIcons.download,
                      label: 'Download',
                      color: const Color(0xFF3B82F6),
                      isLight: isLight,
                      onTap: () {
                        Navigator.pop(ctx);
                        onActionSelected('download');
                      },
                    ),
                    _buildQuickActionButton(
                      ctx,
                      icon: LucideIcons.share2,
                      label: 'Share',
                      color: const Color(0xFF6366F1),
                      isLight: isLight,
                      onTap: () {
                        Navigator.pop(ctx);
                        onActionSelected('share_file');
                      },
                    ),
                    _buildQuickActionButton(
                      ctx,
                      icon: LucideIcons.eye,
                      label: 'Preview',
                      color: const Color(0xFF10B981),
                      isLight: isLight,
                      onTap: () {
                        Navigator.pop(ctx);
                        onActionSelected('preview');
                      },
                    ),
                    _buildQuickActionButton(
                      ctx,
                      icon: LucideIcons.pencil,
                      label: 'Rename',
                      color: const Color(0xFFF59E0B),
                      isLight: isLight,
                      onTap: () {
                        Navigator.pop(ctx);
                        onActionSelected('rename');
                      },
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickActionButton(
                      ctx,
                      icon: LucideIcons.folderOpen,
                      label: 'Open',
                      color: const Color(0xFF6366F1),
                      isLight: isLight,
                      onTap: () {
                        Navigator.pop(ctx);
                        onTap();
                      },
                    ),
                    _buildQuickActionButton(
                      ctx,
                      icon: LucideIcons.pencil,
                      label: 'Rename',
                      color: const Color(0xFFF59E0B),
                      isLight: isLight,
                      onTap: () {
                        Navigator.pop(ctx);
                        onActionSelected('rename');
                      },
                    ),
                    _buildQuickActionButton(
                      ctx,
                      icon: LucideIcons.trash2,
                      label: 'Delete',
                      color: Colors.redAccent,
                      isLight: isLight,
                      onTap: () {
                        Navigator.pop(ctx);
                        onActionSelected('delete');
                      },
                    ),
                  ],
                ),

              if (!file.isFolder) ...[
                const SizedBox(height: 16),
                Divider(
                  color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.08),
                  height: 1,
                ),
                const SizedBox(height: 8),

                // Version History List Item
                _buildActionListTile(
                  ctx,
                  icon: LucideIcons.history,
                  title: 'Version History',
                  subtitle: file.currentVersionNum > 1
                      ? 'Current version: v${file.currentVersionNum}'
                      : 'Upload or restore previous versions',
                  iconColor: const Color(0xFF818CF8),
                  isLight: isLight,
                  onTap: () {
                    Navigator.pop(ctx);
                    onActionSelected('manage_versions');
                  },
                ),

                // APK Version API Item (if APK)
                if (isApk)
                  _buildActionListTile(
                    ctx,
                    icon: LucideIcons.code,
                    title: 'Version API Endpoint',
                    subtitle: 'Live JSON endpoint for auto-updater integration',
                    iconColor: const Color(0xFF10B981),
                    isLight: isLight,
                    onTap: () {
                      Navigator.pop(ctx);
                      onActionSelected('version_api');
                    },
                  ),

                // Delete Action
                _buildActionListTile(
                  ctx,
                  icon: LucideIcons.trash2,
                  title: 'Delete File',
                  subtitle: 'Move file to Recycle Bin',
                  iconColor: Colors.redAccent,
                  isLight: isLight,
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    onActionSelected('delete');
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required bool isLight,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withOpacity(0.25),
                  width: 1.2,
                ),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isLight ? const Color(0xFF1E293B) : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required bool isLight,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive
              ? Colors.redAccent
              : (isLight ? const Color(0xFF0F172A) : Colors.white),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDestructive
              ? Colors.redAccent.withOpacity(0.8)
              : (isLight ? Colors.grey.shade600 : Colors.grey.shade400),
          fontSize: 11.5,
        ),
      ),
      trailing: Icon(
        LucideIcons.chevronRight,
        color: isLight ? Colors.grey.shade400 : Colors.white24,
        size: 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final formattedDate = DateFormat('MMM dd, yyyy').format(file.createdAt);
    final sizeStr = file.isFolder ? 'Folder' : _formatFileSize(file.fileSize);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: isSelected
            ? (isLight ? const Color(0xFFEEF2FF) : const Color(0xFF1E1B4B).withOpacity(0.5))
            : (isLight ? Colors.white : const Color(0xFF0B1329).withOpacity(0.5)),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF4F46E5)
              : (isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.04)),
          width: isSelected ? 1.8 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                )
              ]
            : (isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null),
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getIconColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: _getIconColor().withOpacity(0.15),
              width: 1.0,
            ),
          ),
          child: Icon(
            _getIcon(),
            color: _getIconColor(),
            size: 22,
          ),
        ),
        title: Text(
          file.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isLight ? const Color(0xFF0F172A) : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    sizeStr,
                    style: TextStyle(
                      color: isLight ? Colors.grey.shade600 : Colors.grey.shade400,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: isLight ? Colors.grey.shade400 : Colors.grey.shade600,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: isLight ? Colors.grey.shade600 : Colors.grey.shade400,
                      fontSize: 11.5,
                    ),
                  ),
                  if (file.sharingStatus == 'public') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade500.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Shared',
                        style: TextStyle(
                          color: isLight ? Colors.indigo.shade700 : Colors.indigo.shade300,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ]
                ],
              ),
              if (file.currentVersionNum > 1 && file.modifiedAt != null) ...[
                const SizedBox(height: 3),
                Text(
                  'Modified: ${DateFormat('MMM dd, yyyy, hh:mm a').format(file.modifiedAt!.toLocal())}',
                  style: TextStyle(
                    color: isLight ? Colors.indigo.shade700 : Colors.indigo.shade300.withOpacity(0.8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: isSelectionMode
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF4F46E5)
                        : (isLight ? const Color(0xFFCBD5E1) : Colors.white30),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(LucideIcons.check, color: Colors.white, size: 14)
                    : null,
              )
            : IconButton(
                icon: Icon(
                  LucideIcons.moreVertical,
                  color: isLight ? Colors.grey.shade700 : Colors.grey.shade400,
                  size: 20,
                ),
                splashRadius: 20,
                onPressed: () => _showActionBottomSheet(context, isLight),
              ),
      ),
    );
  }
}
