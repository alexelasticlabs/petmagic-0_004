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
          healthProbe: (_) async => false,
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

  test(
    'first resolve eagerly probes and adopts a reachable candidate',
    () async {
      final previousPreferences = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() {
        SharedPreferencesAsyncPlatform.instance = previousPreferences;
      });

      const persistedBaseUrlKey = 'petmagic_mobile_last_api_base_url';
      final preferences = SharedPreferencesAsync();
      final resolver = ApiBaseUrlResolver(
        preferences: preferences,
        healthProbe: (baseUrl) async => baseUrl == 'http://127.0.0.1:5000',
      );

      addTearDown(resolver.dispose);

      expect(await resolver.resolveBaseUrl(), 'http://127.0.0.1:5000');
      expect(resolver.activeBaseUrl, 'http://127.0.0.1:5000');
      expect(
        await preferences.getString(persistedBaseUrlKey),
        'http://127.0.0.1:5000',
      );
    },
  );

  test(
    'explicit configured base URL ignores stale persisted preference',
    () async {
      final previousPreferences = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() {
        SharedPreferencesAsyncPlatform.instance = previousPreferences;
      });

      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        persistedBaseUrlKey,
        'http://192.168.1.9:5000',
      );

      final probedBaseUrls = <String>[];
      final resolver = ApiBaseUrlResolver(
        preferences: preferences,
        baseUrls: const ['http://127.0.0.1:5000'],
        preferConfiguredBaseUrls: true,
        healthProbe: (baseUrl) async {
          probedBaseUrls.add(baseUrl);
          return true;
        },
      );

      addTearDown(resolver.dispose);

      expect(await resolver.resolveBaseUrl(), 'http://127.0.0.1:5000');
      expect(resolver.activeBaseUrl, 'http://127.0.0.1:5000');
      expect(probedBaseUrls, ['http://127.0.0.1:5000']);
      expect(
        await preferences.getString(persistedBaseUrlKey),
        'http://127.0.0.1:5000',
      );
    },
  );

  test(
    'debug base URL persistence strips path query and fragment secrets',
    () async {
      final previousPreferences = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() {
        SharedPreferencesAsyncPlatform.instance = previousPreferences;
      });

      final preferences = SharedPreferencesAsync();
      final probedBaseUrls = <String>[];
      final resolver = ApiBaseUrlResolver(
        preferences: preferences,
        baseUrls: const [
          'http://127.0.0.1:5000/api?token=raw&signature=secret#debug',
        ],
        healthProbe: (baseUrl) async {
          probedBaseUrls.add(baseUrl);
          return true;
        },
      );

      addTearDown(resolver.dispose);

      expect(await resolver.resolveBaseUrl(), 'http://127.0.0.1:5000');
      expect(probedBaseUrls, ['http://127.0.0.1:5000']);
      expect(
        await preferences.getString(persistedBaseUrlKey),
        'http://127.0.0.1:5000',
      );
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

  test(
    'recent successful base URL resolution skips redundant background probe until stale',
    () async {
      final previousPreferences = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() {
        SharedPreferencesAsyncPlatform.instance = previousPreferences;
      });

      final preferences = SharedPreferencesAsync();
      var now = DateTime.utc(2026, 1, 1, 12);
      var probeCount = 0;
      final resolver = ApiBaseUrlResolver(
        preferences: preferences,
        baseUrls: const ['http://127.0.0.1:5000'],
        backgroundRefreshInterval: const Duration(minutes: 5),
        now: () => now,
        healthProbe: (baseUrl) async {
          probeCount++;
          return baseUrl == 'http://127.0.0.1:5000';
        },
      );

      addTearDown(resolver.dispose);

      expect(await resolver.resolveBaseUrl(), 'http://127.0.0.1:5000');
      expect(probeCount, 1);

      expect(await resolver.resolveBaseUrl(), 'http://127.0.0.1:5000');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        probeCount,
        1,
        reason:
            'recent successful traffic should keep the active base URL warm',
      );

      now = now.add(const Duration(minutes: 6));

      expect(await resolver.resolveBaseUrl(), 'http://127.0.0.1:5000');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        probeCount,
        2,
        reason: 'stale health should trigger a single background re-probe',
      );
    },
  );
}
