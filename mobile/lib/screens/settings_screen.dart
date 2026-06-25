import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _folderIdController = TextEditingController();
  final _client = Supabase.instance.client;
  bool _isSaving = false;

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
    final folderIdInput = _folderIdController.text.trim();
    if (folderIdInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Google Drive Folder ID or Link')),
      );
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to verify folder ID: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
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
                  const SizedBox(height: 16),
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
