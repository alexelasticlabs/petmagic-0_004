import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesStorage {
  static const _themeModeKey = 'petmagic_mobile_theme_mode';
  static const _localeKey = 'petmagic_mobile_locale';

  Future<ThemeMode?> readThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(_themeModeKey);

    return switch (rawValue) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

    await preferences.setString(_themeModeKey, value);
  }

  Future<Locale?> readLocale() async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(_localeKey);
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    final parts = rawValue.split('_');
    if (parts.length == 1) {
      return Locale(parts.first);
    }

    return Locale(parts.first, parts.last);
  }

  Future<void> saveLocale(Locale? locale) async {
    final preferences = await SharedPreferences.getInstance();

    if (locale == null) {
      await preferences.remove(_localeKey);
      return;
    }

    final value = locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';

    await preferences.setString(_localeKey, value);
  }
}
