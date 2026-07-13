import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/profile/application/external_auth_gateway.dart';
import 'package:petmagic_mobile/features/profile/application/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/application/profile_request_tracker.dart';
import 'package:petmagic_mobile/features/profile/application/profile_state.dart';
import 'package:petmagic_mobile/features/profile/domain/auth_password_policy.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';

typedef ProfileAuthFailureLogger =
    void Function(String stage, Object error, StackTrace stackTrace);

/// Coordinates sign-in, registration, and external-account operations.
class ProfileAuthCoordinator {
  const ProfileAuthCoordinator({
    required ProfileRepositoryPort Function() repository,
    required ExternalAuthRepository Function() externalAuthRepository,
    required ProfileRequestTracker requestTracker,
    required ProfileState Function() readState,
    required void Function(ProfileState state) writeState,
    required void Function(ProfileState Function(ProfileState) update)
    updateState,
    required bool Function() ensureNetwork,
    required bool Function() canContinue,
    required void Function(String message) setFailure,
    required void Function(bool requiresLegalAcceptance) markSignedIn,
    required void Function() invalidateLinkedAccounts,
    required ProfileAuthFailureLogger logFailure,
  }) : _repository = repository,
       _externalAuthRepository = externalAuthRepository,
       _requestTracker = requestTracker,
       _readState = readState,
       _writeState = writeState,
       _updateState = updateState,
       _ensureNetwork = ensureNetwork,
       _canContinue = canContinue,
       _setFailure = setFailure,
       _markSignedIn = markSignedIn,
       _invalidateLinkedAccounts = invalidateLinkedAccounts,
       _logFailure = logFailure;

  static const _genericActionError = 'profile.action_failed';

  final ProfileRepositoryPort Function() _repository;
  final ExternalAuthRepository Function() _externalAuthRepository;
  final ProfileRequestTracker _requestTracker;
  final ProfileState Function() _readState;
  final void Function(ProfileState state) _writeState;
  final void Function(ProfileState Function(ProfileState) update) _updateState;
  final bool Function() _ensureNetwork;
  final bool Function() _canContinue;
  final void Function(String message) _setFailure;
  final void Function(bool requiresLegalAcceptance) _markSignedIn;
  final void Function() _invalidateLinkedAccounts;
  final ProfileAuthFailureLogger _logFailure;

  Future<void> login() async {
    if (_readState().isSaving) {
      return;
    }
    if (!_ensureNetwork()) {
      return;
    }

    _writeSavingState();
    final authRequestCancellation = _requestTracker.startAuth();
    try {
      final credentials = _readState();
      await _repository().login(
        email: credentials.email,
        password: credentials.password,
        cancelToken: authRequestCancellation,
      );
      if (!_canContinueRequest(authRequestCancellation)) {
        return;
      }
      final profile = await _repository().fetchProfile(
        cancelToken: authRequestCancellation,
      );
      if (!_canContinueRequest(authRequestCancellation)) {
        return;
      }
      _updateState(
        (state) => state.copyWith(
          isSaving: false,
          profile: profile,
          password: '',
          confirmPassword: '',
        ),
      );
      if (_canContinue()) {
        _markSignedIn(profile.legalAcceptance.requiresAcceptance);
      }
    } on RequestCancelledException {
      _handleCancelledRequest(authRequestCancellation);
    } on AppException catch (error) {
      _setFailure(error.message);
    } catch (error, stackTrace) {
      _logFailure('login_unknown', error, stackTrace);
      _setFailure(_genericActionError);
    } finally {
      _requestTracker.clearAuth(authRequestCancellation);
    }
  }

