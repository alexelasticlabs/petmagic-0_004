import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_change_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_reset_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    'password reset request cancels in-flight submit when network goes offline',
    () async {
      final repository = _DelayedPasswordRepository();
      final networkController = _TestPasswordNetworkStatusController(true);
      final container = ProviderContainer(
        overrides: [
          networkStatusControllerProvider.overrideWith(() => networkController),
          profileRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        passwordResetControllerProvider.notifier,
      )..updateEmail('pet@example.com');
      final requestFuture = controller.requestReset();
      await repository.passwordResetStarted.future;

      expect(repository.passwordResetCancelToken?.isCancelled, isFalse);

      networkController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);

      var state = container.read(passwordResetControllerProvider);
      expect(repository.passwordResetCancelToken?.isCancelled, isTrue);
      expect(state.isSaving, isFalse);
      expect(state.errorMessage, 'templates.network_unavailable');

      repository.completePasswordReset();
      await expectLater(requestFuture, completion(isFalse));

      state = container.read(passwordResetControllerProvider);
      expect(state.codeRequested, isFalse);
      expect(state.successMessage, isNull);
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

  test(
    'password change code request cancels in-flight submit when network goes offline',
    () async {
      final repository = _DelayedPasswordRepository();
      final networkController = _TestPasswordNetworkStatusController(true);
      final container = ProviderContainer(
        overrides: [
          networkStatusControllerProvider.overrideWith(() => networkController),
          profileRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        passwordChangeControllerProvider.notifier,
      )..reset(email: 'pet@example.com');
      final requestFuture = controller.requestCode();
      await repository.passwordChangeCodeStarted.future;

      expect(repository.passwordChangeCodeCancelToken?.isCancelled, isFalse);

      networkController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);

      var state = container.read(passwordChangeControllerProvider);
      expect(repository.passwordChangeCodeCancelToken?.isCancelled, isTrue);
      expect(state.isSaving, isFalse);
      expect(state.errorMessage, 'templates.network_unavailable');

      repository.completePasswordChangeCode();
      await expectLater(requestFuture, completion(isFalse));

      state = container.read(passwordChangeControllerProvider);
      expect(state.codeRequested, isFalse);
      expect(state.successMessage, isNull);
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
  CancelToken? passwordResetCancelToken;
  CancelToken? passwordChangeCodeCancelToken;
  int passwordChangeCodeCalls = 0;

  @override
  Future<void> requestPasswordReset({
    required String email,
    CancelToken? cancelToken,
  }) {
    passwordResetCancelToken = cancelToken;
    if (!passwordResetStarted.isCompleted) {
      passwordResetStarted.complete();
    }
    return _passwordResetCompleter.future;
  }

  @override
  Future<void> requestCurrentPasswordChangeCode({CancelToken? cancelToken}) {
    passwordChangeCodeCalls++;
    passwordChangeCodeCancelToken = cancelToken;
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

class _TestPasswordNetworkStatusController extends NetworkStatusController {
  _TestPasswordNetworkStatusController(this.initialHasInternet);

  final bool initialHasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: initialHasInternet);
  }

  void setHasInternet(bool value) {
    state = state.copyWith(hasInternet: value);
  }
}
