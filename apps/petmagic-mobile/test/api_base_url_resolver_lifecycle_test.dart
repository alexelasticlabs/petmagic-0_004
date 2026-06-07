import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/network/api_base_url_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  const persistedBaseUrlKey = 'petmagic_mobile_last_api_base_url';

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

  test('late health probe completion does not mutate after dispose', () async {
    final previousPreferences = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() {
      SharedPreferencesAsyncPlatform.instance = previousPreferences;
    });

    final preferences = SharedPreferencesAsync();
    final probeStarted = Completer<void>();
    final probeResult = Completer<bool>();
    final resolver = ApiBaseUrlResolver(
      preferences: preferences,
      healthProbe: (_) {
        if (!probeStarted.isCompleted) {
          probeStarted.complete();
        }
        return probeResult.future;
      },
    );

    final resolveFuture = resolver.resolveBaseUrl(forceRefresh: true);
    await probeStarted.future;

    resolver.dispose();
    probeResult.complete(true);

    expect(await resolveFuture, AppConfig.apiBaseUrl);
    expect(resolver.activeBaseUrl, isNull);
    expect(await preferences.getString(persistedBaseUrlKey), isNull);
    expect(
      await resolver.resolveBaseUrl(forceRefresh: true),
      AppConfig.apiBaseUrl,
    );
  });
}
