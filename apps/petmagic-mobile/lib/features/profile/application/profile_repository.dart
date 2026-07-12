import 'dart:async';

import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';

final profileRepositoryProvider = Provider<ProfileRepositoryPort>((ref) {
  throw StateError(
    'ProfileRepositoryPort is not bound. Add the app composition overrides.',
  );
});

const _profileProviderCacheTtl = Duration(minutes: 5);

final currentLegalDocumentsProvider =
    FutureProvider.family<MobileLegalDocuments, String>((ref, locale) {
      if (!ref.read(networkStatusControllerProvider).hasInternet) {
        throw const AppException('templates.network_unavailable');
      }

      final cancelToken = RequestCancellation();
      ref.onDispose(() {
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('profile_legal_documents_cancelled');
        }
      });
      return ref
          .watch(profileRepositoryProvider)
          .fetchCurrentLegalDocuments(locale: locale, cancelToken: cancelToken);
    });

final linkedAccountsProvider =
    FutureProvider.autoDispose<List<MobileLinkedAccount>>((ref) {
      if (!ref.watch(
        appLaunchControllerProvider.select((state) => state.isAuthenticated),
      )) {
        throw const AppException('auth.session_expired');
      }
      if (!ref.read(networkStatusControllerProvider).hasInternet) {
        throw const AppException('templates.network_unavailable');
      }

      final link = ref.keepAlive();
      Timer? disposeTimer;
      ref.onCancel(() {
        disposeTimer?.cancel();
        disposeTimer = Timer(_profileProviderCacheTtl, link.close);
      });
      ref.onResume(() {
        disposeTimer?.cancel();
        disposeTimer = null;
      });
      final cancelToken = RequestCancellation();
      ref.onDispose(() {
        disposeTimer?.cancel();
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('profile_linked_accounts_cancelled');
        }
      });
      return ref
          .watch(profileRepositoryProvider)
          .fetchLinkedAccounts(cancelToken: cancelToken);
    });

abstract interface class ProfileRepositoryPort {
  Future<AuthSession?> readSession();
  Future<void> register({
    required String email,
    required String password,
    required bool termsOfUseAccepted,
    required bool privacyPolicyAccepted,
    required String termsOfUseVersion,
    required String privacyPolicyVersion,
    required bool marketingEmailsEnabled,
    String? displayName,
    RequestCancellation? cancelToken,
  });
  Future<AuthSession> login({
    required String email,
    required String password,
    RequestCancellation? cancelToken,
  });
  Future<void> requestPasswordReset({
    required String email,
    RequestCancellation? cancelToken,
  });
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
    RequestCancellation? cancelToken,
  });
  Future<void> requestCurrentPasswordChangeCode({
    RequestCancellation? cancelToken,
  });
  Future<void> confirmCurrentPasswordChange({
    required String code,
    required String newPassword,
    RequestCancellation? cancelToken,
  });
  Future<void> resendEmailVerificationCode({
    required String email,
    RequestCancellation? cancelToken,
  });
  Future<AuthSession> verifyEmailCode({
    required String email,
    required String code,
    RequestCancellation? cancelToken,
  });
  Future<void> logout();
  Future<void> deleteCurrentAccount({RequestCancellation? cancelToken});
  Future<MobileUserProfile> fetchProfile({RequestCancellation? cancelToken});
  Future<MobileUserProfile> updateProfile({
    required String? displayName,
    RequestCancellation? cancelToken,
  });
  Future<List<MobileLinkedAccount>> fetchLinkedAccounts({
    RequestCancellation? cancelToken,
  });
  Future<MobileLegalDocuments> fetchCurrentLegalDocuments({
    required String locale,
    RequestCancellation? cancelToken,
  });
  Future<MobileUserProfile> acceptCurrentLegalDocuments({
    required MobileLegalDocuments documents,
    RequestCancellation? cancelToken,
  });
  Future<MobileUserProfile> uploadAvatar(
    String filePath, {
    RequestCancellation? cancelToken,
  });
  Future<MobileUserProfile> removeAvatar({RequestCancellation? cancelToken});
  Future<List<MobileLinkedAccount>> unlinkLinkedAccount(
    String provider, {
    RequestCancellation? cancelToken,
  });
}
