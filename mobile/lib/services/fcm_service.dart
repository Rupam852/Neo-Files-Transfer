import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/update_screen.dart';
import '../widgets/transfer_manager_sheet.dart';
import 'update_service.dart';

const _firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyAwSEViej7t93SjwJ8O3HjJz2woqXQkDPQ',
  appId: '1:999795249319:android:05524b71050662ceaa4b82',
  messagingSenderId: '999795249319',
  projectId: 'neo-files-transfer-24881',
  storageBucket: 'neo-files-transfer-24881.firebasestorage.app',
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: _firebaseOptions);
    }
  } catch (_) {}
  debugPrint('[FCM Background] Message received: ${message.messageId} | Data: ${message.data}');
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifs = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  String? _cachedDeviceId;
  String? _currentUserId;
  StreamSubscription<String>? _tokenRefreshSub;

  static const String _fcmChannelId = 'neo_push_notifications';
  static const String _fcmChannelName = 'NeoFiles Alerts & Updates';
  static const String _fcmChannelDesc = 'Important account alerts, system updates and notifications';

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: _firebaseOptions);
      }
      await _fcm.setAutoInitEnabled(true);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 1. Request notification permissions (Android 13+ and iOS)
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      // 2. Configure Foreground presentation
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Setup Android Notification Channel
      const androidChannel = AndroidNotificationChannel(
        _fcmChannelId,
        _fcmChannelName,
        description: _fcmChannelDesc,
        importance: Importance.high,
        playSound: true,
      );

      final androidPlugin = _localNotifs
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidChannel);
      }

      // 4. Listen for foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM Foreground] Title: ${message.notification?.title}, Data: ${message.data}');
        _showForegroundNotification(message);
      });

      // 5. Listen for notification tap (when app opened from background/sleep)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM Opened] Data: ${message.data}');
        _handleNotificationAction(message.data);
      });

      // 6. Check initial message if app was terminated
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM Terminated Opened] Data: ${initialMessage.data}');
        Future.delayed(const Duration(milliseconds: 600), () {
          _handleNotificationAction(initialMessage.data);
        });
      }

      // 7. Subscribe to general broadcast topics
      try {
        await _fcm.subscribeToTopic('all_users');
        await _fcm.subscribeToTopic('app_updates');
      } catch (e) {
        debugPrint('[FCM] Topic subscribe error: $e');
      }

      _isInitialized = true;
      debugPrint('[FCM] Service initialized successfully');
    } catch (e) {
      debugPrint('[FCM] Init error: $e');
    }
  }

  // Bind and sync FCM token to the currently logged in user
  Future<Map<String, dynamic>> syncUserToken(String userId) async {
    _currentUserId = userId;
    try {
      if (!_isInitialized) {
        await init();
      }

      final deviceId = await _getUniqueDeviceId();
      final deviceName = await _getDeviceName();
      final supabase = Supabase.instance.client;

      // 1. Immediately listen to token refresh in background
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) async {
        debugPrint('[FCM] Token refreshed: $newToken');
        if (_currentUserId == userId && newToken.isNotEmpty) {
          try {
            await supabase.from('user_fcm_tokens').upsert({
              'user_id': userId,
              'device_id': deviceId,
              'fcm_token': newToken,
              'device_name': deviceName,
              'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }, onConflict: 'user_id,device_id');
            debugPrint('[FCM] Refreshed token saved to Supabase');
          } catch (e) {
            debugPrint('[FCM] Error updating refreshed token: $e');
          }
        }
      });

      // 2. Retry loop for getToken() in case Google Play Services is initializing on first launch
      String? token;
      String? lastError;
      for (int attempt = 1; attempt <= 5; attempt++) {
        try {
          token = await _fcm.getToken();
          if (token != null && token.isNotEmpty) {
            break;
          }
        } catch (e) {
          lastError = e.toString();
          debugPrint('[FCM] getToken attempt $attempt error: $e');
        }
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      if (token == null || token.isEmpty) {
        debugPrint('[FCM] No token obtained after retries. Last error: $lastError');
        return {
          'success': false,
          'error': lastError ?? 'FCM Token returned null. Please verify Google Play Services.',
        };
      }

      debugPrint('[FCM] Syncing token for user $userId on device $deviceId: $token');

      try {
        await supabase.from('user_fcm_tokens').upsert({
          'user_id': userId,
          'device_id': deviceId,
          'fcm_token': token,
          'device_name': deviceName,
          'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,device_id');
        debugPrint('[FCM] Token successfully saved in user_fcm_tokens via upsert');
      } catch (upsertErr) {
        debugPrint('[FCM] Upsert failed, trying direct insert: $upsertErr');
        try {
          await supabase.from('user_fcm_tokens').delete().eq('user_id', userId).eq('device_id', deviceId);
          await supabase.from('user_fcm_tokens').insert({
            'user_id': userId,
            'device_id': deviceId,
            'fcm_token': token,
            'device_name': deviceName,
            'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
          debugPrint('[FCM] Token successfully inserted via fallback delete+insert');
        } catch (fallbackErr) {
          debugPrint('[FCM] Fallback insert failed: $fallbackErr');
          return {
            'success': false,
            'token': token,
            'error': 'Database error: $fallbackErr',
          };
        }
      }

      // Subscribe to user personal topic
      try {
        await _fcm.subscribeToTopic('user_$userId');
      } catch (_) {}

      return {
        'success': true,
        'token': token,
        'deviceId': deviceId,
        'deviceName': deviceName,
      };
    } catch (e) {
      debugPrint('[FCM] Error syncing user token: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<String?> getCurrentToken() async {
    try {
      if (!_isInitialized) await init();
      return await _fcm.getToken();
    } catch (_) {
      return null;
    }
  }

  // Complete cleanup on logout or account switch:
  // Removes token from Supabase DB, deletes local token, unbinds topics
  Future<void> unbindUserToken(String? userId) async {
    try {
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;

      final targetId = userId ?? _currentUserId;
      final deviceId = await _getUniqueDeviceId();

      if (targetId != null && targetId.isNotEmpty) {
        try {
          final supabase = Supabase.instance.client;
          await supabase
              .from('user_fcm_tokens')
              .delete()
              .eq('user_id', targetId)
              .eq('device_id', deviceId);
          debugPrint('[FCM] Unbound DB token for user $targetId');
        } catch (e) {
          debugPrint('[FCM] Error deleting token from DB: $e');
        }

        try {
          await _fcm.unsubscribeFromTopic('user_$targetId');
        } catch (_) {}
      }

      // Invalidate current Firebase FCM token so no further notifications reach this device
      try {
        await _fcm.deleteToken();
        debugPrint('[FCM] Local token deleted on logout');
      } catch (e) {
        debugPrint('[FCM] Error deleting local token: $e');
      }

      _currentUserId = null;
    } catch (e) {
      debugPrint('[FCM] Unbind error: $e');
    }
  }

  // Display foreground heads-up notification using local notifications
  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'NeoFiles Notification';
    final body = notification?.body ?? data['body'] ?? '';

    final androidDetails = AndroidNotificationDetails(
      _fcmChannelId,
      _fcmChannelName,
      channelDescription: _fcmChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      color: const Color(0xFF4F46E5),
    );

    final notifId = message.hashCode & 0x7FFFFFFF;
    _localNotifs.show(
      id: notifId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: data['type'] ?? data['action'] ?? 'fcm_general',
    );
  }

  // Handle routing when user taps a push notification
  void _handleNotificationAction(Map<String, dynamic> data) {
    final actionType = data['type'] ?? data['action'] ?? '';
    final navState = UpdateService.navigatorKey.currentState;

    if (actionType == 'update_screen' || actionType == 'app_update') {
      if (navState != null) {
        navState.push(
          MaterialPageRoute(builder: (_) => const UpdateScreen()),
        );
      }
    } else if (actionType == 'transfer_manager') {
      final ctx = UpdateService.navigatorKey.currentContext;
      if (ctx != null) {
        TransferManagerSheet.show(ctx);
      }
    }
  }

  Future<String> _getUniqueDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('neofiles_device_unique_id');
    if (id != null && id.isNotEmpty) {
      _cachedDeviceId = id;
      return id;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        id = androidInfo.id.isNotEmpty ? androidInfo.id : 'android_${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        id = iosInfo.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        id = 'device_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (_) {
      id = 'device_${DateTime.now().millisecondsSinceEpoch}';
    }

    await prefs.setString('neofiles_device_unique_id', id);
    _cachedDeviceId = id;
    return id;
  }

  Future<String> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return '${info.brand} ${info.model}'.trim();
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return info.name;
      }
    } catch (_) {}
    return 'Android Device';
  }
}
