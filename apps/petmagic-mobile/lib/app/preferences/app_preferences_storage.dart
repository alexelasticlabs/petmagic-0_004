import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesStorage {
  static const _themeModeKey = 'petmagic_mobile_theme_mode';
  static const _localeKey = 'petmagic_mobile_locale';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<ThemeMode?> readThemeMode() async {
    final rawValue = await _preferences.getString(_themeModeKey);

    return switch (rawValue) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => await _clearInvalidThemeMode(rawValue),
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

    await _preferences.setString(_themeModeKey, value);
  }

  Future<Locale?> readLocale() async {
    final rawValue = await _preferences.getString(_localeKey);
    if (rawValue == null) {
      return null;
    }

    final normalizedValue = rawValue.trim().replaceAll('-', '_');
    if (normalizedValue.isEmpty) {
      await _preferences.remove(_localeKey);
      return null;
    }

    final parts = normalizedValue.split('_');
    if (parts.length > 2 ||
        parts.any((part) => part.isEmpty) ||
        !_isLanguageCode(parts.first)) {
      await _preferences.remove(_localeKey);
      return null;
    }

    final languageCode = parts.first.toLowerCase();
    if (!_isSupportedLanguage(languageCode)) {
      await _preferences.remove(_localeKey);
      return null;
    }

    String? countryCode;
    if (parts.length == 2) {
      if (!_isCountryCode(parts.last)) {
        await _preferences.remove(_localeKey);
        return null;
      }
      countryCode = parts.last.toUpperCase();
    }

    final persistedValue = countryCode == null
        ? languageCode
        : '${languageCode}_$countryCode';
    if (persistedValue != rawValue) {
      await _preferences.setString(_localeKey, persistedValue);
    }

    return Locale(languageCode, countryCode);
  }

  Future<void> saveLocale(Locale? locale) async {
    if (locale == null) {
      await _preferences.remove(_localeKey);
      return;
    }

    final value = locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';

    await _preferences.setString(_localeKey, value);
  }

  Future<ThemeMode?> _clearInvalidThemeMode(String? rawValue) async {
    if (rawValue != null) {
      await _preferences.remove(_themeModeKey);
    }
    return null;
  }

  bool _isLanguageCode(String value) {
    return RegExp(r'^[a-zA-Z]{2}$').hasMatch(value);
  }

  bool _isCountryCode(String value) {
    return RegExp(r'^[a-zA-Z]{2}$').hasMatch(value);
  }

  bool _isSupportedLanguage(String languageCode) {
    return AppLocalizations.supportedLocales.any(
      (locale) => locale.languageCode == languageCode,
    );
  }
}
