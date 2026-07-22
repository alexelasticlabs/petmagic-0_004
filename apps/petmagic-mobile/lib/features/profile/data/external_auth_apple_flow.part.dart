part of 'external_auth_repository.dart';

mixin _ExternalAuthAppleFlow on _MobileExternalAuthRepositoryBase {
  Future<AuthSession> _authenticateWithNativeApple({
    RequestCancellation? cancelToken,
  }) async {
    try {
      final credential = await _appleSignIn();
      final identityToken = credential.identityToken;
      final authorizationCode = credential.authorizationCode;
      if (identityToken == null ||
          identityToken.isEmpty ||
          authorizationCode.isEmpty) {
        throw const AppException(
          _MobileExternalAuthRepositoryBase._genericFailedCode,
        );
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/apple',
        data: {
          'identityToken': identityToken,
          'authorizationCode': authorizationCode,
        },
        options: Options(headers: {'X-Client-Platform': 'mobile'}),
        cancelToken: cancelToken.toDioCancelToken(),
      );

      final session = AuthSession.fromJson(response.data ?? const {});
      await _sessionStorage.save(session);
      _trackSocialAuthEvent(
        'social_login_success',
        provider: ExternalAuthProvider.apple,
        status: 'existing_user_logged_in',
      );
      return session;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        _trackSocialAuthEvent(
          'social_login_failed',
          provider: ExternalAuthProvider.apple,
          status: 'user_cancellation',
        );
        throw const AppException(
          _MobileExternalAuthRepositoryBase._cancelledCode,
        );
      }

      _trackSocialAuthEvent(
        'social_login_failed',
        provider: ExternalAuthProvider.apple,
        status: 'provider_failure',
      );
      throw const AppException(
        _MobileExternalAuthRepositoryBase._genericFailedCode,
      );
    } on AppException {
      rethrow;
    } on DioException catch (error) {
      final mapped = _mapDioException(
        error,
        fallbackMessage: _MobileExternalAuthRepositoryBase._genericFailedCode,
      );
      _trackSocialAuthEvent(
        'social_login_failed',
        provider: ExternalAuthProvider.apple,
        status: _classifyMappedFailure(mapped.message),
      );
      throw mapped;
    } catch (error, stackTrace) {
      _logExternalAuthFailure(
        'authenticate_native_apple_unknown',
        error,
        stackTrace,
      );
      _trackSocialAuthEvent(
        'social_login_failed',
        provider: ExternalAuthProvider.apple,
        status: 'provider_failure',
      );
      throw const AppException(
        _MobileExternalAuthRepositoryBase._genericFailedCode,
      );
    }
  }
}
