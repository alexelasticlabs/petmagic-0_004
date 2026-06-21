import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_password_policy.dart';

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
  static const _genericActionError = 'profile.action_failed';

  void _logPasswordResetFailure(
    String stage,
    Object error,
    StackTrace stackTrace,
  ) {
    AppLogger.warn(
      feature: 'Profile.PasswordReset',
      operation: stage,
      message: 'Password reset step failed',
      context: {'stage': stage},
      error: error,
      stackTrace: stackTrace,
    );
  }

  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  @override
  PasswordResetState build() {
    return const PasswordResetState();
  }

  void _updateStateIfMounted(
    PasswordResetState Function(PasswordResetState current) update,
  ) {
    if (!ref.mounted) {
      return;
    }

    state = update(state);
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
    if (state.isSaving) {
      return false;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final repository = _repository;
    try {
      await repository.requestPasswordReset(email: state.email);
      if (!ref.mounted) {
        return false;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSaving: false,
          codeRequested: true,
          successMessage: 'auth.password_reset_code_sent',
        ),
      );
      return true;
    } on AppException catch (error) {
      _setFailure(error.message);
      return false;
    } catch (error, stackTrace) {
      _logPasswordResetFailure('request_reset_unknown', error, stackTrace);
      _setFailure(_genericActionError);
      return false;
    }
  }

  Future<bool> confirmReset() async {
    if (state.isSaving) {
      return false;
    }

    if (!AuthPasswordPolicy.isValid(state.newPassword)) {
      state = state.copyWith(
        errorMessage: AuthPasswordPolicy.errorMessage,
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

    final repository = _repository;
    try {
      await repository.confirmPasswordReset(
        email: state.email,
        code: state.code,
        newPassword: state.newPassword,
      );
      if (!ref.mounted) {
        return false;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSaving: false,
          code: '',
          newPassword: '',
          confirmPassword: '',
          successMessage: 'auth.password_reset_success',
        ),
      );
      return true;
    } on AppException catch (error) {
      _setFailure(error.message);
      return false;
    } catch (error, stackTrace) {
      _logPasswordResetFailure('confirm_reset_unknown', error, stackTrace);
      _setFailure(_genericActionError);
      return false;
    }
  }

  void _setFailure(String message) {
    _updateStateIfMounted(
      (state) => state.copyWith(
        isSaving: false,
        errorMessage: message,
        clearSuccess: true,
      ),
    );
  }
}
