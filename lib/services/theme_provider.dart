import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global theme provider for dark mode support.
/// Uses ChangeNotifier so any widget can listen to theme changes.
class ThemeProvider extends ChangeNotifier {
  // Singleton instance
  static final ThemeProvider _instance = ThemeProvider._internal();
  factory ThemeProvider() => _instance;
  ThemeProvider._internal();

  static const String _themeKey = 'theme_mode'; // system | light | dark

  ThemeMode _themeMode = ThemeMode.dark; // Default to dark

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  /// Initialize — call once at app startup
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themeKey);
      
      // Migrate from old boolean format if present
      if (saved == null) {
        final oldBool = prefs.getBool('is_dark_mode');
        if (oldBool != null) {
          _themeMode = oldBool ? ThemeMode.dark : ThemeMode.light;
          // Save in new format and remove old key
          await prefs.setString(_themeKey, _themeModeToString(_themeMode));
          await prefs.remove('is_dark_mode');
        } else {
          _themeMode = ThemeMode.dark;
        }
      } else {
        _themeMode = _stringToThemeMode(saved);
      }
      
      debugPrint('🎨 Theme loaded: $_themeMode');
    } catch (e) {
      debugPrint('Failed to load theme: $e');
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }

  /// Set theme mode and persist
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, _themeModeToString(mode));
      debugPrint('🎨 Theme saved: $mode');
    } catch (e) {
      debugPrint('Failed to save theme: $e');
    }
  }

  /// Quick toggles
  void toggleDarkMode() {
    setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark: return 'dark';
      case ThemeMode.light: return 'light';
      case ThemeMode.system: return 'system';
    }
  }

  ThemeMode _stringToThemeMode(String value) {
    switch (value) {
      case 'dark': return ThemeMode.dark;
      case 'light': return ThemeMode.light;
      case 'system': return ThemeMode.system;
      default: return ThemeMode.dark;
    }
  }
}
