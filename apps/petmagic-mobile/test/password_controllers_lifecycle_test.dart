import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_change_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_reset_controller.dart';

void main() {
  test(
    'password reset request ignores delayed completion after disposal',
    () async {
      final repository = _DelayedPasswordRepository();
      final container = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
      );

      final controller = container.read(
        passwordResetControllerProvider.notifier,
      )..updateEmail('pet@example.com');
      final requestFuture = controller.requestReset();
      await repository.passwordResetStarted.future;

      container.dispose();
      repository.completePasswordReset();

      await expectLater(requestFuture, completion(isFalse));
    },
  );

  test(
    'password change code request ignores duplicate submits in flight',
    () async {
      final repository = _DelayedPasswordRepository();
      final container = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        passwordChangeControllerProvider.notifier,
      )..reset(email: 'pet@example.com');
      final firstRequest = controller.requestCode();
      await repository.passwordChangeCodeStarted.future;

      final secondRequest = await controller.requestCode();
      expect(secondRequest, isFalse);
      expect(repository.passwordChangeCodeCalls, 1);

      repository.completePasswordChangeCode();
      await expectLater(firstRequest, completion(isTrue));
    },
  );
}

class _DelayedPasswordRepository extends ProfileRepository {
  _DelayedPasswordRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<void> passwordResetStarted = Completer<void>();
  final Completer<void> passwordChangeCodeStarted = Completer<void>();
  final Completer<void> _passwordResetCompleter = Completer<void>();
  final Completer<void> _passwordChangeCodeCompleter = Completer<void>();
  int passwordChangeCodeCalls = 0;

  @override
  Future<void> requestPasswordReset({required String email}) {
    if (!passwordResetStarted.isCompleted) {
      passwordResetStarted.complete();
    }
    return _passwordResetCompleter.future;
  }

  @override
  Future<void> requestCurrentPasswordChangeCode() {
    passwordChangeCodeCalls++;
    if (!passwordChangeCodeStarted.isCompleted) {
      passwordChangeCodeStarted.complete();
    }
    return _passwordChangeCodeCompleter.future;
  }

  void completePasswordReset() {
    if (!_passwordResetCompleter.isCompleted) {
      _passwordResetCompleter.complete();
    }
  }

  void completePasswordChangeCode() {
    if (!_passwordChangeCodeCompleter.isCompleted) {
      _passwordChangeCodeCompleter.complete();
    }
  }
}
