import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config.dart';
import '../screens/update_screen.dart';

class UpdateService extends ChangeNotifier {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _isChecking = false;
  bool _hasUpdate = false;
  bool _autoCheckEnabled = true;

  String _currentVersion = 'v1.0.0';
  String? _latestVersion;
  String? _description;
  String? _downloadUrl;
  String? _webUrl;
  String? _fileName;
  int? _fileSize;
  DateTime? _lastChecked;
  String? _errorMessage;
  bool _notificationsAllowed = false;

  // Getters
  bool get isChecking => _isChecking;
  bool get hasUpdate => _hasUpdate;
  bool get autoCheckEnabled => _autoCheckEnabled;
  bool get notificationsAllowed => _notificationsAllowed;
  String get currentVersion => _currentVersion;
  String? get latestVersion => _latestVersion;
  String? get description => _description;
  String? get downloadUrl => _downloadUrl;
  String? get webUrl => _webUrl;
  String? get fileName => _fileName;
  int? get fileSize => _fileSize;
  DateTime? get lastChecked => _lastChecked;
  String? get errorMessage => _errorMessage;

  static const String _prefAutoCheckKey = 'auto_check_updates';
  static const String _channelId = 'neo_app_updates';
  static const String _channelName = 'App Updates';
  static const String _channelDesc = 'Notifications for Neo Files app updates';

  /// Initialize notifications and check version if auto-check is enabled
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Load auto check preference (default: true)
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoCheckEnabled = prefs.getBool(_prefAutoCheckKey) ?? true;
    } catch (e) {
      debugPrint('[UpdateService] Error reading SharedPreferences: $e');
    }

    // Get current app version from package_info_plus
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = 'v${packageInfo.version}';
    } catch (e) {
      debugPrint('[UpdateService] Error fetching package info: $e');
      _currentVersion = 'v1.0.0';
    }

    // Setup local notifications for Android
    try {
      const androidInitSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
      const initSettings = InitializationSettings(android: androidInitSettings);

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('[UpdateService] Notification clicked with payload: ${response.payload}');
          _navigateToUpdateScreen();
        },
      );

      // Create notification channel for Android 8.0+
      final androidNotificationPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidNotificationPlugin != null) {
        await androidNotificationPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ),
        );
        // Request notification permission for Android 13+
        await androidNotificationPlugin.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('[UpdateService] Notification initialization error: $e');
    }

    // Check and request notification permission for Android 13+ devices
    await checkNotificationPermission();
    if (!_notificationsAllowed) {
      await requestNotificationPermission();
    }

    // Auto check if enabled
    if (_autoCheckEnabled) {
      checkForUpdates(isAutoCheck: true);
    }
  }

  void _navigateToUpdateScreen() {
    final state = navigatorKey.currentState;
    if (state != null) {
      state.push(
        MaterialPageRoute(
          builder: (_) => const UpdateScreen(),
        ),
      );
    }
  }

  /// Toggle Auto-Check setting and persist
  Future<void> setAutoCheck(bool enabled) async {
    _autoCheckEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefAutoCheckKey, enabled);
    } catch (e) {
      debugPrint('[UpdateService] Error saving auto check preference: $e');
    }
  }

  /// Clear the red dot badge when user views or downloads
  void clearBadge() {
    if (_hasUpdate) {
      _hasUpdate = false;
      notifyListeners();
    }
  }

  /// Compare two version strings (e.g. 'v1.0.2' and 'v1.0.0')
  /// Returns > 0 if v1 > v2, < 0 if v1 < v2, 0 if equal
  int compareVersions(String v1, String v2) {
    String clean1 = v1.toLowerCase().replaceAll(RegExp(r'[^0-9.]'), '');
    String clean2 = v2.toLowerCase().replaceAll(RegExp(r'[^0-9.]'), '');

    List<int> parts1 = clean1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> parts2 = clean2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    int maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (int i = 0; i < maxLen; i++) {
      int p1 = i < parts1.length ? parts1[i] : 0;
      int p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  /// Check version from the API
  Future<void> checkForUpdates({
    bool isAutoCheck = false,
    BuildContext? context,
  }) async {
    if (_isChecking) return;

    _isChecking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = Uri.parse(AppConfig.updateApiUrl);
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['status'] == 'success') {
          final remoteVer = (data['version'] ?? '').toString().trim();
          _latestVersion = remoteVer.startsWith('v') ? remoteVer : 'v$remoteVer';
          _description = data['description']?.toString() ?? '';
          _downloadUrl = data['download_url']?.toString();
          _webUrl = data['web_url']?.toString();
          _fileName = data['file_name']?.toString();
          _fileSize = data['file_size'] is int ? data['file_size'] : int.tryParse('${data['file_size']}');
          _lastChecked = DateTime.now();

          // Compare remote version with current version
          if (_latestVersion != null && compareVersions(_latestVersion!, _currentVersion) > 0) {
            _hasUpdate = true;
            notifyListeners();

            // Trigger system notification in status bar if auto check or when an update is found
            await _showSystemNotification(
              title: 'New Update Available: $_latestVersion 🚀',
              body: 'Tap to view what\'s new and download the latest update.',
            );
          } else {
            _hasUpdate = false;
            notifyListeners();

            if (!isAutoCheck && context != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('You are using the latest version!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } else {
          _errorMessage = data['error'] ?? 'Invalid response from update server';
          notifyListeners();
        }
      } else {
        _errorMessage = 'Server error (${response.statusCode})';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to check update: $e';
      debugPrint('[UpdateService] $e');
      notifyListeners();

      if (!isAutoCheck && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update check failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Check current notification permission status
  Future<void> checkNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      _notificationsAllowed = status.isGranted;
      notifyListeners();
    } catch (e) {
      debugPrint('[UpdateService] Check notification permission error: $e');
    }
  }

  /// Request notification permission for Android 13+ devices
  Future<bool> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        _notificationsAllowed = result.isGranted;
        notifyListeners();
        return result.isGranted;
      }
      _notificationsAllowed = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[UpdateService] Error requesting notification permission: $e');
      return false;
    }
  }

  /// Show Android Status Bar Notification
  Future<void> _showSystemNotification({
    required String title,
    required String body,
  }) async {
    try {
      // Ensure permission is granted before showing notification on Android 13+
      if (!_notificationsAllowed) {
        final granted = await requestNotificationPermission();
        if (!granted) {
          debugPrint('[UpdateService] Notification permission denied by user.');
        }
      }
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
        ticker: 'App Update Available',
        color: Color(0xFF6366F1), // Indigo accent
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id: 1001,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: 'open_update_screen',
      );
    } catch (e) {
      debugPrint('[UpdateService] Failed to post system notification: $e');
    }
  }
}
