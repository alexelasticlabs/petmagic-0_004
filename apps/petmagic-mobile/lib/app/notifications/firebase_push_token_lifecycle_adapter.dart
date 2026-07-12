import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/notifications/push_token_registrar.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/application/push_token_lifecycle_port.dart';
import 'package:petmagic_mobile/features/support/application/support_contract.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_contract.dart';

final firebasePushTokenLifecycleAdapterProvider =
    Provider<PushTokenLifecyclePort>((ref) {
      return FirebasePushTokenLifecycleAdapter(
        registrar: PushTokenRegistrar(
          templateRepository: ref.watch(templateGenerationRepositoryProvider),
          supportRepository: ref.watch(supportChatRepositoryProvider),
          walletRepository: ref.watch(walletRepositoryProvider),
          sessionStorage: ref.watch(authSessionStorageProvider),
        ),
      );
    });

final class FirebasePushTokenLifecycleAdapter
    implements PushTokenLifecyclePort {
  const FirebasePushTokenLifecycleAdapter({
    required PushTokenRegistrar registrar,
  }) : _registrar = registrar;

  final PushTokenRegistrar _registrar;

  @override
  Future<String?> readRegisteredToken() => _registrar.readRegisteredToken();

  @override
  Future<String?> readCurrentDeviceToken() => _readFirebaseToken();

  @override
  Future<bool> registerToken({
    required String token,
    required String platform,
    required String locale,
    required bool Function() canContinue,
  }) => _registrar.registerToken(
    token: token,
    platform: platform,
    locale: locale,
    canContinue: canContinue,
  );

  @override
  Future<void> unregisterToken({
    required String token,
    bool clearRegistrationState = true,
    required bool Function() canContinue,
    required PushTokenUnregisterFailure onFailure,
  }) => _registrar.unregisterToken(
    token: token,
    clearRegistrationState: clearRegistrationState,
    canContinue: canContinue,
    onFailure: onFailure,
  );

  @override
  Future<void> unregisterCurrentToken({
    required bool Function() canContinue,
    required PushTokenUnregisterFailure onFailure,
  }) async {
    final cachedToken = await readRegisteredToken();
    if (!canContinue()) return;

    final token = cachedToken ?? await readCurrentDeviceToken();
    if (token == null || token.isEmpty || !canContinue()) return;

    await unregisterToken(
      token: token,
      canContinue: canContinue,
      onFailure: onFailure,
    );
  }

  Future<String?> _readFirebaseToken() async {
    if (Firebase.apps.isEmpty) return null;
    final token = await FirebaseMessaging.instance.getToken();
    final normalized = token?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
