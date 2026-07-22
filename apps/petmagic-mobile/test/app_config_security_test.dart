import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';

void main() {
  test('production API base URL allowlist rejects non-production origins', () {
    expect(
      AppConfig.normalizeProductionBaseUrl('https://api.petmagic.app'),
      'https://api.petmagic.app',
    );
    expect(
      AppConfig.normalizeProductionBaseUrl('https://api.petmagic.app/'),
      'https://api.petmagic.app',
    );
    expect(
      AppConfig.normalizeProductionBaseUrl('https://api.petmagic.app:443'),
      'https://api.petmagic.app',
    );
    expect(
      AppConfig.isProductionSafeBaseUrl('https://api.petmagic.app'),
      isTrue,
    );

    for (final unsafeUrl in const [
      'http://api.petmagic.app',
      'https://api.petmagic.app:5000',
      'https://staging-api.petmagic.app',
      'https://dev.petmagic.app',
      'https://evil.example',
      'https://api.petmagic.app/v1',
      'https://user@api.petmagic.app',
      'https://api.petmagic.app?x=1',
      'https://api.petmagic.app#debug',
      'https://localhost:5000',
      'https://localhost:5001',
      'https://10.0.2.2:5000',
      'https://10.0.2.2:5001',
      'https://192.168.1.20:5000',
    ]) {
      expect(
        AppConfig.isProductionSafeBaseUrl(unsafeUrl),
        isFalse,
        reason: unsafeUrl,
      );
    }
  });

  test('release flavor configuration must match API and package identity', () {
    expect(
      AppConfig.normalizeReleaseBaseUrl(
        'https://api.staging.petmagic.app',
        environment: 'staging',
      ),
      AppConfig.stagingApiBaseUrl,
    );
    expect(
      AppConfig.normalizeReleaseBaseUrl(
        'https://api.staging.petmagic.app',
        environment: 'production',
      ),
      isNull,
    );

    expect(
      () => AppConfig.validateReleaseConfiguration(
        isReleaseBuild: true,
        environment: 'staging',
        apiBaseUrl: AppConfig.stagingApiBaseUrl,
        packageName: 'com.petmagic.app.staging',
      ),
      returnsNormally,
    );
    expect(
      () => AppConfig.validateReleaseConfiguration(
        isReleaseBuild: true,
        environment: 'production',
        apiBaseUrl: AppConfig.stagingApiBaseUrl,
        packageName: 'com.petmagic.app',
      ),
      throwsStateError,
    );
  });

  test('profile builds keep an explicit local API URL for device QA', () {
    expect(
      AppConfig.resolveApiBaseUrls(
        configuredBaseUrl: 'http://127.0.0.1:5001',
        isDebugBuild: false,
        isReleaseBuild: false,
        isWebBuild: false,
        isAndroidDevice: true,
      ),
      const ['http://127.0.0.1:5001'],
    );
  });

  test('release builds still reject an explicit local API URL', () {
    expect(
      AppConfig.resolveApiBaseUrls(
        configuredBaseUrl: 'http://127.0.0.1:5001',
        isDebugBuild: false,
        isReleaseBuild: true,
        isWebBuild: false,
        isAndroidDevice: true,
      ),
      const [AppConfig.productionApiBaseUrl],
    );
  });

  test('deep-link schemes are isolated by release environment', () {
    expect(
      AppConfig.deepLinkSchemeForEnvironment('production'),
      AppConfig.productionDeepLinkScheme,
    );
    expect(
      AppConfig.deepLinkSchemeForEnvironment('staging'),
      AppConfig.stagingDeepLinkScheme,
    );
    expect(
      AppConfig.isExpectedDeepLinkScheme(
        'petmagic-staging',
        environment: 'staging',
      ),
      isTrue,
    );
    expect(
      AppConfig.isExpectedDeepLinkScheme('petmagic', environment: 'staging'),
      isFalse,
    );
    expect(
      AppConfig.isExpectedDeepLinkScheme(
        'petmagic-staging',
        environment: 'production',
      ),
      isFalse,
    );
    expect(AppConfig.deepLinkSchemeForEnvironment('unexpected'), isNull);
  });

  test(
    'production API base URL allowlist rejects configured debug candidates',
    () {
      final configSource = [
        File('lib/core/config/app_config.dart').readAsStringSync(),
        File(
          'lib/core/config/api_base_url_config_resolver.dart',
        ).readAsStringSync(),
      ].join('\n');
      final debugApiCandidates = RegExp(r"'(http://[^']+)'")
          .allMatches(configSource)
          .map((match) => match.group(1)!)
          .where((url) => url.contains(RegExp(r':500[01]')))
          .toSet();

      expect(
        debugApiCandidates,
        containsAll(<String>{
          'http://10.0.2.2:5000',
          'http://10.0.2.2:5001',
          'http://host.docker.internal:5000',
          'http://host.docker.internal:5001',
          'http://10.0.3.2:5000',
          'http://10.0.3.2:5001',
          'http://127.0.0.1:5000',
          'http://127.0.0.1:5001',
          'http://localhost:5000',
          'http://localhost:5001',
        }),
      );

      for (final debugUrl in debugApiCandidates) {
        expect(
          AppConfig.isProductionSafeBaseUrl(debugUrl),
          isFalse,
          reason: debugUrl,
        );
      }
    },
  );

  test('release API resolver normalizes persisted URLs through allowlist', () {
    final policySource = File(
      'lib/core/network/api_base_url_policy.dart',
    ).readAsStringSync();

    expect(
      policySource,
      contains('return AppConfig.normalizeProductionBaseUrl(trimmed);'),
    );
  });
}
