part of 'profile_repository.dart';

mixin _ProfileAuthRepositoryMixin on _ProfileRepositoryBase {
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
    RequestCancellation? cancelToken,
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
        cancelToken: cancelToken.toDioCancelToken(),
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
    RequestCancellation? cancelToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {'email': email.trim(), 'password': password},
        cancelToken: cancelToken.toDioCancelToken(),
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
    RequestCancellation? cancelToken,
  }) async {
    try {
      await _dio.post<void>(
        '/api/auth/password-reset/request',
        data: {'email': email.trim()},
        cancelToken: cancelToken.toDioCancelToken(),
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
    RequestCancellation? cancelToken,
  }) async {
    try {
      await _dio.post<void>(
        '/api/auth/password-reset/confirm',
        data: {
          'email': email.trim(),
          'code': code.trim(),
          'newPassword': newPassword,
        },
        cancelToken: cancelToken.toDioCancelToken(),
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
    RequestCancellation? cancelToken,
  }) async {
    try {
      await _authorizedRequest<void>(
        (session) => _dio.post<void>(
          '/api/auth/me/password-change/request',
          options: authenticatedRequestOptions(session.accessToken),
          cancelToken: cancelToken.toDioCancelToken(),
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
    RequestCancellation? cancelToken,
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
          cancelToken: cancelToken.toDioCancelToken(),
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
    RequestCancellation? cancelToken,
  }) async {
    try {
      await _dio.post<void>(
        '/api/auth/resend-email-verification-code',
        data: {'email': email.trim()},
        cancelToken: cancelToken.toDioCancelToken(),
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
    RequestCancellation? cancelToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/verify-email-code',
        data: {'email': email.trim(), 'code': code.trim()},
        cancelToken: cancelToken.toDioCancelToken(),
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
  Future<void> deleteCurrentAccount({RequestCancellation? cancelToken}) async {
    try {
      await _authorizedRequest<void>(
        (session) => _dio.delete<void>(
          '/api/auth/me',
          options: authenticatedRequestOptions(session.accessToken),
          cancelToken: cancelToken.toDioCancelToken(),
        ),
        retryTransientFailures: false,
      );

      await _sessionStorage.clear();
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: 'profile.action_failed');
    }
  }
}
