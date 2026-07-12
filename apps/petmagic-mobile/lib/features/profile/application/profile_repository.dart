import 'dart:async';

import 'package:dio/dio.dart';
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

      final cancelToken = CancelToken();
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
      final cancelToken = CancelToken();
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
    CancelToken? cancelToken,
  });
  Future<AuthSession> login({
    required String email,
    required String password,
    CancelToken? cancelToken,
  });
  Future<void> requestPasswordReset({
    required String email,
    CancelToken? cancelToken,
  });
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
    CancelToken? cancelToken,
  });
  Future<void> requestCurrentPasswordChangeCode({CancelToken? cancelToken});
  Future<void> confirmCurrentPasswordChange({
    required String code,
    required String newPassword,
    CancelToken? cancelToken,
  });
  Future<void> resendEmailVerificationCode({
    required String email,
    CancelToken? cancelToken,
  });
  Future<AuthSession> verifyEmailCode({
    required String email,
    required String code,
    CancelToken? cancelToken,
  });
  Future<void> logout();
  Future<void> deleteCurrentAccount({CancelToken? cancelToken});
  Future<MobileUserProfile> fetchProfile({CancelToken? cancelToken});
  Future<MobileUserProfile> updateProfile({
    required String? displayName,
    CancelToken? cancelToken,
  });
  Future<List<MobileLinkedAccount>> fetchLinkedAccounts({
    CancelToken? cancelToken,
  });
  Future<MobileLegalDocuments> fetchCurrentLegalDocuments({
    required String locale,
    CancelToken? cancelToken,
  });
  Future<MobileUserProfile> acceptCurrentLegalDocuments({
    required MobileLegalDocuments documents,
    CancelToken? cancelToken,
  });
  Future<MobileUserProfile> uploadAvatar(
    String filePath, {
    CancelToken? cancelToken,
  });
  Future<MobileUserProfile> removeAvatar({CancelToken? cancelToken});
  Future<List<MobileLinkedAccount>> unlinkLinkedAccount(
    String provider, {
    CancelToken? cancelToken,
  });
}
