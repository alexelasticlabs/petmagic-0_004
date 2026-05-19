import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';

final passwordResetControllerProvider =
    NotifierProvider<PasswordResetController, PasswordResetState>(
      PasswordResetController.new,
    );

class PasswordResetState {
  const PasswordResetState({
    this.email = '',
    this.code = '',
    this.newPassword = '',
    this.confirmPassword = '',
    this.isSaving = false,
    this.codeRequested = false,
    this.errorMessage,
    this.successMessage,
  });

  final String email;
  final String code;
  final String newPassword;
  final String confirmPassword;
  final bool isSaving;
  final bool codeRequested;
  final String? errorMessage;
  final String? successMessage;

  PasswordResetState copyWith({
    String? email,
    String? code,
    String? newPassword,
    String? confirmPassword,
    bool? isSaving,
    bool? codeRequested,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return PasswordResetState(
      email: email ?? this.email,
      code: code ?? this.code,
      newPassword: newPassword ?? this.newPassword,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      isSaving: isSaving ?? this.isSaving,
      codeRequested: codeRequested ?? this.codeRequested,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage: clearSuccess
          ? null
          : successMessage ?? this.successMessage,
    );
  }
}

class PasswordResetController extends Notifier<PasswordResetState> {
  late final ProfileRepository _repository;

  @override
  PasswordResetState build() {
    _repository = ref.watch(profileRepositoryProvider);
    return const PasswordResetState();
  }

  void reset({String email = ''}) {
    state = PasswordResetState(email: email.trim());
  }

  void initializeEmail(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || state.email.isNotEmpty) {
      return;
    }

    state = state.copyWith(email: normalized, clearError: true);
  }

  void updateEmail(String value) {
    state = state.copyWith(email: value, clearError: true, clearSuccess: true);
  }

  void updateCode(String value) {
    state = state.copyWith(code: value, clearError: true, clearSuccess: true);
  }

  void updateNewPassword(String value) {
    state = state.copyWith(
      newPassword: value,
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

  Future<bool> requestReset() async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _repository.requestPasswordReset(email: state.email);
      state = state.copyWith(
        isSaving: false,
        codeRequested: true,
        successMessage: 'auth.password_reset_code_sent',
      );
      return true;
    } on AppException catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
      return false;
    }
  }

  Future<bool> confirmReset() async {
    if (state.newPassword.length < 6) {
      state = state.copyWith(
        errorMessage: 'auth.password_too_short',
        clearSuccess: true,
      );
      return false;
    }

    if (state.newPassword != state.confirmPassword) {
      state = state.copyWith(
        errorMessage: 'auth.password_mismatch',
        clearSuccess: true,
      );
      return false;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _repository.confirmPasswordReset(
        email: state.email,
        code: state.code,
        newPassword: state.newPassword,
      );
      state = state.copyWith(
        isSaving: false,
        code: '',
        newPassword: '',
        confirmPassword: '',
        successMessage: 'auth.password_reset_success',
      );
      return true;
    } on AppException catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
      return false;
    }
  }
}
