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
      'https://10.0.2.2:5000',
      'https://192.168.1.20:5000',
    ]) {
      expect(
        AppConfig.isProductionSafeBaseUrl(unsafeUrl),
        isFalse,
        reason: unsafeUrl,
      );
    }
  });

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
