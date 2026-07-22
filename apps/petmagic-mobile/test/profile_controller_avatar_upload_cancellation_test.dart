import 'dart:async';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/application/avatar_media_gateway.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/data/mobile_avatar_media_gateway.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('provider disposal cancels active avatar upload', () async {
    final repository = _CancellableProfileRepository();
    final container = _profileControllerTestContainer(
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
    final container = _profileControllerTestContainer(
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
    'avatar upload cancels in-flight request when network goes offline',
    () async {
      final repository = _CancellableProfileRepository();
      final networkController = _TestNetworkStatusController(hasInternet: true);
      final container = _profileControllerTestContainer(
        networkStatusController: networkController,
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(profileControllerProvider.notifier);
      final uploadFuture = controller.uploadAvatarFromPath('/tmp/avatar.jpg');

      final cancelToken = await repository.uploadStarted.future;
      expect(cancelToken.isCancelled, isFalse);

      networkController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(profileControllerProvider);
      expect(cancelToken.isCancelled, isTrue);
      expect(state.isSaving, isFalse);
      expect(state.errorMessage, 'templates.network_unavailable');

      await expectLater(uploadFuture, completes);
      expect(
        container.read(profileControllerProvider).errorMessage,
        'templates.network_unavailable',
      );
    },
  );

  test(
    'successful avatar upload deletes managed temporary crop file',
    () async {
      final repository = _SuccessfulAvatarUploadProfileRepository();
      final container = _profileControllerTestContainer(
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
    final container = _profileControllerTestContainer(
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
    final container = _profileControllerTestContainer(
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
    'profile update cancels in-flight request when network goes offline',
    () async {
      final repository = _DelayedProfileMutationRepository();
      final networkController = _TestNetworkStatusController(hasInternet: true);
      final container = _profileControllerTestContainer(
        networkStatusController: networkController,
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(profileControllerProvider.notifier);
      final updateFuture = controller.updateCurrentProfile(
        displayName: 'Late name',
      );
      await repository.updateStarted.future;

      expect(repository.updateCancelToken?.isCancelled, isFalse);

      networkController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);

      var state = container.read(profileControllerProvider);
      expect(repository.updateCancelToken?.isCancelled, isTrue);
      expect(state.isSaving, isFalse);
      expect(state.errorMessage, 'templates.network_unavailable');

      repository.completeUpdate();
      await expectLater(updateFuture, completes);

      state = container.read(profileControllerProvider);
      expect(state.displayName, isNot('Late name'));
      expect(state.profile?.displayName, isNot('Late name'));
      expect(state.errorMessage, 'templates.network_unavailable');
    },
  );

  test(
    'avatar removal cancels in-flight request when network goes offline',
    () async {
      final repository = _DelayedProfileMutationRepository();
      final networkController = _TestNetworkStatusController(hasInternet: true);
      final container = _profileControllerTestContainer(
        networkStatusController: networkController,
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(profileControllerProvider.notifier);
      final removeFuture = controller.removeAvatar();
      await repository.removeStarted.future;

      expect(repository.removeCancelToken?.isCancelled, isFalse);

      networkController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(profileControllerProvider);
      expect(repository.removeCancelToken?.isCancelled, isTrue);
      expect(state.isSaving, isFalse);
      expect(state.errorMessage, 'templates.network_unavailable');

      repository.completeRemove();
      await expectLater(removeFuture, completes);
      expect(
        container.read(profileControllerProvider).errorMessage,
        'templates.network_unavailable',
      );
    },
  );

  test(
    'provider disposal ignores delayed login before profile fetch',
    () async {
      final repository = _DelayedLoginProfileRepository();
      final container = _profileControllerTestContainer(
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
    'login cancels in-flight auth request when network goes offline',
    () async {
      final repository = _DelayedLoginProfileRepository();
      final networkController = _TestNetworkStatusController(hasInternet: true);
      final container = _profileControllerTestContainer(
        networkStatusController: networkController,
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(profileControllerProvider.notifier)
        ..updateEmail('pet@example.com')
        ..updatePassword('hunter2');
      final loginFuture = controller.login();
      await repository.loginStarted.future;

      expect(repository.loginCancelToken?.isCancelled, isFalse);

      networkController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);

      var state = container.read(profileControllerProvider);
      expect(repository.loginCancelToken?.isCancelled, isTrue);
      expect(state.isSaving, isFalse);
      expect(state.errorMessage, 'templates.network_unavailable');

      repository.completeLogin();
      await expectLater(loginFuture, completes);

      state = container.read(profileControllerProvider);
      expect(repository.fetchProfileCalls, 0);
      expect(state.profile, isNull);
    },
  );

  test(
    'register cancels in-flight auth request when network goes offline',
    () async {
      final repository = _DelayedRegisterProfileRepository();
      final networkController = _TestNetworkStatusController(hasInternet: true);
      final container = _profileControllerTestContainer(
        networkStatusController: networkController,
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(profileControllerProvider.notifier)
        ..updateEmail('pet@example.com')
        ..updatePassword('Password123')
        ..updateConfirmPassword('Password123');
      final registerFuture = controller.register(
        termsOfUseAccepted: true,
        privacyPolicyAccepted: true,
        legalDocuments: _legalDocuments(),
        marketingEmailsEnabled: false,
      );
      await repository.registerStarted.future;

      expect(repository.registerCancelToken?.isCancelled, isFalse);

      networkController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);

      var state = container.read(profileControllerProvider);
      expect(repository.registerCancelToken?.isCancelled, isTrue);
      expect(state.isSaving, isFalse);
      expect(state.errorMessage, 'templates.network_unavailable');

      repository.completeRegister();
      await expectLater(registerFuture, completes);

      state = container.read(profileControllerProvider);
      expect(state.successMessage, isNull);
      expect(state.profile, isNull);
    },
  );

  test(
    'external authentication ignores delayed success when network goes offline',
    () async {
      final externalAuthRepository = _DelayedExternalAuthRepository();
      final networkController = _TestNetworkStatusController(hasInternet: true);
      final container = _profileControllerTestContainer(
        networkStatusController: networkController,
        overrides: [
          externalAuthRepositoryProvider.overrideWithValue(
            externalAuthRepository,
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(profileControllerProvider.notifier);
      final authFuture = controller.authenticateWithProvider(
        ExternalAuthProvider.google,
      );
      await externalAuthRepository.authenticateStarted.future;

      expect(
        externalAuthRepository.authenticateCancelToken?.isCancelled,
        isFalse,
      );

      networkController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);

      var state = container.read(profileControllerProvider);
      expect(
        externalAuthRepository.authenticateCancelToken?.isCancelled,
        isTrue,
      );
      expect(state.isSaving, isFalse);
      expect(state.errorMessage, 'templates.network_unavailable');

      externalAuthRepository.completeAuthenticate();
      await expectLater(authFuture, completes);

      state = container.read(profileControllerProvider);
      expect(state.profile, isNull);
    },
  );

  test(
    'external account link ignores delayed success when network goes offline',
    () async {
      final externalAuthRepository = _DelayedExternalAuthRepository();
      final networkController = _TestNetworkStatusController(hasInternet: true);
      final container = _profileControllerTestContainer(
        networkStatusController: networkController,
        overrides: [
          externalAuthRepositoryProvider.overrideWithValue(
            externalAuthRepository,
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(profileControllerProvider.notifier);
      final linkFuture = controller.linkExternalAccount(
        ExternalAuthProvider.google,
      );
      await externalAuthRepository.linkStarted.future;

      expect(externalAuthRepository.linkCancelToken?.isCancelled, isFalse);

      networkController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);

      var state = container.read(profileControllerProvider);
      expect(externalAuthRepository.linkCancelToken?.isCancelled, isTrue);
      expect(state.isSaving, isFalse);
      expect(state.errorMessage, 'templates.network_unavailable');

      externalAuthRepository.completeLink();
      await expectLater(linkFuture, completes);

      state = container.read(profileControllerProvider);
      expect(state.isSaving, isFalse);
    },
  );

  test(
    'external account unlink cancels in-flight request when network goes offline',
    () async {
      final repository = _DelayedUnlinkProfileRepository();
      final networkController = _TestNetworkStatusController(hasInternet: true);
      final container = _profileControllerTestContainer(
        networkStatusController: networkController,
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(profileControllerProvider.notifier);
      final unlinkFuture = controller.unlinkExternalAccount(
        ExternalAuthProvider.google,
      );
      await repository.unlinkStarted.future;

      expect(repository.unlinkCancelToken?.isCancelled, isFalse);

      networkController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);

      var state = container.read(profileControllerProvider);
      expect(repository.unlinkCancelToken?.isCancelled, isTrue);
      expect(state.isSaving, isFalse);
      expect(state.errorMessage, 'templates.network_unavailable');

      repository.completeUnlink();
      await expectLater(unlinkFuture, completes);

      state = container.read(profileControllerProvider);
      expect(state.isSaving, isFalse);
    },
  );

  test(
    'concurrent initialize calls share one in-flight profile request',
    () async {
      final repository = _DelayedInitializeProfileRepository();
      final container = _profileControllerTestContainer(
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
    final container = _profileControllerTestContainer(
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
      final container = _profileControllerTestContainer(
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

  test(
    'profile write actions skip network repositories while offline',
    () async {
      final repository = _TrackingProfileWriteRepository();
      final externalAuthRepository = _TrackingExternalAuthRepository();
      final container = _profileControllerTestContainer(
        hasInternet: false,
        overrides: [
          profileRepositoryProvider.overrideWithValue(repository),
          externalAuthRepositoryProvider.overrideWithValue(
            externalAuthRepository,
          ),
        ],
      );
      addTearDown(container.dispose);

      final managedTempFile = await _createManagedAvatarTempFile();
      addTearDown(() async {
        if (await managedTempFile.exists()) {
          await managedTempFile.delete();
        }
      });

      final controller = container.read(profileControllerProvider.notifier);

      await controller.authenticateWithProvider(ExternalAuthProvider.google);
      await controller.linkExternalAccount(ExternalAuthProvider.google);
      await controller.unlinkExternalAccount(ExternalAuthProvider.google);
      await controller.deleteAccount();
      await controller.uploadAvatarFromPath(managedTempFile.path);
      await controller.removeAvatar();
      await controller.updateCurrentProfile(displayName: 'New name');
      await controller.acceptCurrentLegalDocuments(_legalDocuments());

      expect(externalAuthRepository.authenticateCalls, 0);
      expect(externalAuthRepository.linkCalls, 0);
      expect(repository.unlinkCalls, 0);
      expect(repository.deleteAccountCalls, 0);
      expect(repository.uploadCalls, 0);
      expect(repository.removeCalls, 0);
      expect(repository.updateCalls, 0);
      expect(repository.acceptLegalCalls, 0);
      expect(await managedTempFile.exists(), isFalse);

      final state = container.read(profileControllerProvider);
      expect(state.isSaving, isFalse);
      expect(state.errorMessage, 'templates.network_unavailable');
    },
  );
}

ProviderContainer _profileControllerTestContainer({
  required List<Object?> overrides,
  bool hasInternet = true,
  NetworkStatusController? networkStatusController,
}) {
  return ProviderContainer(
    overrides: [
      avatarMediaGatewayProvider.overrideWithValue(MobileAvatarMediaGateway()),
      networkStatusControllerProvider.overrideWith(
        () =>
            networkStatusController ??
            _TestNetworkStatusController(hasInternet: hasInternet),
      ),
      ...overrides.cast(),
    ],
  );
}

class _CancellableProfileRepository extends ProfileRepository {
  _CancellableProfileRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<RequestCancellation> uploadStarted =
      Completer<RequestCancellation>();
  int uploadCalls = 0;

  @override
  Future<MobileUserProfile> uploadAvatar(
    String filePath, {
    RequestCancellation? cancelToken,
  }) async {
    uploadCalls++;
    final token = cancelToken ?? RequestCancellation();
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
  Future<MobileUserProfile> removeAvatar({RequestCancellation? cancelToken}) {
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

class _DelayedProfileMutationRepository extends ProfileRepository {
  _DelayedProfileMutationRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<void> updateStarted = Completer<void>();
  final Completer<MobileUserProfile> _updateCompleter =
      Completer<MobileUserProfile>();
  final Completer<void> removeStarted = Completer<void>();
  final Completer<MobileUserProfile> _removeCompleter =
      Completer<MobileUserProfile>();
  RequestCancellation? updateCancelToken;
  RequestCancellation? removeCancelToken;

  @override
  Future<MobileUserProfile> updateProfile({
    required String? displayName,
    RequestCancellation? cancelToken,
  }) {
    updateCancelToken = cancelToken;
    if (!updateStarted.isCompleted) {
      updateStarted.complete();
    }
    return _updateCompleter.future;
  }

  @override
  Future<MobileUserProfile> removeAvatar({RequestCancellation? cancelToken}) {
    removeCancelToken = cancelToken;
    if (!removeStarted.isCompleted) {
      removeStarted.complete();
    }
    return _removeCompleter.future;
  }

  void completeUpdate() {
    if (!_updateCompleter.isCompleted) {
      _updateCompleter.complete(_profileWithDisplayName('Late name'));
    }
  }

  void completeRemove() {
    if (!_removeCompleter.isCompleted) {
      _removeCompleter.complete(_profileWithDisplayName('Removed avatar'));
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
    RequestCancellation? cancelToken,
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
  RequestCancellation? loginCancelToken;
  int fetchProfileCalls = 0;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    RequestCancellation? cancelToken,
  }) {
    loginCancelToken = cancelToken;
    if (!loginStarted.isCompleted) {
      loginStarted.complete();
    }
    return _loginCompleter.future;
  }

  @override
  Future<MobileUserProfile> fetchProfile({
    RequestCancellation? cancelToken,
  }) async {
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

class _DelayedRegisterProfileRepository extends ProfileRepository {
  _DelayedRegisterProfileRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<void> registerStarted = Completer<void>();
  final Completer<void> _registerCompleter = Completer<void>();
  RequestCancellation? registerCancelToken;

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
  }) {
    registerCancelToken = cancelToken;
    if (!registerStarted.isCompleted) {
      registerStarted.complete();
    }
    return _registerCompleter.future;
  }

  void completeRegister() {
    if (!_registerCompleter.isCompleted) {
      _registerCompleter.complete();
    }
  }
}

class _DelayedUnlinkProfileRepository extends ProfileRepository {
  _DelayedUnlinkProfileRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<void> unlinkStarted = Completer<void>();
  final Completer<List<MobileLinkedAccount>> _unlinkCompleter =
      Completer<List<MobileLinkedAccount>>();
  RequestCancellation? unlinkCancelToken;

  @override
  Future<List<MobileLinkedAccount>> unlinkLinkedAccount(
    String provider, {
    RequestCancellation? cancelToken,
  }) {
    unlinkCancelToken = cancelToken;
    if (!unlinkStarted.isCompleted) {
      unlinkStarted.complete();
    }
    return _unlinkCompleter.future;
  }

  void completeUnlink() {
    if (!_unlinkCompleter.isCompleted) {
      _unlinkCompleter.complete(const []);
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
  Future<MobileUserProfile> fetchProfile({RequestCancellation? cancelToken}) {
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

  final Completer<RequestCancellation> fetchProfileStarted =
      Completer<RequestCancellation>();

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
  Future<MobileUserProfile> fetchProfile({
    RequestCancellation? cancelToken,
  }) async {
    final token = cancelToken ?? RequestCancellation();
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
  Future<AuthSession> authenticate(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<MobileLinkedAccount>> link(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) async {
    return const [];
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {}
}

class _TrackingProfileWriteRepository extends ProfileRepository {
  _TrackingProfileWriteRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  int unlinkCalls = 0;
  int deleteAccountCalls = 0;
  int uploadCalls = 0;
  int removeCalls = 0;
  int updateCalls = 0;
  int acceptLegalCalls = 0;

  @override
  Future<List<MobileLinkedAccount>> unlinkLinkedAccount(
    String provider, {
    RequestCancellation? cancelToken,
  }) async {
    unlinkCalls++;
    return const [];
  }

  @override
  Future<void> deleteCurrentAccount({RequestCancellation? cancelToken}) async {
    deleteAccountCalls++;
  }

  @override
  Future<MobileUserProfile> uploadAvatar(
    String filePath, {
    RequestCancellation? cancelToken,
  }) async {
    uploadCalls++;
    return _profile();
  }

  @override
  Future<MobileUserProfile> removeAvatar({
    RequestCancellation? cancelToken,
  }) async {
    removeCalls++;
    return _profile();
  }

  @override
  Future<MobileUserProfile> updateProfile({
    required String? displayName,
    RequestCancellation? cancelToken,
  }) async {
    updateCalls++;
    return _profile();
  }

  @override
  Future<MobileUserProfile> acceptCurrentLegalDocuments({
    required MobileLegalDocuments documents,
    RequestCancellation? cancelToken,
  }) async {
    acceptLegalCalls++;
    return _profile();
  }
}

class _TrackingExternalAuthRepository implements ExternalAuthRepository {
  int authenticateCalls = 0;
  int linkCalls = 0;
  int clearSessionCalls = 0;

  @override
  Future<AuthSession> authenticate(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) async {
    authenticateCalls++;
    return AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAtUtc: DateTime.utc(2026, 1, 1),
      user: _profile(),
    );
  }

  @override
  Future<List<MobileLinkedAccount>> link(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) async {
    linkCalls++;
    return const [];
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {
    clearSessionCalls++;
  }
}

class _DelayedExternalAuthRepository implements ExternalAuthRepository {
  final Completer<void> authenticateStarted = Completer<void>();
  final Completer<AuthSession> _authenticateCompleter =
      Completer<AuthSession>();
  final Completer<void> linkStarted = Completer<void>();
  final Completer<List<MobileLinkedAccount>> _linkCompleter =
      Completer<List<MobileLinkedAccount>>();
  RequestCancellation? authenticateCancelToken;
  RequestCancellation? linkCancelToken;

  @override
  Future<AuthSession> authenticate(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) {
    authenticateCancelToken = cancelToken;
    if (!authenticateStarted.isCompleted) {
      authenticateStarted.complete();
    }
    return _authenticateCompleter.future;
  }

  @override
  Future<List<MobileLinkedAccount>> link(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) {
    linkCancelToken = cancelToken;
    if (!linkStarted.isCompleted) {
      linkStarted.complete();
    }
    return _linkCompleter.future;
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {}

  void completeAuthenticate() {
    if (!_authenticateCompleter.isCompleted) {
      _authenticateCompleter.complete(
        AuthSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          expiresAtUtc: DateTime.utc(2026, 1, 1),
          user: _profile(),
        ),
      );
    }
  }

  void completeLink() {
    if (!_linkCompleter.isCompleted) {
      _linkCompleter.complete(const []);
    }
  }
}

class _TestNetworkStatusController extends NetworkStatusController {
  _TestNetworkStatusController({required this.hasInternet});

  final bool hasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: hasInternet);
  }

  void setHasInternet(bool value) {
    state = state.copyWith(hasInternet: value);
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

MobileUserProfile _profileWithDisplayName(String displayName) {
  return MobileUserProfile(
    userId: 'user-1',
    email: 'pet@example.com',
    displayName: displayName,
    isPremium: false,
    emailConfirmed: true,
    termsOfUseAccepted: true,
    privacyPolicyAccepted: true,
    marketingEmailsEnabled: false,
    legalAcceptance: const MobileLegalAcceptanceStatus(
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
    roles: const ['user'],
    avatar: null,
  );
}

MobileLegalDocuments _legalDocuments() {
  return const MobileLegalDocuments(
    termsOfUse: MobileLegalDocument(
      kind: 'terms',
      title: 'Terms',
      version: '1.0',
      publishedAtUtc: null,
      summary: 'Terms',
      sections: [],
    ),
    privacyPolicy: MobileLegalDocument(
      kind: 'privacy',
      title: 'Privacy',
      version: '1.0',
      publishedAtUtc: null,
      summary: 'Privacy',
      sections: [],
    ),
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
