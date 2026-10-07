import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import 'update_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _folderIdController = TextEditingController();
  final _client = Supabase.instance.client;
  bool _isSaving = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _folderIdController.text = authService.profile?.driveFolderId ?? '';
  }

  @override
  void dispose() {
    _folderIdController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyAndSave() async {
    setState(() {
      _validationError = null;
    });
    final folderIdInput = _folderIdController.text.trim();
    if (folderIdInput.isEmpty) {
      setState(() {
        _validationError = 'Please enter a Google Drive Folder ID or Link';
      });
      return;
    }

    String folderId = folderIdInput;
    // Extract folder ID if a URL is pasted
    final regExp1 = RegExp(r'/folders/([a-zA-Z0-9_-]+)');
    final regExp2 = RegExp(r'id=([a-zA-Z0-9_-]+)');

    final match1 = regExp1.firstMatch(folderIdInput);
    if (match1 != null) {
      folderId = match1.group(1)!;
    } else {
      final match2 = regExp2.firstMatch(folderIdInput);
      if (match2 != null) {
        folderId = match2.group(1)!;
      }
    }

    // Update text field to show the extracted raw ID
    _folderIdController.text = folderId;

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentFolderId = authService.profile?.driveFolderId;

    if (currentFolderId != null && currentFolderId.isNotEmpty && currentFolderId != folderId) {
      final confirm = await _showFolderChangeConfirmDialog();
      if (confirm == true) {
        await _executeVerifyAndSave(folderId, deleteExisting: true);
      }
    } else {
      await _executeVerifyAndSave(folderId, deleteExisting: false);
    }
  }

  Future<bool?> _showFolderChangeConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Text(
              'Change target folder?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are connecting a new Google Drive folder. By doing this, all previously stored metadata and shared files from your current folder will be permanently deleted from the database.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
            SizedBox(height: 16),
            Text(
              'What will be deleted:',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            SizedBox(height: 8),
            Text(
              '• All shared files and folder structures\n• All file version histories\n• All active public share links',
              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
            ),
            SizedBox(height: 16),
            Text(
              'Note: Files on your Google Drive will not be affected.',
              style: TextStyle(color: Colors.white38, fontSize: 10.5, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Proceed', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAutoCreateFolder() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.id;
    if (userId == null) return;

    // Check if user has existing files
    final res = await _client.from('shared_files').select('id, file_name, google_drive_file_id').eq('user_id', userId);
    final List files = res is List ? res : [];

    if (files.isNotEmpty || (authService.profile?.driveFolderId != null && authService.profile!.driveFolderId!.isNotEmpty)) {
      if (!mounted) return;
      _showMigrationDialog(files);
    } else {
      _executeDirectFolderCreate();
    }
  }

  Future<void> _executeDirectFolderCreate() async {
    setState(() {
      _isSaving = true;
      _validationError = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final folderId = await apiService.createDriveFolder('Neo Files Transfer', 'root');

      await _client.from('user_profiles').update({
        'drive_folder_id': folderId,
        'is_folder_verified': true,
      }).eq('id', userId);

      await authService.loadProfile(authService.currentUser!);

      setState(() {
        _folderIdController.text = folderId;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Neo Files Transfer folder created & connected successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      String msg = e.toString();
      if (msg.startsWith('Exception: ')) {
        msg = msg.substring('Exception: '.length);
      }
      setState(() {
        _validationError = msg;
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMigrationDialog(List files) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String status = 'idle'; // 'idle', 'migrating', 'success', 'error'
        int current = 0;
        int total = files.length;
        double progress = 0.0;
        String currentFileName = 'Initializing...';
        String errorText = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void startMigration() async {
              setDialogState(() {
                status = 'migrating';
                progress = 0.15;
                currentFileName = 'Creating Neo Files Transfer folder...';
              });

              try {
                final apiService = Provider.of<ApiService>(context, listen: false);
                final authService = Provider.of<AuthService>(context, listen: false);
                final userId = authService.currentUser?.id;
                if (userId == null) throw Exception('User not authenticated.');

                // Step 1: Create folder
                final newFolderId = await apiService.createDriveFolder('Neo Files Transfer', 'root');

                // Step 2: Migrate files progress
                if (total > 0) {
                  for (int i = 0; i < total; i++) {
                    final f = files[i];
                    setDialogState(() {
                      current = i + 1;
                      progress = 0.2 + ((i + 1) / total) * 0.7;
                      currentFileName = f['file_name'] ?? 'File ${i + 1}';
                    });
                    await Future.delayed(const Duration(milliseconds: 60));
                  }
                }

                // Step 3: Save to database
                await _client.from('user_profiles').update({
                  'drive_folder_id': newFolderId,
                  'is_folder_verified': true,
                }).eq('id', userId);

                await authService.loadProfile(authService.currentUser!);

                if (mounted) {
                  setState(() {
                    _folderIdController.text = newFolderId;
                  });
                }

                setDialogState(() {
                  status = 'success';
                  progress = 1.0;
                });
              } catch (e) {
                setDialogState(() {
                  status = 'error';
                  errorText = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.all(24),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: (status == 'success' ? Colors.green : Colors.indigo).withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (status == 'success' ? Colors.green : Colors.indigo).withOpacity(0.3),
                        ),
                      ),
                      child: Icon(
                        status == 'success' ? LucideIcons.checkCircle2 : LucideIcons.folderSync,
                        color: status == 'success' ? Colors.greenAccent : Colors.indigoAccent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      status == 'success'
                          ? '🎉 Migration Completed!'
                          : status == 'migrating'
                              ? 'Migrating to Drive Folder...'
                              : 'Safe Folder Migration',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status == 'success'
                          ? 'All your $total files have been safely connected to your new Drive folder.'
                          : 'A new Neo Files Transfer folder will be created in your Drive. Your existing links, public/private settings and files will stay 100% active!',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    if (status == 'migrating') ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigoAccent),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              currentFileName,
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$current / $total Files',
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],

                    if (status == 'idle') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Existing Files:', style: TextStyle(color: Colors.white60, fontSize: 11.5)),
                                Text('$total Files', style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            const Divider(color: Colors.white10, height: 16),
                            const Row(
                              children: [
                                Icon(LucideIcons.check, size: 13, color: Colors.greenAccent),
                                SizedBox(width: 6),
                                Text('Public & Private Links Safe', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Row(
                              children: [
                                Icon(LucideIcons.check, size: 13, color: Colors.greenAccent),
                                SizedBox(width: 6),
                                Text('Zero Data Loss Guaranteed', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (status == 'error') ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                        ),
                        child: Text(
                          errorText,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 11.5),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    if (status == 'idle')
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: startMigration,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Start Migration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),

                    if (status == 'success')
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Done & Continue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),

                    if (status == 'error')
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close', style: TextStyle(color: Colors.white60)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: startMigration,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo.shade600,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executeVerifyAndSave(String folderId, {required bool deleteExisting}) async {
    setState(() => _isSaving = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      // Step 1: Call verify endpoint via Edge Function
      final verified = await apiService.verifyDriveFolder(folderId);

      if (verified) {
        final userId = authService.currentUser?.id;
        if (userId == null) return;

        // Step 2: If changing folders, delete old records
        if (deleteExisting) {
          await _client.from('shared_files').delete().eq('user_id', userId);
        }

        // Step 3: Save to Supabase table
        await _client.from('user_profiles').update({
          'drive_folder_id': folderId,
          'is_folder_verified': true,
        }).eq('id', userId);

        await authService.loadProfile(authService.currentUser!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Drive folder verified and saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Folder validation returned false. Verify permissions.');
      }
    } catch (e) {
      String msg = e.toString();
      if (msg.startsWith('Exception: ')) {
        msg = msg.substring('Exception: '.length);
      }
      setState(() {
        _validationError = msg;
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSignOutDialog(AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'Are you sure you want to sign out of your session?',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close settings screen
              authService.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final profile = authService.profile;
    final updateService = Provider.of<UpdateService>(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Card
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.5),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
                        ? NetworkImage(profile.avatarUrl!)
                        : null,
                    backgroundColor: Colors.indigo.shade500,
                    child: profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty
                        ? const Icon(LucideIcons.user, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name ?? 'Developer',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile?.email ?? authService.currentUser?.email ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Drive configuration section
            const Text(
              'GOOGLE DRIVE INTEGRATION',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18.0),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.5),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Folder configuration input
                  Row(
                    children: [
                      Icon(
                        LucideIcons.folder,
                        color: profile?.isFolderVerified == true ? Colors.amber : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Drive Target Folder ID',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Verified badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (profile?.isFolderVerified == true ? Colors.green : Colors.red)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Text(
                          profile?.isFolderVerified == true ? 'Verified' : 'Unverified',
                          style: TextStyle(
                            color: profile?.isFolderVerified == true ? Colors.green.shade400 : Colors.red.shade400,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleAutoCreateFolder,
                    icon: const Icon(LucideIcons.sparkles, size: 16),
                    label: const Text(
                      '✨ Auto-Create & Connect Drive Folder',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      '— OR MANUALLY CONNECT VIA ID —',
                      style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _folderIdController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Paste Google Drive Folder ID here...',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12.5),
                      filled: true,
                      fillColor: const Color(0xFF080D1A).withOpacity(0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                    ),
                  ),
                  if (_validationError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(LucideIcons.alertTriangle, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _validationError!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleVerifyAndSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Verify & Save Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Token / Connection section
            const Text(
              'ACCOUNT & SESSION',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18.0),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.5),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.key, color: Colors.white70, size: 20),
                      const SizedBox(width: 12),
                      const Text(
                        'Google API Permissions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (authService.profile?.googleRefreshToken != null && !authService.hasGoogleConnectionError)
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (authService.profile?.googleRefreshToken != null && !authService.hasGoogleConnectionError)
                                ? Colors.green.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (authService.profile?.googleRefreshToken != null && !authService.hasGoogleConnectionError)
                                  ? LucideIcons.check
                                  : LucideIcons.alertTriangle,
                              color: (authService.profile?.googleRefreshToken != null && !authService.hasGoogleConnectionError)
                                  ? Colors.green
                                  : Colors.red,
                              size: 11,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (authService.profile?.googleRefreshToken != null && !authService.hasGoogleConnectionError)
                                  ? 'Connected'
                                  : (authService.hasGoogleConnectionError ? 'Action Required' : 'Disconnected'),
                              style: TextStyle(
                                color: (authService.profile?.googleRefreshToken != null && !authService.hasGoogleConnectionError)
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    authService.hasGoogleConnectionError
                        ? 'A Google Drive permission or connection error was detected. You may need to re-authorize the app and ensure the target Google Drive has storage space and edit access.'
                        : 'The application requires permissions to query your Google Drive to execute proxy transfers. Link your account to start transferring files.',
                    style: TextStyle(
                      color: authService.hasGoogleConnectionError ? Colors.redAccent.shade100 : Colors.white60,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  if (authService.profile?.googleRefreshToken == null || authService.hasGoogleConnectionError) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await authService.signInWithGoogle(forceConsent: true);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Re-authorization failed: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: authService.hasGoogleConnectionError
                            ? Colors.red.shade900.withOpacity(0.4)
                            : const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: authService.hasGoogleConnectionError
                                ? Colors.redAccent.withOpacity(0.3)
                                : Colors.transparent,
                          ),
                        ),
                      ),
                      icon: const Icon(LucideIcons.refreshCw, size: 14),
                      label: Text(
                        authService.hasGoogleConnectionError
                            ? 'Fix Connection / Re-authorize Google'
                            : 'Link / Re-authorize Google Drive',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // App Updates section
            const Text(
              'APP UPDATES',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.5),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: updateService.hasUpdate
                      ? Colors.indigoAccent.withOpacity(0.3)
                      : Colors.white.withOpacity(0.04),
                ),
              ),
              child: Column(
                children: [
                  // Navigate to Update Screen
                  InkWell(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UpdateScreen()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (updateService.hasUpdate ? Colors.indigoAccent : Colors.white10).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  LucideIcons.sparkles,
                                  color: updateService.hasUpdate ? Colors.indigoAccent : Colors.white70,
                                  size: 18,
                                ),
                              ),
                              if (updateService.hasUpdate)
                                Positioned(
                                  top: -3,
                                  right: -3,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Software Update',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (updateService.hasUpdate) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.circle, color: Colors.redAccent, size: 6),
                                            SizedBox(width: 4),
                                            Text(
                                              'UPDATE AVAILABLE',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Installed: ${updateService.currentVersion}${updateService.hasUpdate && updateService.latestVersion != null ? " • New: ${updateService.latestVersion}" : ""}',
                                  style: TextStyle(
                                    color: updateService.hasUpdate ? Colors.indigoAccent.shade100 : Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(LucideIcons.chevronRight, color: Colors.white38, size: 18),
                        ],
                      ),
                    ),
                  ),

                  Divider(height: 1, color: Colors.white.withOpacity(0.06)),

                  // Auto-check on Startup Toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white10.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.bellRing, color: Colors.white70, size: 18),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-check on App Open',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Check for updates when app launches',
                                style: TextStyle(color: Colors.white54, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: updateService.autoCheckEnabled,
                          activeColor: Colors.indigoAccent,
                          activeTrackColor: Colors.indigoAccent.withOpacity(0.4),
                          inactiveTrackColor: Colors.white10,
                          onChanged: (value) => updateService.setAutoCheck(value),
                        ),
                      ],
                    ),
                  ),

                  if (!updateService.notificationsAllowed) ...[
                    Divider(height: 1, color: Colors.white.withOpacity(0.06)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.bellOff, color: Colors.amber, size: 16),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Notifications are off. Allow to get update alerts.',
                                style: TextStyle(color: Colors.amber, fontSize: 11.5),
                              ),
                            ),
                            TextButton(
                              onPressed: () => updateService.requestNotificationPermission(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Allow', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  Divider(height: 1, color: Colors.white.withOpacity(0.06)),

                  // Manual Check Button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: updateService.isChecking
                          ? null
                          : () => updateService.checkForUpdates(context: context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                      ),
                      icon: updateService.isChecking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(LucideIcons.refreshCw, size: 14),
                      label: Text(
                        updateService.isChecking ? 'Checking Updates...' : 'Check for Updates Now',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Logout Button
            OutlinedButton.icon(
              onPressed: () => _showSignOutDialog(authService),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(LucideIcons.logOut, size: 16),
              label: const Text('Logout Session', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
