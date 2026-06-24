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
  bool _isLoading = true;
  String? _loginError;

  User? get currentUser => _user;
  UserProfile? get profile => _profile;
  bool get isAdmin => _isAdmin;
  bool get isPaused => _isPaused;
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
        await loadProfile(session.user, {
          'google_access_token': session.providerToken,
          'google_refresh_token': session.providerRefreshToken,
        });
      } else {
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

    // Realtime listeners for admin/approved status changes
    _setupRealtimeListeners();
  }

  RealtimeChannel? _adminChannel;
  RealtimeChannel? _approvedChannel;

  void _setupRealtimeListeners() {
    if (_user == null) return;

    _adminChannel = _client
        .channel('admin-status-${_user!.id}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'admins',
            callback: (payload) async {
              if (_user != null) {
                final newUserId = payload.newRecord?['user_id']?.toString();
                final oldUserId = payload.oldRecord?['user_id']?.toString();
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
                final oldEmail = payload.oldRecord?['email']?.toString().toLowerCase();
                if (oldEmail == targetEmail) {
                  await signOut();
                }
              } else if (payload.newRecord != null) {
                final newEmail = payload.newRecord?['email']?.toString().toLowerCase();
                if (newEmail == targetEmail) {
                  _isPaused = payload.newRecord?['is_paused'] == true;
                  notifyListeners();
                }
              }
            });
    _approvedChannel?.subscribe();
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
  }

  Future<void> loadProfile(User authUser, [Map<String, String?>? sessionTokens]) async {
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

      // Check if user is Admin
      final adminResponse = await _client
          .from('admins')
          .select()
          .eq('user_id', authUser.id)
          .maybeSingle();

      _isAdmin = adminResponse != null;

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
