import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/network/api_base_url_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  test(
    'background base URL refresh contains async discovery failures',
    () async {
      final previousPreferences = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() {
        SharedPreferencesAsyncPlatform.instance = previousPreferences;
      });

      final uncaughtErrors = <Object>[];

      await runZonedGuarded(() async {
        final resolver = ApiBaseUrlResolver(
          preferences: SharedPreferencesAsync(),
          localSubnetCandidatesProvider: () async {
            throw StateError('local discovery failed');
          },
        );

        addTearDown(resolver.dispose);

        expect(await resolver.resolveBaseUrl(), AppConfig.apiBaseUrl);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }, (error, _) => uncaughtErrors.add(error));

      expect(uncaughtErrors, isEmpty);
    },
  );
}
