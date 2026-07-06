import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_controller.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_storage.dart';

void main() {
  test('app preferences controller does not cache storage in build', () {
    final source = File(
      'lib/app/preferences/app_preferences_controller.dart',
    ).readAsStringSync();

    expect(
      source,
      isNot(contains('late final AppPreferencesStorage _storage')),
    );
    expect(
      source,
      contains(
        'AppPreferencesStorage get _storage => ref.read(appPreferencesStorageProvider)',
      ),
    );
    expect(
      source,
      isNot(contains('_storage = ref.watch(appPreferencesStorageProvider)')),
    );
  });

  test(
    'app preferences controller stops async loading after dispose',
    () async {
      final storage = _DelayedPreferencesStorage();
      final asyncErrors = <Object>[];

      await runZonedGuarded(
        () async {
          final container = ProviderContainer(
            overrides: [
              appPreferencesStorageProvider.overrideWithValue(storage),
            ],
          );

          container.read(appPreferencesControllerProvider);
          await Future<void>.delayed(Duration.zero);

          expect(storage.readThemeModeCalls, 1);
          expect(storage.readLocaleCalls, 0);

          container.dispose();
          storage.themeModeCompleter.complete(ThemeMode.dark);

          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
        },
        (error, stackTrace) {
          asyncErrors.add(error);
        },
      );

      expect(storage.readLocaleCalls, 0);
      expect(asyncErrors, isEmpty);
    },
  );
}

class _DelayedPreferencesStorage implements AppPreferencesStorage {
  final Completer<ThemeMode?> themeModeCompleter = Completer<ThemeMode?>();
  int readThemeModeCalls = 0;
  int readLocaleCalls = 0;

  @override
  Future<ThemeMode?> readThemeMode() {
    readThemeModeCalls += 1;
    return themeModeCompleter.future;
  }

  @override
  Future<Locale?> readLocale() async {
    readLocaleCalls += 1;
    return const Locale('en');
  }

  @override
  Future<void> saveLocale(Locale? locale) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
