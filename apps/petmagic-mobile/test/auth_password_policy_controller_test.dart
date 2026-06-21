import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_change_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_reset_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';

void main() {
  test('registration blocks weak passwords before repository call', () async {
    final repository = _PasswordPolicyRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    final controller = container.read(profileControllerProvider.notifier)
      ..updateEmail('pet@example.com')
      ..updatePassword('pet123')
      ..updateConfirmPassword('pet123');

    await controller.register(
      termsOfUseAccepted: true,
      privacyPolicyAccepted: true,
      legalDocuments: null,
      marketingEmailsEnabled: false,
    );

    expect(repository.registerCalled, isFalse);
    expect(
      container.read(profileControllerProvider).errorMessage,
      'auth.password_policy_invalid',
    );
  });

  test('password reset blocks weak passwords before repository call', () async {
    final repository = _PasswordPolicyRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    final controller = container.read(passwordResetControllerProvider.notifier)
      ..updateEmail('pet@example.com')
      ..updateCode('123456')
      ..updateNewPassword('pet123')
      ..updateConfirmPassword('pet123');

    final result = await controller.confirmReset();

    expect(result, isFalse);
    expect(repository.confirmPasswordResetCalled, isFalse);
    expect(
      container.read(passwordResetControllerProvider).errorMessage,
      'auth.password_policy_invalid',
    );
  });

  test(
    'password change blocks weak passwords before repository call',
    () async {
      final repository = _PasswordPolicyRepository();
      final container = _container(repository);
      addTearDown(container.dispose);

      final controller =
          container.read(passwordChangeControllerProvider.notifier)
            ..updateCode('123456')
            ..updateNewPassword('pet123')
            ..updateConfirmPassword('pet123');

      final result = await controller.confirmChange();

      expect(result, isFalse);
      expect(repository.confirmCurrentPasswordChangeCalled, isFalse);
      expect(
        container.read(passwordChangeControllerProvider).errorMessage,
        'auth.password_policy_invalid',
      );
    },
  );
}

ProviderContainer _container(ProfileRepository repository) {
  return ProviderContainer(
    overrides: [profileRepositoryProvider.overrideWithValue(repository)],
  );
}

class _PasswordPolicyRepository extends ProfileRepository {
  _PasswordPolicyRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  bool registerCalled = false;
  bool confirmPasswordResetCalled = false;
  bool confirmCurrentPasswordChangeCalled = false;

  @override
  Future<void> register({
    required String email,
    required String password,
    required bool termsOfUseAccepted,
    required bool privacyPolicyAccepted,
    required String termsOfUseVersion,
    required String privacyPolicyVersion,
    required bool marketingEmailsEnabled,
    String? displayName,
  }) async {
    registerCalled = true;
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    confirmPasswordResetCalled = true;
  }

  @override
  Future<void> confirmCurrentPasswordChange({
    required String code,
    required String newPassword,
  }) async {
    confirmCurrentPasswordChangeCalled = true;
  }
}
