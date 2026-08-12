import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _textScaleFactor = 1.0;
  late final Future<void> _ready;
  int _themeRevision = 0;
  int _textScaleRevision = 0;

  ThemeMode get themeMode => _themeMode;
  double get textScaleFactor => _textScaleFactor;
  Future<void> get ready => _ready;

  SettingsProvider() {
    _ready = _loadSettings();
  }

  Future<void> _loadSettings() async {
    final themeRevision = _themeRevision;
    final textScaleRevision = _textScaleRevision;
    final prefs = await SharedPreferences.getInstance();

    if (themeRevision == _themeRevision) {
      final storedTheme = prefs.getString('theme_mode');
      final legacyIsDark = prefs.getBool('is_dark_mode');
      _themeMode = _themeModeFromStorage(storedTheme) ??
          (legacyIsDark == null
              ? ThemeMode.system
              : legacyIsDark
                  ? ThemeMode.dark
                  : ThemeMode.light);
    }

    if (textScaleRevision == _textScaleRevision) {
      _textScaleFactor = prefs.getDouble('text_scale_factor') ?? 1.0;
    }
    notifyListeners();
  }

  ThemeMode? _themeModeFromStorage(String? value) {
    switch (value) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return null;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeRevision++;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
    await prefs.remove('is_dark_mode');
  }

  /// Compatibilidad con llamadas antiguas; las nuevas pantallas deben usar
  /// [setThemeMode] para poder elegir también el modo del sistema.
  Future<void> toggleTheme(bool isDark) {
    return setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setTextScale(double scale) async {
    _textScaleRevision++;
    _textScaleFactor = scale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('text_scale_factor', scale);
  }
}
