import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themePrefKey = 'neo_app_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeService() {
    _loadThemeFromPrefs();
  }

  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themePrefKey);
      if (savedMode == 'light') {
        _themeMode = ThemeMode.light;
      } else if (savedMode == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system; // Default to System theme on Android
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[ThemeService] Error loading theme: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'dark';
      if (mode == ThemeMode.light) {
        val = 'light';
      } else if (mode == ThemeMode.system) {
        val = 'system';
      }
      await prefs.setString(_themePrefKey, val);
    } catch (e) {
      debugPrint('[ThemeService] Error saving theme: $e');
    }
  }
}

class AppTheme {
  // --- SOFT WHITE LIGHT THEME ---
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Plus Jakarta Sans',
    scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Soft elegant off-white
    primaryColor: const Color(0xFF4F46E5), // Indigo-600
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF4F46E5),
      secondary: Color(0xFF6366F1),
      surface: Color(0xFFFFFFFF), // Pure white cards & dialogs
      background: Color(0xFFF8FAFC),
      onPrimary: Colors.white,
      onSurface: Color(0xFF0F172A), // Slate-900 crisp typography
      onBackground: Color(0xFF0F172A),
      error: Color(0xFFEF4444),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF8FAFC),
      foregroundColor: Color(0xFF0F172A),
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Color(0xFF0F172A)),
      titleTextStyle: TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'Plus Jakarta Sans',
      ),
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE2E8F0),
      thickness: 1,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: Color(0xFF334155)),
      bodyMedium: TextStyle(color: Color(0xFF475569)),
      bodySmall: TextStyle(color: Color(0xFF64748B)),
    ),
  );

  // --- MIDNIGHT SLATE DARK THEME ---
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Plus Jakarta Sans',
    scaffoldBackgroundColor: const Color(0xFF030712),
    primaryColor: const Color(0xFF6366F1),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF6366F1),
      secondary: Color(0xFF818CF8),
      surface: Color(0xFF0F172A),
      background: Color(0xFF030712),
      onPrimary: Colors.white,
      onSurface: Colors.white,
      onBackground: Colors.white,
      error: Color(0xFFEF4444),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF030712),
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'Plus Jakarta Sans',
      ),
    ),
    cardTheme: CardTheme(
      color: const Color(0xFF0F172A),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1E293B), width: 1),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF0F172A),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF1E293B), width: 1),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF0F172A),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF1E293B),
      thickness: 1,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: Colors.white70),
      bodyMedium: TextStyle(color: Colors.white70),
      bodySmall: TextStyle(color: Colors.white60),
    ),
  );
}
