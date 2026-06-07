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
}
