import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/notifications/push_token_registration_cache.dart';
import 'package:petmagic_mobile/core/notifications/push_token_registrar.dart';
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

  @override
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
    String? appVersion,
    String? locale,
  }) async {
    registerCalls++;
  }

  @override
  Future<void> unregisterPushToken(String token) async {}
}

class _RecordingSupportChatRepository extends SupportChatRepository {
  _RecordingSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  int registerCalls = 0;

  @override
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
    String? appVersion,
    String? locale,
  }) async {
    registerCalls++;
  }

  @override
  Future<void> unregisterPushToken(String token) async {}
}

class _RecordingWalletRepository extends WalletRepository {
  _RecordingWalletRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  int registerCalls = 0;

  @override
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? locale,
  }) async {
    registerCalls++;
  }

  @override
  Future<void> unregisterPushToken(String token) async {}
}