  Future<void> register({
    required bool termsOfUseAccepted,
    required bool privacyPolicyAccepted,
    required MobileLegalDocuments? legalDocuments,
    required bool marketingEmailsEnabled,
  }) async {
    final current = _readState();
    if (current.isSaving) {
      return;
    }
    if (!AuthPasswordPolicy.isValid(current.password)) {
      _writeState(
        current.copyWith(
          errorMessage: AuthPasswordPolicy.errorMessage,
          clearSuccess: true,
        ),
      );
      return;
    }
    if (current.password != current.confirmPassword) {
      _writeState(
        current.copyWith(
          errorMessage: 'auth.password_mismatch',
          clearSuccess: true,
        ),
      );
      return;
    }
    if (legalDocuments == null ||
        legalDocuments.termsOfUse.version.trim().isEmpty ||
        legalDocuments.privacyPolicy.version.trim().isEmpty) {
      _writeState(
        current.copyWith(
          errorMessage: 'auth.legal_documents_unavailable',
          clearSuccess: true,
        ),
      );
      return;
    }
    if (!_ensureNetwork()) {
      return;
    }

    _writeSavingState();
    final authRequestCancellation = _requestTracker.startAuth();
    try {
      final registration = _readState();
      await _repository().register(
        email: registration.email,
        password: registration.password,
        displayName: registration.displayName,
        termsOfUseAccepted: termsOfUseAccepted,
        privacyPolicyAccepted: privacyPolicyAccepted,
        termsOfUseVersion: legalDocuments.termsOfUse.version,
        privacyPolicyVersion: legalDocuments.privacyPolicy.version,
        marketingEmailsEnabled: marketingEmailsEnabled,
        cancelToken: authRequestCancellation,
      );
      if (!_canContinueRequest(authRequestCancellation)) {
        return;
      }
      _updateState(
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
      _handleCancelledRequest(authRequestCancellation);
    } on AppException catch (error) {
      _setFailure(error.message);
    } catch (error, stackTrace) {
      _logFailure('register_unknown', error, stackTrace);
      _setFailure(_genericActionError);
    } finally {
      _requestTracker.clearAuth(authRequestCancellation);
    }
  }

  Future<void> authenticateWithProvider(ExternalAuthProvider provider) async {
    if (_readState().isSaving) {
      return;
    }
    if (!_ensureNetwork()) {
      return;
    }

    _writeSavingState();
    final authRequestCancellation = _requestTracker.startAuth();
    try {
      final session = await _externalAuthRepository().authenticate(
        provider,
        cancelToken: authRequestCancellation,
      );
      if (!_canContinueRequest(authRequestCancellation)) {
        return;
      }
      _updateState(
        (state) => state.copyWith(
          isSaving: false,
          profile: session.user,
          password: '',
          confirmPassword: '',
        ),
      );
      if (_canContinue()) {
        _markSignedIn(session.user.legalAcceptance.requiresAcceptance);
      }
    } on RequestCancelledException {
      _handleCancelledRequest(authRequestCancellation);
    } on AppException catch (error) {
      _setFailure(error.message);
    } catch (error, stackTrace) {
      _logFailure('authenticate_provider_unknown', error, stackTrace);
      _setFailure('auth.external_invalid');
    } finally {
      _requestTracker.clearAuth(authRequestCancellation);
    }
  }

  Future<void> linkExternalAccount(ExternalAuthProvider provider) {
    return _changeExternalAccount(
      operation: (cancelToken) =>
          _externalAuthRepository().link(provider, cancelToken: cancelToken),
      failureStage: 'link_external_unknown',
      unknownErrorMessage: 'auth.external_invalid',
    );
  }

  Future<void> unlinkExternalAccount(ExternalAuthProvider provider) {
    return _changeExternalAccount(
      operation: (cancelToken) => _repository().unlinkLinkedAccount(
        provider.apiValue,
        cancelToken: cancelToken,
      ),
      failureStage: 'unlink_external_unknown',
      unknownErrorMessage: _genericActionError,
    );
  }

  Future<void> _changeExternalAccount({
    required Future<Object?> Function(RequestCancellation cancelToken)
    operation,
    required String failureStage,
    required String unknownErrorMessage,
  }) async {
    if (!_ensureNetwork()) {
      return;
    }

    _writeSavingState();
    final authRequestCancellation = _requestTracker.startAuth();
    try {
      await operation(authRequestCancellation);
      if (!_canContinueRequest(authRequestCancellation)) {
        return;
      }
      _invalidateLinkedAccounts();
      _updateState((state) => state.copyWith(isSaving: false));
    } on RequestCancelledException {
      _handleCancelledRequest(authRequestCancellation);
    } on AppException catch (error) {
      _setFailure(error.message);
    } catch (error, stackTrace) {
      _logFailure(failureStage, error, stackTrace);
      _setFailure(unknownErrorMessage);
    } finally {
      _requestTracker.clearAuth(authRequestCancellation);
    }
  }

  void _writeSavingState() {
    _writeState(
      _readState().copyWith(
        isSaving: true,
        clearError: true,
        clearSuccess: true,
      ),
    );
  }

  bool _canContinueRequest(RequestCancellation cancelToken) {
    return _canContinue() && !cancelToken.isCancelled;
  }

  void _handleCancelledRequest(RequestCancellation cancelToken) {
    if (!_requestTracker.ownsAuth(cancelToken)) {
      return;
    }
    _updateState((state) => state.copyWith(isSaving: false, clearError: true));
  }
}
