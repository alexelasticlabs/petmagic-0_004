import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
  );
});

final currentLegalDocumentsProvider =
    FutureProvider.family<MobileLegalDocuments, String>((ref, locale) {
      return ref
          .watch(profileRepositoryProvider)
          .fetchCurrentLegalDocuments(locale: locale);
    });

final linkedAccountsProvider = FutureProvider<List<MobileLinkedAccount>>((ref) {
  return ref.watch(profileRepositoryProvider).fetchLinkedAccounts();
});

class ProfileRepository {
  ProfileRepository({
    required Dio dio,
    required AuthSessionStorage sessionStorage,
    AuthSessionCoordinator? authSessionCoordinator,
  }) : _dio = dio,
       _sessionStorage = sessionStorage,
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage);

  final Dio _dio;
  final AuthSessionStorage _sessionStorage;
  final AuthSessionCoordinator _authSessionCoordinator;

  static const _maxAvatarBytes = 8 * 1024 * 1024;

  Future<AuthSession?> readSession() => _sessionStorage.read();

  Future<void> register({
    required String email,
    required String password,
    required bool termsOfUseAccepted,
    required bool privacyPolicyAccepted,
    required String termsOfUseVersion,
    required String privacyPolicyVersion,
    required bool marketingEmailsEnabled,
    String? displayName,
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
      );

      return;
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallbackMessage: 'auth.registration_failed',
      );
    }
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {'email': email.trim(), 'password': password},
      );

      final session = AuthSession.fromJson(response.data ?? const {});
      await _sessionStorage.save(session);
      return session;
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: 'auth.login_failed');
    }
  }

  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _dio.post<void>(
        '/api/auth/request-password-reset',
        data: {'email': email.trim()},
      );
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallbackMessage: 'auth.password_reset_request_failed',
      );
    }
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _dio.post<void>(
        '/api/auth/reset-password',
        data: {
          'email': email.trim(),
          'code': code.trim(),
          'newPassword': newPassword,
        },
      );
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallbackMessage: 'auth.password_reset_failed',
      );
    }
  }

  Future<void> requestCurrentPasswordChangeCode() async {
    try {
      await _authorizedRequest<void>(
        (session) => _dio.post<void>(
          '/api/auth/me/password-change/request',
          options: authenticatedRequestOptions(session.accessToken),
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

  Future<void> confirmCurrentPasswordChange({
    required String code,
    required String newPassword,
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

  Future<void> resendEmailVerificationCode({required String email}) async {
    try {
      await _dio.post<void>(
        '/api/auth/resend-email-verification-code',
        data: {'email': email.trim()},
      );
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallbackMessage: 'auth.email_verification_resend_failed',
      );
    }
  }

  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    try {
      await _dio.post<void>(
        '/api/auth/verify-email-code',
        data: {'email': email.trim(), 'code': code.trim()},
      );
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallbackMessage: 'auth.email_verification_failed',
      );
    }
  }

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

  Future<void> deleteCurrentAccount() async {
    try {
      await _authorizedRequest<void>(
        (session) => _dio.delete<void>(
          '/api/auth/me',
          options: authenticatedRequestOptions(session.accessToken),
        ),
        retryTransientFailures: false,
      );

      await _sessionStorage.clear();
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: 'profile.action_failed');
    }
  }

  Future<MobileUserProfile> fetchProfile() async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/auth/me',
        options: authenticatedRequestOptions(session.accessToken),
      ),
    );

    final profile = MobileUserProfile.fromJson(response.data ?? const {});
    await _replaceStoredUser(profile);
    return profile;
  }

  Future<MobileUserProfile> updateProfile({
    required String? displayName,
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

  Future<List<MobileLinkedAccount>> fetchLinkedAccounts() async {
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.get<List<dynamic>>(
        '/api/auth/me/linked-accounts',
        options: authenticatedRequestOptions(session.accessToken),
      ),
    );

    return (response.data ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(MobileLinkedAccount.fromJson)
        .toList(growable: false);
  }

  Future<MobileLegalDocuments> fetchCurrentLegalDocuments({
    required String locale,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/legal/current',
        queryParameters: {'locale': locale},
      );

      return MobileLegalDocuments.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallbackMessage: 'auth.legal_documents_unavailable',
      );
    }
  }

  Future<MobileUserProfile> acceptCurrentLegalDocuments({
    required MobileLegalDocuments documents,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/legal/accept',
        data: {
          'termsOfUseVersion': documents.termsOfUse.version,
          'privacyPolicyVersion': documents.privacyPolicy.version,
        },
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );

    final profile = MobileUserProfile.fromJson(response.data ?? const {});
    await _replaceStoredUser(profile);
    return profile;
  }

  Future<MobileUserProfile> uploadAvatar(
    String filePath, {
    CancelToken? cancelToken,
  }) async {
    final fileName = filePath.split(Platform.pathSeparator).last;
    final mediaType = _resolveMediaType(fileName);
    final uploadMediaType = await _validateAvatarForUpload(
      filePath: filePath,
      mediaType: mediaType,
    );

    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) async => _dio.put<Map<String, dynamic>>(
        '/api/auth/me/avatar',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(
            filePath,
            filename: fileName,
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
  }

  Future<MobileUserProfile> removeAvatar() async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.delete<Map<String, dynamic>>(
        '/api/auth/me/avatar',
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );

    final profile = MobileUserProfile.fromJson(response.data ?? const {});
    await _replaceStoredUser(profile);
    return profile;
  }

  Future<List<MobileLinkedAccount>> unlinkLinkedAccount(String provider) async {
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.delete<List<dynamic>>(
        '/api/auth/me/linked-accounts/${Uri.encodeComponent(provider)}',
        options: authenticatedRequestOptions(session.accessToken),
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
    final detail = payload.detail?.trim();

    final isUserNotFound =
        title == 'users.not_found' || detail == 'User not found.';
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
    if (_startsWith(header, const [0xFF, 0xD8, 0xFF])) {
      return MediaType('image', 'jpeg');
    }
    if (_startsWith(header, const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ])) {
      return MediaType('image', 'png');
    }
    if (header.length >= 12 &&
        _asciiEquals(header, 0, 'RIFF') &&
        _asciiEquals(header, 8, 'WEBP')) {
      return MediaType('image', 'webp');
    }

    return null;
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

  bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) {
      return false;
    }
    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) {
        return false;
      }
    }
    return true;
  }

  bool _asciiEquals(List<int> bytes, int offset, String value) {
    if (bytes.length < offset + value.length) {
      return false;
    }
    for (var index = 0; index < value.length; index++) {
      if (bytes[offset + index] != value.codeUnitAt(index)) {
        return false;
      }
    }
    return true;
  }
}
