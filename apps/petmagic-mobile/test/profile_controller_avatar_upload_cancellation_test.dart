import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';

void main() {
  test('provider disposal cancels active avatar upload', () async {
    final repository = _CancellableProfileRepository();
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(repository)],
    );
    final managedTempFile = await _createManagedAvatarTempFile();
    addTearDown(() async {
      if (await managedTempFile.exists()) {
        await managedTempFile.delete();
      }
    });

    final controller = container.read(profileControllerProvider.notifier);
    final uploadFuture = controller.uploadAvatarFromPath(managedTempFile.path);

    final cancelToken = await repository.uploadStarted.future;
    expect(cancelToken.isCancelled, isFalse);

    container.dispose();

    expect(cancelToken.isCancelled, isTrue);
    await expectLater(uploadFuture, completes);
    expect(await managedTempFile.exists(), isFalse);
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

  test(
    'successful avatar upload deletes managed temporary crop file',
    () async {
      final repository = _SuccessfulAvatarUploadProfileRepository();
      final container = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final managedTempFile = await _createManagedAvatarTempFile();
      addTearDown(() async {
        if (await managedTempFile.exists()) {
          await managedTempFile.delete();
        }
      });

      await container
          .read(profileControllerProvider.notifier)
          .uploadAvatarFromPath(managedTempFile.path);

      expect(repository.uploadedPaths, [managedTempFile.path]);
      expect(await managedTempFile.exists(), isFalse);
    },
  );

  test('successful avatar upload keeps non-managed source file', () async {
    final repository = _SuccessfulAvatarUploadProfileRepository();
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final sourceDir = await Directory.systemTemp.createTemp(
      'petmagic-profile-source-',
    );
    addTearDown(() async {
      if (await sourceDir.exists()) {
        await sourceDir.delete(recursive: true);
      }
    });
    final sourceFile = File(
      '${sourceDir.path}${Platform.pathSeparator}avatar.jpg',
    );
    await sourceFile.writeAsBytes(List<int>.filled(32, 1), flush: true);

    await container
        .read(profileControllerProvider.notifier)
        .uploadAvatarFromPath(sourceFile.path);

    expect(repository.uploadedPaths, [sourceFile.path]);
    expect(await sourceFile.exists(), isTrue);
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

  test(
    'concurrent initialize calls share one in-flight profile request',
    () async {
      final repository = _DelayedInitializeProfileRepository();
      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedProfileAppLaunchController.new,
          ),
          profileRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(profileControllerProvider.notifier);
      final firstInitialize = controller.initialize();
      await repository.fetchProfileStarted.future;

      final secondInitialize = controller.initialize();

      repository.completeFetchProfile();
      await Future.wait([firstInitialize, secondInitialize]);

      expect(repository.readSessionCalls, 1);
      expect(repository.fetchProfileCalls, 1);
    },
  );

  test('provider disposal cancels active initialize profile fetch', () async {
    final repository = _CancellableInitializeProfileRepository();
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(repository)],
    );

    final controller = container.read(profileControllerProvider.notifier);
    final initializeFuture = controller.initialize();
    final cancelToken = await repository.fetchProfileStarted.future;
    expect(cancelToken.isCancelled, isFalse);

    container.dispose();

    expect(cancelToken.isCancelled, isTrue);
    await expectLater(initializeFuture, completes);
  });

  test(
    'logout cancels active initialize profile fetch and keeps session signed out',
    () async {
      final repository = _CancellableInitializeProfileRepository();
      final launchController = _MutableProfileAppLaunchController(true);
      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(() => launchController),
          profileRepositoryProvider.overrideWithValue(repository),
          externalAuthRepositoryProvider.overrideWith(
            (ref) => _NoopExternalAuthRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(profileControllerProvider.notifier);
      final initializeFuture = controller.initialize();
      final cancelToken = await repository.fetchProfileStarted.future;
      expect(cancelToken.isCancelled, isFalse);

      await controller.logout();

      expect(cancelToken.isCancelled, isTrue);
      await expectLater(initializeFuture, completes);
      final state = container.read(profileControllerProvider);
      final launchState = container.read(appLaunchControllerProvider);
      expect(state.profile, isNull);
      expect(state.isLoading, isFalse);
      expect(launchState.isAuthenticated, isFalse);
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

class _SuccessfulAvatarUploadProfileRepository extends ProfileRepository {
  _SuccessfulAvatarUploadProfileRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final List<String> uploadedPaths = <String>[];

  @override
  Future<MobileUserProfile> uploadAvatar(
    String filePath, {
    CancelToken? cancelToken,
  }) async {
    uploadedPaths.add(filePath);
    return _profile();
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
  Future<MobileUserProfile> fetchProfile({CancelToken? cancelToken}) async {
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

class _DelayedInitializeProfileRepository extends ProfileRepository {
  _DelayedInitializeProfileRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<void> fetchProfileStarted = Completer<void>();
  final Completer<MobileUserProfile> _fetchProfileCompleter =
      Completer<MobileUserProfile>();
  int readSessionCalls = 0;
  int fetchProfileCalls = 0;

  @override
  Future<AuthSession?> readSession() async {
    readSessionCalls++;
    return AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAtUtc: DateTime.utc(2026, 1, 1),
      user: _profile(),
    );
  }

  @override
  Future<MobileUserProfile> fetchProfile({CancelToken? cancelToken}) {
    fetchProfileCalls++;
    if (!fetchProfileStarted.isCompleted) {
      fetchProfileStarted.complete();
    }
    return _fetchProfileCompleter.future;
  }

  void completeFetchProfile() {
    if (!_fetchProfileCompleter.isCompleted) {
      _fetchProfileCompleter.complete(_profile());
    }
  }
}

class _CancellableInitializeProfileRepository extends ProfileRepository {
  _CancellableInitializeProfileRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<CancelToken> fetchProfileStarted = Completer<CancelToken>();

  @override
  Future<AuthSession?> readSession() async {
    return AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAtUtc: DateTime.utc(2026, 1, 1),
      user: _profile(),
    );
  }

  @override
  Future<MobileUserProfile> fetchProfile({CancelToken? cancelToken}) async {
    final token = cancelToken ?? CancelToken();
    if (!fetchProfileStarted.isCompleted) {
      fetchProfileStarted.complete(token);
    }

    await token.whenCancel;
    throw const RequestCancelledException();
  }

  @override
  Future<void> logout() async {}
}

class _AuthenticatedProfileAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: true,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class _MutableProfileAppLaunchController extends AppLaunchController {
  _MutableProfileAppLaunchController(this._isAuthenticated);

  bool _isAuthenticated;

  @override
  AppLaunchState build() {
    return AppLaunchState(
      isLoading: false,
      isAuthenticated: _isAuthenticated,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }

  @override
  void markSignedOut() {
    _isAuthenticated = false;
    super.markSignedOut();
  }
}

class _NoopExternalAuthRepository implements ExternalAuthRepository {
  @override
  Future<AuthSession> authenticate(ExternalAuthProvider provider) {
    throw UnimplementedError();
  }

  @override
  Future<List<MobileLinkedAccount>> link(ExternalAuthProvider provider) async {
    return const [];
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {}
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

Future<File> _createManagedAvatarTempFile() async {
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'petmagic_avatar_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  await file.writeAsBytes(List<int>.filled(64, 7), flush: true);
  return file;
}
