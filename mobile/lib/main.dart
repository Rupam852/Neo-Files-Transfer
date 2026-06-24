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

class HomeRouteResolver extends StatelessWidget {
  const HomeRouteResolver({Key? key}) : super(key: key);

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

    if (auth.currentUser == null) {
      return const LoginScreen();
    }

    if (auth.isPaused) {
      return const PendingScreen();
    }

    return const DashboardScreen();
  }
}
