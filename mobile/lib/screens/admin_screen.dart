import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newAdminEmailController = TextEditingController();

  List<Map<String, dynamic>> _registrations = [];
  List<Map<String, dynamic>> _approvedUsers = [];
  List<Map<String, dynamic>> _admins = [];
  Map<String, bool> _settings = {};
  List<Map<String, dynamic>> _logs = [];

  Map<String, dynamic>? _currentAdminRecord;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isAddingAdmin = false;
  bool _isDeletingLogs = false;

  // Realtime channels
  RealtimeChannel? _pendingChannel;
  RealtimeChannel? _approvedChannel;
  RealtimeChannel? _settingsChannel;
  RealtimeChannel? _adminsChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadAdminData();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _newAdminEmailController.dispose();
    _clearRealtimeListeners();
    super.dispose();
  }

  void _setupRealtimeListeners() {
    _pendingChannel = _client
        .channel('admin-pending-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pending_registrations',
          callback: (payload) => _loadAdminData(showSpinner: false),
        );
    _pendingChannel?.subscribe();

    _approvedChannel = _client
        .channel('admin-approved-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'approved_users',
          callback: (payload) => _loadAdminData(showSpinner: false),
        );
    _approvedChannel?.subscribe();

    _settingsChannel = _client
        .channel('admin-settings-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'system_settings',
          callback: (payload) => _loadSettingsData(),
        );
    _settingsChannel?.subscribe();

    _adminsChannel = _client
        .channel('admin-admins-list-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'admins',
          callback: (payload) => _loadAdminData(showSpinner: false),
        );
    _adminsChannel?.subscribe();
  }

  void _clearRealtimeListeners() {
    if (_pendingChannel != null) _client.removeChannel(_pendingChannel!);
    if (_approvedChannel != null) _client.removeChannel(_approvedChannel!);
    if (_settingsChannel != null) _client.removeChannel(_settingsChannel!);
    if (_adminsChannel != null) _client.removeChannel(_adminsChannel!);
  }

  Future<void> _loadAdminData({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() => _isLoading = true);
    }
    try {
      // 1. Fetch current admin role
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId != null) {
        final adminRes = await _client
            .from('admins')
            .select()
            .eq('user_id', currentUserId)
            .maybeSingle();
        _currentAdminRecord = adminRes;
      }

      // 2. Fetch admins list
      final adminsRes = await _client
          .from('admins')
          .select()
          .order('created_at', ascending: false);
      final List<Map<String, dynamic>> adminsList = List<Map<String, dynamic>>.from(adminsRes as List);
      final Set<String> adminEmails = Set<String>.from(adminsList.map((a) => (a['email'] as String).toLowerCase()));

      // Fetch user profiles for admins to get avatar_url
      final adminUserIds = adminsList.map((a) => a['user_id'] as String).toSet().toList();
      Map<String, String> adminAvatarsMap = {};
      if (adminUserIds.isNotEmpty) {
        final profilesRes = await _client
            .from('user_profiles')
            .select('id, avatar_url')
            .inFilter('id', adminUserIds);
        for (final p in (profilesRes as List)) {
          adminAvatarsMap[p['id'] as String] = (p['avatar_url'] ?? '') as String;
        }
      }

      // Merge avatar_url into admins list
      final List<Map<String, dynamic>> mergedAdminsList = adminsList.map((a) {
        final userId = a['user_id'] as String;
        return {
          ...a,
          'avatar_url': adminAvatarsMap[userId] ?? '',
        };
      }).toList();

      // 3. Fetch pending registrations (filtering out admins)
      final regRes = await _client
          .from('pending_registrations')
          .select()
          .eq('status', 'pending')
          .order('submitted_at', ascending: false);
      final List<Map<String, dynamic>> pendingList = List<Map<String, dynamic>>.from(regRes as List);
      final filteredPending = pendingList.where((u) => !adminEmails.contains((u['email'] as String).toLowerCase())).toList();

      // 4. Fetch approved users (filtering out admins)
      final userRes = await _client
          .from('approved_users')
          .select()
          .order('approved_at', ascending: false);
      final List<Map<String, dynamic>> approvedList = List<Map<String, dynamic>>.from(userRes as List);
      final filteredApproved = approvedList.where((u) => !adminEmails.contains((u['email'] as String).toLowerCase())).toList();

      // 5. Fetch system settings
      final settingsRes = await _client.from('system_settings').select();
      final Map<String, bool> settingsMap = {};
      for (final s in settingsRes) {
        settingsMap[s['key'] as String] = s['value'] == true;
      }

      // 6. Fetch activity logs
      final logRes = await _client
          .from('activity_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      final List<Map<String, dynamic>> logsList = List<Map<String, dynamic>>.from(logRes as List);

      // Fetch user profiles for these logs
      final userIds = logsList.map((log) => log['user_id'] as String).toSet().toList();
      Map<String, Map<String, dynamic>> profilesMap = {};
      if (userIds.isNotEmpty) {
        final profilesRes = await _client
            .from('user_profiles')
            .select('id, name, email')
            .inFilter('id', userIds);
        for (final p in (profilesRes as List)) {
          profilesMap[p['id'] as String] = p as Map<String, dynamic>;
        }
      }

      // Merge profiles into logs
      final mergedLogs = logsList.map((log) {
        final userId = log['user_id'] as String;
        final profile = profilesMap[userId];
        return {
          ...log,
          'user_profiles': profile,
        };
      }).toList();

      setState(() {
        _registrations = filteredPending;
        _approvedUsers = filteredApproved;
        _admins = mergedAdminsList;
        _settings = settingsMap;
        _logs = mergedLogs;
      });
    } catch (e) {
      debugPrint('Failed to load admin data: $e');
    } finally {
      if (showSpinner) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSettingsData() async {
    try {
      final settingsRes = await _client.from('system_settings').select();
      final Map<String, bool> settingsMap = {};
      for (final s in settingsRes) {
        settingsMap[s['key'] as String] = s['value'] == true;
      }
      if (mounted) {
        setState(() {
          _settings = settingsMap;
        });
      }
    } catch (e) {
      debugPrint('Failed to load system settings: $e');
    }
  }

  Future<void> _approveRegistration(Map<String, dynamic> reg) async {
    final regId = reg['id'];
    final email = reg['email'] as String;

    try {
      // 1. Add to approved_users
      await _client.from('approved_users').insert({
        'email': email.toLowerCase(),
        'approved_by': _client.auth.currentUser?.id,
      });

      // 2. Update registration status
      await _client
          .from('pending_registrations')
          .update({'status': 'approved'})
          .eq('id', regId);

      // 3. Log action
      await _client.from('admin_activity_logs').insert({
        'admin_id': _client.auth.currentUser?.id,
        'action': 'approve_user',
        'details': 'Approved user registration: $email',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approved user: $email'), backgroundColor: const Color(0xFF10B981)),
      );
      _loadAdminData(showSpinner: false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _rejectRegistration(Map<String, dynamic> reg) async {
    final regId = reg['id'];
    final email = reg['email'];

    try {
      await _client
          .from('pending_registrations')
          .update({'status': 'rejected'})
          .eq('id', regId);

      await _client.from('admin_activity_logs').insert({
        'admin_id': _client.auth.currentUser?.id,
        'action': 'reject_user',
        'details': 'Rejected user registration: $email',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rejected user request: $email')),
      );
      _loadAdminData(showSpinner: false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _toggleUserPause(Map<String, dynamic> user) async {
    if (_currentAdminRecord?['role'] != 'super_admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the Super Administrator can pause/resume users.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final userId = user['id'];
    final email = user['email'];
    final isPaused = user['is_paused'] == true;

    try {
      await _client
          .from('approved_users')
          .update({'is_paused': !isPaused})
          .eq('id', userId);

      await _client.from('admin_activity_logs').insert({
        'admin_id': _client.auth.currentUser?.id,
        'action': isPaused ? 'resume_user' : 'pause_user',
        'details': '${isPaused ? "Resumed" : "Paused"} access for user: $email',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${isPaused ? "Resumed" : "Paused"} user: $email'),
          backgroundColor: isPaused ? const Color(0xFF10B981) : Colors.amber,
        ),
      );
      _loadAdminData(showSpinner: false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _revokeUser(Map<String, dynamic> user) async {
    final userId = user['id'];
    final email = user['email'];

    try {
      await _client.from('approved_users').delete().eq('id', userId);

      // Also clean up pending_registrations for this email
      await _client.from('pending_registrations').delete().eq('email', email);

      await _client.from('admin_activity_logs').insert({
        'admin_id': _client.auth.currentUser?.id,
        'action': 'revoke_user',
        'details': 'Revoked user console access: $email',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Revoked access for user: $email'), backgroundColor: Colors.redAccent),
      );
      _loadAdminData(showSpinner: false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to revoke user: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _toggleSetting(String key, bool currentVal) async {
    final newVal = !currentVal;
    
    // Update local state immediately for responsiveness
    setState(() {
      _settings[key] = newVal;
    });

    try {
      await _client
          .from('system_settings')
          .upsert({'key': key, 'value': newVal}, onConflict: 'key');

      await _client.from('admin_activity_logs').insert({
        'admin_id': _client.auth.currentUser?.id,
        'action': newVal ? '${key}_enabled' : '${key}_disabled',
        'details': 'Toggled $key: $newVal',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${key.replaceAll("_", " ").toUpperCase()} ${newVal ? "enabled" : "disabled"}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
      await _loadSettingsData();
    } catch (e) {
      // Revert on failure
      setState(() {
        _settings[key] = currentVal;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update setting: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _addAdmin(String email) async {
    final targetEmail = email.trim().toLowerCase();
    if (targetEmail.isEmpty) return;

    setState(() => _isAddingAdmin = true);
    try {
      if (_currentAdminRecord?['role'] != 'super_admin') {
        throw Exception('Only the Super Administrator can add other administrators.');
      }

      final userRes = await _client
          .from('user_profiles')
          .select('id, email')
          .eq('email', targetEmail)
          .maybeSingle();

      if (userRes == null) {
        throw Exception('User must sign up and log in once before being promoted to admin.');
      }

      final isAlreadyAdmin = _admins.any((a) => (a['email'] as String).toLowerCase() == targetEmail);
      if (isAlreadyAdmin) {
        throw Exception('This user is already an administrator.');
      }

      await _client.from('admins').insert({
        'user_id': userRes['id'],
        'email': targetEmail,
        'role': 'admin',
      });

      await _client.from('admin_activity_logs').insert({
        'admin_id': _client.auth.currentUser?.id,
        'action': 'admin_added',
        'details': 'Promoted user $targetEmail to admin',
      });

      _newAdminEmailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$targetEmail promoted to Admin successfully!'), backgroundColor: const Color(0xFF10B981)),
      );
      _loadAdminData(showSpinner: false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isAddingAdmin = false);
    }
  }

  Future<void> _deleteAdmin(Map<String, dynamic> admin) async {
    final adminEmail = admin['email'] as String;
    if (_currentAdminRecord?['role'] != 'super_admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the Super Administrator can remove administrators.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (adminEmail.toLowerCase() == _client.auth.currentUser?.email?.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot remove yourself as an administrator.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Remove Administrator', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to remove administrator access for $adminEmail?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _client.from('admins').delete().eq('id', admin['id']);

      await _client.from('admin_activity_logs').insert({
        'admin_id': _client.auth.currentUser?.id,
        'action': 'admin_removed',
        'details': 'Removed admin: $adminEmail',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed admin access for $adminEmail'), backgroundColor: const Color(0xFF10B981)),
      );
      _loadAdminData(showSpinner: false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove admin: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.signOut();
      }
    }
  }

  Widget? _buildDrawer() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final profile = auth.profile;
    final currentUser = _client.auth.currentUser;
    final email = currentUser?.email ?? '';
    final role = _currentAdminRecord?['role'] ?? 'admin';
    final isSuperAdmin = role == 'super_admin';

    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 16,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.indigoAccent.withOpacity(0.1),
                    backgroundImage: profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
                        ? NetworkImage(profile.avatarUrl!)
                        : null,
                    child: profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty
                        ? const Icon(LucideIcons.shield, color: Colors.indigoAccent, size: 24)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSuperAdmin
                                ? Colors.purple.withOpacity(0.1)
                                : Colors.indigoAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                          child: Text(
                            isSuperAdmin ? 'SUPER ADMIN' : 'ADMIN',
                            style: TextStyle(
                              color: isSuperAdmin ? Colors.purpleAccent : Colors.indigoAccent.shade100,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(LucideIcons.settings, color: Colors.indigoAccent),
              title: const Text('System Settings', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Configure maintenance mode & sharing features', style: TextStyle(color: Colors.white30, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _showSettingsBottomSheet();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.activity, color: Colors.tealAccent),
              title: const Text('Audit Logs', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('View and clear administration activity history', style: TextStyle(color: Colors.white30, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _showLogsBottomSheet();
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Colors.redAccent.withOpacity(0.08),
                leading: const Icon(LucideIcons.logOut, color: Colors.redAccent),
                title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutDialog(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            final maintenanceMode = _settings['maintenance_mode'] == true;
            final downloadsEnabled = _settings['downloads_enabled'] != false;
            final sharingEnabled = _settings['sharing_enabled'] != false;

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'System Controls',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF030712).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Column(
                      children: [
                        _buildSettingToggle(
                          label: 'Maintenance Mode',
                          description: 'Show a maintenance notification screen to all users.',
                          checked: maintenanceMode,
                          onChange: () async {
                            await _toggleSetting('maintenance_mode', maintenanceMode);
                            setBottomSheetState(() {});
                          },
                        ),
                        const Divider(color: Colors.white10),
                        _buildSettingToggle(
                          label: 'Downloads Enabled',
                          description: 'Allow clients to download files through shared URLs.',
                          checked: downloadsEnabled,
                          onChange: () async {
                            await _toggleSetting('downloads_enabled', downloadsEnabled);
                            setBottomSheetState(() {});
                          },
                        ),
                        const Divider(color: Colors.white10),
                        _buildSettingToggle(
                          label: 'Sharing Enabled',
                          description: 'Allow normal users to generate public sharing links.',
                          checked: sharingEnabled,
                          onChange: () async {
                            await _toggleSetting('sharing_enabled', sharingEnabled);
                            setBottomSheetState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLogsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Audit Logs',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              if (_logs.isNotEmpty && !_isDeletingLogs)
                                TextButton.icon(
                                  onPressed: () async {
                                    await _showClearLogsConfirmDialog(setBottomSheetState);
                                  },
                                  icon: const Icon(LucideIcons.trash2, size: 14, color: Colors.redAccent),
                                  label: const Text(
                                    'Clear',
                                    style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(LucideIcons.x, color: Colors.white60),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    Expanded(
                      child: _isDeletingLogs
                          ? const Center(
                              child: CircularProgressIndicator(color: Colors.indigoAccent),
                            )
                          : RefreshIndicator(
                              onRefresh: () async {
                                await _loadAdminData(showSpinner: false);
                                setBottomSheetState(() {});
                              },
                              color: Colors.indigoAccent,
                              backgroundColor: const Color(0xFF0F172A),
                              child: _logs.isEmpty
                                  ? _buildEmptyState('No logs found.', scrollController)
                                  : ListView.builder(
                                      controller: scrollController,
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                                      itemCount: _logs.length,
                                      itemBuilder: (context, index) {
                                        final log = _logs[index];
                                        final profile = log['user_profiles'];
                                        final action = log['action'];
                                        final details = log['details'] ?? '';
                                        final date = DateFormat('MMM dd, hh:mm a').format(DateTime.parse(log['created_at']));

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12.0),
                                          padding: const EdgeInsets.all(12.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF030712).withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(12.0),
                                            border: Border.all(color: Colors.white.withOpacity(0.02)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    action.toString().toUpperCase(),
                                                    style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 10.5),
                                                  ),
                                                  Text(date, style: const TextStyle(color: Colors.white30, fontSize: 10)),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                details,
                                                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'By: ${profile?['name'] ?? profile?['email'] ?? 'System'}',
                                                style: const TextStyle(color: Colors.white30, fontSize: 10.5),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          SystemNavigator.pop();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF030712),
          drawer: _buildDrawer(),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Admin Dashboard',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.indigoAccent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              isScrollable: true,
              tabs: [
                Tab(text: 'Requests (${_registrations.length})'),
                Tab(text: 'Approved (${_approvedUsers.length})'),
                Tab(text: 'Admins (${_admins.length})'),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: TextFormField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.search, color: Colors.white38, size: 16),
                          hintText: 'Search by name or email...',
                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12.5),
                          filled: true,
                          fillColor: const Color(0xFF0F172A).withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.04)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.04)),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          RefreshIndicator(
                            onRefresh: () => _loadAdminData(showSpinner: false),
                            color: Colors.indigoAccent,
                            backgroundColor: const Color(0xFF0F172A),
                            child: _buildRequestsTab(),
                          ),
                          RefreshIndicator(
                            onRefresh: () => _loadAdminData(showSpinner: false),
                            color: Colors.indigoAccent,
                            backgroundColor: const Color(0xFF0F172A),
                            child: _buildApprovedTab(),
                          ),
                          RefreshIndicator(
                            onRefresh: () => _loadAdminData(showSpinner: false),
                            color: Colors.indigoAccent,
                            backgroundColor: const Color(0xFF0F172A),
                            child: _buildAdminsTab(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    final filtered = _registrations.where((r) {
      final query = _searchQuery.toLowerCase();
      final name = (r['name'] ?? '').toString().toLowerCase();
      final email = (r['email'] ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState('No pending registrations found.');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final reg = filtered[index];
        final formattedDate = DateFormat('MMM dd, hh:mm a').format(DateTime.parse(reg['submitted_at']));

        return Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.5),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    reg['name'] ?? 'No Name',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Email: ${reg['email']}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Phone: ${reg['phone']}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _rejectRegistration(reg),
                    child: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _approveRegistration(reg),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Approve'),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildApprovedTab() {
    final filtered = _approvedUsers.where((u) {
      final query = _searchQuery.toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return email.contains(query);
    }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState('No approved users yet.');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final user = filtered[index];
        final isPaused = user['is_paused'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.5),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['email'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPaused ? 'Status: Suspended' : 'Status: Active',
                      style: TextStyle(
                        color: isPaused ? Colors.redAccent.shade200 : const Color(0xFF34D399),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'pause') _toggleUserPause(user);
                  if (val == 'revoke') _revokeUser(user);
                },
                icon: const Icon(LucideIcons.moreVertical, color: Colors.white54, size: 20),
                itemBuilder: (context) {
                  final isSuperAdmin = _currentAdminRecord?['role'] == 'super_admin';
                  return [
                    if (isSuperAdmin) ...[
                      PopupMenuItem(
                        value: 'pause',
                        child: Row(
                          children: [
                            Icon(isPaused ? LucideIcons.checkCircle : LucideIcons.pause, color: Colors.white70, size: 16),
                            const SizedBox(width: 10),
                            Text(isPaused ? 'Resume' : 'Pause', style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                    ],
                    const PopupMenuItem(
                      value: 'revoke',
                      child: Row(
                        children: [
                          Icon(LucideIcons.trash2, color: Colors.redAccent, size: 16),
                          SizedBox(width: 10),
                          Text('Revoke', style: TextStyle(color: Colors.redAccent, fontSize: 13.5)),
                        ],
                      ),
                    ),
                  ];
                },
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdminsTab() {
    final isSuperAdmin = _currentAdminRecord?['role'] == 'super_admin';

    final filtered = _admins.where((a) {
      final query = _searchQuery.toLowerCase();
      final email = (a['email'] ?? '').toString().toLowerCase();
      return email.contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSuperAdmin) ...[
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.5),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PROMOTE USER TO ADMIN',
                    style: TextStyle(color: Colors.indigoAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _newAdminEmailController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Enter email address...',
                            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12.5),
                            filled: true,
                            fillColor: const Color(0xFF080D1A).withOpacity(0.8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _isAddingAdmin
                            ? null
                            : () => _addAdmin(_newAdminEmailController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        ),
                        child: _isAddingAdmin
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The user must have logged into the app at least once before they can be promoted.',
                    style: TextStyle(color: Colors.white30, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12.0),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: Colors.amber.withOpacity(0.1)),
              ),
              child: Row(
                children: const [
                  Icon(LucideIcons.shieldAlert, color: Colors.amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only the Super Administrator can add or remove other administrators.',
                      style: TextStyle(color: Colors.amber, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          const Text(
            'ADMINISTRATORS LIST',
            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final admin = filtered[index];
              final email = admin['email'] as String;
              final role = admin['role'] ?? 'admin';
              final isSelf = email.toLowerCase() == _client.auth.currentUser?.email?.toLowerCase();
              final avatarUrl = admin['avatar_url'] as String?;
              final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
              final String initials = email.isNotEmpty ? email[0].toUpperCase() : 'A';

              return Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.indigoAccent.withOpacity(0.1),
                      backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                      child: !hasAvatar
                          ? Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.indigoAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: role == 'super_admin'
                                  ? Colors.purple.withOpacity(0.1)
                                  : Colors.indigoAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              role == 'super_admin' ? 'Super Admin' : 'Admin',
                              style: TextStyle(
                                color: role == 'super_admin' ? Colors.purpleAccent : Colors.indigoAccent.shade100,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSuperAdmin && !isSelf && role != 'super_admin') ...[
                      IconButton(
                        icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 18),
                        onPressed: () => _deleteAdmin(admin),
                        tooltip: 'Revoke Admin privileges',
                      ),
                    ]
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingToggle({
    required String label,
    required String description,
    required bool checked,
    required VoidCallback onChange,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white38, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: checked,
            onChanged: (val) => onChange(),
            activeColor: Colors.indigoAccent,
            activeTrackColor: Colors.indigoAccent.withOpacity(0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.white10,
          ),
        ],
      ),
    );
  }

  Future<void> _showClearLogsConfirmDialog(StateSetter setBottomSheetState) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Audit Logs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'Are you sure you want to clear all activity and audit logs? This action is permanent and cannot be undone.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() {
          _isDeletingLogs = true;
        });
        setBottomSheetState(() {}); // Show loader in bottom sheet!
        
        await _client.from('activity_logs').delete().neq('action', 'non_existent_action_placeholder');
        
        await _client.from('admin_activity_logs').insert({
          'admin_id': _client.auth.currentUser?.id,
          'action': 'logs_cleared',
          'details': 'Cleared all activity/audit logs',
        });

        await _loadAdminData(showSpinner: false);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audit logs cleared successfully.'), backgroundColor: Color(0xFF10B981)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear logs: $e'), backgroundColor: Colors.redAccent),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isDeletingLogs = false;
          });
          setBottomSheetState(() {}); // Hide loader in bottom sheet!
        }
      }
    }
  }

  Widget _buildEmptyState(String text, [ScrollController? controller]) {
    return Center(
      child: SingleChildScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: 300,
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(color: Colors.white38, fontSize: 13.5),
          ),
        ),
      ),
    );
  }
}
