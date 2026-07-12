import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_change_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_reset_controller.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';

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

  test(
    'registration blocks missing legal documents before repository call',
    () async {
      final repository = _PasswordPolicyRepository();
      final container = _container(repository);
      addTearDown(container.dispose);

      final controller = container.read(profileControllerProvider.notifier)
        ..updateEmail('pet@example.com')
        ..updatePassword('Password123')
        ..updateConfirmPassword('Password123');

      await controller.register(
        termsOfUseAccepted: true,
        privacyPolicyAccepted: true,
        legalDocuments: null,
        marketingEmailsEnabled: false,
      );

      expect(repository.registerCalled, isFalse);
      expect(
        container.read(profileControllerProvider).errorMessage,
        'auth.legal_documents_unavailable',
      );
    },
  );

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

  test('login skips offline request before repository call', () async {
    final repository = _PasswordPolicyRepository();
    final container = _container(
      repository,
      networkController: _TestNetworkStatusController(
        initialHasInternet: false,
      ),
    );
    addTearDown(container.dispose);

    final controller = container.read(profileControllerProvider.notifier)
      ..updateEmail('pet@example.com')
      ..updatePassword('Password123');

    await controller.login();

    expect(repository.loginCalled, isFalse);
    expect(
      container.read(profileControllerProvider).errorMessage,
      'templates.network_unavailable',
    );
  });

  test('password reset skips offline request before repository call', () async {
    final repository = _PasswordPolicyRepository();
    final container = _container(
      repository,
      networkController: _TestNetworkStatusController(
        initialHasInternet: false,
      ),
    );
    addTearDown(container.dispose);

    final controller = container.read(passwordResetControllerProvider.notifier)
      ..updateEmail('pet@example.com');

    final result = await controller.requestReset();

    expect(result, isFalse);
    expect(repository.requestPasswordResetCalled, isFalse);
    expect(
      container.read(passwordResetControllerProvider).errorMessage,
      'templates.network_unavailable',
    );
  });

  test(
    'password change skips offline request before repository call',
    () async {
      final repository = _PasswordPolicyRepository();
      final container = _container(
        repository,
        networkController: _TestNetworkStatusController(
          initialHasInternet: false,
        ),
      );
      addTearDown(container.dispose);

      final controller = container.read(
        passwordChangeControllerProvider.notifier,
      )..reset(email: 'pet@example.com');

      final result = await controller.requestCode();

      expect(result, isFalse);
      expect(repository.requestCurrentPasswordChangeCodeCalled, isFalse);
      expect(
        container.read(passwordChangeControllerProvider).errorMessage,
        'templates.network_unavailable',
      );
    },
  );
}

ProviderContainer _container(
  ProfileRepository repository, {
  NetworkStatusController? networkController,
}) {
  return ProviderContainer(
    overrides: [
      profileRepositoryProvider.overrideWithValue(repository),
      networkStatusControllerProvider.overrideWith(
        () =>
            networkController ??
            _TestNetworkStatusController(initialHasInternet: true),
      ),
    ],
  );
}

class _PasswordPolicyRepository extends ProfileRepository {
  _PasswordPolicyRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  bool registerCalled = false;
  bool loginCalled = false;
  bool requestPasswordResetCalled = false;
  bool requestCurrentPasswordChangeCodeCalled = false;
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
    RequestCancellation? cancelToken,
  }) async {
    registerCalled = true;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    RequestCancellation? cancelToken,
  }) async {
    loginCalled = true;
    return AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAtUtc: DateTime.utc(2030, 1, 1),
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
          termsOfUseAcceptedVersion: '2026-05-20',
          termsOfUseAcceptedAtUtc: null,
          privacyPolicyAccepted: true,
          privacyPolicyAcceptedVersion: '2026-05-20',
          privacyPolicyAcceptedAtUtc: null,
          currentTermsOfUseVersion: '2026-05-20',
          currentPrivacyPolicyVersion: '2026-05-20',
          requiresAcceptance: false,
        ),
        roles: ['user'],
        avatar: null,
      ),
    );
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
    RequestCancellation? cancelToken,
  }) async {
    confirmPasswordResetCalled = true;
  }

  @override
  Future<void> confirmCurrentPasswordChange({
    required String code,
    required String newPassword,
    RequestCancellation? cancelToken,
  }) async {
    confirmCurrentPasswordChangeCalled = true;
  }

  @override
  Future<void> requestPasswordReset({
    required String email,
    RequestCancellation? cancelToken,
  }) async {
    requestPasswordResetCalled = true;
  }

  @override
  Future<void> requestCurrentPasswordChangeCode({
    RequestCancellation? cancelToken,
  }) async {
    requestCurrentPasswordChangeCodeCalled = true;
  }
}

class _TestNetworkStatusController extends NetworkStatusController {
  _TestNetworkStatusController({required this.initialHasInternet});

  final bool initialHasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: initialHasInternet);
  }
}
