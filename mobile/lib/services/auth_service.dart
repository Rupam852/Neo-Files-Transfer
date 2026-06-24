import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  User? _user;
  UserProfile? _profile;
  bool _isAdmin = false;
  bool _isPaused = false;
  bool _isSessionInvalidated = false;
  bool _isUnderMaintenance = false;
  bool _isDownloadsEnabled = true;
  bool _isSharingEnabled = true;
  bool _isLoading = true;
  String? _loginError;
  String? _localMobileSessionId;

  User? get currentUser => _user;
  UserProfile? get profile => _profile;
  bool get isAdmin => _isAdmin;
  bool get isPaused => _isPaused;
  bool get isSessionInvalidated => _isSessionInvalidated;
  bool get isUnderMaintenance => _isUnderMaintenance;
  bool get isDownloadsEnabled => _isDownloadsEnabled;
  bool get isSharingEnabled => _isSharingEnabled;
  bool get isLoading => _isLoading;
  String? get loginError => _loginError;

  AuthService() {
    _init();
  }

  void _init() {
    // Listen for auth state changes
    _client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      _user = session?.user;

      if (session != null) {
        final prefs = await SharedPreferences.getInstance();
        if (session.providerToken != null) {
          await prefs.setString('google_provider_token', session.providerToken!);
        }
        if (session.providerRefreshToken != null) {
          await prefs.setString('google_refresh_token', session.providerRefreshToken!);
        }
        final bool isFresh = data.event == AuthChangeEvent.signedIn;
        await loadProfile(
          session.user,
          {
            'google_access_token': session.providerToken,
            'google_refresh_token': session.providerRefreshToken,
          },
          isFresh,
        );
        _setupRealtimeListeners();
      } else {
        _clearRealtimeListeners();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('google_provider_token');
        await prefs.remove('google_refresh_token');
        _profile = null;
        _isAdmin = false;
        _isPaused = false;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  RealtimeChannel? _adminChannel;
  RealtimeChannel? _approvedChannel;
  RealtimeChannel? _profileChannel;
  RealtimeChannel? _settingsChannel;

  Future<String> _getOrCreateLocalMobileSessionId() async {
    if (_localMobileSessionId != null) return _localMobileSessionId!;
    final prefs = await SharedPreferences.getInstance();
    var sessionId = prefs.getString('active_mobile_session_id');
    if (sessionId == null) {
      sessionId = DateTime.now().millisecondsSinceEpoch.toString() + '_' + 
                  UniqueKey().hashCode.toString();
      await prefs.setString('active_mobile_session_id', sessionId);
    }
    _localMobileSessionId = sessionId;
    return sessionId;
  }

  void _setupRealtimeListeners() {
    _clearRealtimeListeners();
    if (_user == null) return;

    _adminChannel = _client
        .channel('admin-status-${_user!.id}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'admins',
            callback: (payload) async {
              if (_user != null) {
                final Map<String, dynamic>? newRecord = payload.newRecord;
                final Map<String, dynamic>? oldRecord = payload.oldRecord;
                final newUserId = newRecord?['user_id']?.toString();
                final oldUserId = oldRecord?['user_id']?.toString();
                if (newUserId == _user!.id || oldUserId == _user!.id) {
                  await loadProfile(_user!);
                }
              }
            });
    _adminChannel?.subscribe();

    _approvedChannel = _client
        .channel('approved-status-${_user!.id}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'approved_users',
            callback: (payload) async {
              if (_user == null) return;
              final targetEmail = _user!.email?.toLowerCase();
              if (payload.eventType == PostgresChangeEvent.delete) {
                final oldEmail = payload.oldRecord['email']?.toString().toLowerCase();
                if (oldEmail == targetEmail) {
                  await signOut();
                }
              } else {
                final newEmail = payload.newRecord['email']?.toString().toLowerCase();
                if (newEmail == targetEmail) {
                  _isPaused = payload.newRecord['is_paused'] == true;
                  notifyListeners();
                }
              }
            });
    _approvedChannel?.subscribe();

    _profileChannel = _client
        .channel('profile-status-${_user!.id}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_profiles',
            callback: (payload) async {
              if (_user == null) return;
              final Map<String, dynamic>? newRecord = payload.newRecord;
              if (newRecord != null) {
                final newMobileSession = newRecord['active_mobile_session_id'] as String?;
                final localSession = _localMobileSessionId;
                if (newMobileSession != null &&
                    localSession != null &&
                    newMobileSession != localSession) {
                  _isSessionInvalidated = true;
                  notifyListeners();
                }
              }
            });
    _profileChannel?.subscribe();

    // Listen to system_settings for maintenance mode changes
    _settingsChannel = _client
        .channel('auth-settings-changes')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'system_settings',
            callback: (payload) async {
              // Re-fetch all settings to get the latest state
              try {
                final settingsRes = await _client.from('system_settings').select();
                bool maintenance = false;
                bool downloads = true;
                bool sharing = true;
                for (final s in settingsRes) {
                  if (s['key'] == 'maintenance_mode') {
                    maintenance = s['value'] == true;
                  } else if (s['key'] == 'downloads_enabled') {
                    downloads = s['value'] != false;
                  } else if (s['key'] == 'sharing_enabled') {
                    sharing = s['value'] != false;
                  }
                }
                _isUnderMaintenance = maintenance;
                _isDownloadsEnabled = downloads;
                _isSharingEnabled = sharing;
                notifyListeners();
              } catch (e) {
                debugPrint('Failed to refresh settings: $e');
              }
            });
    _settingsChannel?.subscribe();
  }

  void _clearRealtimeListeners() {
    if (_adminChannel != null) {
      _client.removeChannel(_adminChannel!);
      _adminChannel = null;
    }
    if (_approvedChannel != null) {
      _client.removeChannel(_approvedChannel!);
      _approvedChannel = null;
    }
    if (_profileChannel != null) {
      _client.removeChannel(_profileChannel!);
      _profileChannel = null;
    }
    if (_settingsChannel != null) {
      _client.removeChannel(_settingsChannel!);
      _settingsChannel = null;
    }
  }

  Future<void> loadProfile(User authUser, [Map<String, String?>? sessionTokens, bool isFreshSignIn = false]) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Fetch user profile from DB
      var response = await _client
          .from('user_profiles')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      UserProfile? profileData;
      if (response != null) {
        profileData = UserProfile.fromJson(response);
      }

      if (profileData == null) {
        // Create profile on-the-fly
        final newProfile = {
          'id': authUser.id,
          'email': authUser.email ?? '',
          'name': authUser.userMetadata?['full_name'] ?? authUser.userMetadata?['name'] ?? '',
          'avatar_url': authUser.userMetadata?['avatar_url'] ?? '',
        };

        if (sessionTokens?['google_access_token'] != null) {
          newProfile['google_access_token'] = sessionTokens!['google_access_token']!;
        }
        if (sessionTokens?['google_refresh_token'] != null) {
          newProfile['google_refresh_token'] = sessionTokens!['google_refresh_token']!;
        }

        final inserted = await _client
            .from('user_profiles')
            .insert(newProfile)
            .select()
            .maybeSingle();

        if (inserted != null) {
          profileData = UserProfile.fromJson(inserted);
        }
      } else {
        // Check if we need to sync tokens
        final updates = <String, String>{};
        if (sessionTokens?['google_access_token'] != null &&
            response!['google_access_token'] != sessionTokens!['google_access_token']) {
          updates['google_access_token'] = sessionTokens['google_access_token']!;
        }
        if (sessionTokens?['google_refresh_token'] != null &&
            response!['google_refresh_token'] != sessionTokens!['google_refresh_token']) {
          updates['google_refresh_token'] = sessionTokens['google_refresh_token']!;
        }

        if (updates.isNotEmpty) {
          final updated = await _client
              .from('user_profiles')
              .update(updates)
              .eq('id', authUser.id)
              .select()
              .maybeSingle();
          if (updated != null) {
            profileData = UserProfile.fromJson(updated);
          }
        }
      }

      _profile = profileData;

      if (profileData != null) {
        final localSessionId = await _getOrCreateLocalMobileSessionId();
        final dbMobileSessionId = response?['active_mobile_session_id'] as String?;

        if (isFreshSignIn || dbMobileSessionId == null) {
          await _client
              .from('user_profiles')
              .update({'active_mobile_session_id': localSessionId})
              .eq('id', authUser.id);
          _isSessionInvalidated = false;
          profileData = UserProfile(
            id: profileData.id,
            email: profileData.email,
            name: profileData.name,
            avatarUrl: profileData.avatarUrl,
            driveFolderId: profileData.driveFolderId,
            isFolderVerified: profileData.isFolderVerified,
            googleRefreshToken: profileData.googleRefreshToken,
            activeWebSessionId: profileData.activeWebSessionId,
            activeMobileSessionId: localSessionId,
            createdAt: profileData.createdAt,
            updatedAt: profileData.updatedAt,
          );
        } else if (dbMobileSessionId != localSessionId) {
          _isSessionInvalidated = true;
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      // Check if user is Admin
      final adminResponse = await _client
          .from('admins')
          .select()
          .eq('user_id', authUser.id)
          .maybeSingle();

      _isAdmin = adminResponse != null;

      // Fetch maintenance mode setting
      try {
        final settingsRes = await _client.from('system_settings').select();
        _isUnderMaintenance = false;
        _isDownloadsEnabled = true;
        _isSharingEnabled = true;
        for (final s in settingsRes) {
          if (s['key'] == 'maintenance_mode') {
            _isUnderMaintenance = s['value'] == true;
          } else if (s['key'] == 'downloads_enabled') {
            _isDownloadsEnabled = s['value'] != false;
          } else if (s['key'] == 'sharing_enabled') {
            _isSharingEnabled = s['value'] != false;
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch settings: $e');
      }

      // Check if user is Paused (if not Admin)
      if (!_isAdmin) {
        final approvedResponse = await _client
            .from('approved_users')
            .select('id, is_paused')
            .eq('email', authUser.email?.toLowerCase() ?? '')
            .maybeSingle();

        if (approvedResponse == null) {
          // Check if there is a pending/rejected request in pending_registrations
          final pendingReg = await _client
              .from('pending_registrations')
              .select('status')
              .eq('email', authUser.email?.toLowerCase() ?? '')
              .maybeSingle();

          String errMsg;
          if (pendingReg != null) {
            final status = pendingReg['status'];
            if (status == 'rejected') {
              errMsg = 'Your access request has been rejected by an administrator.';
            } else {
              errMsg = 'Your access request is pending administrator approval.';
            }
          } else {
            errMsg = 'Access denied. Please submit a registration request first.';
          }

          // Sign out but preserve error
          _clearRealtimeListeners();
          await _client.auth.signOut();
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('google_provider_token');
          await prefs.remove('google_refresh_token');
          
          _user = null;
          _profile = null;
          _isAdmin = false;
          _isPaused = false;
          _isLoading = false;
          _loginError = errMsg;
          notifyListeners();
          return;
        }
        _isPaused = approvedResponse['is_paused'] == true;
        _loginError = null;
      } else {
        _isPaused = false;
        _loginError = null;
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle({bool forceConsent = false}) async {
    _loginError = null;
    notifyListeners();
    // SUPABASE NATIVE OAUTH LOGIN WITH DEEP LINKS
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.neofiles.neofilestransfer://login-callback/',
      scopes: 'email profile https://www.googleapis.com/auth/drive',
      queryParams: {
        'access_type': 'offline',
        if (forceConsent) 'prompt': 'consent',
      },
      authScreenLaunchMode: LaunchMode.inAppWebView,
    );
  }

  Future<void> signOut({bool clearError = true}) async {
    _clearRealtimeListeners();
    await _client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('google_provider_token');
    await prefs.remove('google_refresh_token');
    _user = null;
    _profile = null;
    _isAdmin = false;
    _isPaused = false;
    _isSessionInvalidated = false;
    _isUnderMaintenance = false;
    _isDownloadsEnabled = true;
    _isSharingEnabled = true;
    _isLoading = false;
    if (clearError) {
      _loginError = null;
    }
    notifyListeners();
  }

  Future<String?> getGoogleAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('google_provider_token');
  }

  Future<String?> getGoogleRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('google_refresh_token');
  }

  Future<void> setGoogleAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('google_provider_token', token);
  }
}
