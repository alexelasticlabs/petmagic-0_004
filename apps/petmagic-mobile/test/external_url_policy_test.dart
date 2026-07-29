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
      final uri = parseSafeExternalUri('https://petgpt.app/terms');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'petgpt.app');
    });

    test('rejects private and local https urls before external handoff', () {
      for (final host in const [
        'localhost',
        'media.localhost',
        '127.0.0.1',
        '0.0.0.0',
        '0.0.0.1',
        '10.0.0.42',
        '100.64.0.1',
        '169.254.169.254',
        '192.168.1.25',
        '2130706433',
        '0x7f000001',
        '0177.0.0.1',
        '127.1',
        '127.0.1',
        '0300.0250.0001.0001',
        '[::1]',
        '[::]',
        '[0:0:0:0:0:0:0:0]',
        '[0:0:0:0:0:0:0:1]',
        '[fd00::1]',
        '[fe90::1]',
        '[fec0::1]',
        '[ff02::1]',
        '[fe80::1]',
        '[::ffff:127.0.0.1]',
        '[::127.0.0.1]',
        '[::7f00:1]',
        '[0:0:0:0:0:ffff:7f00:1]',
        '[0:0:0:0:0:ffff:127.0.0.1]',
        '[0:0:0:0:0:0:7f00:1]',
        '[0:0:0:0:0:0:127.0.0.1]',
        '[::ffff:10.0.0.5]',
      ]) {
        expect(
          parseSafeExternalUri('https://$host/media/template.mp4'),
          isNull,
          reason: host,
        );
      }
    });

    test('enforces https allowlist when provided', () {
      final allowedHosts = premiumExternalAllowedHosts();
      expect(
        parseSafeExternalUri(
          'https://petgpt.app/privacy',
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
          'https://user@petgpt.app/privacy',
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
      expect(parseSafeExternalUri('http://172.16.0.42:5000/health'), isNotNull);
      expect(parseSafeExternalUri('http://172.31.0.42:5000/health'), isNotNull);
      expect(parseSafeExternalUri('http://0.0.0.0:5000/health'), isNull);
      expect(parseSafeExternalUri('http://100.64.0.1:5000/health'), isNull);
      expect(
        parseSafeExternalUri('http://169.254.169.254/latest/meta-data'),
        isNull,
      );
      expect(parseSafeExternalUri('http://224.0.0.1:5000/health'), isNull);
      expect(
        parseSafeExternalUri('http://[0:0:0:0:0:0:0:1]:5000/health'),
        isNull,
      );
      expect(parseSafeExternalUri('http://2130706433:5000/health'), isNull);
      expect(parseSafeExternalUri('http://0x7f000001:5000/health'), isNull);
      expect(parseSafeExternalUri('http://example.com/unsafe'), isNull);
    });

    test('rejects every local debug http host when local http is disabled', () {
      for (final localHost in const [
        'localhost',
        'media.localhost',
        '127.0.0.1',
        '0.0.0.0',
        '0.0.0.1',
        '10.0.2.2',
        '10.0.3.2',
        'host.docker.internal',
        '192.168.1.25',
        '10.0.0.42',
        '100.64.0.1',
        '169.254.169.254',
        '224.0.0.1',
        '2130706433',
        '0x7f000001',
        '0177.0.0.1',
        '127.1',
        '127.0.1',
        '0300.0250.0001.0001',
        '[ff02::1]',
      ]) {
        expect(
          parseSafeExternalUri(
            'http://$localHost:5000/media/template.mp4',
            allowLocalHttp: false,
          ),
          isNull,
          reason: localHost,
        );
      }

      expect(
        parseSafeExternalUri(
          'http://example.com/media/template.mp4',
          allowLocalHttp: true,
        ),
        isNull,
      );
    });
  });

  group('premiumExternalAllowedHosts', () {
    test('contains core trusted hosts', () {
      final hosts = premiumExternalAllowedHosts();
      expect(hosts.contains('petgpt.app'), isTrue);
      expect(hosts.contains('api.petgpt.app'), isTrue);
      expect(hosts.contains('checkout.stripe.com'), isTrue);
      expect(hosts.contains('petmagic.app'), isFalse);
      expect(hosts.contains('api.petmagic.app'), isFalse);
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
          'https://api.petgpt.app/api/support/attachments/file',
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

      expect(hosts.contains('api.petgpt.app'), isTrue);
      expect(hosts.contains('cdn.petgpt.app'), isTrue);
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
          'https://example-account.r2.cloudflarestorage.com/petmagic/templates-media/result.jpg',
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

  group('generationShareAllowedHosts', () {
    test('allows only trusted generation share origins', () {
      expect(
        parseSafeGenerationShareUri(
          'https://app.petgpt.app/share/generation/token',
        ),
        isNotNull,
      );
      expect(
        parseSafeGenerationShareUri(
          'https://api.petgpt.app/share/generation/token',
        ),
        isNotNull,
      );
      expect(
        parseSafeGenerationShareUri(
          'https://evil.example/share/generation/token',
        ),
        isNull,
      );
      expect(
        parseSafeGenerationShareUri(
          'https://app.petgpt.app@evil.example/share/generation/token',
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
          'https://example-account.r2.cloudflarestorage.com/petmagic/templates-media/avatar.jpg',
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

  test(
    'allows public legacy IPv4 numeric encodings when no host allowlist is provided',
    () {
      expect(parseSafeExternalUri('https://134744072/public'), isNotNull);
      expect(parseSafeExternalUri('https://0x08080808/public'), isNotNull);
    },
  );
}

bool hostsContainsCoreAvatarOrigins(Set<String> hosts) {
  return hosts.contains('api.petgpt.app') &&
      hosts.contains('cdn.petgpt.app') &&
      hosts.contains('cdn.petmagic.ai');
}
