import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import '../services/theme_service.dart';
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

  Future<void> _handleAutoCreateFolder() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.id;
    if (userId == null) return;
    final isLight = Theme.of(context).brightness == Brightness.light;

    if (authService.profile?.driveFolderId != null && authService.profile!.driveFolderId!.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isLight ? Colors.white : const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          title: Row(
            children: [
              const Icon(LucideIcons.sparkles, color: Colors.indigoAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Create New Folder?',
                  style: TextStyle(
                    color: isLight ? const Color(0xFF0F172A) : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'A fresh Neo Files Transfer folder will be created in your Google Drive and set as your primary upload destination.\n\n'
            '📌 Important Note:\n'
            '• Your existing files will remain in your previous folder and their download links will stay 100% active.\n'
            '• If you want all files in one place, you can manually move/shift them into the new folder in Google Drive.',
            style: TextStyle(
              color: isLight ? const Color(0xFF475569) : Colors.white70,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: isLight ? const Color(0xFF64748B) : Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeDirectFolderCreate();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Confirm & Create', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      await _executeDirectFolderCreate();
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

  void _showSignOutDialog(AuthService authService) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isLight ? Colors.white : const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout Session',
          style: TextStyle(
            color: isLight ? const Color(0xFF0F172A) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of your session?',
          style: TextStyle(
            color: isLight ? const Color(0xFF475569) : Colors.white70,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isLight ? const Color(0xFF64748B) : Colors.white60)),
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
    final isLight = Theme.of(context).brightness == Brightness.light;

    final bgColor = isLight ? const Color(0xFFF8FAFC) : const Color(0xFF030712);
    final cardBg = isLight ? Colors.white : const Color(0xFF0F172A).withOpacity(0.5);
    final cardBorder = isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.04);
    final titleTextColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subtitleTextColor = isLight ? const Color(0xFF64748B) : Colors.grey.shade400;
    final sectionHeaderColor = isLight ? const Color(0xFF475569) : Colors.white70;
    final cardShadow = isLight
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ]
        : null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: isLight ? Colors.white : Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: titleTextColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Settings',
            style: TextStyle(color: titleTextColor, fontWeight: FontWeight.bold),
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
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: cardBorder),
                  boxShadow: cardShadow,
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
                            style: TextStyle(
                              color: titleTextColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile?.email ?? authService.currentUser?.email ?? '',
                            style: TextStyle(
                              color: subtitleTextColor,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // App Appearance / Theme section
              Text(
                'APP APPEARANCE / THEME',
                style: TextStyle(
                  color: sectionHeaderColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Consumer<ThemeService>(
                builder: (context, themeService, _) {
                  return Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.white : const Color(0xFF0F172A).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.06),
                      ),
                      boxShadow: cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              themeService.themeMode == ThemeMode.light
                                  ? LucideIcons.sun
                                  : themeService.themeMode == ThemeMode.dark
                                      ? LucideIcons.moon
                                      : LucideIcons.smartphone,
                              color: Colors.indigoAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Choose Theme',
                                    style: TextStyle(
                                      color: titleTextColor,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    themeService.themeMode == ThemeMode.light
                                        ? 'Soft White Theme Active'
                                        : themeService.themeMode == ThemeMode.dark
                                            ? 'Midnight Dark Theme Active'
                                            : 'System Theme Active',
                                    style: TextStyle(
                                      color: subtitleTextColor,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 3-Option Segmented Selector
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF070B14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isLight ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Dark Mode Button
                              Expanded(
                                child: _ThemeOptionButton(
                                  label: 'Dark',
                                  icon: LucideIcons.moon,
                                  isSelected: themeService.themeMode == ThemeMode.dark,
                                  isLightApp: isLight,
                                  onTap: () => themeService.setThemeMode(ThemeMode.dark),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Light Mode Button
                              Expanded(
                                child: _ThemeOptionButton(
                                  label: 'Light',
                                  icon: LucideIcons.sun,
                                  isSelected: themeService.themeMode == ThemeMode.light,
                                  isLightApp: isLight,
                                  onTap: () => themeService.setThemeMode(ThemeMode.light),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // System Mode Button
                              Expanded(
                                child: _ThemeOptionButton(
                                  label: 'System',
                                  icon: LucideIcons.smartphone,
                                  isSelected: themeService.themeMode == ThemeMode.system,
                                  isLightApp: isLight,
                                  onTap: () => themeService.setThemeMode(ThemeMode.system),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),

              // Drive configuration section
              Text(
                'GOOGLE DRIVE INTEGRATION',
                style: TextStyle(
                  color: sectionHeaderColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: cardBorder),
                  boxShadow: cardShadow,
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
                        Text(
                          'Drive Target Folder ID',
                          style: TextStyle(
                            color: titleTextColor,
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
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleAutoCreateFolder,
                      icon: const Icon(LucideIcons.sparkles, size: 16),
                      label: Text(
                        authService.profile?.driveFolderId != null && authService.profile!.driveFolderId!.isNotEmpty
                            ? '✨ Re-create & Connect Drive Folder'
                            : '✨ Auto-Create & Connect Drive Folder',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                    if (authService.profile?.driveFolderId != null && authService.profile!.driveFolderId!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(isLight ? 0.06 : 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.indigo.withOpacity(isLight ? 0.18 : 0.2)),
                        ),
                        child: Text(
                          'Note: Existing files will remain in your previous folder and keep working. You can optionally move them manually in Google Drive if you wish.',
                          style: TextStyle(
                            color: isLight ? Colors.indigo.shade800 : Colors.indigoAccent,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
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
                                style: TextStyle(
                                  color: isLight ? Colors.red.shade900 : Colors.white70,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Token / Connection section
              Text(
                'ACCOUNT & SESSION',
                style: TextStyle(
                  color: sectionHeaderColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: cardBorder),
                  boxShadow: cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.key, color: sectionHeaderColor, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Google API Permissions',
                          style: TextStyle(
                            color: titleTextColor,
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
                        color: authService.hasGoogleConnectionError
                            ? (isLight ? Colors.red.shade800 : Colors.redAccent.shade100)
                            : subtitleTextColor,
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
                              ? (isLight ? Colors.red.shade100 : Colors.red.shade900.withOpacity(0.4))
                              : (isLight ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)),
                          foregroundColor: authService.hasGoogleConnectionError
                              ? (isLight ? Colors.red.shade900 : Colors.white)
                              : (isLight ? const Color(0xFF0F172A) : Colors.white),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: authService.hasGoogleConnectionError
                                  ? Colors.redAccent.withOpacity(0.3)
                                  : (isLight ? const Color(0xFFE2E8F0) : Colors.transparent),
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
              Text(
                'APP UPDATES',
                style: TextStyle(
                  color: sectionHeaderColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: updateService.hasUpdate
                        ? Colors.indigoAccent.withOpacity(0.3)
                        : cardBorder,
                  ),
                  boxShadow: cardShadow,
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
                                    color: (updateService.hasUpdate
                                            ? Colors.indigoAccent
                                            : (isLight ? const Color(0xFFF1F5F9) : Colors.white10))
                                        .withOpacity(isLight ? 0.9 : 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    LucideIcons.sparkles,
                                    color: updateService.hasUpdate
                                        ? Colors.indigoAccent
                                        : (isLight ? const Color(0xFF64748B) : Colors.white70),
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
                                        border: Border.all(color: isLight ? Colors.white : const Color(0xFF0F172A), width: 1.5),
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
                                      Text(
                                        'Software Update',
                                        style: TextStyle(
                                          color: titleTextColor,
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
                                      color: updateService.hasUpdate
                                          ? (isLight ? const Color(0xFF4F46E5) : Colors.indigoAccent.shade100)
                                          : subtitleTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(LucideIcons.chevronRight, color: isLight ? const Color(0xFF94A3B8) : Colors.white38, size: 18),
                          ],
                        ),
                      ),
                    ),

                    Divider(height: 1, color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.06)),

                    // Auto-check on Startup Toggle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isLight ? const Color(0xFFF1F5F9) : Colors.white10.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(LucideIcons.bellRing, color: isLight ? const Color(0xFF64748B) : Colors.white70, size: 18),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Auto-check on App Open',
                                  style: TextStyle(
                                    color: titleTextColor,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Check for updates when app launches',
                                  style: TextStyle(color: subtitleTextColor, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: updateService.autoCheckEnabled,
                            activeColor: Colors.indigoAccent,
                            activeTrackColor: Colors.indigoAccent.withOpacity(0.4),
                            inactiveTrackColor: isLight ? const Color(0xFFE2E8F0) : Colors.white10,
                            onChanged: (value) => updateService.setAutoCheck(value),
                          ),
                        ],
                      ),
                    ),

                    if (!updateService.notificationsAllowed) ...[
                      Divider(height: 1, color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.06)),
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

                    Divider(height: 1, color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.06)),

                    // Manual Check Button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        onPressed: updateService.isChecking
                            ? null
                            : () => updateService.checkForUpdates(context: context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                          foregroundColor: isLight ? const Color(0xFF0F172A) : Colors.white,
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.08)),
                          ),
                        ),
                        icon: updateService.isChecking
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isLight ? const Color(0xFF0F172A) : Colors.white,
                                ),
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
                  side: BorderSide(color: Colors.redAccent.withOpacity(isLight ? 0.4 : 0.3)),
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
  }  ),
  );
  }
}

class _ThemeOptionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isLightApp;
  final VoidCallback onTap;

  const _ThemeOptionButton({
    Key? key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isLightApp,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color activeBg;
    Color activeText;
    Color inactiveText;

    if (isLightApp) {
      activeBg = Colors.white;
      activeText = const Color(0xFF4F46E5);
      inactiveText = Colors.grey.shade600;
    } else {
      activeBg = const Color(0xFF1E293B);
      activeText = Colors.white;
      inactiveText = Colors.grey.shade400;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? activeText : inactiveText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeText : inactiveText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
