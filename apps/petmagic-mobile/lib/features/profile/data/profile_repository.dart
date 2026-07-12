export 'package:petmagic_mobile/features/profile/application/profile_repository.dart'
    show
        ProfileRepositoryPort,
        currentLegalDocumentsProvider,
        linkedAccountsProvider,
        profileRepositoryProvider;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/application/profile_repository.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';
import 'package:petmagic_mobile/shared/files/media_signature.dart';
import 'package:petmagic_mobile/shared/files/upload_media_policy.dart';

final dioProfileRepositoryProvider = Provider<ProfileRepositoryPort>((ref) {
  return ProfileRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
    imageUploadOptimizer: const ImageUploadOptimizer(),
  );
});

class ProfileRepository implements ProfileRepositoryPort {
  ProfileRepository({
    required Dio dio,
    required AuthSessionStore sessionStorage,
    AuthSessionCoordinator? authSessionCoordinator,
    ImageUploadOptimizer? imageUploadOptimizer,
  }) : _dio = dio,
       _sessionStorage = sessionStorage,
       _imageUploadOptimizer =
           imageUploadOptimizer ?? const ImageUploadOptimizer(),
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage);

  final Dio _dio;
  final AuthSessionStore _sessionStorage;
  final ImageUploadOptimizer _imageUploadOptimizer;
  final AuthSessionCoordinator _authSessionCoordinator;

  static const _maxAvatarBytes = UploadMediaPolicy.avatarMaxBytes;

  @override
  Future<AuthSession?> readSession() => _sessionStorage.read();

  @override
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
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/auth/register',
        data: {
          'email': email.trim(),
          'password': password,
          'termsOfUseAccepted': termsOfUseAccepted,
          'privacyPolicyAccepted': privacyPolicyAccepted,
          'termsOfUseVersion': termsOfUseVersion,
          'privacyPolicyVersion': privacyPolicyVersion,
          'marketingEmailsEnabled': marketingEmailsEnabled,
          'displayName': displayName?.trim().isEmpty ?? true
              ? null
              : displayName!.trim(),
        },
        options: anonymousRequestOptions(),
        cancelToken: cancelToken,
      );

      return;
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallbackMessage: 'auth.registration_failed',
      );
    }
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {'email': email.trim(), 'password': password},
        cancelToken: cancelToken,
      );

      final session = AuthSession.fromJson(response.data ?? const {});
      await _sessionStorage.save(session);
      return session;
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: 'auth.login_failed');
    }
  }

  @override
  Future<void> requestPasswordReset({
    required String email,
    CancelToken? cancelToken,
  }) async {
    try {
      await _dio.post<void>(
        '/api/auth/password-reset/request',
        data: {'email': email.trim()},
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallbackMessage: 'auth.password_reset_request_failed',
      );
    }
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
    CancelToken? cancelToken,
  }) async {
    try {
      await _dio.post<void>(
        '/api/auth/password-reset/confirm',
        data: {
          'email': email.trim(),
          'code': code.trim(),
          'newPassword': newPassword,
        },
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallbackMessage: 'auth.password_reset_failed',
      );
    }
  }

  @override
  Future<void> requestCurrentPasswordChangeCode({
    CancelToken? cancelToken,
  }) async {
    try {
      await _authorizedRequest<void>(
        (session) => _dio.post<void>(
          '/api/auth/me/password-change/request',
          options: authenticatedRequestOptions(session.accessToken),
          cancelToken: cancelToken,
        ),
        retryTransientFailures: false,
      );
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallbackMessage: 'auth.password_reset_request_failed',
      );
    }
  }

  @override
  Future<void> confirmCurrentPasswordChange({
    required String code,
    required String newPassword,
    CancelToken? cancelToken,
  }) async {
    try {
      await _authorizedRequest<void>(
        (session) => _dio.post<void>(
          '/api/auth/me/password-change/confirm',
          data: {
            'code': code.trim(),
            'newPassword': newPassword,
            'refreshToken': session.refreshToken,
          },
          options: authenticatedRequestOptions(session.accessToken),
          cancelToken: cancelToken,
        ),
        retryTransientFailures: false,
      );
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallbackMessage: 'auth.password_reset_failed',
      );
    }
  }

  @override
  Future<void> resendEmailVerificationCode({
    required String email,
    CancelToken? cancelToken,
  }) async {
    try {
      await _dio.post<void>(
        '/api/auth/resend-email-verification-code',
        data: {'email': email.trim()},
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallbackMessage: 'auth.email_verification_resend_failed',
      );
    }
  }

  @override
  Future<AuthSession> verifyEmailCode({
    required String email,
    required String code,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/verify-email-code',
        data: {'email': email.trim(), 'code': code.trim()},
        cancelToken: cancelToken,
      );
      final session = AuthSession.fromJson(response.data ?? const {});
      await _sessionStorage.save(session);
      return session;
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallbackMessage: 'auth.email_verification_failed',
      );
    }
  }

  @override
  Future<void> logout() async {
    final session = await _sessionStorage.read();
    await _sessionStorage.clear();

    if (session == null) {
      return;
    }

    try {
      await _dio.post<void>(
        '/api/auth/logout',
        data: {'refreshToken': session.refreshToken},
        options: authenticatedRequestOptions(session.accessToken),
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Profile.Auth',
        operation: 'remote_logout',
        message: 'Remote logout failed after local session clear',
        context: {'stage': 'remote_logout'},
        error: error,
        stackTrace: stackTrace,
      );
      // Keep logout local-first.
    }
  }

  @override
  Future<void> deleteCurrentAccount({CancelToken? cancelToken}) async {
    try {
      await _authorizedRequest<void>(
        (session) => _dio.delete<void>(
          '/api/auth/me',
          options: authenticatedRequestOptions(session.accessToken),
          cancelToken: cancelToken,
        ),
        retryTransientFailures: false,
      );

      await _sessionStorage.clear();
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: 'profile.action_failed');
    }
  }

  @override
  Future<MobileUserProfile> fetchProfile({CancelToken? cancelToken}) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/auth/me',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );

    final profile = MobileUserProfile.fromJson(response.data ?? const {});
    await _replaceStoredUser(profile);
    return profile;
  }

  @override
  Future<MobileUserProfile> updateProfile({
    required String? displayName,
    CancelToken? cancelToken,
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
          cancelToken: cancelToken,
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
    CancelToken? cancelToken,
  }) async {
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.get<List<dynamic>>(
        '/api/auth/me/linked-accounts',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );

    return (response.data ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(MobileLinkedAccount.fromJson)
        .toList(growable: false);
  }

  @override
  Future<MobileLegalDocuments> fetchCurrentLegalDocuments({
    required String locale,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/legal/current',
        queryParameters: {'locale': locale},
        cancelToken: cancelToken,
      );

      return MobileLegalDocuments.fromJson(response.data ?? const {});
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
    CancelToken? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/legal/accept',
        data: {
          'termsOfUseVersion': documents.termsOfUse.version,
          'privacyPolicyVersion': documents.privacyPolicy.version,
        },
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
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
    CancelToken? cancelToken,
  }) async {
    final fileName = filePath.split(Platform.pathSeparator).last;
    final mediaType = _resolveMediaType(fileName);
    OptimizedUploadFile? optimizedAvatar;
    try {
      optimizedAvatar = await _imageUploadOptimizer.optimizeForAvatar(
        XFile(filePath, name: fileName, mimeType: mediaType.toString()),
        cancelToken: cancelToken,
      );
      final uploadFile = optimizedAvatar.file;
      final uploadFileName = uploadFile.name.isNotEmpty
          ? uploadFile.name
          : uploadFile.path.split(Platform.pathSeparator).last;
      final uploadMediaType = await _validateAvatarForUpload(
        filePath: uploadFile.path,
        mediaType: _resolveMediaType(uploadFileName),
      );

      final response = await _authorizedRequest<Map<String, dynamic>>(
        (session) async => _dio.put<Map<String, dynamic>>(
          '/api/auth/me/avatar',
          data: FormData.fromMap({
            'file': await MultipartFile.fromFile(
              uploadFile.path,
              filename: uploadFileName,
              contentType: uploadMediaType,
            ),
          }),
          cancelToken: cancelToken,
          options: authenticatedMultipartRequestOptions(session.accessToken),
        ),
        retryTransientFailures: false,
      );

      final profile = MobileUserProfile.fromJson(response.data ?? const {});
      await _replaceStoredUser(profile);
      return profile;
    } finally {
      await optimizedAvatar?.dispose();
    }
  }

  @override
  Future<MobileUserProfile> removeAvatar({CancelToken? cancelToken}) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.delete<Map<String, dynamic>>(
        '/api/auth/me/avatar',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
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
    CancelToken? cancelToken,
  }) async {
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.delete<List<dynamic>>(
        '/api/auth/me/linked-accounts/${Uri.encodeComponent(provider)}',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );

    return (response.data ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(MobileLinkedAccount.fromJson)
        .toList(growable: false);
  }

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

  Future<MediaType> _validateAvatarForUpload({
    required String filePath,
    required MediaType mediaType,
  }) async {
    if (!_isAllowedAvatarMediaType(mediaType)) {
      throw const AppException('profile.action_failed', statusCode: 400);
    }

    int fileSizeBytes;
    try {
      fileSizeBytes = await File(filePath).length();
    } on FileSystemException catch (error) {
      throw AppException(
        'profile.action_failed',
        statusCode: 400,
        cause: error,
      );
    }

    if (fileSizeBytes <= 0 || fileSizeBytes > _maxAvatarBytes) {
      throw const AppException('profile.action_failed', statusCode: 400);
    }

    final detectedMediaType = await _detectAvatarMediaType(filePath);
    if (detectedMediaType == null ||
        !_isAllowedAvatarMediaType(detectedMediaType)) {
      throw const AppException('profile.action_failed', statusCode: 400);
    }

    return detectedMediaType;
  }

  bool _isAllowedAvatarMediaType(MediaType mediaType) {
    return mediaType.type == 'image' &&
        (mediaType.subtype == 'jpeg' ||
            mediaType.subtype == 'png' ||
            mediaType.subtype == 'webp');
  }

  MediaType _resolveMediaType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => throw const AppException('profile.action_failed', statusCode: 400),
    };
  }

  Future<MediaType?> _detectAvatarMediaType(String path) async {
    final header = await _avatarHeader(path);
    final contentType = detectAvatarUploadContentType(header);
    return contentType == null ? null : MediaType.parse(contentType);
  }

  Future<List<int>> _avatarHeader(String path) async {
    try {
      final chunks = await File(path).openRead(0, 32).toList();
      return [for (final chunk in chunks) ...chunk];
    } on FileSystemException catch (error) {
      throw AppException(
        'profile.action_failed',
        statusCode: 400,
        cause: error,
      );
    }
  }
}
