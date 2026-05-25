import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
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
        '/api/auth/password-reset/request',
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
        '/api/auth/password-reset/confirm',
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

  Future<void> deleteCurrentAccount() async {
    try {
      await _authorizedRequest<void>(
        (session) => _dio.delete<void>(
          '/api/auth/me',
          options: Options(
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
            },
          ),
        ),
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

  Future<List<MobileLinkedAccount>> fetchLinkedAccounts() async {
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.get<List<dynamic>>(
        '/api/auth/me/linked-accounts',
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
          },
        ),
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

  Future<List<MobileLinkedAccount>> unlinkLinkedAccount(String provider) async {
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.delete<List<dynamic>>(
        '/api/auth/me/linked-accounts/${Uri.encodeComponent(provider)}',
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
          },
        ),
      ),
    );

    return (response.data ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(MobileLinkedAccount.fromJson)
        .toList(growable: false);
  }

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request,
  ) async {
    return _authSessionCoordinator.authorizedRequest(
      request: request,
      mapError: _mapDioException,
      requestFailedMessage: 'auth.request_failed',
      sessionExpiredMessage: 'auth.session_expired',
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
    final payload = NetworkErrorMapper.parseApiPayload(error);
    if (payload.flattened != null) {
      return NetworkErrorMapper.fromMessage(error, payload.flattened!);
    }

    if (payload.detail != null) {
      return NetworkErrorMapper.fromMessage(error, payload.detail!);
    }

    if (payload.title != null) {
      return NetworkErrorMapper.fromMessage(error, payload.title!);
    }

    return NetworkErrorMapper.fallback(error, fallbackMessage: fallbackMessage);
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
