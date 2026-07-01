import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_password_policy.dart';
import 'package:petmagic_mobile/shared/files/temp_media_cleanup.dart';
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
  static const _managedAvatarTempFilePrefix = 'petmagic_avatar_';

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

  final ImagePicker _imagePicker = ImagePicker();
  CancelToken? _activeAvatarUploadCancelToken;
  CancelToken? _activeInitializeCancelToken;
  Future<void>? _initializeInFlight;

  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  @override
  ProfileState build() {
    ref.onDispose(() {
      _cancelActiveInitialize();
      _cancelActiveAvatarUpload();
    });
    return const ProfileState.initial();
  }

  void _updateStateIfMounted(
    ProfileState Function(ProfileState current) update,
  ) {
    if (!ref.mounted) {
      return;
    }

    state = update(state);
  }

  CancelToken? _startAvatarUpload() {
    if (_activeAvatarUploadCancelToken != null) {
      return null;
    }

    final cancelToken = CancelToken();
    _activeAvatarUploadCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveAvatarUpload() {
    final cancelToken = _activeAvatarUploadCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('profile_avatar_upload_cancelled');
    }
    _activeAvatarUploadCancelToken = null;
  }

  void _clearActiveAvatarUpload(CancelToken cancelToken) {
    if (identical(_activeAvatarUploadCancelToken, cancelToken)) {
      _activeAvatarUploadCancelToken = null;
    }
  }

  CancelToken _startInitializeRequest() {
    _cancelActiveInitialize();
    final cancelToken = CancelToken();
    _activeInitializeCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveInitialize() {
    final cancelToken = _activeInitializeCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('profile_initialize_cancelled');
    }
    _activeInitializeCancelToken = null;
  }

  void _clearActiveInitialize(CancelToken cancelToken) {
    if (identical(_activeInitializeCancelToken, cancelToken)) {
      _activeInitializeCancelToken = null;
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

      final initializeCancelToken = _startInitializeRequest();
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
          cancelToken: initializeCancelToken,
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
        _clearActiveInitialize(initializeCancelToken);
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

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final repository = _repository;
    try {
      await repository.login(email: state.email, password: state.password);
      if (!ref.mounted) {
        return;
      }
      final profile = await repository.fetchProfile();
      if (!ref.mounted) {
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
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('login_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
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

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final repository = _repository;
    try {
      await repository.register(
        email: state.email,
        password: state.password,
        displayName: state.displayName,
        termsOfUseAccepted: termsOfUseAccepted,
        privacyPolicyAccepted: privacyPolicyAccepted,
        termsOfUseVersion: legalDocuments?.termsOfUse.version ?? '',
        privacyPolicyVersion: legalDocuments?.privacyPolicy.version ?? '',
        marketingEmailsEnabled: marketingEmailsEnabled,
      );
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
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('register_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    }
  }

  Future<void> authenticateWithProvider(ExternalAuthProvider provider) async {
    if (state.isSaving) {
      return;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final externalAuthRepository = ref.read(externalAuthRepositoryProvider);
    try {
      final session = await externalAuthRepository.authenticate(provider);
      if (!ref.mounted) {
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
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('authenticate_provider_unknown', error, stackTrace);
      _setFailure(message: 'auth.external_invalid');
    }
  }

  Future<void> linkExternalAccount(ExternalAuthProvider provider) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final externalAuthRepository = ref.read(externalAuthRepositoryProvider);
    try {
      await externalAuthRepository.link(provider);
      if (!ref.mounted) {
        return;
      }
      ref.invalidate(linkedAccountsProvider);
      _updateStateIfMounted((state) => state.copyWith(isSaving: false));
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('link_external_unknown', error, stackTrace);
      _setFailure(message: 'auth.external_invalid');
    }
  }

  Future<void> unlinkExternalAccount(ExternalAuthProvider provider) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final repository = _repository;
    try {
      await repository.unlinkLinkedAccount(provider.apiValue);
      if (!ref.mounted) {
        return;
      }
      ref.invalidate(linkedAccountsProvider);
      _updateStateIfMounted((state) => state.copyWith(isSaving: false));
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('unlink_external_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
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

  Future<void> deleteAccount() async {
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
      await repository.deleteCurrentAccount();
      if (!ref.mounted) {
        return;
      }
      await _clearExternalAuthSessions(
        externalAuthRepository,
        failureStage: 'delete_account_external_cleanup',
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
          successMessage: 'profile.account_deleted',
        ),
      );
      if (!ref.mounted) {
        return;
      }
      ref.read(appLaunchControllerProvider.notifier).markSignedOut();
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('delete_account_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    }
  }

  Future<XFile?> pickAvatarImage() {
    return _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
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
    final uploadCancelToken = _startAvatarUpload();
    if (uploadCancelToken == null) {
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
        cancelToken: uploadCancelToken,
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
      _updateStateIfMounted(
        (state) => state.copyWith(isSaving: false, clearError: true),
      );
    } on DioException catch (error, stackTrace) {
      if (CancelToken.isCancel(error)) {
        _updateStateIfMounted(
          (state) => state.copyWith(isSaving: false, clearError: true),
        );
        return;
      }

      _logProfileFailure('upload_avatar_dio', error, stackTrace);
      _setFailure(message: _genericActionError);
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('upload_avatar_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    } finally {
      _clearActiveAvatarUpload(uploadCancelToken);
      await _deleteManagedAvatarTempFile(filePath);
    }
  }

  Future<void> removeAvatar() async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final profile = await _repository.removeAvatar();
      _updateStateIfMounted(
        (state) => state.copyWith(isSaving: false, profile: profile),
      );
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('remove_avatar_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    }
  }

  Future<void> updateCurrentProfile({required String? displayName}) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final profile = await _repository.updateProfile(displayName: displayName);
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSaving: false,
          profile: profile,
          displayName: profile.displayName ?? '',
        ),
      );
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('update_profile_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    }
  }

  Future<void> acceptCurrentLegalDocuments(
    MobileLegalDocuments legalDocuments,
  ) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final profile = await _repository.acceptCurrentLegalDocuments(
        documents: legalDocuments,
      );
      _updateStateIfMounted(
        (state) => state.copyWith(isSaving: false, profile: profile),
      );
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('accept_legal_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    }
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
      await CachedNetworkImage.evictFromCache(safeImageUrl);
      imageCache.evict(NetworkImage(safeImageUrl));
    } catch (error, stackTrace) {
      _logProfileFailure('avatar_cache_evict_failed', error, stackTrace);
    }
  }

  Future<void> _deleteManagedAvatarTempFile(String filePath) async {
    if (!_isManagedAvatarTempFile(filePath)) {
      return;
    }

    await TempMediaCleanup.deleteIfExists(File(filePath));
  }

  bool _isManagedAvatarTempFile(String filePath) {
    final segments = Uri.file(filePath).pathSegments;
    final fileName = segments.isEmpty ? filePath : segments.last;
    if (!fileName.startsWith(_managedAvatarTempFilePrefix)) {
      return false;
    }

    final normalizedPath = _normalizedFilePath(filePath);
    final normalizedTempRoot = _normalizedDirectoryPath(
      Directory.systemTemp.path,
    );
    return normalizedPath.startsWith(normalizedTempRoot);
  }

  String _normalizedFilePath(String value) {
    return value.replaceAll('\\', '/').toLowerCase();
  }

  String _normalizedDirectoryPath(String value) {
    final normalized = _normalizedFilePath(value);
    return normalized.endsWith('/') ? normalized : '$normalized/';
  }
}
