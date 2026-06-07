import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';

void main() {
  test('provider disposal cancels active avatar upload', () async {
    final repository = _CancellableProfileRepository();
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(repository)],
    );

    final controller = container.read(profileControllerProvider.notifier);
    final uploadFuture = controller.uploadAvatarFromPath('/tmp/avatar.jpg');

    final cancelToken = await repository.uploadStarted.future;
    expect(cancelToken.isCancelled, isFalse);

    container.dispose();

    expect(cancelToken.isCancelled, isTrue);
    await expectLater(uploadFuture, completes);
  });

  test('ignores duplicate avatar upload while one is in flight', () async {
    final repository = _CancellableProfileRepository();
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(repository)],
    );

    final controller = container.read(profileControllerProvider.notifier);
    final firstUpload = controller.uploadAvatarFromPath('/tmp/avatar-1.jpg');

    final cancelToken = await repository.uploadStarted.future;
    expect(cancelToken.isCancelled, isFalse);

    await controller.uploadAvatarFromPath('/tmp/avatar-2.jpg');

    expect(repository.uploadCalls, 1);
    container.dispose();
    await expectLater(firstUpload, completes);
  });

  test('provider disposal ignores delayed avatar removal completion', () async {
    final repository = _DelayedProfileActionRepository();
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(repository)],
    );

    final controller = container.read(profileControllerProvider.notifier);
    final removeFuture = controller.removeAvatar();
    await repository.removeStarted.future;

    container.dispose();
    repository.completeRemove();

    await expectLater(removeFuture, completes);
  });

  test(
    'provider disposal ignores delayed login before profile fetch',
    () async {
      final repository = _DelayedLoginProfileRepository();
      final container = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
      );

      final controller = container.read(profileControllerProvider.notifier)
        ..updateEmail('pet@example.com')
        ..updatePassword('hunter2');
      final loginFuture = controller.login();
      await repository.loginStarted.future;

      container.dispose();
      repository.completeLogin();

      await expectLater(loginFuture, completes);
      expect(repository.fetchProfileCalls, 0);
    },
  );
}

class _CancellableProfileRepository extends ProfileRepository {
  _CancellableProfileRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<CancelToken> uploadStarted = Completer<CancelToken>();
  int uploadCalls = 0;

  @override
  Future<MobileUserProfile> uploadAvatar(
    String filePath, {
    CancelToken? cancelToken,
  }) async {
    uploadCalls++;
    final token = cancelToken ?? CancelToken();
    if (!uploadStarted.isCompleted) {
      uploadStarted.complete(token);
    }

    await token.whenCancel;
    throw const RequestCancelledException();
  }
}

class _DelayedProfileActionRepository extends ProfileRepository {
  _DelayedProfileActionRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<void> removeStarted = Completer<void>();
  final Completer<MobileUserProfile> _removeCompleter =
      Completer<MobileUserProfile>();

  @override
  Future<MobileUserProfile> removeAvatar() {
    if (!removeStarted.isCompleted) {
      removeStarted.complete();
    }
    return _removeCompleter.future;
  }

  void completeRemove() {
    if (!_removeCompleter.isCompleted) {
      _removeCompleter.complete(_profile());
    }
  }
}

class _DelayedLoginProfileRepository extends ProfileRepository {
  _DelayedLoginProfileRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<void> loginStarted = Completer<void>();
  final Completer<AuthSession> _loginCompleter = Completer<AuthSession>();
  int fetchProfileCalls = 0;

  @override
  Future<AuthSession> login({required String email, required String password}) {
    if (!loginStarted.isCompleted) {
      loginStarted.complete();
    }
    return _loginCompleter.future;
  }

  @override
  Future<MobileUserProfile> fetchProfile() async {
    fetchProfileCalls++;
    return _profile();
  }

  void completeLogin() {
    if (!_loginCompleter.isCompleted) {
      _loginCompleter.complete(
        AuthSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          expiresAtUtc: DateTime.utc(2026, 1, 1),
          user: _profile(),
        ),
      );
    }
  }
}

MobileUserProfile _profile() {
  return const MobileUserProfile(
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
      termsOfUseAcceptedVersion: '1.0',
      termsOfUseAcceptedAtUtc: null,
      privacyPolicyAccepted: true,
      privacyPolicyAcceptedVersion: '1.0',
      privacyPolicyAcceptedAtUtc: null,
      currentTermsOfUseVersion: '1.0',
      currentPrivacyPolicyVersion: '1.0',
      requiresAcceptance: false,
    ),
    roles: ['user'],
    avatar: null,
  );
}
