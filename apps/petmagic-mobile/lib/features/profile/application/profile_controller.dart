// Public profile application state and use-case orchestration.

import 'package:petmagic_mobile/core/files/local_media_file.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/application/avatar_media_gateway.dart';
import 'package:petmagic_mobile/features/profile/application/external_auth_gateway.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/application/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/application/push_token_lifecycle_port.dart';
import 'package:petmagic_mobile/features/profile/domain/auth_password_policy.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(ProfileController.new);

class ProfileState {
  const ProfileState({
    required this.isLoading,
    required this.isSaving,
    required this.displayName,
    required this.email,
    required this.password,
    required this.confirmPassword,
    this.profile,
    this.errorMessage,
    this.successMessage,
  });

  const ProfileState.initial()
    : this(
        isLoading: true,
        isSaving: false,
        displayName: '',
        email: '',
        password: '',
        confirmPassword: '',
      );

  final bool isLoading;
  final bool isSaving;
  final String displayName;
  final String email;
  final String password;
  final String confirmPassword;
  final MobileUserProfile? profile;
  final String? errorMessage;
  final String? successMessage;

  bool get isAuthenticated => profile != null;

  ProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? displayName,
    String? email,
    String? password,
    String? confirmPassword,
    MobileUserProfile? profile,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearSession = false,
    bool clearProfile = false,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      profile: clearProfile ? null : (profile ?? this.profile),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

class ProfileController extends Notifier<ProfileState> {
  static const _genericActionError = 'profile.action_failed';

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

  RequestCancellation? _activeAvatarUploadRequestCancellation;
  RequestCancellation? _activeInitializeRequestCancellation;
  RequestCancellation? _activeAuthRequestCancellation;
  RequestCancellation? _activeProfileMutationRequestCancellation;
  Future<void>? _initializeInFlight;

  ProfileRepositoryPort get _repository => ref.read(profileRepositoryProvider);

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
      _cancelActiveInitialize();
      _cancelActiveAvatarUpload();
      _cancelActiveAuthRequest();
      _cancelActiveProfileMutation();
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

    _cancelActiveInitialize();
    _cancelActiveAvatarUpload();
    _cancelActiveAuthRequest();
    _cancelActiveProfileMutation();
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

  RequestCancellation? _startAvatarUpload() {
    if (_activeAvatarUploadRequestCancellation != null) {
      return null;
    }

    final cancelToken = RequestCancellation();
    _activeAvatarUploadRequestCancellation = cancelToken;
    return cancelToken;
  }

  void _cancelActiveAvatarUpload() {
    final cancelToken = _activeAvatarUploadRequestCancellation;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('profile_avatar_upload_cancelled');
    }
    _activeAvatarUploadRequestCancellation = null;
  }

  void _clearActiveAvatarUpload(RequestCancellation cancelToken) {
    if (identical(_activeAvatarUploadRequestCancellation, cancelToken)) {
      _activeAvatarUploadRequestCancellation = null;
    }
  }

  RequestCancellation _startInitializeRequest() {
    _cancelActiveInitialize();
    final cancelToken = RequestCancellation();
    _activeInitializeRequestCancellation = cancelToken;
    return cancelToken;
  }

