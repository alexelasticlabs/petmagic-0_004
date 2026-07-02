import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_password_policy.dart';

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
  CancelToken? _activeRequestCancelToken;

  void _logPasswordChangeFailure(
    String stage,
    Object error,
    StackTrace stackTrace,
  ) {
    AppLogger.warn(
      feature: 'Profile.PasswordChange',
      operation: stage,
      message: 'Password change step failed',
      context: {'stage': stage},
      error: error,
      stackTrace: stackTrace,
    );
  }

  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  @override
  PasswordChangeState build() {
    ref.listen<bool>(
      networkStatusControllerProvider.select((state) => state.hasInternet),
      (_, hasInternet) => _handleNetworkStatusChanged(hasInternet),
    );
    ref.onDispose(_cancelActiveRequest);
    return const PasswordChangeState();
  }

  void _updateStateIfMounted(
    PasswordChangeState Function(PasswordChangeState current) update,
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

    _cancelActiveRequest();
    _updateStateIfMounted(
      (state) => state.copyWith(
        isSaving: false,
        errorMessage: 'templates.network_unavailable',
        clearSuccess: true,
      ),
    );
  }

  CancelToken _startRequestCancelToken() {
    _cancelActiveRequest();
    final cancelToken = CancelToken();
    _activeRequestCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveRequest() {
    final cancelToken = _activeRequestCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('password_change_cancelled');
    }
    _activeRequestCancelToken = null;
  }

  void _clearActiveRequest(CancelToken cancelToken) {
    if (identical(_activeRequestCancelToken, cancelToken)) {
      _activeRequestCancelToken = null;
    }
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
    if (state.isSaving) {
      return false;
    }

    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      _setFailure('templates.network_unavailable');
      return false;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final repository = _repository;
    final cancelToken = _startRequestCancelToken();
    try {
      await repository.requestCurrentPasswordChangeCode(
        cancelToken: cancelToken,
      );
      if (!ref.mounted || cancelToken.isCancelled) {
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
    } on RequestCancelledException {
      return false;
    } on AppException catch (error) {
      _setFailure(error.message);
      return false;
    } catch (error, stackTrace) {
      _logPasswordChangeFailure('request_code_unknown', error, stackTrace);
      _setFailure(_genericActionError);
      return false;
    } finally {
      _clearActiveRequest(cancelToken);
    }
  }

  Future<bool> confirmChange() async {
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

    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      _setFailure('templates.network_unavailable');
      return false;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );

    final repository = _repository;
    final cancelToken = _startRequestCancelToken();
    try {
      await repository.confirmCurrentPasswordChange(
        code: state.code,
        newPassword: state.newPassword,
        cancelToken: cancelToken,
      );
      if (!ref.mounted || cancelToken.isCancelled) {
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
    } on RequestCancelledException {
      return false;
    } on AppException catch (error) {
      _setFailure(error.message);
      return false;
    } catch (error, stackTrace) {
      _logPasswordChangeFailure('confirm_change_unknown', error, stackTrace);
      _setFailure(_genericActionError);
      return false;
    } finally {
      _clearActiveRequest(cancelToken);
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
