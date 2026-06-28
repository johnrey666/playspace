import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Holds the user's theme preferences (light/dark/system + accent color) and
/// persists them with shared_preferences so they survive restarts.
class ThemeController extends ChangeNotifier {
  ThemeController() {
    _load();
  }

  static const _modeKey = 'theme_mode';
  static const _seedKey = 'theme_seed';

  ThemeMode _mode = ThemeMode.system;
  Color _seed = AppTheme.seed;

  ThemeMode get mode => _mode;
  Color get seed => _seed;

  bool isDark(BuildContext context) {
    if (_mode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _mode == ThemeMode.dark;
  }

  /// Preset accent colors offered in the picker.
  static const List<Color> presetColors = [
    Color(0xFF6D5DF6), // indigo (default)
    Color(0xFF2563EB), // blue
    Color(0xFF7C3AED), // violet
    Color(0xFFEC4899), // pink
    Color(0xFFEF4444), // red
    Color(0xFFF97316), // orange
    Color(0xFFEAB308), // amber
    Color(0xFF10B981), // emerald
    Color(0xFF06B6D4), // cyan
    Color(0xFF0F172A), // slate
  ];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_modeKey);
    final seedValue = prefs.getInt(_seedKey);
    if (modeIndex != null && modeIndex >= 0 && modeIndex < ThemeMode.values.length) {
      _mode = ThemeMode.values[modeIndex];
    }
    if (seedValue != null) _seed = Color(seedValue);
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modeKey, mode.index);
  }

  Future<void> toggleDark(bool dark) =>
      setMode(dark ? ThemeMode.dark : ThemeMode.light);

  Future<void> setSeed(Color color) async {
    _seed = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedKey, color.toARGB32());
  }
}
