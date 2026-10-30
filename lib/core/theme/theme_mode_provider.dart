import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide theme mode (System / Claro / Oscuro), persisted to SharedPreferences
/// so the choice survives restarts. Wired into [MaterialApp.router] in main.dart.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _prefKey = 'app_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      state = _fromString(raw);
    } catch (_) {
      // Keep the default on any read failure.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.name);
    } catch (_) {
      // Non-fatal: the in-memory state still applies for this session.
    }
  }

  static ThemeMode _fromString(String? raw) {
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
