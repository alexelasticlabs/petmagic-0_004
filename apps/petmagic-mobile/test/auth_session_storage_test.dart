import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';

void main() {
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
    'ignores missing secure storage session without reviving legacy state',
    () async {
      final secureStorage = _FakeSecureStorage(<String, String>{});
      final storage = AuthSessionStorage(secureStorage: secureStorage);

      final session = await storage.read();

      expect(session, isNull);
      expect(secureStorage.values, isEmpty);
    },
  );

  test('persists auth session only in secure storage', () async {
    final secureStorage = _FakeSecureStorage(<String, String>{});
    final storage = AuthSessionStorage(secureStorage: secureStorage);

    await storage.save(_session);

    expect(secureStorage.values, contains(AuthSessionStorage.sessionKey));
    expect(
      secureStorage.values[AuthSessionStorage.sessionKey],
      contains('"refreshToken":"refresh-token"'),
    );
  });

  test('clear removes auth session from secure storage', () async {
    final secureStorage = _FakeSecureStorage({
      AuthSessionStorage.sessionKey: jsonEncode(_session.toJson()),
    });
    final storage = AuthSessionStorage(secureStorage: secureStorage);

    await storage.clear();

    expect(
      secureStorage.values,
      isNot(contains(AuthSessionStorage.sessionKey)),
    );
  });
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
