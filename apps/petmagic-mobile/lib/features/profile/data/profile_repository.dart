export 'package:petmagic_mobile/features/profile/application/profile_repository.dart'
    show
        ProfileRepositoryPort,
        currentLegalDocumentsProvider,
        linkedAccountsProvider,
        profileRepositoryProvider;

import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/network/dio_request_cancellation.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_dto_mapper.dart';
import 'package:petmagic_mobile/features/profile/data/profile_avatar_upload_preparer.dart';
import 'package:petmagic_mobile/features/profile/application/profile_repository.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';

part 'profile_auth_repository_mixin.part.dart';

final dioProfileRepositoryProvider = Provider<ProfileRepositoryPort>((ref) {
  return ProfileRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
    imageUploadOptimizer: const ImageUploadOptimizer(),
  );
});

abstract class _ProfileRepositoryBase implements ProfileRepositoryPort {
  _ProfileRepositoryBase({
    required Dio dio,
    required AuthSessionStore sessionStorage,
    AuthSessionCoordinator? authSessionCoordinator,
    ImageUploadOptimizer? imageUploadOptimizer,
  }) : _dio = dio,
       _sessionStorage = sessionStorage,
       _avatarUploadPreparer = ProfileAvatarUploadPreparer(
         imageUploadOptimizer:
             imageUploadOptimizer ?? const ImageUploadOptimizer(),
       ),
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage);

  final Dio _dio;
  final AuthSessionStore _sessionStorage;
  final ProfileAvatarUploadPreparer _avatarUploadPreparer;
  final AuthSessionCoordinator _authSessionCoordinator;

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request, {
    bool retryTransientFailures = true,
  }) async {
    return _authSessionCoordinator.authorizedRequest(
      request: request,
      mapError: _mapDioException,
      requestFailedMessage: 'auth.request_failed',
      sessionExpiredMessage: 'auth.session_expired',
      transientRetryAttempts: retryTransientFailures ? 2 : 1,
    );
  }

  Future<void> _replaceStoredUser(MobileUserProfile profile) async {
    final session = await _sessionStorage.read();
    if (session == null) {
      return;
    }

    await _sessionStorage.save(
      AuthSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        expiresAtUtc: session.expiresAtUtc,
        user: profile,
      ),
    );
  }

  AppException _mapDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
    if (CancelToken.isCancel(error)) {
      return const RequestCancelledException();
    }

    if (NetworkErrorMapper.isConnectivityIssue(error)) {
      return NetworkErrorMapper.fromMessage(
        error,
        'templates.network_unavailable',
        includeCause: false,
      );
    }

    final payload = NetworkErrorMapper.parseApiPayload(error);
    final statusCode = error.response?.statusCode;
    final title = payload.title?.trim();
    final isUserNotFound = title == 'users.not_found';
    if (isUserNotFound && statusCode == 404) {
      return NetworkErrorMapper.fromMessage(
        error,
        'auth.session_expired',
        statusCode: statusCode,
      );
    }

    final safeMessage = NetworkErrorMapper.safePayloadMessage(payload);
    if (safeMessage != null) {
      return NetworkErrorMapper.fromMessage(error, safeMessage);
    }

    return NetworkErrorMapper.fallback(error, fallbackMessage: fallbackMessage);
  }
}

class ProfileRepository extends _ProfileRepositoryBase
    with _ProfileAuthRepositoryMixin
    implements ProfileRepositoryPort {
  ProfileRepository({
    required super.dio,
    required super.sessionStorage,
    super.authSessionCoordinator,
    super.imageUploadOptimizer,
  });
  @override
  Future<MobileUserProfile> fetchProfile({
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/auth/me',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
    );

    final profile = MobileUserProfile.fromJson(response.data ?? const {});
    await _replaceStoredUser(profile);
    return profile;
  }

  @override
  Future<MobileUserProfile> updateProfile({
    required String? displayName,
    RequestCancellation? cancelToken,
  }) async {
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (session) => _dio.put<Map<String, dynamic>>(
          '/api/auth/me/profile',
          data: {
            'displayName': displayName?.trim().isEmpty ?? true
                ? null
                : displayName!.trim(),
          },
          options: authenticatedRequestOptions(session.accessToken),
          cancelToken: cancelToken.toDioCancelToken(),
        ),
        retryTransientFailures: false,
      );

      final profile = MobileUserProfile.fromJson(response.data ?? const {});
      await _replaceStoredUser(profile);
      return profile;
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: 'profile.action_failed');
    }
  }

  @override
  Future<List<MobileLinkedAccount>> fetchLinkedAccounts({
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.get<List<dynamic>>(
        '/api/auth/me/linked-accounts',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
    );

    return (response.data ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(mapMobileLinkedAccountDto)
        .toList(growable: false);
  }

  @override
  Future<MobileLegalDocuments> fetchCurrentLegalDocuments({
    required String locale,
    RequestCancellation? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/legal/current',
        queryParameters: {'locale': locale},
        cancelToken: cancelToken.toDioCancelToken(),
      );

      return mapMobileLegalDocumentsDto(response.data ?? const {});
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallbackMessage: 'auth.legal_documents_unavailable',
      );
    }
  }

  @override
  Future<MobileUserProfile> acceptCurrentLegalDocuments({
    required MobileLegalDocuments documents,
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/legal/accept',
        data: {
          'termsOfUseVersion': documents.termsOfUse.version,
          'privacyPolicyVersion': documents.privacyPolicy.version,
        },
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );

    final profile = MobileUserProfile.fromJson(response.data ?? const {});
    await _replaceStoredUser(profile);
    return profile;
  }

  @override
  Future<MobileUserProfile> uploadAvatar(
    String filePath, {
    RequestCancellation? cancelToken,
  }) async {
    final prepared = await _avatarUploadPreparer.prepare(
      filePath,
      cancelToken: cancelToken,
    );
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (session) async => _dio.put<Map<String, dynamic>>(
          '/api/auth/me/avatar',
          data: FormData.fromMap({
            'file': await MultipartFile.fromFile(
              prepared.filePath,
              filename: prepared.fileName,
              contentType: prepared.mediaType,
            ),
          }),
          cancelToken: cancelToken.toDioCancelToken(),
          options: authenticatedMultipartRequestOptions(session.accessToken),
        ),
        retryTransientFailures: false,
      );

      final profile = MobileUserProfile.fromJson(response.data ?? const {});
      await _replaceStoredUser(profile);
      return profile;
    } finally {
      await prepared.dispose();
    }
  }

  @override
  Future<MobileUserProfile> removeAvatar({
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.delete<Map<String, dynamic>>(
        '/api/auth/me/avatar',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );

    final profile = MobileUserProfile.fromJson(response.data ?? const {});
    await _replaceStoredUser(profile);
    return profile;
  }

  @override
  Future<List<MobileLinkedAccount>> unlinkLinkedAccount(
    String provider, {
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.delete<List<dynamic>>(
        '/api/auth/me/linked-accounts/${Uri.encodeComponent(provider)}',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );

    return (response.data ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(mapMobileLinkedAccountDto)
        .toList(growable: false);
  }
}
