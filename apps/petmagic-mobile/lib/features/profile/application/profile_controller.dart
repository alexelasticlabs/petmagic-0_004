// Public profile application state and use-case orchestration.

import 'package:petmagic_mobile/core/files/local_media_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/application/avatar_media_gateway.dart';
import 'package:petmagic_mobile/features/profile/application/external_auth_gateway.dart';
import 'package:petmagic_mobile/features/profile/application/profile_account_coordinator.dart';
import 'package:petmagic_mobile/features/profile/application/profile_auth_coordinator.dart';
import 'package:petmagic_mobile/features/profile/application/profile_avatar_coordinator.dart';
import 'package:petmagic_mobile/features/profile/application/profile_bootstrap_service.dart';
import 'package:petmagic_mobile/features/profile/application/profile_mutation_coordinator.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/application/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/application/profile_request_tracker.dart';
import 'package:petmagic_mobile/features/profile/application/profile_state.dart';
import 'package:petmagic_mobile/features/profile/application/push_token_lifecycle_port.dart';

export 'package:petmagic_mobile/features/profile/application/profile_state.dart';

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(ProfileController.new);

class ProfileController extends Notifier<ProfileState> {
  void _logProfileFailure(
    String stage,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> context = const {},
  }) {
    final payload = <String, Object>{'stage': stage};
    for (final entry in context.entries) {
      final value = entry.value;
      if (value != null) {
        payload[entry.key] = value.toString();
      }
    }

    AppLogger.warn(
      feature: 'Profile',
      operation: stage,
      message: 'Profile controller step failed',
      context: payload,
      error: error,
      stackTrace: stackTrace,
    );
  }

  final _requestTracker = ProfileRequestTracker();
  Future<void>? _initializeInFlight;

  ProfileRepositoryPort get _repository => ref.read(profileRepositoryProvider);

  ProfileAuthCoordinator get _authCoordinator => ProfileAuthCoordinator(
    repository: () => _repository,
    externalAuthRepository: () => ref.read(externalAuthRepositoryProvider),
    requestTracker: _requestTracker,
    readState: () => state,
    writeState: (next) => state = next,
    updateState: _updateStateIfMounted,
    ensureNetwork: _ensureNetworkForAction,
    canContinue: () => ref.mounted,
    setFailure: (message) => _setFailure(message: message),
    markSignedIn: (requiresLegalAcceptance) {
      ref
          .read(appLaunchControllerProvider.notifier)
          .markSignedInWithLegalStatus(
            requiresLegalAcceptance: requiresLegalAcceptance,
          );
    },
    invalidateLinkedAccounts: () => ref.invalidate(linkedAccountsProvider),
    logFailure: _logProfileFailure,
  );

  ProfileAccountCoordinator get _accountCoordinator =>
      ProfileAccountCoordinator(
        repository: () => _repository,
        externalAuthRepository: () => ref.read(externalAuthRepositoryProvider),
        pushTokenLifecycle: () => ref.read(pushTokenLifecyclePortProvider),
        requestTracker: _requestTracker,
        updateState: _updateStateIfMounted,
        ensureNetwork: _ensureNetworkForAction,
        canContinue: () => ref.mounted,
        setFailure: (message) => _setFailure(message: message),
        markSignedOut: () =>
            ref.read(appLaunchControllerProvider.notifier).markSignedOut(),
        logFailure: _logProfileFailure,
      );

  ProfileAvatarCoordinator get _avatarCoordinator => ProfileAvatarCoordinator(
    repository: _repository,
    mediaGateway: ref.read(avatarMediaGatewayProvider),
    requestTracker: _requestTracker,
    readState: () => state,
    updateState: _updateStateIfMounted,
    ensureNetwork: _ensureNetworkForAction,
    hasInternet: () => ref.read(networkStatusControllerProvider).hasInternet,
    canContinue: () => ref.mounted,
    setFailure: (message) => _setFailure(message: message),
    markSignedIn: (requiresLegalAcceptance) {
      ref
          .read(appLaunchControllerProvider.notifier)
          .markSignedInWithLegalStatus(
            requiresLegalAcceptance: requiresLegalAcceptance,
          );
    },
    logFailure: _logProfileFailure,
  );

  ProfileMutationCoordinator get _mutationCoordinator =>
      ProfileMutationCoordinator(
        repository: _repository,
        requestTracker: _requestTracker,
        updateState: _updateStateIfMounted,
        ensureNetwork: _ensureNetworkForAction,
        canContinue: () => ref.mounted,
        setFailure: (message) => _setFailure(message: message),
        logFailure: _logProfileFailure,
      );

  @override
  ProfileState build() {
    ref.listen<AppLaunchState>(
      appLaunchControllerProvider,
      _handleLaunchStateChanged,
    );
    ref.listen<bool>(
      networkStatusControllerProvider.select((state) => state.hasInternet),
      (_, hasInternet) => _handleNetworkStatusChanged(hasInternet),
    );
    ref.onDispose(() {
      _requestTracker.cancelAll();
    });
    return const ProfileState.initial();
  }

  void _handleLaunchStateChanged(
    AppLaunchState? previous,
    AppLaunchState next,
  ) {
    if (next.isLoading || next.isAuthenticated) {
      return;
    }

    if (previous?.isAuthenticated != true) {
      return;
    }

    _requestTracker.cancelAll();
    _updateStateIfMounted(
      (state) => state.copyWith(
        isLoading: false,
        isSaving: false,
        password: '',
        confirmPassword: '',
        clearProfile: true,
        clearError: true,
      ),
    );
  }

  void _updateStateIfMounted(
    ProfileState Function(ProfileState current) update,
  ) {
    if (!ref.mounted) {
      return;
    }

    state = update(state);
  }

  void _handleNetworkStatusChanged(bool hasInternet) {
    if (hasInternet) {
      return;
    }

    final hasActiveAuth = _requestTracker.hasActiveAuth;
    final hasActiveProfileMutation = _requestTracker.hasActiveProfileMutation;
    _requestTracker.cancelAvatarUpload();
    _requestTracker.cancelProfileMutation();
    if (hasActiveAuth || !hasActiveProfileMutation) {
      return;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(
        isSaving: false,
        errorMessage: 'templates.network_unavailable',
        clearSuccess: true,
      ),
    );
  }

  Future<void> initialize({String initialEmail = ''}) async {
    final inFlight = _initializeInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final operation = () async {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
        clearSuccess: true,
      );

      final initializeRequestCancellation = _requestTracker.startInitialize();
      try {
        final result = await ProfileBootstrapService(repository: _repository)
            .restore(
              cancelToken: initializeRequestCancellation,
              canContinue: () => ref.mounted,
              logFailure: _logProfileFailure,
            );
        if (result.isAborted) {
          return;
        }
        if (result.isCancelled) {
          _updateStateIfMounted(
            (state) => state.copyWith(isLoading: false, clearError: true),
          );
          return;
        }

        final profile = result.profile;
        _updateStateIfMounted(
          (state) => state.copyWith(
            isLoading: false,
            profile: profile,
            email: profile?.email ?? initialEmail,
            errorMessage: result.errorMessage,
            clearError: result.errorMessage == null,
            clearSuccess: result.errorMessage != null,
            clearSession: profile == null,
            clearProfile: profile == null,
          ),
        );

        if (!ref.mounted || profile == null) {
          if (result.shouldMarkSignedOut && ref.mounted) {
            ref.read(appLaunchControllerProvider.notifier).markSignedOut();
          }
          return;
        }
        ref
            .read(appLaunchControllerProvider.notifier)
            .markSignedInWithLegalStatus(
              requiresLegalAcceptance:
                  profile.legalAcceptance.requiresAcceptance,
            );
      } finally {
        _requestTracker.clearInitialize(initializeRequestCancellation);
      }
    }();

    _initializeInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_initializeInFlight, operation)) {
        _initializeInFlight = null;
      }
    }
  }

  void updateEmail(String value) {
    state = state.copyWith(email: value, clearError: true, clearSuccess: true);
  }

  void updateDisplayName(String value) {
    state = state.copyWith(
      displayName: value,
      clearError: true,
      clearSuccess: true,
    );
  }

  void updatePassword(String value) {
    state = state.copyWith(
      password: value,
      clearError: true,
      clearSuccess: true,
    );
  }

  void updateConfirmPassword(String value) {
    state = state.copyWith(
      confirmPassword: value,
      clearError: true,
      clearSuccess: true,
    );
  }

  Future<void> login() => _authCoordinator.login();

  Future<void> register({
    required bool termsOfUseAccepted,
    required bool privacyPolicyAccepted,
    required MobileLegalDocuments? legalDocuments,
    required bool marketingEmailsEnabled,
  }) {
    return _authCoordinator.register(
      termsOfUseAccepted: termsOfUseAccepted,
      privacyPolicyAccepted: privacyPolicyAccepted,
      legalDocuments: legalDocuments,
      marketingEmailsEnabled: marketingEmailsEnabled,
    );
  }

  Future<void> authenticateWithProvider(ExternalAuthProvider provider) {
    return _authCoordinator.authenticateWithProvider(provider);
  }

  Future<void> linkExternalAccount(ExternalAuthProvider provider) {
    return _authCoordinator.linkExternalAccount(provider);
  }

  Future<void> unlinkExternalAccount(ExternalAuthProvider provider) {
    return _authCoordinator.unlinkExternalAccount(provider);
  }

  Future<void> logout() => _accountCoordinator.logout();

  Future<void> deleteAccount() => _accountCoordinator.deleteAccount();

  Future<LocalMediaFile?> pickAvatarImage() => _avatarCoordinator.pickImage();

  Future<void> uploadAvatarFromPath(String filePath) {
    return _avatarCoordinator.uploadFromPath(filePath);
  }

  Future<void> removeAvatar() => _avatarCoordinator.remove();

  Future<void> updateCurrentProfile({required String? displayName}) {
    return _mutationCoordinator.updateProfile(displayName: displayName);
  }

  Future<void> acceptCurrentLegalDocuments(
    MobileLegalDocuments legalDocuments,
  ) {
    return _mutationCoordinator.acceptLegalDocuments(legalDocuments);
  }

  bool _ensureNetworkForAction() {
    if (ref.read(networkStatusControllerProvider).hasInternet) {
      return true;
    }

    _setFailure(message: 'templates.network_unavailable');
    return false;
  }

  void _setFailure({
    required String message,
    String? email,
    bool clearSession = false,
    bool clearProfile = false,
  }) {
    _updateStateIfMounted(
      (state) => state.copyWith(
        isLoading: false,
        isSaving: false,
        email: email,
        errorMessage: message,
        clearSuccess: true,
        clearSession: clearSession,
        clearProfile: clearProfile,
      ),
    );
  }
}

// Public profile application controller.
