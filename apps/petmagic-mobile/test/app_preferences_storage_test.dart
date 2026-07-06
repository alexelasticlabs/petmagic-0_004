import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const themeModeKey = 'petmagic_mobile_theme_mode';
  const localeKey = 'petmagic_mobile_locale';

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('clears invalid persisted theme mode', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(themeModeKey, 'midnight');

    final storage = AppPreferencesStorage();

    expect(await storage.readThemeMode(), isNull);
    expect(await preferences.getString(themeModeKey), isNull);
  });

  test('clears malformed persisted locale', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(localeKey, 'ru_RU_POSIX');

    final storage = AppPreferencesStorage();

    expect(await storage.readLocale(), isNull);
    expect(await preferences.getString(localeKey), isNull);
  });

  test('clears unsupported persisted locale', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(localeKey, 'ja');

    final storage = AppPreferencesStorage();

    expect(await storage.readLocale(), isNull);
    expect(await preferences.getString(localeKey), isNull);
  });

  test('normalizes legacy hyphenated persisted locale', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(localeKey, 'en-US');

    final storage = AppPreferencesStorage();
    final locale = await storage.readLocale();

    expect(locale, const Locale('en', 'US'));
    expect(await preferences.getString(localeKey), 'en_US');
  });
}
