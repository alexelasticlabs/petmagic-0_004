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

  @override
  AppPreferencesState build() {
    _storage = ref.watch(appPreferencesStorageProvider);
    Future.microtask(_load);
    return const AppPreferencesState.initial();
  }

  Future<void> _load() async {
    if (!ref.mounted) {
      return;
    }

    final savedThemeMode = await _storage.readThemeMode();
    if (!ref.mounted) {
      return;
    }

    final savedLocale = await _storage.readLocale();
    if (!ref.mounted) {
      return;
    }

    state = state.copyWith(
      themeMode: savedThemeMode ?? state.themeMode,
      locale: savedLocale,
      localeWasSet: true,
      hasLoaded: true,
    );
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode, hasLoaded: true);
    await _storage.saveThemeMode(mode);
  }

  Future<void> updateLocale(Locale? locale) async {
    state = state.copyWith(locale: locale, localeWasSet: true, hasLoaded: true);
    await _storage.saveLocale(locale);
  }
}
