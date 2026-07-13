import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/profile/application/external_auth_gateway.dart';
import 'package:petmagic_mobile/features/profile/application/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/application/profile_request_tracker.dart';
import 'package:petmagic_mobile/features/profile/application/profile_state.dart';
import 'package:petmagic_mobile/features/profile/application/push_token_lifecycle_port.dart';

typedef ProfileAccountFailureLogger =
    void Function(
      String stage,
      Object error,
      StackTrace stackTrace, {
      Map<String, Object?> context,
    });

/// Coordinates logout and destructive account lifecycle operations.
class ProfileAccountCoordinator {
  const ProfileAccountCoordinator({
    required ProfileRepositoryPort Function() repository,
    required ExternalAuthRepository Function() externalAuthRepository,
    required PushTokenLifecyclePort Function() pushTokenLifecycle,
    required ProfileRequestTracker requestTracker,
    required void Function(ProfileState Function(ProfileState) update)
    updateState,
    required bool Function() ensureNetwork,
    required bool Function() canContinue,
    required void Function(String message) setFailure,
    required void Function() markSignedOut,
    required ProfileAccountFailureLogger logFailure,
  }) : _repository = repository,
       _externalAuthRepository = externalAuthRepository,
       _pushTokenLifecycle = pushTokenLifecycle,
       _requestTracker = requestTracker,
       _updateState = updateState,
       _ensureNetwork = ensureNetwork,
       _canContinue = canContinue,
       _setFailure = setFailure,
       _markSignedOut = markSignedOut,
       _logFailure = logFailure;

  final ProfileRepositoryPort Function() _repository;
  final ExternalAuthRepository Function() _externalAuthRepository;
  final PushTokenLifecyclePort Function() _pushTokenLifecycle;
  final ProfileRequestTracker _requestTracker;
  final void Function(ProfileState Function(ProfileState) update) _updateState;
  final bool Function() _ensureNetwork;
  final bool Function() _canContinue;
  final void Function(String message) _setFailure;
  final void Function() _markSignedOut;
  final ProfileAccountFailureLogger _logFailure;

  Future<void> logout() async {
    _requestTracker.cancelInitialize();
    _requestTracker.cancelAvatarUpload();
    _writeSavingState();

    try {
      await _unregisterPushTokenBeforeLogout();
      await _repository().logout();
      if (!_canContinue()) {
        return;
      }
      await _clearExternalAuthSessions(failureStage: 'logout_external_cleanup');
      if (!_canContinue()) {
        return;
      }
      _updateState(
        (state) => state.copyWith(
          isSaving: false,
          clearSession: true,
          clearProfile: true,
          password: '',
          confirmPassword: '',
          successMessage: 'logout',
        ),
      );
      if (_canContinue()) {
        _markSignedOut();
      }
    } on AppException catch (error) {
      _setFailure(error.message);
    } catch (error, stackTrace) {
      _logFailure('logout_unknown', error, stackTrace);
      _setFailure('profile.action_failed');
    }
  }

  Future<void> deleteAccount() async {
    if (!_ensureNetwork()) {
      return;
    }

    _requestTracker.cancelInitialize();
    _requestTracker.cancelAvatarUpload();
    _writeSavingState();
    final cancelToken = _requestTracker.startProfileMutation();
    try {
      await _unregisterPushTokenBeforeLogout();
      if (!_canContinueRequest(cancelToken)) {
        return;
      }
      await _repository().deleteCurrentAccount(cancelToken: cancelToken);
      if (!_canContinueRequest(cancelToken)) {
        return;
      }
      await _clearExternalAuthSessions(
        failureStage: 'delete_account_external_cleanup',
      );
      if (!_canContinueRequest(cancelToken)) {
        return;
      }
      _updateState(
        (state) => state.copyWith(
          isSaving: false,
          clearSession: true,
          clearProfile: true,
          password: '',
          confirmPassword: '',
          successMessage: 'profile.account_deleted',
        ),
      );
      if (_canContinueRequest(cancelToken)) {
        _markSignedOut();
      }
    } on RequestCancelledException {
      return;
    } on AppException catch (error) {
      _setFailure(error.message);
    } catch (error, stackTrace) {
      _logFailure('delete_account_unknown', error, stackTrace);
      _setFailure('profile.action_failed');
    } finally {
      _requestTracker.clearProfileMutation(cancelToken);
    }
  }

  Future<void> _unregisterPushTokenBeforeLogout() async {
    try {
      await _pushTokenLifecycle().unregisterCurrentToken(
        canContinue: _canContinue,
        onFailure: (stage, error, stackTrace) {
          _logFailure('logout_push_token_${stage}_cleanup', error, stackTrace);
        },
      );
    } catch (error, stackTrace) {
      _logFailure('logout_push_token_cleanup', error, stackTrace);
    }
  }

  Future<void> _clearExternalAuthSessions({
    required String failureStage,
  }) async {
    for (final provider in ExternalAuthProvider.values) {
      try {
        await _externalAuthRepository().clearSession(provider);
      } catch (error, stackTrace) {
        _logFailure(
          failureStage,
          error,
          stackTrace,
          context: {'provider': provider.apiValue},
        );
        // Local provider cleanup is best-effort; logout/delete must finish.
      }
    }
  }

  void _writeSavingState() {
    _updateState(
      (state) =>
          state.copyWith(isSaving: true, clearError: true, clearSuccess: true),
    );
  }

  bool _canContinueRequest(RequestCancellation cancelToken) {
    return _canContinue() && !cancelToken.isCancelled;
  }
}
