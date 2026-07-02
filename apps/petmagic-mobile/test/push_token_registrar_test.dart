import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/notifications/push_token_registration_cache.dart';
import 'package:petmagic_mobile/core/notifications/push_token_registrar.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
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
      registrationCache: SharedPreferencesPushTokenRegistrationCache(
        preferences: SharedPreferencesAsync(),
      ),
    );
  });

  test(
    'clearing registration state forces backend registration again for the next user',
    () async {
      final templateRepository = _RecordingTemplateGenerationRepository();
      final supportRepository = _RecordingSupportChatRepository();
      final walletRepository = _RecordingWalletRepository();
      final cache = SharedPreferencesPushTokenRegistrationCache(
        preferences: SharedPreferencesAsync(),
      );
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

  test('registration cache clears legacy raw token keys on read', () async {
    final preferences = SharedPreferencesAsync();
    final cache = SharedPreferencesPushTokenRegistrationCache(
      preferences: preferences,
    );
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
    final cache = SharedPreferencesPushTokenRegistrationCache(
      preferences: SharedPreferencesAsync(),
    );

    expect(
      () => cache.writeLastCompletedRegistrationKey(
        'raw-device-token|user-1|android|en-US|1.0.0|device-1',
      ),
      throwsArgumentError,
    );
  });

  test('registration dedupe is isolated by signed-in account scope', () async {
    final cache = SharedPreferencesPushTokenRegistrationCache(
      preferences: SharedPreferencesAsync(),
    );
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
      final cache = SharedPreferencesPushTokenRegistrationCache(
        preferences: SharedPreferencesAsync(),
      );
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

class _RecordingTemplateGenerationRepository
    extends TemplateGenerationRepository {
  _RecordingTemplateGenerationRepository()
    : super(
        dio: Dio(),
        sessionStorage: AuthSessionStorage(),
        preferences: SharedPreferencesAsync(),
      );

  int registerCalls = 0;
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
    lastPlatform = platform;
    lastLocale = locale;
  }

  @override
  Future<void> unregisterPushToken(String token) async {}
}

class _RecordingSupportChatRepository extends SupportChatRepository {
  _RecordingSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  int registerCalls = 0;
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
    lastPlatform = platform;
    lastLocale = locale;
  }

  @override
  Future<void> unregisterPushToken(String token) async {}
}

class _RecordingWalletRepository extends WalletRepository {
  _RecordingWalletRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  int registerCalls = 0;
  String? lastPlatform;
  String? lastLocale;

  @override
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? locale,
  }) async {
    registerCalls++;
    lastPlatform = platform;
    lastLocale = locale;
  }

  @override
  Future<void> unregisterPushToken(String token) async {}
}
