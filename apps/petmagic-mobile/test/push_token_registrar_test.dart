import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/notifications/push_token_registration_cache.dart';
import 'package:petmagic_mobile/app/notifications/push_token_registrar.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await PushTokenRegistrar.clearRegistrationState(
      registrationCache: _registrationCache(),
    );
  });

  test(
    'clearing registration state forces backend registration again for the next user',
    () async {
      final templateRepository = _RecordingTemplateGenerationRepository();
      final supportRepository = _RecordingSupportChatRepository();
      final walletRepository = _RecordingWalletRepository();
      final cache = _registrationCache();
      final registrar = PushTokenRegistrar(
        templateRepository: templateRepository,
        supportRepository: supportRepository,
        walletRepository: walletRepository,
        sessionStorage: _SignedInAuthSessionStorage('user-1'),
        registrationCache: cache,
      );

      await registrar.registerToken(
        token: 'device-token',
        platform: 'android',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );
      expect(templateRepository.registerCalls, 1);
      expect(supportRepository.registerCalls, 1);
      expect(walletRepository.registerCalls, 1);
      final persistedKey = await cache.readLastCompletedRegistrationKey();
      expect(persistedKey, startsWith(pushTokenRegistrationFingerprintPrefix));
      expect(persistedKey, isNot(contains('device-token')));
      expect(persistedKey, isNot(contains('user-1')));
      expect(persistedKey, isNot(contains('device-1')));
      expect(await cache.readLastCompletedRegistrationToken(), 'device-token');

      await registrar.registerToken(
        token: 'device-token',
        platform: 'android',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );
      expect(templateRepository.registerCalls, 1);
      expect(supportRepository.registerCalls, 1);
      expect(walletRepository.registerCalls, 1);

      await PushTokenRegistrar.clearRegistrationState(registrationCache: cache);

      await registrar.registerToken(
        token: 'device-token',
        platform: 'android',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );
      expect(templateRepository.registerCalls, 2);
      expect(supportRepository.registerCalls, 2);
      expect(walletRepository.registerCalls, 2);
    },
  );

  test(
    'registered token is restored from secure cache across registrar instances',
    () async {
      final templateRepository = _RecordingTemplateGenerationRepository();
      final supportRepository = _RecordingSupportChatRepository();
      final walletRepository = _RecordingWalletRepository();
      final preferences = SharedPreferencesAsync();
      final secureStorage = _FakeSecureStorage();
      final cache = _registrationCache(
        preferences: preferences,
        secureStorage: secureStorage,
      );
      final firstRegistrar = PushTokenRegistrar(
        templateRepository: templateRepository,
        supportRepository: supportRepository,
        walletRepository: walletRepository,
        sessionStorage: _SignedInAuthSessionStorage('user-1'),
        registrationCache: cache,
      );

      await firstRegistrar.registerToken(
        token: 'old-device-token',
        platform: 'android',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );

      PushTokenRegistrar.invalidateToken('old-device-token');

      final secondRegistrar = PushTokenRegistrar(
        templateRepository: templateRepository,
        supportRepository: supportRepository,
        walletRepository: walletRepository,
        sessionStorage: _SignedInAuthSessionStorage('user-1'),
        registrationCache: cache,
      );

      final persistedKey = await preferences.getString(
        'petmagic_mobile_push_token_last_registration_key_v1',
      );
      expect(await secondRegistrar.readRegisteredToken(), 'old-device-token');
      expect(persistedKey, startsWith(pushTokenRegistrationFingerprintPrefix));
      expect(persistedKey, isNot(contains('old-device-token')));
      expect(secureStorage.values.toString(), contains('old-device-token'));
    },
  );

  test(
    'registration fingerprint without secure token does not skip backend registration',
    () async {
      final templateRepository = _RecordingTemplateGenerationRepository();
      final supportRepository = _RecordingSupportChatRepository();
      final walletRepository = _RecordingWalletRepository();
      final preferences = SharedPreferencesAsync();
      final secureStorage = _FakeSecureStorage();
      final cache = _registrationCache(
        preferences: preferences,
        secureStorage: secureStorage,
      );
      final firstRegistrar = PushTokenRegistrar(
        templateRepository: templateRepository,
        supportRepository: supportRepository,
        walletRepository: walletRepository,
        sessionStorage: _SignedInAuthSessionStorage('user-1'),
        registrationCache: cache,
      );

      await firstRegistrar.registerToken(
        token: 'device-token',
        platform: 'android',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );
      final persistedKey = await preferences.getString(
        'petmagic_mobile_push_token_last_registration_key_v1',
      );
      expect(persistedKey, startsWith(pushTokenRegistrationFingerprintPrefix));

      PushTokenRegistrar.invalidateToken('device-token');
      secureStorage.values.remove(
        'petmagic_mobile_push_token_last_registration_token_v1',
      );

      final secondRegistrar = PushTokenRegistrar(
        templateRepository: templateRepository,
        supportRepository: supportRepository,
        walletRepository: walletRepository,
        sessionStorage: _SignedInAuthSessionStorage('user-1'),
        registrationCache: cache,
      );

      await secondRegistrar.registerToken(
        token: 'device-token',
        platform: 'android',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );

      expect(templateRepository.registerCalls, 2);
      expect(supportRepository.registerCalls, 2);
      expect(walletRepository.registerCalls, 2);
      expect(await cache.readLastCompletedRegistrationToken(), 'device-token');
    },
  );

  test(
    'registration cache clears legacy raw token preference on read',
    () async {
      final preferences = SharedPreferencesAsync();
      final secureStorage = _FakeSecureStorage({
        'petmagic_mobile_push_token_last_registration_token_v1':
            'secure-device-token',
      });
      final cache = _registrationCache(
        preferences: preferences,
        secureStorage: secureStorage,
      );
      await preferences.setString(
        'petmagic_mobile_push_token_last_registration_token_v1',
        'legacy-raw-device-token',
      );

      expect(
        await cache.readLastCompletedRegistrationToken(),
        'secure-device-token',
      );
      expect(
        await preferences.getString(
          'petmagic_mobile_push_token_last_registration_token_v1',
        ),
        isNull,
      );
      expect(
        secureStorage
            .values['petmagic_mobile_push_token_last_registration_token_v1'],
        'secure-device-token',
      );
    },
  );

  test(
    'registration cache clear removes legacy raw token preference',
    () async {
      final preferences = SharedPreferencesAsync();
      final secureStorage = _FakeSecureStorage({
        'petmagic_mobile_push_token_last_registration_token_v1':
            'secure-device-token',
      });
      final cache = _registrationCache(
        preferences: preferences,
        secureStorage: secureStorage,
      );
      await preferences.setString(
        'petmagic_mobile_push_token_last_registration_token_v1',
        'legacy-raw-device-token',
      );

      await cache.clear();

      expect(
        await preferences.getString(
          'petmagic_mobile_push_token_last_registration_token_v1',
        ),
        isNull,
      );
      expect(
        secureStorage.values.containsKey(
          'petmagic_mobile_push_token_last_registration_token_v1',
        ),
        isFalse,
      );
    },
  );

  test('registration cache clears legacy raw token keys on read', () async {
    final preferences = SharedPreferencesAsync();
    final cache = _registrationCache(preferences: preferences);
    await preferences.setString(
      'petmagic_mobile_push_token_last_registration_key_v1',
      'raw-device-token|user-1|android|en-US|1.0.0|device-1',
    );

    expect(await cache.readLastCompletedRegistrationKey(), isNull);
    expect(
      await preferences.getString(
        'petmagic_mobile_push_token_last_registration_key_v1',
      ),
      isNull,
    );
  });

  test('registration cache rejects new raw token keys on write', () async {
    final cache = _registrationCache();

    expect(
      () => cache.writeLastCompletedRegistrationKey(
        'raw-device-token|user-1|android|en-US|1.0.0|device-1',
      ),
      throwsArgumentError,
    );
  });

  test('registration dedupe is isolated by signed-in account scope', () async {
    final cache = _registrationCache();
    final firstTemplateRepository = _RecordingTemplateGenerationRepository();
    final firstSupportRepository = _RecordingSupportChatRepository();
    final firstWalletRepository = _RecordingWalletRepository();
    final firstRegistrar = PushTokenRegistrar(
      templateRepository: firstTemplateRepository,
      supportRepository: firstSupportRepository,
      walletRepository: firstWalletRepository,
      sessionStorage: _SignedInAuthSessionStorage('user-1'),
      registrationCache: cache,
    );

    await firstRegistrar.registerToken(
      token: 'device-token',
      platform: 'android',
      locale: 'en_US',
      appVersion: '1.0.0',
      deviceId: 'device-1',
    );
    expect(firstTemplateRepository.registerCalls, 1);
    expect(firstSupportRepository.registerCalls, 1);
    expect(firstWalletRepository.registerCalls, 1);

    final secondTemplateRepository = _RecordingTemplateGenerationRepository();
    final secondSupportRepository = _RecordingSupportChatRepository();
    final secondWalletRepository = _RecordingWalletRepository();
    final secondRegistrar = PushTokenRegistrar(
      templateRepository: secondTemplateRepository,
      supportRepository: secondSupportRepository,
      walletRepository: secondWalletRepository,
      sessionStorage: _SignedInAuthSessionStorage('user-2'),
      registrationCache: cache,
    );

    await secondRegistrar.registerToken(
      token: 'device-token',
      platform: 'android',
      locale: 'en_US',
      appVersion: '1.0.0',
      deviceId: 'device-1',
    );

    expect(secondTemplateRepository.registerCalls, 1);
    expect(secondSupportRepository.registerCalls, 1);
    expect(secondWalletRepository.registerCalls, 1);
  });

  test(
    'registration dedupe treats equivalent platform and locale formats as the same device',
    () async {
      final templateRepository = _RecordingTemplateGenerationRepository();
      final supportRepository = _RecordingSupportChatRepository();
      final walletRepository = _RecordingWalletRepository();
      final cache = _registrationCache();
      final registrar = PushTokenRegistrar(
        templateRepository: templateRepository,
        supportRepository: supportRepository,
        walletRepository: walletRepository,
        sessionStorage: _SignedInAuthSessionStorage('user-1'),
        registrationCache: cache,
      );

      await registrar.registerToken(
        token: 'device-token',
        platform: 'iOS',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );
      await registrar.registerToken(
        token: 'device-token',
        platform: 'ios',
        locale: 'en-US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );

      expect(templateRepository.registerCalls, 1);
      expect(supportRepository.registerCalls, 1);
      expect(walletRepository.registerCalls, 1);
      expect(templateRepository.lastPlatform, 'ios');
      expect(supportRepository.lastPlatform, 'ios');
      expect(walletRepository.lastPlatform, 'ios');
      expect(templateRepository.lastLocale, 'en-US');
      expect(supportRepository.lastLocale, 'en-US');
      expect(walletRepository.lastLocale, 'en-US');
    },
  );

  test(
    'failed multi-module registration rolls back partial token registrations',
    () async {
      final templateRepository = _RecordingTemplateGenerationRepository();
      final supportRepository = _RecordingSupportChatRepository();
      final walletRepository = _RecordingWalletRepository(
        registerFailure: DioException(
          requestOptions: RequestOptions(
            path: '/api/economy/notifications/push-token',
          ),
        ),
      );
      final cache = _registrationCache();
      final registrar = PushTokenRegistrar(
        templateRepository: templateRepository,
        supportRepository: supportRepository,
        walletRepository: walletRepository,
        sessionStorage: _SignedInAuthSessionStorage('user-1'),
        registrationCache: cache,
      );

      await expectLater(
        registrar.registerToken(
          token: 'device-token',
          platform: 'android',
          locale: 'en_US',
          appVersion: '1.0.0',
          deviceId: 'device-1',
        ),
        throwsA(isA<DioException>()),
      );

      expect(templateRepository.unregisterCalls, 1);
      expect(supportRepository.unregisterCalls, 1);
      expect(walletRepository.unregisterCalls, 1);
      expect(await cache.readLastCompletedRegistrationKey(), isNull);

      walletRepository.registerFailure = null;
      await registrar.registerToken(
        token: 'device-token',
        platform: 'android',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );

      expect(templateRepository.registerCalls, 2);
      expect(supportRepository.registerCalls, 2);
      expect(walletRepository.registerCalls, 2);
      expect(
        await cache.readLastCompletedRegistrationKey(),
        startsWith(pushTokenRegistrationFingerprintPrefix),
      );
    },
  );

  test(
    'registration persistence failure clears partial token cache and rolls back backends',
    () async {
      final templateRepository = _RecordingTemplateGenerationRepository();
      final supportRepository = _RecordingSupportChatRepository();
      final walletRepository = _RecordingWalletRepository();
      final cache = _FailingRegistrationCache(failKeyWrites: true);
      final registrar = PushTokenRegistrar(
        templateRepository: templateRepository,
        supportRepository: supportRepository,
        walletRepository: walletRepository,
        sessionStorage: _SignedInAuthSessionStorage('user-1'),
        registrationCache: cache,
      );

      await expectLater(
        registrar.registerToken(
          token: 'device-token',
          platform: 'android',
          locale: 'en_US',
          appVersion: '1.0.0',
          deviceId: 'device-1',
        ),
        throwsStateError,
      );

      expect(templateRepository.registerCalls, 1);
      expect(supportRepository.registerCalls, 1);
      expect(walletRepository.registerCalls, 1);
      expect(templateRepository.unregisterCalls, 1);
      expect(supportRepository.unregisterCalls, 1);
      expect(walletRepository.unregisterCalls, 1);
      expect(await cache.readLastCompletedRegistrationToken(), isNull);
      expect(await cache.readLastCompletedRegistrationKey(), isNull);

      cache.failKeyWrites = false;
      await registrar.registerToken(
        token: 'device-token',
        platform: 'android',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );

      expect(templateRepository.registerCalls, 2);
      expect(supportRepository.registerCalls, 2);
      expect(walletRepository.registerCalls, 2);
      expect(templateRepository.unregisterCalls, 1);
      expect(supportRepository.unregisterCalls, 1);
      expect(walletRepository.unregisterCalls, 1);
      expect(await cache.readLastCompletedRegistrationToken(), 'device-token');
      expect(
        await cache.readLastCompletedRegistrationKey(),
        startsWith(pushTokenRegistrationFingerprintPrefix),
      );
    },
  );

  test(
    'late cancelled registration rolls back backend token registrations',
    () async {
      final templateRepository = _RecordingTemplateGenerationRepository();
      final supportRepository = _RecordingSupportChatRepository();
      final walletRepository = _RecordingWalletRepository();
      final cache = _registrationCache();
      final registrar = PushTokenRegistrar(
        templateRepository: templateRepository,
        supportRepository: supportRepository,
        walletRepository: walletRepository,
        sessionStorage: _SignedInAuthSessionStorage('user-1'),
        registrationCache: cache,
      );
      var canContinueCalls = 0;

      final registered = await registrar.registerToken(
        token: 'device-token',
        platform: 'android',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
        canContinue: () {
          canContinueCalls++;
          return canContinueCalls < 4;
        },
      );

      expect(registered, isFalse);
      expect(templateRepository.registerCalls, 1);
      expect(supportRepository.registerCalls, 1);
      expect(walletRepository.registerCalls, 1);
      expect(templateRepository.unregisterCalls, 1);
      expect(supportRepository.unregisterCalls, 1);
      expect(walletRepository.unregisterCalls, 1);
      expect(await cache.readLastCompletedRegistrationKey(), isNull);
    },
  );

  test(
    'registration finishing after state clear does not restore persisted token',
    () async {
      final templateRepository = _RecordingTemplateGenerationRepository();
      final supportRepository = _RecordingSupportChatRepository();
      final walletRepository = _RecordingWalletRepository();
      final registerGate = Completer<void>();
      templateRepository.registerGate = registerGate.future;
      supportRepository.registerGate = registerGate.future;
      walletRepository.registerGate = registerGate.future;
      final cache = _registrationCache();
      final registrar = PushTokenRegistrar(
        templateRepository: templateRepository,
        supportRepository: supportRepository,
        walletRepository: walletRepository,
        sessionStorage: _SignedInAuthSessionStorage('user-1'),
        registrationCache: cache,
      );

      final registration = registrar.registerToken(
        token: 'device-token',
        platform: 'android',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );
      await _waitUntil(() => walletRepository.registerCalls == 1);

      await PushTokenRegistrar.clearRegistrationState(registrationCache: cache);
      registerGate.complete();

      expect(await registration, isFalse);
      expect(await cache.readLastCompletedRegistrationToken(), isNull);
      expect(await cache.readLastCompletedRegistrationKey(), isNull);
      expect(templateRepository.unregisterCalls, 1);
      expect(supportRepository.unregisterCalls, 1);
      expect(walletRepository.unregisterCalls, 1);
    },
  );

  test(
    'late cancelled unregister reports success after local cleanup',
    () async {
      final templateRepository = _RecordingTemplateGenerationRepository();
      final supportRepository = _RecordingSupportChatRepository();
      final walletRepository = _RecordingWalletRepository();
      final cache = _registrationCache();
      final registrar = PushTokenRegistrar(
        templateRepository: templateRepository,
        supportRepository: supportRepository,
        walletRepository: walletRepository,
        sessionStorage: _SignedInAuthSessionStorage('user-1'),
        registrationCache: cache,
      );

      await registrar.registerToken(
        token: 'device-token',
        platform: 'android',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );
      expect(
        await cache.readLastCompletedRegistrationKey(),
        startsWith(pushTokenRegistrationFingerprintPrefix),
      );

      var canContinueCalls = 0;
      final unregistered = await registrar.unregisterToken(
        token: 'device-token',
        canContinue: () {
          canContinueCalls++;
          return canContinueCalls < 3;
        },
      );

      expect(unregistered, isTrue);
      expect(templateRepository.unregisterCalls, 1);
      expect(supportRepository.unregisterCalls, 1);
      expect(walletRepository.unregisterCalls, 1);
      expect(await cache.readLastCompletedRegistrationKey(), isNull);

      await registrar.registerToken(
        token: 'device-token',
        platform: 'android',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );
      expect(templateRepository.registerCalls, 2);
      expect(supportRepository.registerCalls, 2);
      expect(walletRepository.registerCalls, 2);
    },
  );

  test(
    'stale token unregister does not clear current registration fingerprint',
    () async {
      final templateRepository = _RecordingTemplateGenerationRepository();
      final supportRepository = _RecordingSupportChatRepository();
      final walletRepository = _RecordingWalletRepository();
      final cache = _registrationCache();
      final registrar = PushTokenRegistrar(
        templateRepository: templateRepository,
        supportRepository: supportRepository,
        walletRepository: walletRepository,
        sessionStorage: _SignedInAuthSessionStorage('user-1'),
        registrationCache: cache,
      );

      await registrar.registerToken(
        token: 'old-device-token',
        platform: 'android',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );
      await registrar.registerToken(
        token: 'new-device-token',
        platform: 'android',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );
      final currentKey = await cache.readLastCompletedRegistrationKey();
      expect(currentKey, startsWith(pushTokenRegistrationFingerprintPrefix));

      final unregistered = await registrar.unregisterToken(
        token: 'old-device-token',
        clearRegistrationState: false,
      );

      expect(unregistered, isTrue);
      expect(await cache.readLastCompletedRegistrationKey(), currentKey);

      await registrar.registerToken(
        token: 'new-device-token',
        platform: 'android',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );
      expect(templateRepository.registerCalls, 2);
      expect(supportRepository.registerCalls, 2);
      expect(walletRepository.registerCalls, 2);
    },
  );

  test(
    'clear-state unregister is not deduped with concurrent stale unregister',
    () async {
      final templateRepository = _RecordingTemplateGenerationRepository();
      final supportRepository = _RecordingSupportChatRepository();
      final walletRepository = _RecordingWalletRepository();
      final cache = _registrationCache();
      final registrar = PushTokenRegistrar(
        templateRepository: templateRepository,
        supportRepository: supportRepository,
        walletRepository: walletRepository,
        sessionStorage: _SignedInAuthSessionStorage('user-1'),
        registrationCache: cache,
      );

      await registrar.registerToken(
        token: 'device-token',
        platform: 'android',
        locale: 'en_US',
        appVersion: '1.0.0',
        deviceId: 'device-1',
      );
      expect(
        await cache.readLastCompletedRegistrationKey(),
        startsWith(pushTokenRegistrationFingerprintPrefix),
      );

      final unregisterGate = Completer<void>();
      templateRepository.unregisterGate = unregisterGate.future;
      supportRepository.unregisterGate = unregisterGate.future;
      walletRepository.unregisterGate = unregisterGate.future;

      final staleUnregister = registrar.unregisterToken(
        token: 'device-token',
        clearRegistrationState: false,
      );
      await Future<void>.delayed(Duration.zero);

      final clearStateUnregister = registrar.unregisterToken(
        token: 'device-token',
      );
      await Future<void>.delayed(Duration.zero);
      unregisterGate.complete();

      expect(await staleUnregister, isTrue);
      expect(await clearStateUnregister, isTrue);
      expect(await cache.readLastCompletedRegistrationKey(), isNull);
      expect(templateRepository.unregisterCalls, 2);
      expect(supportRepository.unregisterCalls, 2);
      expect(walletRepository.unregisterCalls, 2);
    },
  );
}

