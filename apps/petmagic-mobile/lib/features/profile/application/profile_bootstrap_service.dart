import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/profile/application/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';

typedef ProfileBootstrapFailureLogger =
    void Function(String stage, Object error, StackTrace stackTrace);

class ProfileBootstrapResult {
  const ProfileBootstrapResult._({
    this.profile,
    this.errorMessage,
    this.shouldMarkSignedOut = false,
    this.isAborted = false,
    this.isCancelled = false,
  });

  const ProfileBootstrapResult.authenticated(
    MobileUserProfile profile, {
    String? errorMessage,
  }) : this._(profile: profile, errorMessage: errorMessage);

  const ProfileBootstrapResult.guest({
    String? errorMessage,
    bool shouldMarkSignedOut = false,
  }) : this._(
         errorMessage: errorMessage,
         shouldMarkSignedOut: shouldMarkSignedOut,
       );

  const ProfileBootstrapResult.cancelled() : this._(isCancelled: true);

  const ProfileBootstrapResult.aborted() : this._(isAborted: true);

  final MobileUserProfile? profile;
  final String? errorMessage;
  final bool shouldMarkSignedOut;
  final bool isAborted;
  final bool isCancelled;
}

/// Restores the current profile while preserving cached-session fallback rules.
class ProfileBootstrapService {
  const ProfileBootstrapService({required ProfileRepositoryPort repository})
    : _repository = repository;

  final ProfileRepositoryPort _repository;

  Future<ProfileBootstrapResult> restore({
    required RequestCancellation cancelToken,
    required bool Function() canContinue,
    required ProfileBootstrapFailureLogger logFailure,
  }) async {
    try {
      final session = await _repository.readSession();
      if (!canContinue()) {
        return const ProfileBootstrapResult.aborted();
      }
      if (session == null) {
        return const ProfileBootstrapResult.guest();
      }

      final profile = await _repository.fetchProfile(cancelToken: cancelToken);
      if (!canContinue()) {
        return const ProfileBootstrapResult.aborted();
      }
      return ProfileBootstrapResult.authenticated(profile);
    } on RequestCancelledException {
      return const ProfileBootstrapResult.cancelled();
    } on AppException catch (error) {
      final storedSession = await _repository.readSession();
      if (!canContinue()) {
        return const ProfileBootstrapResult.aborted();
      }
      if (storedSession != null && error.statusCode != 401) {
        return ProfileBootstrapResult.authenticated(
          storedSession.user,
          errorMessage: error.message,
        );
      }

      return ProfileBootstrapResult.guest(
        errorMessage: error.message,
        shouldMarkSignedOut: error.statusCode == 401,
      );
    } catch (error, stackTrace) {
      logFailure('initialize_unknown', error, stackTrace);
      final storedSession = await _repository.readSession();
      if (!canContinue()) {
        return const ProfileBootstrapResult.aborted();
      }
      if (storedSession != null) {
        return ProfileBootstrapResult.authenticated(
          storedSession.user,
          errorMessage: 'profile.action_failed',
        );
      }

      return const ProfileBootstrapResult.guest(
        errorMessage: 'profile.action_failed',
      );
    }
  }
}
