import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService extends ChangeNotifier {
  static const String _keyAppLockEnabled = 'neo_app_lock_enabled';

  final LocalAuthentication _localAuth = LocalAuthentication();
  
  bool _isAppLockEnabled = false;
  bool _isLocked = false;
  bool _isAuthenticating = false;

  SecurityService([SharedPreferences? prefs]) {
    if (prefs != null) {
      _initSync(prefs);
    } else {
      _loadPreferences();
    }
  }

  void _initSync(SharedPreferences prefs) {
    _isAppLockEnabled = prefs.getBool(_keyAppLockEnabled) ?? false;
    if (_isAppLockEnabled) {
      _isLocked = true;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_isLocked && !_isAuthenticating) {
          authenticate();
        }
      });
    }
  }

  bool get isAppLockEnabled => _isAppLockEnabled;
  bool get isLocked => _isLocked;
  bool get isAuthenticating => _isAuthenticating;

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_keyAppLockEnabled) ?? false;
      if (enabled != _isAppLockEnabled) {
        _isAppLockEnabled = enabled;
        if (_isAppLockEnabled) {
          _isLocked = true;
        }
        notifyListeners();
        
        if (_isLocked) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_isLocked && !_isAuthenticating) {
              authenticate();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[SecurityService] Error loading preferences: $e');
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
      // Stays UNLOCKED for current session while using the app
      _isLocked = false;
    } else {
      _isLocked = false;
    }

    _isAppLockEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAppLockEnabled, enabled);
    notifyListeners();
    return true;
  }
}
