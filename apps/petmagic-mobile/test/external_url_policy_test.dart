import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

void main() {
  group('parseSafeExternalUri', () {
    test('returns null for empty or malformed values', () {
      expect(parseSafeExternalUri(null), isNull);
      expect(parseSafeExternalUri('   '), isNull);
      expect(parseSafeExternalUri('not a url'), isNull);
      expect(parseSafeExternalUri('javascript:alert(1)'), isNull);
    });

    test('allows https url when no allowlist is provided', () {
      final uri = parseSafeExternalUri('https://petmagic.app/terms');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'petmagic.app');
    });

    test('enforces https allowlist when provided', () {
      final allowedHosts = premiumExternalAllowedHosts();
      expect(
        parseSafeExternalUri(
          'https://petmagic.app/privacy',
          allowedHttpsHosts: allowedHosts,
        ),
        isNotNull,
      );
      expect(
        parseSafeExternalUri(
          'https://evil.example/phish',
          allowedHttpsHosts: allowedHosts,
        ),
        isNull,
      );
    });

    test('allows debug http only for local/private hosts', () {
      expect(parseSafeExternalUri('http://localhost:5000/health'), isNotNull);
      expect(parseSafeExternalUri('http://127.0.0.1:5000/health'), isNotNull);
      expect(
        parseSafeExternalUri('http://192.168.1.25:5000/health'),
        isNotNull,
      );
      expect(parseSafeExternalUri('http://10.0.0.42:5000/health'), isNotNull);
      expect(parseSafeExternalUri('http://example.com/unsafe'), isNull);
    });
  });

  group('premiumExternalAllowedHosts', () {
    test('contains core trusted hosts', () {
      final hosts = premiumExternalAllowedHosts();
      expect(hosts.contains('petmagic.app'), isTrue);
      expect(hosts.contains('api.petmagic.app'), isTrue);
      expect(hosts.contains('checkout.stripe.com'), isTrue);
    });
  });
}
