import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/auth/auth_session.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';

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
    'corrupted secure storage session does not crash when cleanup fails',
    () async {
      final secureStorage = _FakeSecureStorage({
        AuthSessionStorage.sessionKey: '{not-valid-json',
      })..failDelete = true;
      final storage = AuthSessionStorage(secureStorage: secureStorage);

      final session = await storage.read();

      expect(session, isNull);
      expect(
        secureStorage.values,
        contains(AuthSessionStorage.sessionKey),
        reason: 'cleanup failure is logged but must not crash startup',
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

  test('does not persist unused avatar file names in secure storage', () async {
    final secureStorage = _FakeSecureStorage(<String, String>{});
    final storage = AuthSessionStorage(secureStorage: secureStorage);

    await storage.save(_sessionWithAvatarFileName);

    final raw = secureStorage.values[AuthSessionStorage.sessionKey]!;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final user = json['user'] as Map<String, dynamic>;
    final avatar = user['avatar'] as Map<String, dynamic>;

    expect(avatar['url'], 'https://cdn.petmagic.app/avatar.jpg');
    expect(avatar['contentType'], 'image/jpeg');
    expect(avatar, isNot(contains('fileName')));
    expect(raw, isNot(contains('alice-passport-scan.jpg')));
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

  test(
    'keeps a session available when persistent storage write times out',
    () async {
      final storage = AuthSessionStorage(
        secureStorage: _StalledWriteSecureStorage(),
        writeTimeout: const Duration(milliseconds: 1),
      );
      final session = AuthSession.fromJson({
        'accessToken': 'access-token',
        'refreshToken': 'refresh-token',
        'expiresAtUtc': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
        'user': const <String, dynamic>{},
      });

      await storage.save(session);

      expect(await storage.read(), same(session));
    },
  );
}

class _StalledWriteSecureStorage extends FlutterSecureStorage {
  _StalledWriteSecureStorage();

  final _writeCompleter = Completer<void>();

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
  }) => _writeCompleter.future;
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

final _sessionWithAvatarFileName = AuthSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  expiresAtUtc: DateTime.utc(2035),
  user: MobileUserProfile(
    userId: 'user-1',
    email: 'pet@example.com',
    displayName: 'Pet Parent',
    isPremium: false,
    emailConfirmed: true,
    termsOfUseAccepted: true,
    privacyPolicyAccepted: true,
    marketingEmailsEnabled: false,
    legalAcceptance: const MobileLegalAcceptanceStatus(
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
    roles: const ['User'],
    avatar: MobileUserAvatar(
      url: 'https://cdn.petmagic.app/avatar.jpg',
      fileName: 'alice-passport-scan.jpg',
      contentType: 'image/jpeg',
      fileSizeBytes: 12345,
      updatedAtUtc: DateTime.utc(2035),
    ),
  ),
);

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage(this.values);

  final Map<String, String> values;
  final List<String> deletedKeys = <String>[];
  bool failDelete = false;

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
    if (failDelete) {
      throw StateError('secure storage delete failed');
    }

    deletedKeys.add(key);
    values.remove(key);
  }
}