SharedPreferencesPushTokenRegistrationCache _registrationCache({
  SharedPreferencesAsync? preferences,
  _FakeSecureStorage? secureStorage,
}) {
  return SharedPreferencesPushTokenRegistrationCache(
    preferences: preferences ?? SharedPreferencesAsync(),
    secureStorage: secureStorage ?? _FakeSecureStorage(),
  );
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Condition was not met before timeout.');
    }

    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _SignedInAuthSessionStorage extends AuthSessionStorage {
  _SignedInAuthSessionStorage(this.userId);

  final String userId;

  @override
  Future<AuthSession?> read() async {
    return AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAtUtc: DateTime.utc(2030),
      user: MobileUserProfile(
        userId: userId,
        email: '$userId@example.com',
        displayName: 'User $userId',
        isPremium: false,
        emailConfirmed: true,
        termsOfUseAccepted: true,
        privacyPolicyAccepted: true,
        marketingEmailsEnabled: false,
        legalAcceptance: const MobileLegalAcceptanceStatus(
          termsOfUseAccepted: true,
          termsOfUseAcceptedVersion: '2026-01',
          termsOfUseAcceptedAtUtc: null,
          privacyPolicyAccepted: true,
          privacyPolicyAcceptedVersion: '2026-01',
          privacyPolicyAcceptedAtUtc: null,
          currentTermsOfUseVersion: '2026-01',
          currentPrivacyPolicyVersion: '2026-01',
          requiresAcceptance: false,
        ),
        roles: const ['user'],
        avatar: null,
      ),
    );
  }

  @override
  Future<void> save(AuthSession session) async {}

  @override
  Future<void> clear() async {}
}

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage([Map<String, String>? values])
    : values = values ?? <String, String>{};

  final Map<String, String> values;

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
    values.remove(key);
  }
}

