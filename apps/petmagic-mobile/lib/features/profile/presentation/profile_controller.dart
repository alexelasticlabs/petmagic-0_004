import 'dart:developer' as developer;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';

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
    this.session,
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
  final AuthSession? session;
  final MobileUserProfile? profile;
  final String? errorMessage;
  final String? successMessage;

  bool get isAuthenticated => session != null;

  ProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? displayName,
    String? email,
    String? password,
    String? confirmPassword,
    AuthSession? session,
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
      session: clearSession ? null : (session ?? this.session),
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

    developer.Timeline.instantSync(
      'petmagic.profile.controller.error',
      arguments: payload,
    );
    developer.log(
      'ProfileController::$stage failed',
      name: 'PetMagic.Profile.Controller',
      error: error,
      stackTrace: stackTrace,
    );
  }

  final ImagePicker _imagePicker = ImagePicker();
  final ImageCropper _imageCropper = ImageCropper();

  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  @override
  ProfileState build() {
    return const ProfileState.initial();
  }

  Future<void> initialize({String initialEmail = ''}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final session = await _repository.readSession();
      if (session == null) {
        state = state.copyWith(
          isLoading: false,
          email: initialEmail,
          clearSession: true,
          clearProfile: true,
        );
        return;
      }

      final profile = await _repository.fetchProfile();
      final hydratedSession = AuthSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        expiresAtUtc: session.expiresAtUtc,
        user: profile,
      );
      state = state.copyWith(
        isLoading: false,
        session: hydratedSession,
        profile: profile,
        email: hydratedSession.user.email,
        clearError: true,
      );
      ref
          .read(appLaunchControllerProvider.notifier)
          .markSignedInWithLegalStatus(
            requiresLegalAcceptance:
                hydratedSession.user.legalAcceptance.requiresAcceptance,
          );
    } on AppException catch (error) {
      final storedSession = await _repository.readSession();
      if (storedSession != null && error.statusCode != 401) {
        state = state.copyWith(
          isLoading: false,
          session: storedSession,
          profile: storedSession.user,
          email: storedSession.user.email,
          errorMessage: error.message,
          clearSuccess: true,
        );
        return;
      }

      if (error.statusCode == 401) {
        ref.read(appLaunchControllerProvider.notifier).markSignedOut();
      }

      state = state.copyWith(
        isLoading: false,
        email: initialEmail,
        errorMessage: error.message,
        clearSession: true,
        clearProfile: true,
      );
    } catch (error, stackTrace) {
      _logProfileFailure('initialize_unknown', error, stackTrace);
      final storedSession = await _repository.readSession();
      if (storedSession != null) {
        state = state.copyWith(
          isLoading: false,
          session: storedSession,
          profile: storedSession.user,
          email: storedSession.user.email,
          errorMessage: _genericActionError,
          clearSuccess: true,
        );
        return;
      }

      _setFailure(
        message: _genericActionError,
        email: initialEmail,
        clearSession: true,
        clearProfile: true,
      );
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
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final session = await _repository.login(
        email: state.email,
        password: state.password,
      );
      final profile = await _repository.fetchProfile();
      final hydratedSession = AuthSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        expiresAtUtc: session.expiresAtUtc,
        user: profile,
      );
      state = state.copyWith(
        isSaving: false,
        session: hydratedSession,
        profile: profile,
        password: '',
        confirmPassword: '',
      );
      ref
          .read(appLaunchControllerProvider.notifier)
          .markSignedInWithLegalStatus(
            requiresLegalAcceptance:
                hydratedSession.user.legalAcceptance.requiresAcceptance,
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
    required MobileLegalDocuments legalDocuments,
    required bool marketingEmailsEnabled,
  }) async {
    if (state.password.length < 6) {
      state = state.copyWith(
        errorMessage: 'auth.password_too_short',
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

    try {
      await _repository.register(
        email: state.email,
        password: state.password,
        displayName: state.displayName,
        termsOfUseAccepted: termsOfUseAccepted,
        privacyPolicyAccepted: privacyPolicyAccepted,
        termsOfUseVersion: legalDocuments.termsOfUse.version,
        privacyPolicyVersion: legalDocuments.privacyPolicy.version,
        marketingEmailsEnabled: marketingEmailsEnabled,
      );
      state = state.copyWith(
        isSaving: false,
        clearSession: true,
        clearProfile: true,
        password: '',
        confirmPassword: '',
        successMessage: 'auth.registration_pending_verification',
      );
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('register_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    }
  }

  Future<void> authenticateWithProvider(ExternalAuthProvider provider) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final session = await ref
          .read(externalAuthRepositoryProvider)
          .authenticate(provider);
      state = state.copyWith(
        isSaving: false,
        session: session,
        profile: session.user,
        password: '',
        confirmPassword: '',
      );
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

    try {
      await ref.read(externalAuthRepositoryProvider).link(provider);
      ref.invalidate(linkedAccountsProvider);
      state = state.copyWith(isSaving: false);
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

    try {
      await _repository.unlinkLinkedAccount(provider.apiValue);
      ref.invalidate(linkedAccountsProvider);
      state = state.copyWith(isSaving: false);
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('unlink_external_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    }
  }

  Future<void> logout() async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _repository.logout();
      try {
        await ref
            .read(externalAuthRepositoryProvider)
            .clearSession(ExternalAuthProvider.google);
      } catch (error, stackTrace) {
        _logProfileFailure('logout_google_cleanup', error, stackTrace);
        // Logout must still complete even if provider cleanup fails.
      }
      state = state.copyWith(
        isSaving: false,
        clearSession: true,
        clearProfile: true,
        password: '',
        confirmPassword: '',
        successMessage: 'logout',
      );
      ref.read(appLaunchControllerProvider.notifier).markSignedOut();
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('logout_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    }
  }

  Future<void> deleteAccount() async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _repository.deleteCurrentAccount();
      try {
        await ref
            .read(externalAuthRepositoryProvider)
            .clearSession(ExternalAuthProvider.google);
      } catch (error, stackTrace) {
        _logProfileFailure('delete_account_google_cleanup', error, stackTrace);
        // Account deletion must still complete even if provider cleanup fails.
      }

      state = state.copyWith(
        isSaving: false,
        clearSession: true,
        clearProfile: true,
        password: '',
        confirmPassword: '',
        successMessage: 'profile.account_deleted',
      );
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

  Future<void> uploadAvatarFromPath(String filePath) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final previousAvatarUrl = state.profile?.avatar?.url;
      final profile = await _repository.uploadAvatar(filePath);
      final nextAvatarUrl = profile.avatar?.url;

      state = state.copyWith(
        isSaving: false,
        profile: profile,
        session: _replaceSessionUser(profile),
      );

      await _evictAvatarCache(previousAvatarUrl);
      await _evictAvatarCache(nextAvatarUrl);

      ref
          .read(appLaunchControllerProvider.notifier)
          .markSignedInWithLegalStatus(
            requiresLegalAcceptance: profile.legalAcceptance.requiresAcceptance,
          );
    } on AppException catch (error) {
      _setFailure(message: error.message);
    } catch (error, stackTrace) {
      _logProfileFailure('upload_avatar_unknown', error, stackTrace);
      _setFailure(message: _genericActionError);
    }
  }

  Future<void> uploadAvatar() async {
    final file = await pickAvatarImage();
    if (file == null) {
      return;
    }

    final croppedFile = await _imageCropper.cropImage(
      sourcePath: file.path,
      maxWidth: 1200,
      maxHeight: 1200,
      compressQuality: 92,
      compressFormat: ImageCompressFormat.jpg,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'PetMagic',
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
          cropStyle: CropStyle.circle,
        ),
        IOSUiSettings(
          title: 'PetMagic',
          aspectRatioLockEnabled: true,
          aspectRatioPickerButtonHidden: true,
          resetAspectRatioEnabled: false,
          rotateButtonsHidden: false,
          cropStyle: CropStyle.circle,
        ),
      ],
    );
    if (croppedFile == null) {
      return;
    }

    await uploadAvatarFromPath(croppedFile.path);
  }

  Future<void> removeAvatar() async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final profile = await _repository.removeAvatar();
      state = state.copyWith(
        isSaving: false,
        profile: profile,
        session: _replaceSessionUser(profile),
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
      state = state.copyWith(
        isSaving: false,
        profile: profile,
        session: _replaceSessionUser(profile),
        displayName: profile.displayName ?? '',
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
      state = state.copyWith(
        isSaving: false,
        profile: profile,
        session: _replaceSessionUser(profile),
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
    state = state.copyWith(
      isLoading: false,
      isSaving: false,
      email: email,
      errorMessage: message,
      clearSuccess: true,
      clearSession: clearSession,
      clearProfile: clearProfile,
    );
  }

  AuthSession? _replaceSessionUser(MobileUserProfile profile) {
    final session = state.session;
    if (session == null) {
      return null;
    }

    return AuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAtUtc: session.expiresAtUtc,
      user: profile,
    );
  }

  Future<void> _evictAvatarCache(String? imageUrl) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return;
    }

    try {
      await CachedNetworkImage.evictFromCache(imageUrl);
      imageCache.evict(NetworkImage(imageUrl));
    } catch (error, stackTrace) {
      _logProfileFailure(
        'avatar_cache_evict_failed',
        error,
        stackTrace,
        context: {'avatar_url': imageUrl},
      );
    }
  }
}
