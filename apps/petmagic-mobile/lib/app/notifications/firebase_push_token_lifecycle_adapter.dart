import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/notifications/push_token_registrar.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/core/firebase/firebase_app_initializer.dart';
import 'package:petmagic_mobile/core/notifications/firebase_messaging_token_reader.dart';
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
  FirebasePushTokenLifecycleAdapter({
    required PushTokenRegistrar registrar,
    FirebaseAppInitializer? appInitializer,
    FirebaseMessagingTokenReader? tokenReader,
  }) : _registrar = registrar,
       _appInitializer = appInitializer ?? firebaseAppInitializer,
       _tokenReader = tokenReader ?? firebaseMessagingTokenReader;

  final PushTokenRegistrar _registrar;
  final FirebaseAppInitializer _appInitializer;
  final FirebaseMessagingTokenReader _tokenReader;

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

    final token =
        cachedToken ?? await _readFirebaseToken(canContinue: canContinue);
    if (token == null || token.isEmpty || !canContinue()) return;

    await unregisterToken(
      token: token,
      canContinue: canContinue,
      onFailure: onFailure,
    );
  }

  Future<String?> _readFirebaseToken({bool Function()? canContinue}) async {
    if (canContinue != null && !canContinue()) return null;
    if (!await _appInitializer.ensureInitialized()) return null;
    if (canContinue != null && !canContinue()) return null;
    return _tokenReader.readToken(canContinue: canContinue);
  }
}
