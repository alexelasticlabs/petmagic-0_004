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

  test(
    'production API base URL allowlist rejects configured debug candidates',
    () {
      final configSource = File(
        'lib/core/config/app_config.dart',
      ).readAsStringSync();
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
    final resolverSource = File(
      'lib/core/network/api_base_url_resolver.dart',
    ).readAsStringSync();

    expect(
      resolverSource,
      contains('return AppConfig.normalizeProductionBaseUrl(trimmed);'),
    );
  });
}
