import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService extends ChangeNotifier with WidgetsBindingObserver {
  static const String _keyAppLockEnabled = 'neo_app_lock_enabled';
  static const String _keyLockTimeout = 'neo_lock_timeout_seconds';

  final LocalAuthentication _localAuth = LocalAuthentication();
  
  bool _isAppLockEnabled = false;
  int _lockTimeoutSeconds = 0; // 0 = Immediately, 60 = 1 min, 300 = 5 min
  bool _isLocked = false;
  bool _isAuthenticating = false;
  DateTime? _pausedTimestamp;

  SecurityService() {
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
  }

  bool get isAppLockEnabled => _isAppLockEnabled;
  int get lockTimeoutSeconds => _lockTimeoutSeconds;
  bool get isLocked => _isLocked;
  bool get isAuthenticating => _isAuthenticating;

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAppLockEnabled = prefs.getBool(_keyAppLockEnabled) ?? false;
      _lockTimeoutSeconds = prefs.getInt(_keyLockTimeout) ?? 0;
      
      // If app lock is enabled, lock app on fresh launch
      if (_isAppLockEnabled) {
        _isLocked = true;
      }
      notifyListeners();
      
      if (_isLocked) {
        authenticate();
      }
    } catch (e) {
      debugPrint('[SecurityService] Error loading preferences: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isAppLockEnabled) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pausedTimestamp = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTimestamp != null && !_isLocked) {
        final elapsed = DateTime.now().difference(_pausedTimestamp!).inSeconds;
        if (elapsed >= _lockTimeoutSeconds) {
          _isLocked = true;
          notifyListeners();
          authenticate();
        }
      }
      _pausedTimestamp = null;
    }
  }

  Future<bool> canCheckBiometrics() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      debugPrint('[SecurityService] Error checking biometrics: $e');
      return false;
    }
  }

  Future<bool> authenticate() async {
    if (_isAuthenticating) return false;
    _isAuthenticating = true;
    notifyListeners();

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate with Fingerprint, Face, or PIN to access Neo Files',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate) {
        _isLocked = false;
      }
      return didAuthenticate;
    } catch (e) {
      debugPrint('[SecurityService] Authentication error: $e');
      return false;
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<bool> setAppLockEnabled(bool enabled) async {
    if (enabled) {
      // Must authenticate successfully before turning on App Lock
      final success = await authenticate();
      if (!success) return false;
    }

    _isAppLockEnabled = enabled;
    if (!enabled) {
      _isLocked = false;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAppLockEnabled, enabled);
    notifyListeners();
    return true;
  }

  Future<void> setLockTimeout(int seconds) async {
    _lockTimeoutSeconds = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLockTimeout, seconds);
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
