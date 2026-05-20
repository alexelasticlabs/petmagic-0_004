import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late final ProfileRepository _repository;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  ProfileState build() {
    _repository = ref.watch(profileRepositoryProvider);
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
      ref.read(appLaunchControllerProvider.notifier).markSignedIn();
    } on AppException catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
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
      final session = await _repository.register(
        email: state.email,
        password: state.password,
        displayName: state.displayName,
        termsOfUseAccepted: termsOfUseAccepted,
        privacyPolicyAccepted: privacyPolicyAccepted,
        termsOfUseVersion: legalDocuments.termsOfUse.version,
        privacyPolicyVersion: legalDocuments.privacyPolicy.version,
        marketingEmailsEnabled: marketingEmailsEnabled,
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
      ref.read(appLaunchControllerProvider.notifier).markSignedIn();
    } on AppException catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
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
      ref.read(appLaunchControllerProvider.notifier).markSignedIn();
    } on AppException catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'auth.external_invalid',
      );
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
      state = state.copyWith(isSaving: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'auth.external_invalid',
      );
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
      state = state.copyWith(isSaving: false, errorMessage: error.message);
    }
  }

  Future<void> logout() async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    await _repository.logout();
    state = state.copyWith(
      isSaving: false,
      clearSession: true,
      clearProfile: true,
      password: '',
      confirmPassword: '',
      successMessage: 'logout',
    );
    ref.read(appLaunchControllerProvider.notifier).markSignedOut();
  }

  Future<void> uploadAvatar() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (file == null) {
      return;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final profile = await _repository.uploadAvatar(file.path);
      state = state.copyWith(
        isSaving: false,
        profile: profile,
        session: _replaceSessionUser(profile),
      );
    } on AppException catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
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
      state = state.copyWith(
        isSaving: false,
        profile: profile,
        session: _replaceSessionUser(profile),
      );
    } on AppException catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
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
      state = state.copyWith(isSaving: false, errorMessage: error.message);
    }
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
}
