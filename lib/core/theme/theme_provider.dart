import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isDark = true;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _isDark;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('theme_mode') ?? 'system';
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.toString().split('.').last == savedTheme,
        orElse: () => ThemeMode.system,
      );
      _updateDarkMode();
      notifyListeners();
    } catch (e) {
      // Use system default if loading fails
      _themeMode = ThemeMode.system;
      _updateDarkMode();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _updateDarkMode();
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'theme_mode',
        mode.toString().split('.').last,
      );
    } catch (e) {
      // Silently fail if saving fails
    }
  }

  void _updateDarkMode() {
    if (_themeMode == ThemeMode.dark) {
      _isDark = true;
    } else if (_themeMode == ThemeMode.light) {
      _isDark = false;
    } else {
      // System mode - would need platform brightness check
      _isDark = false; // Default, will be updated by MaterialApp
    }
  }

  ThemeData getTheme(BuildContext context) {
    return _isDark
        ? AppTheme.darkTheme(context)
        : AppTheme.lightTheme(context);
  }
}

