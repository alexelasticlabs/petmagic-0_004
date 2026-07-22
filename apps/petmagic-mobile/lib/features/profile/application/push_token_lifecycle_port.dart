import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef PushTokenUnregisterFailure =
    void Function(String stage, Object error, StackTrace stackTrace);

final pushTokenLifecyclePortProvider = Provider<PushTokenLifecyclePort>((ref) {
  throw StateError(
    'PushTokenLifecyclePort is not bound. Add the app composition overrides.',
  );
});

abstract interface class PushTokenLifecyclePort {
  Future<String?> readRegisteredToken();

  Future<String?> readCurrentDeviceToken();

  Future<bool> registerToken({
    required String token,
    required String platform,
    required String locale,
    required bool Function() canContinue,
  });

  Future<void> unregisterToken({
    required String token,
    bool clearRegistrationState = true,
    required bool Function() canContinue,
    required PushTokenUnregisterFailure onFailure,
  });

  Future<void> unregisterCurrentToken({
    required bool Function() canContinue,
    required PushTokenUnregisterFailure onFailure,
  });
}
