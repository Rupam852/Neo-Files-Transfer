import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/in_app_notification.dart';
import 'auth_service.dart';

class NotificationService extends ChangeNotifier {
  static const String _keyDownloadAlerts = 'neo_notif_download_alerts';
  static const String _keyUploadAlerts = 'neo_notif_upload_alerts';
  static const String _keySecurityAlerts = 'neo_notif_security_alerts';
  static const String _keyUpdateAlerts = 'neo_notif_update_alerts';

  final SupabaseClient _client = Supabase.instance.client;
  AuthService? _authService;

  List<InAppNotification> _notifications = [];
  bool _isLoading = false;
  RealtimeChannel? _notificationChannel;
  Timer? _pollingTimer;

  bool _downloadAlertsEnabled = true;
  bool _uploadAlertsEnabled = true;
  bool _securityAlertsEnabled = true;
  bool _updateAlertsEnabled = true;

  // Callback to display real-time in-app notification toasts/snackbars
  void Function(InAppNotification notification)? onNewNotification;

  NotificationService([AuthService? authService]) {
    _loadNotificationPreferences();
    if (authService != null) {
      update(authService);
    }
  }

  List<InAppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool get downloadAlertsEnabled => _downloadAlertsEnabled;
  bool get uploadAlertsEnabled => _uploadAlertsEnabled;
  bool get securityAlertsEnabled => _securityAlertsEnabled;
  bool get updateAlertsEnabled => _updateAlertsEnabled;

  Future<void> _loadNotificationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _downloadAlertsEnabled = prefs.getBool(_keyDownloadAlerts) ?? true;
      _uploadAlertsEnabled = prefs.getBool(_keyUploadAlerts) ?? true;
      _securityAlertsEnabled = prefs.getBool(_keySecurityAlerts) ?? true;
      _updateAlertsEnabled = prefs.getBool(_keyUpdateAlerts) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('[NotificationService] Error loading preferences: $e');
    }
  }

  Future<void> setDownloadAlerts(bool enabled) async {
    _downloadAlertsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDownloadAlerts, enabled);
    notifyListeners();
  }

  Future<void> setUploadAlerts(bool enabled) async {
    _uploadAlertsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUploadAlerts, enabled);
    notifyListeners();
  }

  Future<void> setSecurityAlerts(bool enabled) async {
    _securityAlertsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySecurityAlerts, enabled);
    notifyListeners();
  }

  Future<void> setUpdateAlerts(bool enabled) async {
    _updateAlertsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUpdateAlerts, enabled);
    notifyListeners();
  }

  void update(AuthService authService) {
    final previousUserId = _authService?.currentUser?.id;
    _authService = authService;
    final currentUserId = authService.currentUser?.id;

    if (currentUserId != previousUserId) {
      if (currentUserId != null) {
        loadNotifications();
        _setupRealtimeSubscription(currentUserId);
        _startPolling();
      } else {
        _cleanup();
      }
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      loadNotifications(isBackground: true);
    });
  }

  void _cleanup() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    if (_notificationChannel != null) {
      _client.removeChannel(_notificationChannel!);
      _notificationChannel = null;
    }
    _notifications = [];
    notifyListeners();
  }

  Future<void> loadNotifications({bool isBackground = false}) async {
    final user = _authService?.currentUser;
    if (user == null) return;

    if (!isBackground) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final res = await _client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      _notifications = (res as List)
          .map((item) => InAppNotification.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (!isBackground) {
        debugPrint('[NotificationService] Error loading notifications: $e');
      }
    } finally {
      if (!isBackground) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _setupRealtimeSubscription(String userId) {
    if (_notificationChannel != null) {
      _client.removeChannel(_notificationChannel!);
    }

    _notificationChannel = _client
        .channel('user_notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            _handleRealtimePayload(payload, userId);
          },
        );

    _notificationChannel?.subscribe();
  }

  void _handleRealtimePayload(PostgresChangePayload payload, String currentUserId) {
    if (payload.eventType == PostgresChangeEvent.insert) {
      final newRecord = payload.newRecord;
      if (newRecord.isNotEmpty && newRecord['user_id'] == currentUserId) {
        final notif = InAppNotification.fromJson(newRecord);
        // Add to top of list if not already present
        if (!_notifications.any((n) => n.id == notif.id)) {
          _notifications.insert(0, notif);
          notifyListeners();

          // Check if user has enabled alerts for this notification category
          final type = notif.type.toLowerCase();
          final isDownload = type == 'download' || notif.title.toLowerCase().contains('download');
          final isUpload = type == 'upload' || notif.title.toLowerCase().contains('upload');
          final isSecurity = type == 'security' || type == 'approval' || notif.title.toLowerCase().contains('security') || notif.title.toLowerCase().contains('access');
          final isUpdate = type == 'update' || notif.title.toLowerCase().contains('update') || notif.title.toLowerCase().contains('version');

          bool shouldAlert = true;
          if (isDownload && !_downloadAlertsEnabled) shouldAlert = false;
          if (isUpload && !_uploadAlertsEnabled) shouldAlert = false;
          if (isSecurity && !_securityAlertsEnabled) shouldAlert = false;
          if (isUpdate && !_updateAlertsEnabled) shouldAlert = false;

          if (shouldAlert) {
            onNewNotification?.call(notif);
          }
        }
      }
    } else if (payload.eventType == PostgresChangeEvent.update) {
      final updatedRecord = payload.newRecord;
      if (updatedRecord.isNotEmpty && updatedRecord['user_id'] == currentUserId) {
        final notif = InAppNotification.fromJson(updatedRecord);
        final index = _notifications.indexWhere((n) => n.id == notif.id);
        if (index != -1) {
          _notifications[index] = notif;
          notifyListeners();
        }
      }
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      final oldRecord = payload.oldRecord;
      final deletedId = oldRecord['id']?.toString();
      if (deletedId != null) {
        _notifications.removeWhere((n) => n.id == deletedId);
        notifyListeners();
      }
    }
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();

      try {
        await _client.from('notifications').update({'is_read': true}).eq('id', id);
      } catch (e) {
        debugPrint('[NotificationService] Error marking as read: $e');
      }
    }
  }

  Future<void> markAllAsRead() async {
    final user = _authService?.currentUser;
    if (user == null) return;

    final unreadItems = _notifications.where((n) => !n.isRead).toList();
    if (unreadItems.isEmpty) return;

    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();

    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('[NotificationService] Error marking all as read: $e');
    }
  }

  Future<void> clearAll() async {
    final user = _authService?.currentUser;
    if (user == null) return;

    _notifications.clear();
    notifyListeners();

    try {
      await _client.from('notifications').delete().eq('user_id', user.id);
    } catch (e) {
      debugPrint('[NotificationService] Error clearing notifications: $e');
    }
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
