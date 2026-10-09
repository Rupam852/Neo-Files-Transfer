import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/shared_file.dart';
import '../services/file_service.dart';

class FolderPickerDialog extends StatefulWidget {
  final List<String> excludedFolderIds;
  final String? currentFolderId;

  const FolderPickerDialog({
    super.key,
    required this.excludedFolderIds,
    this.currentFolderId,
  });

  static Future<String?> show(
    BuildContext context, {
    required List<String> excludedFolderIds,
    String? currentFolderId,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FolderPickerDialog(
        excludedFolderIds: excludedFolderIds,
        currentFolderId: currentFolderId,
      ),
    );
  }

  @override
  State<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  List<SharedFile> _folders = [];
  bool _isLoading = true;
  String? _selectedFolderId;
  String _selectedFolderName = 'Root (Home)';

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.currentFolderId;
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    try {
      final fileService = Provider.of<FileService>(context, listen: false);
      final all = await fileService.getAllFolders();
      final excluded = widget.excludedFolderIds.toSet();
      if (mounted) {
        setState(() {
          _folders = all.where((f) => !excluded.contains(f.id)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bgColor = isLight ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.08);
    final titleColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subColor = isLight ? const Color(0xFF64748B) : Colors.white60;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 5,
          )
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFCBD5E1) : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.folderInput, color: Color(0xFF818CF8), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Move Items To',
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Space_Grotesk',
                          ),
                        ),
                        Text(
                          'Select destination folder',
                          style: TextStyle(color: subColor, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, color: subColor, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            // Folder list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Root Folder option
                        _buildFolderTile(
                          id: null,
                          name: 'Root (Home)',
                          isRoot: true,
                          isLight: isLight,
                        ),
                        const SizedBox(height: 6),
                        ..._folders.map((folder) => _buildFolderTile(
                              id: folder.id,
                              name: folder.fileName,
                              isRoot: false,
                              isLight: isLight,
                            )),
                      ],
                    ),
            ),

            // Bottom action button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: subColor,
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, _selectedFolderId ?? '__ROOT__'),
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: Text(
                        'Move to ${_selectedFolderName.length > 12 ? "${_selectedFolderName.substring(0, 10)}..." : _selectedFolderName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderTile({
    required String? id,
    required String name,
    required bool isRoot,
    required bool isLight,
  }) {
    final isSelected = _selectedFolderId == id;
    final activeBg = const Color(0xFF4F46E5).withValues(alpha: isLight ? 0.12 : 0.2);
    final inactiveBg = isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B).withValues(alpha: 0.5);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? activeBg : inactiveBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? const Color(0xFF4F46E5) : (isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.05)),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: () {
          setState(() {
            _selectedFolderId = id;
            _selectedFolderName = name;
          });
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isRoot
                ? const Color(0xFF4F46E5).withValues(alpha: 0.15)
                : Colors.amber.shade400.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isRoot ? LucideIcons.hardDrive : LucideIcons.folder,
            color: isRoot ? const Color(0xFF818CF8) : Colors.amber.shade400,
            size: 20,
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            color: isLight ? const Color(0xFF0F172A) : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        trailing: isSelected
            ? const Icon(LucideIcons.checkCircle2, color: Color(0xFF4F46E5), size: 20)
            : null,
      ),
    );
  }
}
