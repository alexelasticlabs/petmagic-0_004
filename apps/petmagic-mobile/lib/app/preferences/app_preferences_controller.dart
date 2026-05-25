import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_storage.dart';

final appPreferencesStorageProvider = Provider<AppPreferencesStorage>((ref) {
  return AppPreferencesStorage();
});

final appPreferencesControllerProvider =
    NotifierProvider<AppPreferencesController, AppPreferencesState>(
      AppPreferencesController.new,
    );

class AppPreferencesState {
  const AppPreferencesState({
    required this.themeMode,
    required this.locale,
    required this.hasLoaded,
  });

  const AppPreferencesState.initial()
    : this(themeMode: ThemeMode.system, locale: null, hasLoaded: false);

  final ThemeMode themeMode;
  final Locale? locale;
  final bool hasLoaded;

  AppPreferencesState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool localeWasSet = false,
    bool? hasLoaded,
  }) {
    return AppPreferencesState(
      themeMode: themeMode ?? this.themeMode,
      locale: localeWasSet ? locale : this.locale,
      hasLoaded: hasLoaded ?? this.hasLoaded,
    );
  }
}

class AppPreferencesController extends Notifier<AppPreferencesState> {
  late final AppPreferencesStorage _storage;

  static const _legacyEnglishUsLocale = Locale('en', 'US');
  static const _englishLocale = Locale('en');

  @override
  AppPreferencesState build() {
    _storage = ref.watch(appPreferencesStorageProvider);
    Future.microtask(_load);
    return const AppPreferencesState.initial();
  }

  Future<void> _load() async {
    final savedThemeMode = await _storage.readThemeMode();
    final savedLocale = await _storage.readLocale();
    final normalizedLocale = _normalizeLocale(savedLocale);

    state = state.copyWith(
      themeMode: savedThemeMode ?? state.themeMode,
      locale: normalizedLocale,
      localeWasSet: true,
      hasLoaded: true,
    );

    if (savedLocale != normalizedLocale) {
      await _storage.saveLocale(normalizedLocale);
    }
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode, hasLoaded: true);
    await _storage.saveThemeMode(mode);
  }

  Future<void> updateLocale(Locale? locale) async {
    final normalizedLocale = _normalizeLocale(locale);
    state = state.copyWith(
      locale: normalizedLocale,
      localeWasSet: true,
      hasLoaded: true,
    );
    await _storage.saveLocale(normalizedLocale);
  }

  Locale? _normalizeLocale(Locale? locale) {
    if (locale == null) {
      return null;
    }

    if (locale.languageCode == _legacyEnglishUsLocale.languageCode &&
        locale.countryCode == _legacyEnglishUsLocale.countryCode) {
      return _englishLocale;
    }

    return locale;
  }
}