  void _cancelActiveInitialize() {
    final cancelToken = _activeInitializeRequestCancellation;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('profile_initialize_cancelled');
    }
    _activeInitializeRequestCancellation = null;
  }

  void _clearActiveInitialize(RequestCancellation cancelToken) {
    if (identical(_activeInitializeRequestCancellation, cancelToken)) {
      _activeInitializeRequestCancellation = null;
    }
  }

  void _handleNetworkStatusChanged(bool hasInternet) {
    if (hasInternet) {
      return;
    }

    _cancelActiveAvatarUpload();
    _cancelActiveAuthRequest();
    _cancelActiveProfileMutation();
    _updateStateIfMounted(
      (state) => state.copyWith(
        isSaving: false,
        errorMessage: 'templates.network_unavailable',
        clearSuccess: true,
      ),
    );
  }

  RequestCancellation _startAuthRequest() {
    _cancelActiveAuthRequest();
    final cancelToken = RequestCancellation();
    _activeAuthRequestCancellation = cancelToken;
    return cancelToken;
  }

  void _cancelActiveAuthRequest() {
    final cancelToken = _activeAuthRequestCancellation;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('profile_auth_cancelled');
    }
    _activeAuthRequestCancellation = null;
  }

  void _clearActiveAuthRequest(RequestCancellation cancelToken) {
    if (identical(_activeAuthRequestCancellation, cancelToken)) {
      _activeAuthRequestCancellation = null;
    }
  }

  void _handleCancelledAuthRequest(RequestCancellation cancelToken) {
    if (!identical(_activeAuthRequestCancellation, cancelToken)) {
      return;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(isSaving: false, clearError: true),
    );
  }

  RequestCancellation _startProfileMutation() {
    _cancelActiveProfileMutation();
    final cancelToken = RequestCancellation();
    _activeProfileMutationRequestCancellation = cancelToken;
    return cancelToken;
  }

  void _cancelActiveProfileMutation() {
    final cancelToken = _activeProfileMutationRequestCancellation;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('profile_mutation_cancelled');
    }
    _activeProfileMutationRequestCancellation = null;
  }

  void _clearActiveProfileMutation(RequestCancellation cancelToken) {
    if (identical(_activeProfileMutationRequestCancellation, cancelToken)) {
      _activeProfileMutationRequestCancellation = null;
    }
  }

  Future<void> initialize({String initialEmail = ''}) async {
    final inFlight = _initializeInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final repository = _repository;
    final operation = () async {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
        clearSuccess: true,
      );

      final initializeRequestCancellation = _startInitializeRequest();
      try {
        final session = await repository.readSession();
        if (!ref.mounted) {
          return;
        }
        if (session == null) {
          _updateStateIfMounted(
            (state) => state.copyWith(
              isLoading: false,
              email: initialEmail,
              clearSession: true,
              clearProfile: true,
            ),
          );
          return;
        }

        final profile = await repository.fetchProfile(
          cancelToken: initializeRequestCancellation,
        );
        if (!ref.mounted) {
          return;
        }
        _updateStateIfMounted(
          (state) => state.copyWith(
            isLoading: false,
            profile: profile,
            email: profile.email,
            clearError: true,
          ),
        );
        if (!ref.mounted) {
          return;
        }
        ref
            .read(appLaunchControllerProvider.notifier)
            .markSignedInWithLegalStatus(
              requiresLegalAcceptance:
                  profile.legalAcceptance.requiresAcceptance,
            );
      } on RequestCancelledException {
        _updateStateIfMounted(
          (state) => state.copyWith(isLoading: false, clearError: true),
        );
      } on AppException catch (error) {
        final storedSession = await repository.readSession();
        if (!ref.mounted) {
          return;
        }
        if (storedSession != null && error.statusCode != 401) {
          _updateStateIfMounted(
            (state) => state.copyWith(
              isLoading: false,
              profile: storedSession.user,
              email: storedSession.user.email,
              errorMessage: error.message,
              clearSuccess: true,
            ),
          );
          return;
        }

        if (error.statusCode == 401) {
          if (!ref.mounted) {
            return;
          }
          ref.read(appLaunchControllerProvider.notifier).markSignedOut();
        }

        _updateStateIfMounted(
          (state) => state.copyWith(
            isLoading: false,
            email: initialEmail,
            errorMessage: error.message,
            clearSession: true,
            clearProfile: true,
          ),
        );
      } catch (error, stackTrace) {
        _logProfileFailure('initialize_unknown', error, stackTrace);
        final storedSession = await repository.readSession();
        if (!ref.mounted) {
          return;
        }
        if (storedSession != null) {
          _updateStateIfMounted(
            (state) => state.copyWith(
              isLoading: false,
              profile: storedSession.user,
              email: storedSession.user.email,
              errorMessage: _genericActionError,
              clearSuccess: true,
            ),
          );
          return;
        }

        _setFailure(
          message: _genericActionError,
          email: initialEmail,
          clearSession: true,
          clearProfile: true,
        );
      } finally {
        _clearActiveInitialize(initializeRequestCancellation);
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

  Future<void> login() async {
    if (state.isSaving) {
      return;
    }

    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      _setFailure(message: 'templates.network_unavailable');
      return;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final repository = _repository;
    final authRequestCancellation = _startAuthRequest();
    try {
      await repository.login(
        email: state.email,
        password: state.password,
        cancelToken: authRequestCancellation,
      );
      if (!ref.mounted || authRequestCancellation.isCancelled) {
        return;
      }
      final profile = await repository.fetchProfile(
        cancelToken: authRequestCancellation,
      );
      if (!ref.mounted || authRequestCancellation.isCancelled) {
        return;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSaving: false,
          profile: profile,
          password: '',
          confirmPassword: '',
        ),
      );
      if (!ref.mounted) {
        return;
      }
      ref
          .read(appLaunchControllerProvider.notifier)
          .markSignedInWithLegalStatus(
            requiresLegalAcceptance: profile.legalAcceptance.requiresAcceptance,
          );
    } on RequestCancelledException {
      _handleCancelledAuthRequest(authRequestCancellation);
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('login_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    } finally {
      _clearActiveAuthRequest(authRequestCancellation);
    }
  }

  Future<void> register({
    required bool termsOfUseAccepted,
    required bool privacyPolicyAccepted,
    required MobileLegalDocuments? legalDocuments,
    required bool marketingEmailsEnabled,
  }) async {
    if (state.isSaving) {
      return;
    }

    if (!AuthPasswordPolicy.isValid(state.password)) {
      state = state.copyWith(
        errorMessage: AuthPasswordPolicy.errorMessage,
        clearSuccess: true,
      );
      return;
    }

    if (state.password != state.confirmPassword) {
      state = state.copyWith(
        errorMessage: 'auth.password_mismatch',
        clearSuccess: true,
      );
      return;
    }

    if (legalDocuments == null ||
        legalDocuments.termsOfUse.version.trim().isEmpty ||
        legalDocuments.privacyPolicy.version.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'auth.legal_documents_unavailable',
        clearSuccess: true,
      );
      return;
    }

    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      _setFailure(message: 'templates.network_unavailable');
      return;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final repository = _repository;
    final authRequestCancellation = _startAuthRequest();
    try {
      await repository.register(
        email: state.email,
        password: state.password,
        displayName: state.displayName,
        termsOfUseAccepted: termsOfUseAccepted,
        privacyPolicyAccepted: privacyPolicyAccepted,
        termsOfUseVersion: legalDocuments.termsOfUse.version,
        privacyPolicyVersion: legalDocuments.privacyPolicy.version,
        marketingEmailsEnabled: marketingEmailsEnabled,
        cancelToken: authRequestCancellation,
      );
      if (!ref.mounted || authRequestCancellation.isCancelled) {
        return;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSaving: false,
          clearSession: true,
          clearProfile: true,
          password: '',
          confirmPassword: '',
          successMessage: 'auth.registration_pending_verification',
        ),
      );
    } on RequestCancelledException {
      _handleCancelledAuthRequest(authRequestCancellation);
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('register_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    } finally {
      _clearActiveAuthRequest(authRequestCancellation);
    }
  }

  Future<void> authenticateWithProvider(ExternalAuthProvider provider) async {
    if (state.isSaving) {
      return;
    }

    if (!_ensureNetworkForAction()) {
      return;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final externalAuthRepository = ref.read(externalAuthRepositoryProvider);
    final authRequestCancellation = _startAuthRequest();
    try {
      final session = await externalAuthRepository.authenticate(
        provider,
        cancelToken: authRequestCancellation,
      );
      if (!ref.mounted || authRequestCancellation.isCancelled) {
        return;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSaving: false,
          profile: session.user,
          password: '',
          confirmPassword: '',
        ),
      );
      if (!ref.mounted) {
        return;
      }
      ref
          .read(appLaunchControllerProvider.notifier)
          .markSignedInWithLegalStatus(
            requiresLegalAcceptance:
                session.user.legalAcceptance.requiresAcceptance,
          );
    } on RequestCancelledException {
      _handleCancelledAuthRequest(authRequestCancellation);
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('authenticate_provider_unknown', error, stackTrace);
      _setFailure(message: 'auth.external_invalid');
    } finally {
      _clearActiveAuthRequest(authRequestCancellation);
    }
  }

  Future<void> linkExternalAccount(ExternalAuthProvider provider) async {
    if (!_ensureNetworkForAction()) {
      return;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final externalAuthRepository = ref.read(externalAuthRepositoryProvider);
    final authRequestCancellation = _startAuthRequest();
    try {
      await externalAuthRepository.link(
        provider,
        cancelToken: authRequestCancellation,
      );
      if (!ref.mounted || authRequestCancellation.isCancelled) {
        return;
      }
      ref.invalidate(linkedAccountsProvider);
      _updateStateIfMounted((state) => state.copyWith(isSaving: false));
    } on RequestCancelledException {
      _handleCancelledAuthRequest(authRequestCancellation);
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('link_external_unknown', error, stackTrace);
      _setFailure(message: 'auth.external_invalid');
    } finally {
      _clearActiveAuthRequest(authRequestCancellation);
    }
  }

  Future<void> unlinkExternalAccount(ExternalAuthProvider provider) async {
    if (!_ensureNetworkForAction()) {
      return;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final repository = _repository;
    final authRequestCancellation = _startAuthRequest();
    try {
      await repository.unlinkLinkedAccount(
        provider.apiValue,
        cancelToken: authRequestCancellation,
      );
      if (!ref.mounted || authRequestCancellation.isCancelled) {
        return;
      }
      ref.invalidate(linkedAccountsProvider);
      _updateStateIfMounted((state) => state.copyWith(isSaving: false));
    } on RequestCancelledException {
      _handleCancelledAuthRequest(authRequestCancellation);
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('unlink_external_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    } finally {
      _clearActiveAuthRequest(authRequestCancellation);
    }
  }

  Future<void> logout() async {
    _cancelActiveInitialize();
    _cancelActiveAvatarUpload();
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final repository = _repository;
    final externalAuthRepository = ref.read(externalAuthRepositoryProvider);
    try {
      await _unregisterPushTokenBeforeLogout();
      await repository.logout();
      if (!ref.mounted) {
        return;
      }
      await _clearExternalAuthSessions(
        externalAuthRepository,
        failureStage: 'logout_external_cleanup',
      );
      if (!ref.mounted) {
        return;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSaving: false,
          clearSession: true,
          clearProfile: true,
          password: '',
          confirmPassword: '',
          successMessage: 'logout',
        ),
      );
      if (!ref.mounted) {
        return;
      }
      ref.read(appLaunchControllerProvider.notifier).markSignedOut();
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('logout_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    }
  }

  Future<void> _unregisterPushTokenBeforeLogout() async {
    try {
      await ref
          .read(pushTokenLifecyclePortProvider)
          .unregisterCurrentToken(
            canContinue: () => ref.mounted,
            onFailure: (stage, error, stackTrace) {
              _logProfileFailure(
                'logout_push_token_${stage}_cleanup',
                error,
                stackTrace,
              );
            },
          );
    } catch (error, stackTrace) {
      _logProfileFailure('logout_push_token_cleanup', error, stackTrace);
    }
  }

  Future<void> deleteAccount() async {
    if (!_ensureNetworkForAction()) {
      return;
    }

    _cancelActiveInitialize();
    _cancelActiveAvatarUpload();
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final repository = _repository;
    final externalAuthRepository = ref.read(externalAuthRepositoryProvider);
    final mutationRequestCancellation = _startProfileMutation();
    try {
      await _unregisterPushTokenBeforeLogout();
      if (!ref.mounted || mutationRequestCancellation.isCancelled) {
        return;
      }
      await repository.deleteCurrentAccount(
        cancelToken: mutationRequestCancellation,
      );
      if (!ref.mounted || mutationRequestCancellation.isCancelled) {
        return;
      }
      await _clearExternalAuthSessions(
        externalAuthRepository,
        failureStage: 'delete_account_external_cleanup',
      );

      if (!ref.mounted || mutationRequestCancellation.isCancelled) {
        return;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSaving: false,
          clearSession: true,
          clearProfile: true,
          password: '',
          confirmPassword: '',
          successMessage: 'profile.account_deleted',
        ),
      );
      if (!ref.mounted || mutationRequestCancellation.isCancelled) {
        return;
      }
      ref.read(appLaunchControllerProvider.notifier).markSignedOut();
    } on RequestCancelledException {
      return;
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('delete_account_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    } finally {
      _clearActiveProfileMutation(mutationRequestCancellation);
    }
  }

  Future<LocalMediaFile?> pickAvatarImage() {
    return ref.read(avatarMediaGatewayProvider).pickAvatarImage();
  }

  Future<void> _clearExternalAuthSessions(
    ExternalAuthRepository externalAuthRepository, {
    required String failureStage,
  }) async {
    for (final provider in ExternalAuthProvider.values) {
      try {
        await externalAuthRepository.clearSession(provider);
      } catch (error, stackTrace) {
        _logProfileFailure(
          failureStage,
          error,
          stackTrace,
          context: {'provider': provider.apiValue},
        );
        // Local provider cleanup is best-effort; app logout/delete must finish.
      }
    }
  }

  Future<void> uploadAvatarFromPath(String filePath) async {
    final avatarMediaGateway = ref.read(avatarMediaGatewayProvider);
    if (!_ensureNetworkForAction()) {
      await avatarMediaGateway.deleteManagedTempFile(filePath);
      return;
    }

    final uploadRequestCancellation = _startAvatarUpload();
    if (uploadRequestCancellation == null) {
      return;
    }

    _updateStateIfMounted(
      (state) =>
          state.copyWith(isSaving: true, clearError: true, clearSuccess: true),
    );

    try {
      final previousAvatarUrl = state.profile?.avatar?.url;
      final profile = await _repository.uploadAvatar(
        filePath,
        cancelToken: uploadRequestCancellation,
      );
      if (!ref.mounted) {
        return;
      }

      final nextAvatarUrl = profile.avatar?.url;

      _updateStateIfMounted(
        (state) => state.copyWith(isSaving: false, profile: profile),
      );

      await _evictAvatarCache(previousAvatarUrl);
      await _evictAvatarCache(nextAvatarUrl);
      if (!ref.mounted) {
        return;
      }

      ref
          .read(appLaunchControllerProvider.notifier)
          .markSignedInWithLegalStatus(
            requiresLegalAcceptance: profile.legalAcceptance.requiresAcceptance,
          );
    } on RequestCancelledException {
      if (!ref.mounted) {
        return;
      }
      final hasInternet = ref.read(networkStatusControllerProvider).hasInternet;
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSaving: false,
          clearError: hasInternet,
          errorMessage: hasInternet ? null : 'templates.network_unavailable',
        ),
      );
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('upload_avatar_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    } finally {
      _clearActiveAvatarUpload(uploadRequestCancellation);
      await avatarMediaGateway.deleteManagedTempFile(filePath);
    }
  }

  Future<void> removeAvatar() async {
    if (!_ensureNetworkForAction()) {
      return;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final mutationRequestCancellation = _startProfileMutation();
    try {
      final profile = await _repository.removeAvatar(
        cancelToken: mutationRequestCancellation,
      );
      if (!ref.mounted || mutationRequestCancellation.isCancelled) {
        return;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(isSaving: false, profile: profile),
      );
    } on RequestCancelledException {
      return;
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('remove_avatar_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    } finally {
      _clearActiveProfileMutation(mutationRequestCancellation);
    }
  }

  Future<void> updateCurrentProfile({required String? displayName}) async {
    if (!_ensureNetworkForAction()) {
      return;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final mutationRequestCancellation = _startProfileMutation();
    try {
      final profile = await _repository.updateProfile(
        displayName: displayName,
        cancelToken: mutationRequestCancellation,
      );
      if (!ref.mounted || mutationRequestCancellation.isCancelled) {
        return;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSaving: false,
          profile: profile,
          displayName: profile.displayName ?? '',
        ),
      );
    } on RequestCancelledException {
      return;
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('update_profile_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    } finally {
      _clearActiveProfileMutation(mutationRequestCancellation);
    }
  }

  Future<void> acceptCurrentLegalDocuments(
    MobileLegalDocuments legalDocuments,
  ) async {
    if (!_ensureNetworkForAction()) {
      return;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final mutationRequestCancellation = _startProfileMutation();
    try {
      final profile = await _repository.acceptCurrentLegalDocuments(
        documents: legalDocuments,
        cancelToken: mutationRequestCancellation,
      );
      if (!ref.mounted || mutationRequestCancellation.isCancelled) {
        return;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(isSaving: false, profile: profile),
      );
    } on RequestCancelledException {
      return;
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('accept_legal_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    } finally {
      _clearActiveProfileMutation(mutationRequestCancellation);
    }
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

  Future<void> _evictAvatarCache(String? imageUrl) async {
    final safeImageUrl = parseSafeProfileAvatarUri(imageUrl)?.toString();
    if (safeImageUrl == null) {
      return;
    }

    try {
      await ref.read(avatarMediaGatewayProvider).evictAvatarCache(safeImageUrl);
    } catch (error, stackTrace) {
      _logProfileFailure('avatar_cache_evict_failed', error, stackTrace);
    }
  }
}

// Public profile application controller.
