import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'config.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/file_service.dart';
import 'services/update_service.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'services/security_service.dart';
import 'services/share_receiver_service.dart';
import 'services/transfer_service.dart';
import 'widgets/app_lock_screen.dart';
import 'widgets/share_upload_dialog.dart';
import 'screens/login_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/maintenance_screen.dart';

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
        ChangeNotifierProvider<ThemeService>(
          create: (_) => ThemeService(),
        ),
        ChangeNotifierProvider<SecurityService>(
          create: (_) => SecurityService(),
        ),
        ChangeNotifierProvider<ShareReceiverService>(
          create: (_) => ShareReceiverService(),
        ),
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
        ChangeNotifierProxyProvider<AuthService, NotificationService>(
          create: (context) => NotificationService(
            Provider.of<AuthService>(context, listen: false),
          ),
          update: (_, auth, notifService) {
            if (notifService == null) {
              return NotificationService(auth);
            }
            notifService.update(auth);
            return notifService;
          },
        ),
        ChangeNotifierProvider<UpdateService>(
          create: (_) => UpdateService()..initialize(),
        ),
        ChangeNotifierProxyProvider3<AuthService, ApiService, FileService, TransferService>(
          create: (context) => TransferService(
            Provider.of<AuthService>(context, listen: false),
            Provider.of<ApiService>(context, listen: false),
            Provider.of<FileService>(context, listen: false),
          ),
          update: (_, auth, api, fileService, transferService) {
            if (transferService == null) {
              return TransferService(auth, api, fileService);
            }
            transferService.update(auth, api, fileService);
            return transferService;
          },
        ),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            title: 'Neo Files',
            navigatorKey: UpdateService.navigatorKey,
            debugShowCheckedModeBanner: false,
            themeMode: themeService.themeMode,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const HomeRouteResolver(),
          );
        },
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
  bool? _lastIsUnderMaintenance;
  String? _lastUserId;
  bool _checkedInitialShare = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initShareListener();
    });
  }

  void _initShareListener() {
    final shareReceiver = Provider.of<ShareReceiverService>(context, listen: false);
    
    // Listen for ongoing share intents
    shareReceiver.onSharedFilesReceived.listen((files) {
      if (files.isNotEmpty && mounted) {
        _checkAndShowShareDialog(files);
      }
    });

    // Check cold-start share intent once
    if (!_checkedInitialShare) {
      _checkedInitialShare = true;
      shareReceiver.checkInitialSharedFiles().then((files) {
        if (files.isNotEmpty && mounted) {
          _checkAndShowShareDialog(files);
        }
      });
    }
  }

  void _checkAndShowShareDialog(List<IncomingSharedFile> files) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final security = Provider.of<SecurityService>(context, listen: false);

    if (auth.currentUser != null && !security.isLocked && !auth.isPaused && !auth.isUnderMaintenance) {
      ShareUploadDialog.show(context: context, files: files);
    }
  }

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
      _lastIsUnderMaintenance = auth.isUnderMaintenance;
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
    final newIsUnderMaintenance = _authService!.isUnderMaintenance;
    final newUserId = _authService!.currentUser?.id;

    final maintenanceChanged = newIsUnderMaintenance != _lastIsUnderMaintenance;
    final shouldPop = (newIsAdmin != _lastIsAdmin) ||
        (newIsPaused != _lastIsPaused) ||
        (newUserId != _lastUserId) ||
        (maintenanceChanged && !newIsAdmin);

    if (newIsAdmin != _lastIsAdmin ||
        newIsPaused != _lastIsPaused ||
        newIsUnderMaintenance != _lastIsUnderMaintenance ||
        newUserId != _lastUserId) {
      _lastIsAdmin = newIsAdmin;
      _lastIsPaused = newIsPaused;
      _lastIsUnderMaintenance = newIsUnderMaintenance;
      _lastUserId = newUserId;

      if (shouldPop) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.popUntil((route) => route.isFirst);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final security = Provider.of<SecurityService>(context);

    // If app lock is enabled and currently locked, show AppLockScreen
    if (security.isLocked && auth.currentUser != null) {
      return const AppLockScreen();
    }

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

    if (auth.currentUser == null) {
      return const LoginScreen();
    }

    if (auth.isAdmin) {
      return const AdminScreen();
    }

    // Maintenance mode: show screen to regular users (admins bypass it)
    if (auth.isUnderMaintenance) {
      return const MaintenanceScreen();
    }

    if (auth.isPaused) {
      return const PendingScreen();
    }

    return const DashboardScreen();
  }
}
