import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier with ChangeNotifier {
  final String key = "theme_mode";
  SharedPreferences? _prefs;
  late ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  ThemeNotifier() {
    // Set default theme to system
    _themeMode = ThemeMode.system;
    _loadFromPrefs();
  }

  _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  _loadFromPrefs() async {
    await _initPrefs();
    String? themeString = _prefs!.getString(key);
    if (themeString == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeString == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  _saveToPrefs(ThemeMode themeMode) async {
    await _initPrefs();
    if (themeMode == ThemeMode.light) {
      _prefs!.setString(key, 'light');
    } else if (themeMode == ThemeMode.dark) {
      _prefs!.setString(key, 'dark');
    } else {
      _prefs!.setString(key, 'system');
    }
  }

  void setTheme(ThemeMode themeMode) {
    if (_themeMode == themeMode) return;

    _themeMode = themeMode;
    _saveToPrefs(themeMode);
    notifyListeners();
  }
}

