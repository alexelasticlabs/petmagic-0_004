import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/files/local_media_file.dart';
import 'package:petmagic_mobile/features/profile/application/avatar_media_gateway.dart';
import 'package:petmagic_mobile/features/profile/application/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/application/profile_request_tracker.dart';
import 'package:petmagic_mobile/features/profile/application/profile_state.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

typedef ProfileAvatarFailureLogger =
    void Function(String stage, Object error, StackTrace stackTrace);

/// Coordinates avatar selection, upload, removal, and cache invalidation.
class ProfileAvatarCoordinator {
  const ProfileAvatarCoordinator({
    required ProfileRepositoryPort repository,
    required AvatarMediaGateway mediaGateway,
    required ProfileRequestTracker requestTracker,
    required ProfileState Function() readState,
    required void Function(ProfileState Function(ProfileState) update)
    updateState,
    required bool Function() ensureNetwork,
    required bool Function() hasInternet,
    required bool Function() canContinue,
    required void Function(String message) setFailure,
    required void Function(bool requiresLegalAcceptance) markSignedIn,
    required ProfileAvatarFailureLogger logFailure,
  }) : _repository = repository,
       _mediaGateway = mediaGateway,
       _requestTracker = requestTracker,
       _readState = readState,
       _updateState = updateState,
       _ensureNetwork = ensureNetwork,
       _hasInternet = hasInternet,
       _canContinue = canContinue,
       _setFailure = setFailure,
       _markSignedIn = markSignedIn,
       _logFailure = logFailure;

  final ProfileRepositoryPort _repository;
  final AvatarMediaGateway _mediaGateway;
  final ProfileRequestTracker _requestTracker;
  final ProfileState Function() _readState;
  final void Function(ProfileState Function(ProfileState) update) _updateState;
  final bool Function() _ensureNetwork;
  final bool Function() _hasInternet;
  final bool Function() _canContinue;
  final void Function(String message) _setFailure;
  final void Function(bool requiresLegalAcceptance) _markSignedIn;
  final ProfileAvatarFailureLogger _logFailure;

  Future<LocalMediaFile?> pickImage() => _mediaGateway.pickAvatarImage();

  Future<void> uploadFromPath(String filePath) async {
    if (!_ensureNetwork()) {
      await _mediaGateway.deleteManagedTempFile(filePath);
      return;
    }

    final cancelToken = _requestTracker.tryStartAvatarUpload();
    if (cancelToken == null) {
      return;
    }

    _updateState(
      (state) =>
          state.copyWith(isSaving: true, clearError: true, clearSuccess: true),
    );
    try {
      final previousAvatarUrl = _readState().profile?.avatar?.url;
      final profile = await _repository.uploadAvatar(
        filePath,
        cancelToken: cancelToken,
      );
      if (!_canContinue()) {
        return;
      }

      _updateState(
        (state) => state.copyWith(isSaving: false, profile: profile),
      );
      await _evictAvatarCache(previousAvatarUrl);
      await _evictAvatarCache(profile.avatar?.url);
      if (_canContinue()) {
        _markSignedIn(profile.legalAcceptance.requiresAcceptance);
      }
    } on RequestCancelledException {
      if (!_canContinue()) {
        return;
      }
      final hasInternet = _hasInternet();
      _updateState(
        (state) => state.copyWith(
          isSaving: false,
          clearError: hasInternet,
          errorMessage: hasInternet ? null : 'templates.network_unavailable',
        ),
      );
    } on AppException catch (error) {
      _setFailure(error.message);
    } catch (error, stackTrace) {
      _logFailure('upload_avatar_unknown', error, stackTrace);
      _setFailure('profile.action_failed');
    } finally {
      _requestTracker.clearAvatarUpload(cancelToken);
      await _mediaGateway.deleteManagedTempFile(filePath);
    }
  }

  Future<void> remove() async {
    if (!_ensureNetwork()) {
      return;
    }

    _updateState(
      (state) =>
          state.copyWith(isSaving: true, clearError: true, clearSuccess: true),
    );
    final cancelToken = _requestTracker.startProfileMutation();
    try {
      final profile = await _repository.removeAvatar(cancelToken: cancelToken);
      if (!_canContinue() || cancelToken.isCancelled) {
        return;
      }
      _updateState(
        (state) => state.copyWith(isSaving: false, profile: profile),
      );
    } on RequestCancelledException {
      return;
    } on AppException catch (error) {
      _setFailure(error.message);
    } catch (error, stackTrace) {
      _logFailure('remove_avatar_unknown', error, stackTrace);
      _setFailure('profile.action_failed');
    } finally {
      _requestTracker.clearProfileMutation(cancelToken);
    }
  }

  Future<void> _evictAvatarCache(String? imageUrl) async {
    final safeImageUrl = parseSafeProfileAvatarUri(imageUrl)?.toString();
    if (safeImageUrl == null) {
      return;
    }

    try {
      await _mediaGateway.evictAvatarCache(safeImageUrl);
    } catch (error, stackTrace) {
      _logFailure('avatar_cache_evict_failed', error, stackTrace);
    }
  }
}
