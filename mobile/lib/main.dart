import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'config.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/file_service.dart';
import 'screens/login_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/session_invalidated_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Client
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
        ProxyProvider<AuthService, ApiService>(
          update: (_, auth, __) => ApiService(auth),
        ),
        ChangeNotifierProxyProvider2<AuthService, ApiService, FileService>(
          create: (context) => FileService(
            Provider.of<AuthService>(context, listen: false),
            Provider.of<ApiService>(context, listen: false),
          ),
          update: (_, auth, api, fileService) {
            if (fileService == null) {
              return FileService(auth, api);
            }
            fileService.update(auth, api);
            return fileService;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Neo Files',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Plus Jakarta Sans',
          colorScheme: const ColorScheme.dark(
            primary: Colors.indigoAccent,
            background: Color(0xFF030712),
            surface: Color(0xFF0F172A),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white70),
            bodyMedium: TextStyle(color: Colors.white70),
          ),
        ),
        home: const HomeRouteResolver(),
      ),
    );
  }
}

class HomeRouteResolver extends StatefulWidget {
  const HomeRouteResolver({Key? key}) : super(key: key);

  @override
  State<HomeRouteResolver> createState() => _HomeRouteResolverState();
}

class _HomeRouteResolverState extends State<HomeRouteResolver> {
  AuthService? _authService;
  bool? _lastIsAdmin;
  bool? _lastIsPaused;
  bool? _lastIsSessionInvalidated;
  String? _lastUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthService>(context);
    if (_authService != auth) {
      _authService?.removeListener(_onAuthChanged);
      _authService = auth;
      _authService?.addListener(_onAuthChanged);
      _lastIsAdmin = auth.isAdmin;
      _lastIsPaused = auth.isPaused;
      _lastIsSessionInvalidated = auth.isSessionInvalidated;
      _lastUserId = auth.currentUser?.id;
    }
  }

  @override
  void dispose() {
    _authService?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted || _authService == null) return;

    final newIsAdmin = _authService!.isAdmin;
    final newIsPaused = _authService!.isPaused;
    final newIsSessionInvalidated = _authService!.isSessionInvalidated;
    final newUserId = _authService!.currentUser?.id;

    if (newIsAdmin != _lastIsAdmin ||
        newIsPaused != _lastIsPaused ||
        newIsSessionInvalidated != _lastIsSessionInvalidated ||
        newUserId != _lastUserId) {
      _lastIsAdmin = newIsAdmin;
      _lastIsPaused = newIsPaused;
      _lastIsSessionInvalidated = newIsSessionInvalidated;
      _lastUserId = newUserId;

      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF030712),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitPulse(
                color: Colors.indigoAccent,
                size: 50.0,
              ),
              SizedBox(height: 16),
              Text(
                'Loading session...',
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (auth.isSessionInvalidated) {
      return const SessionInvalidatedScreen();
    }

    if (auth.currentUser == null) {
      return const LoginScreen();
    }

    if (auth.isAdmin) {
      return const AdminScreen();
    }

    if (auth.isPaused) {
      return const PendingScreen();
    }

    return const DashboardScreen();
  }
}