class _FailingRegistrationCache implements PushTokenRegistrationCache {
  _FailingRegistrationCache({required this.failKeyWrites});

  bool failKeyWrites;
  String? _key;
  String? _token;

  @override
  Future<String?> readLastCompletedRegistrationKey() async {
    return _key;
  }

  @override
  Future<String?> readLastCompletedRegistrationToken() async {
    return _token;
  }

  @override
  Future<void> writeLastCompletedRegistrationKey(String key) async {
    if (failKeyWrites) {
      throw StateError('failed to persist push registration fingerprint');
    }
    _key = key;
  }

  @override
  Future<void> writeLastCompletedRegistrationToken(String token) async {
    _token = token;
  }

  @override
  Future<void> clear() async {
    _key = null;
    _token = null;
  }
}

class _RecordingTemplateGenerationRepository
    extends TemplateGenerationRepository {
  _RecordingTemplateGenerationRepository()
    : super(
        dio: Dio(),
        sessionStorage: AuthSessionStorage(),
        preferences: SharedPreferencesAsync(),
      );

  int registerCalls = 0;
  int unregisterCalls = 0;
  Future<void>? registerGate;
  Future<void>? unregisterGate;
  String? lastPlatform;
  String? lastLocale;

  @override
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
    String? appVersion,
    String? locale,
  }) async {
    registerCalls++;
    await registerGate;
    lastPlatform = platform;
    lastLocale = locale;
  }

  @override
  Future<void> unregisterPushToken(String token) async {
    unregisterCalls++;
    await unregisterGate;
  }
}

class _RecordingSupportChatRepository extends SupportChatRepository {
  _RecordingSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  int registerCalls = 0;
  int unregisterCalls = 0;
  Future<void>? registerGate;
  Future<void>? unregisterGate;
  String? lastPlatform;
  String? lastLocale;

  @override
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
    String? appVersion,
    String? locale,
  }) async {
    registerCalls++;
    await registerGate;
    lastPlatform = platform;
    lastLocale = locale;
  }

  @override
  Future<void> unregisterPushToken(String token) async {
    unregisterCalls++;
    await unregisterGate;
  }
}

class _RecordingWalletRepository extends WalletRepository {
  _RecordingWalletRepository({this.registerFailure})
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  Object? registerFailure;
  int registerCalls = 0;
  int unregisterCalls = 0;
  Future<void>? registerGate;
  Future<void>? unregisterGate;
  String? lastPlatform;
  String? lastLocale;

  @override
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? locale,
  }) async {
    registerCalls++;
    await registerGate;
    final failure = registerFailure;
    if (failure != null) {
      throw failure;
    }

    lastPlatform = platform;
    lastLocale = locale;
  }

  @override
  Future<void> unregisterPushToken(String token) async {
    unregisterCalls++;
    await unregisterGate;
  }
}
