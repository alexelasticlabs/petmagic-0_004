import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';

final passwordChangeControllerProvider =
    NotifierProvider<PasswordChangeController, PasswordChangeState>(
      PasswordChangeController.new,
    );

class PasswordChangeState {
  const PasswordChangeState({
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

  PasswordChangeState copyWith({
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
    return PasswordChangeState(
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

class PasswordChangeController extends Notifier<PasswordChangeState> {
  static const _genericActionError = 'profile.action_failed';

  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  @override
  PasswordChangeState build() {
    return const PasswordChangeState();
  }

  void reset({required String email}) {
    state = PasswordChangeState(email: email.trim());
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

  Future<bool> requestCode() async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _repository.requestCurrentPasswordChangeCode();
      state = state.copyWith(
        isSaving: false,
        codeRequested: true,
        successMessage: 'auth.password_reset_code_sent',
      );
      return true;
    } on AppException catch (error) {
      _setFailure(error.message);
      return false;
    } catch (_) {
      _setFailure(_genericActionError);
      return false;
    }
  }

  Future<bool> confirmChange() async {
    if (state.newPassword.length < 8) {
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
      await _repository.confirmCurrentPasswordChange(
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
      _setFailure(error.message);
      return false;
    } catch (_) {
      _setFailure(_genericActionError);
      return false;
    }
  }

  void _setFailure(String message) {
    state = state.copyWith(
      isSaving: false,
      errorMessage: message,
      clearSuccess: true,
    );
  }
}
