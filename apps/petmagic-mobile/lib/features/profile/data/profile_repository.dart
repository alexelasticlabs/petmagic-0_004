import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';

final authSessionStorageProvider = Provider<AuthSessionStorage>((ref) {
  return AuthSessionStorage();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
  );
});

final currentLegalDocumentsProvider =
    FutureProvider.family<MobileLegalDocuments, String>((ref, locale) {
      return ref
          .watch(profileRepositoryProvider)
          .fetchCurrentLegalDocuments(locale: locale);
    });

class ProfileRepository {
  ProfileRepository({
    required Dio dio,
    required AuthSessionStorage sessionStorage,
  }) : _dio = dio,
       _sessionStorage = sessionStorage;

  final Dio _dio;
  final AuthSessionStorage _sessionStorage;

  Future<AuthSession?> readSession() => _sessionStorage.read();

  Future<AuthSession> register({
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

      return login(email: email, password: password);
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: 'Registration failed.');
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
      throw _mapDioException(error, fallbackMessage: 'Login failed.');
    }
  }

  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _dio.post<void>(
        '/api/auth/password-reset/request',
        data: {'email': email.trim()},
      );
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallbackMessage: 'Password reset request failed.',
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
        '/api/auth/password-reset/confirm',
        data: {
          'email': email.trim(),
          'code': code.trim(),
          'newPassword': newPassword,
        },
      );
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: 'Password reset failed.');
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
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
          },
        ),
      );
    } catch (_) {
      // Keep logout local-first.
    }
  }

  Future<MobileUserProfile> fetchProfile() async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/auth/me',
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
          },
        ),
      ),
    );

    final profile = MobileUserProfile.fromJson(response.data ?? const {});
    await _replaceStoredUser(profile);
    return profile;
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
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
          },
        ),
      ),
    );

    final profile = MobileUserProfile.fromJson(response.data ?? const {});
    await _replaceStoredUser(profile);
    return profile;
  }

  Future<MobileUserProfile> uploadAvatar(String filePath) async {
    final fileName = filePath.split(Platform.pathSeparator).last;
    final mediaType = _resolveMediaType(fileName);

    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) async => _dio.put<Map<String, dynamic>>(
        '/api/auth/me/avatar',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(
            filePath,
            filename: fileName,
            contentType: mediaType,
          ),
        }),
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
          },
        ),
      ),
    );

    final profile = MobileUserProfile.fromJson(response.data ?? const {});
    await _replaceStoredUser(profile);
    return profile;
  }

  Future<MobileUserProfile> removeAvatar() async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.delete<Map<String, dynamic>>(
        '/api/auth/me/avatar',
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
          },
        ),
      ),
    );

    final profile = MobileUserProfile.fromJson(response.data ?? const {});
    await _replaceStoredUser(profile);
    return profile;
  }

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request,
  ) async {
    var session = await _sessionStorage.read();
    if (session == null) {
      throw const AppException('Sign in is required.', statusCode: 401);
    }

    try {
      return await request(session);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        session = await _refreshSession(session.refreshToken);
        return request(session);
      }

      throw _mapDioException(error, fallbackMessage: 'Request failed.');
    }
  }

  Future<AuthSession> _refreshSession(String refreshToken) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final refreshed = AuthSession.fromJson(response.data ?? const {});
      await _sessionStorage.save(refreshed);
      return refreshed;
    } on DioException catch (error) {
      await _sessionStorage.clear();
      throw _mapDioException(error, fallbackMessage: 'Session expired.');
    }
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
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final detail = responseData['detail'] as String?;
      final title = responseData['title'] as String?;
      final errors = responseData['errors'];
      if (errors is Map<String, dynamic>) {
        final flattened = errors.values
            .whereType<List<dynamic>>()
            .expand((value) => value.whereType<String>())
            .join(' ');
        if (flattened.isNotEmpty) {
          return AppException(
            flattened,
            statusCode: error.response?.statusCode,
            cause: error,
          );
        }
      }

      if (detail != null && detail.isNotEmpty) {
        return AppException(
          detail,
          statusCode: error.response?.statusCode,
          cause: error,
        );
      }

      if (title != null && title.isNotEmpty) {
        return AppException(
          title,
          statusCode: error.response?.statusCode,
          cause: error,
        );
      }
    }

    return AppException(
      fallbackMessage,
      statusCode: error.response?.statusCode,
      cause: error,
    );
  }

  MediaType _resolveMediaType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'gif' => MediaType('image', 'gif'),
      _ => MediaType('image', 'jpeg'),
    };
  }
}
