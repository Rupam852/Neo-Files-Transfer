import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../models/user_profile.dart';
import 'fcm_service.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  User? _user;
  UserProfile? _profile;
  bool _isAdmin = false;
  bool _isPaused = false;
  bool _isUnderMaintenance = false;
  bool _isDownloadsEnabled = true;
  bool _isSharingEnabled = true;
  bool _isLoading = true;
  String? _loginError;
  bool _isProfileLoading = false;
  bool _hasGoogleConnectionError = false;

  User? get currentUser => _user;
  UserProfile? get profile => _profile;
  bool get isAdmin => _isAdmin;
  bool get isPaused => _isPaused;
  bool get isUnderMaintenance => _isUnderMaintenance;
  bool get isDownloadsEnabled => _isDownloadsEnabled;
  bool get isSharingEnabled => _isSharingEnabled;
  bool get isLoading => _isLoading;
  String? get loginError => _loginError;
  bool get hasGoogleConnectionError => _hasGoogleConnectionError;

  void setGoogleConnectionError(bool value) {
    if (_hasGoogleConnectionError != value) {
      _hasGoogleConnectionError = value;
      notifyListeners();
    }
  }

  AuthService() {
    _init();
  }

  void _init() {
    // Restore active session synchronously if present
    final initialSession = _client.auth.currentSession;
    if (initialSession != null) {
      _user = initialSession.user;
      loadProfile(initialSession.user);
      _setupRealtimeListeners();
    } else {
      _isLoading = false;
    }

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
  RealtimeChannel? _settingsChannel;

  void _setupRealtimeListeners() {
    _clearRealtimeListeners();
    if (_user == null) return;

    _adminChannel = _client
        .channel('admin-status-${_user!.id}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'admins',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: _user!.id,
            ),
            callback: (payload) async {
              if (_user != null) {
                await loadProfile(_user!);
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

    // Listen to system_settings for maintenance mode changes
    _settingsChannel = _client
        .channel('auth-settings-changes')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'system_settings',
            callback: (payload) async {
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
                debugPrint('Failed to refresh system settings: $e');
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
    if (_settingsChannel != null) {
      _client.removeChannel(_settingsChannel!);
      _settingsChannel = null;
    }
  }

  Future<void> refreshProfile() async {
    if (_user != null) {
      await loadProfile(_user!);
    }
  }

  Future<void> loadProfile(
    User authUser, [
    Map<String, String?>? sessionTokens,
    bool isFreshSignIn = false,
  ]) async {
    if (_isProfileLoading) return;
    _isProfileLoading = true;
    _isLoading = true;
    notifyListeners();

    try {
      // Step 1: Fetch user profile
      final response = await _client
          .from('user_profiles')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      UserProfile? profileData;

      if (response == null) {
        // Create new profile record
        final insertPayload = <String, dynamic>{
          'id': authUser.id,
          'email': authUser.email,
          'name': authUser.userMetadata?['full_name'] ??
              authUser.userMetadata?['name'] ??
              '',
          'avatar_url': authUser.userMetadata?['avatar_url'] ?? '',
        };

        if (sessionTokens?['google_access_token'] != null) {
          insertPayload['google_access_token'] = sessionTokens!['google_access_token'];
        }
        if (sessionTokens?['google_refresh_token'] != null) {
          insertPayload['google_refresh_token'] = sessionTokens!['google_refresh_token'];
        }

        final inserted = await _client
            .from('user_profiles')
            .insert(insertPayload)
            .select()
            .maybeSingle();

        if (inserted != null) {
          profileData = UserProfile.fromJson(inserted);
        } else {
          profileData = UserProfile(
            id: authUser.id,
            email: authUser.email ?? '',
            name: (insertPayload['name'] as String?) ?? '',
            avatarUrl: insertPayload['avatar_url'] as String?,
            isFolderVerified: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      } else {
        profileData = UserProfile.fromJson(response);

        // Update refresh token in DB if present in session
        final updates = <String, dynamic>{};
        if (sessionTokens?['google_refresh_token'] != null &&
            profileData.googleRefreshToken != sessionTokens!['google_refresh_token']) {
          updates['google_refresh_token'] = sessionTokens['google_refresh_token'];
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

      // Sync FCM device token with authenticated user in Supabase
      FcmService().syncUserToken(authUser.id);

      // Check if user is Admin (check by user_id and fallback to email)
      Map<String, dynamic>? adminResponse;
      try {
        adminResponse = await _client
            .from('admins')
            .select()
            .eq('user_id', authUser.id)
            .maybeSingle();

        if (adminResponse == null && authUser.email != null) {
          adminResponse = await _client
              .from('admins')
              .select()
              .eq('email', authUser.email!.toLowerCase())
              .maybeSingle();
        }
      } catch (e) {
        debugPrint('Admin check query error: $e');
      }

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

      // Check if user is Paused or Approved (if not Admin)
      if (!_isAdmin) {
        Map<String, dynamic>? approvedResponse;
        bool approvedQuerySuccess = false;
        try {
          approvedResponse = await _client
              .from('approved_users')
              .select('id, is_paused')
              .eq('email', authUser.email?.toLowerCase() ?? '')
              .maybeSingle();
          approvedQuerySuccess = true;
        } catch (e) {
          debugPrint('Approved users check query error: $e');
        }

        // Only log out if query succeeded and user is definitely not approved
        if (approvedQuerySuccess && approvedResponse == null) {
          // Check if there is a pending/rejected request in pending_registrations
          Map<String, dynamic>? pendingReg;
          try {
            pendingReg = await _client
                .from('pending_registrations')
                .select('status')
                .eq('email', authUser.email?.toLowerCase() ?? '')
                .maybeSingle();
          } catch (_) {}

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

        if (approvedResponse != null) {
          _isPaused = approvedResponse['is_paused'] == true;
        }
        _loginError = null;
      } else {
        _isPaused = false;
        _loginError = null;
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      _isProfileLoading = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle({bool forceConsent = false}) async {
    _loginError = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{'access_type': 'offline'};
      if (forceConsent) {
        queryParams['prompt'] = 'consent select_account';
      }

      final res = await _client.auth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: 'com.neofiles.neofilestransfer://login-callback/',
        scopes: 'email profile https://www.googleapis.com/auth/drive.file',
        queryParams: queryParams,
      );

      final resultUrl = await FlutterWebAuth2.authenticate(
        url: res.url,
        callbackUrlScheme: 'com.neofiles.neofilestransfer',
      );

      final uri = Uri.parse(resultUrl);
      await _client.auth.getSessionFromUrl(uri);
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      _loginError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut({bool clearError = true}) async {
    final oldUserId = _user?.id;
    _clearRealtimeListeners();
    try {
      await FcmService().unbindUserToken(oldUserId);
    } catch (e) {
      debugPrint('[AuthService] Error unbinding FCM token on signOut: $e');
    }
    await _client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('google_provider_token');
    await prefs.remove('google_refresh_token');
    _user = null;
    _profile = null;
    _isAdmin = false;
    _isPaused = false;
    _isUnderMaintenance = false;
    _isDownloadsEnabled = true;
    _isSharingEnabled = true;
    _isLoading = false;
    _hasGoogleConnectionError = false;
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
