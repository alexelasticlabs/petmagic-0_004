import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/profile/application/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/application/profile_request_tracker.dart';
import 'package:petmagic_mobile/features/profile/application/profile_state.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';

typedef ProfileMutationFailureLogger =
    void Function(String stage, Object error, StackTrace stackTrace);

/// Coordinates authenticated profile and legal-document mutations.
class ProfileMutationCoordinator {
  const ProfileMutationCoordinator({
    required ProfileRepositoryPort repository,
    required ProfileRequestTracker requestTracker,
    required void Function(ProfileState Function(ProfileState) update)
    updateState,
    required bool Function() ensureNetwork,
    required bool Function() canContinue,
    required void Function(String message) setFailure,
    required ProfileMutationFailureLogger logFailure,
  }) : _repository = repository,
       _requestTracker = requestTracker,
       _updateState = updateState,
       _ensureNetwork = ensureNetwork,
       _canContinue = canContinue,
       _setFailure = setFailure,
       _logFailure = logFailure;

  final ProfileRepositoryPort _repository;
  final ProfileRequestTracker _requestTracker;
  final void Function(ProfileState Function(ProfileState) update) _updateState;
  final bool Function() _ensureNetwork;
  final bool Function() _canContinue;
  final void Function(String message) _setFailure;
  final ProfileMutationFailureLogger _logFailure;

  Future<void> updateProfile({required String? displayName}) async {
    await _execute(
      operation: (cancelToken) => _repository.updateProfile(
        displayName: displayName,
        cancelToken: cancelToken,
      ),
      applyProfile: (state, profile) => state.copyWith(
        isSaving: false,
        profile: profile,
        displayName: profile.displayName ?? '',
      ),
      failureStage: 'update_profile_unknown',
    );
  }

  Future<void> acceptLegalDocuments(MobileLegalDocuments documents) async {
    await _execute(
      operation: (cancelToken) => _repository.acceptCurrentLegalDocuments(
        documents: documents,
        cancelToken: cancelToken,
      ),
      applyProfile: (state, profile) =>
          state.copyWith(isSaving: false, profile: profile),
      failureStage: 'accept_legal_unknown',
    );
  }

  Future<void> _execute({
    required Future<MobileUserProfile> Function(RequestCancellation cancelToken)
    operation,
    required ProfileState Function(ProfileState, MobileUserProfile)
    applyProfile,
    required String failureStage,
  }) async {
    if (!_ensureNetwork()) {
      return;
    }

    _updateState(
      (state) =>
          state.copyWith(isSaving: true, clearError: true, clearSuccess: true),
    );
    final cancelToken = _requestTracker.startProfileMutation();
    try {
      final profile = await operation(cancelToken);
      if (!_canContinue() || cancelToken.isCancelled) {
        return;
      }
      _updateState((state) => applyProfile(state, profile));
    } on RequestCancelledException {
      return;
    } on AppException catch (error) {
      _setFailure(error.message);
    } catch (error, stackTrace) {
      _logFailure(failureStage, error, stackTrace);
      _setFailure('profile.action_failed');
    } finally {
      _requestTracker.clearProfileMutation(cancelToken);
    }
  }
}
