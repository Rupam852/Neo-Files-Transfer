import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../models/shared_file.dart';

class FileListItem extends StatelessWidget {
  final SharedFile file;
  final VoidCallback onTap;
  final Function(String) onActionSelected;

  const FileListItem({
    Key? key,
    required this.file,
    required this.onTap,
    required this.onActionSelected,
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

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM dd, yyyy').format(file.createdAt);
    final sizeStr = file.isFolder ? 'Folder' : _formatFileSize(file.fileSize);

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1329).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.04),
          width: 1.0,
        ),
      ),
      child: ListTile(
        onTap: onTap,
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
          style: const TextStyle(
            color: Colors.white,
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
                      color: Colors.grey.shade400,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade600,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: Colors.grey.shade400,
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
                          color: Colors.indigo.shade300,
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
                    color: Colors.indigo.shade300.withOpacity(0.8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          color: const Color(0xFF0F172A),
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: onActionSelected,
          icon: Icon(
            LucideIcons.moreVertical,
            color: Colors.grey.shade400,
            size: 20,
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(LucideIcons.pencil, color: Colors.white70, size: 16),
                  SizedBox(width: 10),
                  Text('Rename', style: TextStyle(color: Colors.white70, fontSize: 13.5)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  const Icon(LucideIcons.share2, color: Colors.white70, size: 16),
                  const SizedBox(width: 10),
                  Text(
                    file.sharingStatus == 'public' ? 'Make Private' : 'Make Public & Share',
                    style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                  ),
                ],
              ),
            ),
            if (!file.isFolder) ...[
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(LucideIcons.download, color: Colors.white70, size: 16),
                    SizedBox(width: 10),
                    Text('Download', style: TextStyle(color: Colors.white70, fontSize: 13.5)),
                  ],
                ),
              ),
            ],
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(LucideIcons.trash2, color: Colors.redAccent, size: 16),
                  SizedBox(width: 10),
                  Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 13.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
