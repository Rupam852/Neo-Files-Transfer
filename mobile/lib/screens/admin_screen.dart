import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _registrations = [];
  List<Map<String, dynamic>> _approvedUsers = [];
  List<Map<String, dynamic>> _logs = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Load pending registrations
      final regRes = await _client
          .from('pending_registrations')
          .select()
          .eq('status', 'pending')
          .order('submitted_at', ascending: false);

      // 2. Load approved users
      final userRes = await _client
          .from('approved_users')
          .select()
          .order('approved_at', ascending: false);

      // 3. Load activity logs
      final logRes = await _client
          .from('activity_logs')
          .select('*, user_profiles(name, email)')
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _registrations = List<Map<String, dynamic>>.from(regRes as List);
        _approvedUsers = List<Map<String, dynamic>>.from(userRes as List);
        _logs = List<Map<String, dynamic>>.from(logRes as List);
      });
    } catch (e) {
      debugPrint('Failed to load admin data: $e');
    } finally {
      setState(() => _isLoading = false);
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
      _loadAdminData();
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
      _loadAdminData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _toggleUserPause(Map<String, dynamic> user) async {
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
      _loadAdminData();
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

      await _client.from('admin_activity_logs').insert({
        'admin_id': _client.auth.currentUser?.id,
        'action': 'revoke_user',
        'details': 'Revoked user console access: $email',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Revoked access for user: $email'), backgroundColor: Colors.redAccent),
      );
      _loadAdminData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to revoke user: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.indigoAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Requests'),
            Tab(text: 'Approved'),
            Tab(text: 'Audit Logs'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            onPressed: _loadAdminData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsTab(),
                _buildApprovedTab(),
                _buildLogsTab(),
              ],
            ),
    );
  }

  Widget _buildRequestsTab() {
    if (_registrations.isEmpty) {
      return _buildEmptyState('No pending registrations found.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20.0),
      itemCount: _registrations.length,
      itemBuilder: (context, index) {
        final reg = _registrations[index];
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
    if (_approvedUsers.isEmpty) {
      return _buildEmptyState('No approved users yet.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20.0),
      itemCount: _approvedUsers.length,
      itemBuilder: (context, index) {
        final user = _approvedUsers[index];
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
                itemBuilder: (context) => [
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
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogsTab() {
    if (_logs.isEmpty) {
      return _buildEmptyState('No logs found.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20.0),
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
            color: const Color(0xFF0F172A).withOpacity(0.3),
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
    );
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(color: Colors.white38, fontSize: 13.5),
      ),
    );
  }
}
