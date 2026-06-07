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

    test('rejects urls with userinfo to avoid misleading hosts', () {
      final allowedHosts = premiumExternalAllowedHosts();
      expect(
        parseSafeExternalUri(
          'https://user@petmagic.app/privacy',
          allowedHttpsHosts: allowedHosts,
        ),
        isNull,
      );
      expect(
        parseSafeExternalUri(
          'https://checkout.stripe.com@evil.example/session',
          allowedHttpsHosts: allowedHosts,
        ),
        isNull,
      );
      expect(parseSafeExternalUri('https://user@example.com/path'), isNull);
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

  group('supportExternalAllowedHosts', () {
    test('allows only trusted support attachment origins', () {
      final allowedHosts = supportExternalAllowedHosts();

      expect(
        parseSafeExternalUri(
          'https://cdn.petmagic.ai/support/file.jpg?signature=secret',
          allowedHttpsHosts: allowedHosts,
        ),
        isNotNull,
      );
      expect(
        parseSafeExternalUri(
          'https://api.petmagic.app/api/support/attachments/file',
          allowedHttpsHosts: allowedHosts,
        ),
        isNotNull,
      );
      expect(
        parseSafeExternalUri(
          'https://evil.example/support/file.jpg',
          allowedHttpsHosts: allowedHosts,
        ),
        isNull,
      );
      expect(
        parseSafeExternalUri(
          'https://cdn.petmagic.ai@evil.example/support/file.jpg',
          allowedHttpsHosts: allowedHosts,
        ),
        isNull,
      );
    });

    test('parseSafeSupportExternalUri applies the support allowlist', () {
      expect(
        parseSafeSupportExternalUri('https://cdn.petmagic.ai/support/file.jpg'),
        isNotNull,
      );
      expect(
        parseSafeSupportExternalUri('https://evil.example/support/file.jpg'),
        isNull,
      );
    });
  });

  group('generationMediaAllowedHosts', () {
    test('contains production generation media origins', () {
      final hosts = generationMediaAllowedHosts();

      expect(hosts.contains('api.petmagic.app'), isTrue);
      expect(hosts.contains('cdn.petmagic.app'), isTrue);
      expect(hosts.contains('cdn.petmagic.ai'), isTrue);
    });

    test('allowlist rejects arbitrary generation media origins', () {
      final allowedHosts = generationMediaAllowedHosts();

      expect(
        parseSafeExternalUri(
          'https://cdn.petmagic.ai/generations/result.jpg',
          allowedHttpsHosts: allowedHosts,
        ),
        isNotNull,
      );
      expect(
        parseSafeExternalUri(
          'https://evil.example/generations/result.jpg',
          allowedHttpsHosts: allowedHosts,
        ),
        isNull,
      );
    });
  });

  group('profileAvatarAllowedHosts', () {
    test('allows only trusted avatar origins', () {
      final allowedHosts = profileAvatarAllowedHosts();

      expect(hostsContainsCoreAvatarOrigins(allowedHosts), isTrue);
      expect(
        parseSafeExternalUri(
          'https://cdn.petmagic.ai/avatars/user.jpg',
          allowedHttpsHosts: allowedHosts,
        ),
        isNotNull,
      );
      expect(
        parseSafeExternalUri(
          'https://evil.example/avatars/user.jpg',
          allowedHttpsHosts: allowedHosts,
        ),
        isNull,
      );
      expect(
        parseSafeProfileAvatarUri('https://evil.example/avatars/user.jpg'),
        isNull,
      );
    });
  });
}

bool hostsContainsCoreAvatarOrigins(Set<String> hosts) {
  return hosts.contains('api.petmagic.app') &&
      hosts.contains('cdn.petmagic.app') &&
      hosts.contains('cdn.petmagic.ai');
}
