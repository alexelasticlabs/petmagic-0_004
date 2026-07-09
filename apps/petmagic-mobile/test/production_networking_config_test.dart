import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production mobile manifests do not allow local or cleartext networking',
    () {
      final androidManifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final iosInfo = File('ios/Runner/Info.plist').readAsStringSync();

      expect(androidManifest, contains('android:usesCleartextTraffic="false"'));
      expect(iosInfo, isNot(contains('NSAllowsLocalNetworking')));
      expect(iosInfo, isNot(contains('NSAllowsArbitraryLoads')));
      expect(iosInfo, isNot(contains('NSExceptionAllowsInsecureHTTPLoads')));
    },
  );

  test('iOS release config does not disable Flutter Impeller rendering', () {
    final iosInfo = File('ios/Runner/Info.plist').readAsStringSync();

    expect(iosInfo, contains('CADisableMinimumFrameDurationOnPhone'));
    expect(iosInfo, isNot(contains('FLTEnableImpeller')));
  });

  test('release API resolver keeps local network discovery debug-only', () {
    final resolver = File(
      'lib/core/network/api_base_url_resolver.dart',
    ).readAsStringSync();

    expect(
      resolver,
      contains(
        'if (kDebugMode && !kIsWeb) {\n'
        '      final subnetCandidates = await _readLocalSubnetCandidates();',
      ),
    );
    expect(
      resolver,
      contains(
        'if (!kDebugMode) {\n'
        '      return AppConfig.normalizeProductionBaseUrl(trimmed);',
      ),
    );
    expect(
      resolver,
      contains('await _preferences.remove(_persistedBaseUrlKey);'),
    );
    expect(resolver, contains("if (!kDebugMode) {\n      return const [];"));
  });

  test('release API config rejects dev origins before Dio can use them', () {
    final config = File('lib/core/config/app_config.dart').readAsStringSync();

    expect(
      config,
      contains(
        'if (!kDebugMode) {\n'
        '        final productionBaseUrl = normalizeProductionBaseUrl(',
      ),
    );
    expect(config, contains("return const [productionApiBaseUrl];"));
    expect(config, contains("static const productionApiBaseUrl = 'https://"));
    expect(
      config,
      isNot(contains("static const productionApiBaseUrl = 'http://")),
    );
  });

  test('release Dio and health probes do not send tunnel bypass headers', () {
    final dioProvider = File(
      'lib/core/network/dio_provider.dart',
    ).readAsStringSync();
    final resolver = File(
      'lib/core/network/api_base_url_resolver.dart',
    ).readAsStringSync();

    expect(
      dioProvider,
      contains(
        'if (kDebugMode) {\n'
        "    headers['ngrok-skip-browser-warning'] = 'true';\n"
        "    headers['Bypass-Tunnel-Reminder'] = 'true';",
      ),
    );
    expect(
      resolver,
      contains(
        'if (kDebugMode) {\n'
        "        request.headers.set('ngrok-skip-browser-warning', 'true');\n"
        "        request.headers.set('Bypass-Tunnel-Reminder', 'true');",
      ),
    );
  });

  test('Dio provider closes HTTP client when app scope is disposed', () {
    final dioProvider = File(
      'lib/core/network/dio_provider.dart',
    ).readAsStringSync();

    expect(
      dioProvider,
      contains('ref.onDispose(() => dio.close(force: true));'),
    );
  });

  test('API base URL resolver logs only sanitized origins', () {
    final resolver = File(
      'lib/core/network/api_base_url_resolver.dart',
    ).readAsStringSync();

    expect(resolver, contains("'base_url_origin': _logSafeBaseUrlOrigin("));
    expect(resolver, contains('String _logSafeBaseUrlOrigin(String baseUrl)'));
    expect(resolver, isNot(contains("context: {'base_url':")));
  });

  test(
    'android release keeps FCM auto init while smoke manifests disable it',
    () {
      final mainManifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final debugManifest = File(
        'android/app/src/debug/AndroidManifest.xml',
      ).readAsStringSync();
      final profileManifest = File(
        'android/app/src/profile/AndroidManifest.xml',
      ).readAsStringSync();

      expect(mainManifest, contains('firebase_messaging_auto_init_enabled'));
      expect(
        mainManifest,
        contains(
          'android:name="firebase_messaging_auto_init_enabled"\n'
          '            android:value="true"',
        ),
      );
      for (final manifest in [debugManifest, profileManifest]) {
        expect(manifest, contains('firebase_messaging_auto_init_enabled'));
        expect(manifest, contains('android:value="false"'));
        expect(manifest, contains('tools:replace="android:value"'));
      }
    },
  );
}
