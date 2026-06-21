import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  test(
    'clears corrupted secure storage session after decode failure',
    () async {
      final secureStorage = _FakeSecureStorage({
        AuthSessionStorage.sessionKey: '{not-valid-json',
      });
      final storage = AuthSessionStorage(secureStorage: secureStorage);

      final session = await storage.read();

      expect(session, isNull);
      expect(
        secureStorage.values,
        isNot(contains(AuthSessionStorage.sessionKey)),
      );
      expect(
        secureStorage.deletedKeys,
        contains(AuthSessionStorage.sessionKey),
      );
    },
  );

  test(
    'removes legacy shared preferences session without restoring tokens',
    () async {
      SharedPreferences.setMockInitialValues({
        AuthSessionStorage.sessionKey:
            '{"accessToken":"legacy-access","refreshToken":"legacy-refresh"}',
      });
      final secureStorage = _FakeSecureStorage(<String, String>{});
      final storage = AuthSessionStorage(secureStorage: secureStorage);

      final session = await storage.read();
      await _flushMicrotasks();
      final preferences = await SharedPreferences.getInstance();

      expect(session, isNull);
      expect(preferences.containsKey(AuthSessionStorage.sessionKey), isFalse);
      expect(secureStorage.values, isEmpty);
    },
  );

  test('persists auth session only in secure storage', () async {
    final secureStorage = _FakeSecureStorage(<String, String>{});
    final storage = AuthSessionStorage(secureStorage: secureStorage);

    await storage.save(_session);
    final preferences = await SharedPreferences.getInstance();

    expect(preferences.containsKey(AuthSessionStorage.sessionKey), isFalse);
    expect(secureStorage.values, contains(AuthSessionStorage.sessionKey));
    expect(
      secureStorage.values[AuthSessionStorage.sessionKey],
      contains('"refreshToken":"refresh-token"'),
    );
  });

  test(
    'clear removes auth session from secure storage and legacy shared preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        AuthSessionStorage.sessionKey:
            '{"accessToken":"legacy-access","refreshToken":"legacy-refresh"}',
      });
      final secureStorage = _FakeSecureStorage({
        AuthSessionStorage.sessionKey: jsonEncode(_session.toJson()),
      });
      final storage = AuthSessionStorage(secureStorage: secureStorage);

      await storage.clear();
      final preferences = await SharedPreferences.getInstance();

      expect(
        secureStorage.values,
        isNot(contains(AuthSessionStorage.sessionKey)),
      );
      expect(preferences.containsKey(AuthSessionStorage.sessionKey), isFalse);
    },
  );

  test(
    'retries legacy shared preferences cleanup after transient failure',
    () async {
      SharedPreferences.setMockInitialValues({
        AuthSessionStorage.sessionKey:
            '{"accessToken":"legacy-access","refreshToken":"legacy-refresh"}',
      });
      final secureStorage = _FakeSecureStorage(<String, String>{});
      var loaderCalls = 0;
      final storage = AuthSessionStorage(
        secureStorage: secureStorage,
        legacyPreferencesLoader: () async {
          loaderCalls += 1;
          if (loaderCalls == 1) {
            throw StateError('preferences unavailable');
          }
          return SharedPreferences.getInstance();
        },
      );

      expect(await storage.read(), isNull);
      await _flushMicrotasks();
      var preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey(AuthSessionStorage.sessionKey), isTrue);

      await storage.clear();
      preferences = await SharedPreferences.getInstance();

      expect(loaderCalls, 2);
      expect(preferences.containsKey(AuthSessionStorage.sessionKey), isFalse);
    },
  );

  test('bounded legacy cleanup does not block secure session read', () async {
    final secureStorage = _FakeSecureStorage({
      AuthSessionStorage.sessionKey: jsonEncode(_session.toJson()),
    });
    final legacyPreferencesCompleter = Completer<SharedPreferences>();
    final storage = AuthSessionStorage(
      secureStorage: secureStorage,
      legacyCleanupTimeout: const Duration(milliseconds: 200),
      legacyPreferencesLoader: () => legacyPreferencesCompleter.future,
    );

    final stopwatch = Stopwatch()..start();
    final session = await storage.read();
    stopwatch.stop();

    expect(session?.accessToken, 'access-token');
    expect(session?.refreshToken, 'refresh-token');
    expect(stopwatch.elapsedMilliseconds, lessThan(100));

    await Future<void>.delayed(const Duration(milliseconds: 240));
  });
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final _session = AuthSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  expiresAtUtc: DateTime.utc(2035),
  user: const MobileUserProfile(
    userId: 'user-1',
    email: 'pet@example.com',
    displayName: 'Pet Parent',
    isPremium: false,
    emailConfirmed: true,
    termsOfUseAccepted: true,
    privacyPolicyAccepted: true,
    marketingEmailsEnabled: false,
    legalAcceptance: MobileLegalAcceptanceStatus(
      termsOfUseAccepted: true,
      termsOfUseAcceptedVersion: '1',
      termsOfUseAcceptedAtUtc: null,
      privacyPolicyAccepted: true,
      privacyPolicyAcceptedVersion: '1',
      privacyPolicyAcceptedAtUtc: null,
      currentTermsOfUseVersion: '1',
      currentPrivacyPolicyVersion: '1',
      requiresAcceptance: false,
    ),
    roles: ['User'],
    avatar: null,
  ),
);

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage(this.values);

  final Map<String, String> values;
  final List<String> deletedKeys = <String>[];

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
      return;
    }

    values[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    deletedKeys.add(key);
    values.remove(key);
  }
}
