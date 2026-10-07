import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/in_app_notification.dart';
import 'auth_service.dart';

class NotificationService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  AuthService? _authService;

  List<InAppNotification> _notifications = [];
  bool _isLoading = false;
  RealtimeChannel? _notificationChannel;

  // Callback to display real-time in-app notification toasts/snackbars
  void Function(InAppNotification notification)? onNewNotification;

  NotificationService([AuthService? authService]) {
    if (authService != null) {
      update(authService);
    }
  }

  List<InAppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void update(AuthService authService) {
    final previousUserId = _authService?.currentUser?.id;
    _authService = authService;
    final currentUserId = authService.currentUser?.id;

    if (currentUserId != previousUserId) {
      if (currentUserId != null) {
        loadNotifications();
        _setupRealtimeSubscription(currentUserId);
      } else {
        _cleanup();
      }
    }
  }

  void _cleanup() {
    if (_notificationChannel != null) {
      _client.removeChannel(_notificationChannel!);
      _notificationChannel = null;
    }
    _notifications = [];
    notifyListeners();
  }

  Future<void> loadNotifications() async {
    final user = _authService?.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

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
      debugPrint('[NotificationService] Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setupRealtimeSubscription(String userId) {
    if (_notificationChannel != null) {
      _client.removeChannel(_notificationChannel!);
    }

    _notificationChannel = _client
        .channel('user-notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _handleRealtimePayload(payload);
          },
        );

    _notificationChannel?.subscribe();
  }

  void _handleRealtimePayload(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.insert) {
      final newRecord = payload.newRecord;
      if (newRecord.isNotEmpty) {
        final notif = InAppNotification.fromJson(newRecord);
        // Add to top of list if not already present
        if (!_notifications.any((n) => n.id == notif.id)) {
          _notifications.insert(0, notif);
          notifyListeners();
          onNewNotification?.call(notif);
        }
      }
    } else if (payload.eventType == PostgresChangeEvent.update) {
      final updatedRecord = payload.newRecord;
      if (updatedRecord.isNotEmpty) {
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
