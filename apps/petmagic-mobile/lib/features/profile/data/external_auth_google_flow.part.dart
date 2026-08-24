part of 'external_auth_repository.dart';

mixin _ExternalAuthGoogleFlow on _MobileExternalAuthRepositoryBase {
  Future<AuthSession> _authenticateWithNativeGoogle({
    RequestCancellation? cancelToken,
  }) async {
    try {
      final serverClientId = await _resolveGoogleServerClientId(
        cancelToken: cancelToken,
      );
      AppLogger.info(
        feature: 'Profile.ExternalAuth',
        operation: 'google_native_auth_stage',
        message: 'Resolved Google mobile auth config',
        context: {
          'stage': 'mobile_config_loaded',
          'has_server_client_id': serverClientId != null,
          'base_url': _dio.options.baseUrl,
        },
      );

      final account = await _googleSignInAdapter.authenticate(
        serverClientId: serverClientId,
      );
      AppLogger.info(
        feature: 'Profile.ExternalAuth',
        operation: 'google_native_auth_stage',
        message: 'Google account selected',
        context: {
          'stage': 'account_selected',
          'email_present': account.email.isNotEmpty,
        },
      );

      final idToken = account.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AppException(
          _MobileExternalAuthRepositoryBase._genericFailedCode,
        );
      }
      AppLogger.info(
        feature: 'Profile.ExternalAuth',
        operation: 'google_native_auth_stage',
        message: 'Google id token acquired',
        context: {
          'stage': 'id_token_acquired',
          'id_token_length': idToken.length,
        },
      );

      AppLogger.info(
        feature: 'Profile.ExternalAuth',
        operation: 'google_native_auth_stage',
        message: 'Starting backend token exchange',
        context: {
          'stage': 'native_exchange_started',
          'path': '/api/auth/external/google/native',
          'base_url': _dio.options.baseUrl,
        },
      );
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/external/google/native',
        data: {'idToken': idToken},
        options: Options(headers: {'X-Client-Platform': 'mobile'}),
        cancelToken: cancelToken.toDioCancelToken(),
      );

      final session = AuthSession.fromJson(response.data ?? const {});
      await _sessionStorage.save(session);
      _trackSocialAuthEvent(
        'social_login_success',
        provider: ExternalAuthProvider.google,
        status: 'success',
      );
      return session;
    } on AppException catch (error) {
      _trackSocialAuthEvent(
        'social_login_failed',
        provider: ExternalAuthProvider.google,
        status: _classifyMappedFailure(error.message),
      );
      _scheduleGoogleSessionReset();
      rethrow;
    } on GoogleSignInException catch (error, stackTrace) {
      _logGoogleSignInException(error, stackTrace);
      final mapped = _mapGoogleSignInException(error);
      _trackSocialAuthEvent(
        'social_login_failed',
        provider: ExternalAuthProvider.google,
        status: _classifyGoogleSignInFailure(error),
      );
      _scheduleGoogleSessionReset();
      throw mapped;
    } on GoogleSignInConfigurationException catch (error, stackTrace) {
      AppLogger.error(
        feature: 'Profile.ExternalAuth',
        operation: 'authenticate_native_google_configuration',
        message: 'Google sign-in adapter configuration failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw const AppException('auth.external_not_configured');
    } on DioException catch (error) {
      _scheduleGoogleSessionReset();
      final mapped = _mapDioException(
        error,
        fallbackMessage: _MobileExternalAuthRepositoryBase._genericFailedCode,
      );
      _logExternalAuthFailure(
        'authenticate_native_google_dio',
        error,
        error.stackTrace,
      );
      _trackSocialAuthEvent(
        'social_login_failed',
        provider: ExternalAuthProvider.google,
        status: _classifyMappedFailure(mapped.message),
      );
      throw mapped;
    } catch (error, stackTrace) {
      _logExternalAuthFailure(
        'authenticate_native_google_unknown',
        error,
        stackTrace,
      );
      _scheduleGoogleSessionReset();
      throw const AppException(
        _MobileExternalAuthRepositoryBase._genericFailedCode,
      );
    }
  }

  AppException _mapGoogleSignInException(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.interrupted => const AppException(
        _MobileExternalAuthRepositoryBase._cancelledCode,
      ),
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        const AppException('auth.external_not_configured'),
      GoogleSignInExceptionCode.uiUnavailable => const AppException(
        'auth.external_launch_failed',
      ),
      _ => const AppException(
        _MobileExternalAuthRepositoryBase._genericFailedCode,
      ),
    };
  }

  String _classifyGoogleSignInFailure(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.interrupted => 'user_cancellation',
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'configuration_failure',
      GoogleSignInExceptionCode.uiUnavailable => 'provider_unavailable',
      _ => 'provider_failure',
    };
  }

  void _logGoogleSignInException(
    GoogleSignInException error,
    StackTrace stackTrace,
  ) {
    AppLogger.error(
      feature: 'Profile.ExternalAuth',
      operation: 'authenticate_native_google_sign_in',
      message: 'Google sign-in SDK failed',
      context: {
        'code': error.code.name,
        'has_description': error.description?.isNotEmpty ?? false,
        'has_details': error.details != null,
      },
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<String?> _resolveGoogleServerClientId({
    RequestCancellation? cancelToken,
  }) async {
    try {
      final configResponse = await _dio.get<Map<String, dynamic>>(
        '/api/auth/external/google/mobile-config',
        cancelToken: cancelToken.toDioCancelToken(),
      );
      final serverClientId =
          configResponse.data?['serverClientId'] as String? ??
          configResponse.data?['ServerClientId'] as String?;
      if (serverClientId == null || serverClientId.isEmpty) {
        throw const AppException(
          _MobileExternalAuthRepositoryBase._genericFailedCode,
        );
      }

      return serverClientId;
    } on DioException catch (error) {
      _logExternalAuthFailure(
        'resolve_google_mobile_config_dio',
        error,
        error.stackTrace,
      );
      if (_canContinueGoogleWithoutMobileConfig(error)) {
        _trackSocialAuthEvent(
          'google_mobile_config_unavailable',
          provider: ExternalAuthProvider.google,
          status: 'native_sdk_fallback',
        );
        return null;
      }

      rethrow;
    }
  }

  bool _canContinueGoogleWithoutMobileConfig(DioException error) {
    return error.response?.statusCode == 403;
  }

  void _scheduleGoogleSessionReset() {
    unawaited(_resetGoogleSession());
  }

  Future<void> _resetGoogleSession() async {
    try {
      await _googleSignInAdapter.disconnect().timeout(
        const Duration(seconds: 1),
      );
    } catch (error, stackTrace) {
      _logExternalAuthFailure('google_disconnect_cleanup', error, stackTrace);
      try {
        await _googleSignInAdapter.signOut().timeout(
          const Duration(seconds: 1),
        );
      } catch (innerError, innerStackTrace) {
        _logExternalAuthFailure(
          'google_sign_out_cleanup',
          innerError,
          innerStackTrace,
        );
        // Best-effort cleanup only.
      }
    }
  }

  Future<List<MobileLinkedAccount>> _linkGoogleNatively({
    RequestCancellation? cancelToken,
  }) async {
    try {
      final session = await _readAuthorizedSession();
      final serverClientId = await _resolveGoogleServerClientId(
        cancelToken: cancelToken,
      );
      final account = await _googleSignInAdapter.authenticate(
        serverClientId: serverClientId,
      );
      final idToken = account.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AppException(
          _MobileExternalAuthRepositoryBase._genericFailedCode,
        );
      }

      final response = await _dio.post<List<dynamic>>(
        '/api/auth/me/linked-accounts/google/native',
        data: {'idToken': idToken},
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      );

      return (response.data ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(mapMobileLinkedAccountDto)
          .toList(growable: false);
    } on AppException {
      _scheduleGoogleSessionReset();
      rethrow;
    } on GoogleSignInException catch (error, stackTrace) {
      _logGoogleSignInException(error, stackTrace);
      _scheduleGoogleSessionReset();
      throw _mapGoogleSignInException(error);
    } on GoogleSignInConfigurationException catch (error, stackTrace) {
      AppLogger.error(
        feature: 'Profile.ExternalAuth',
        operation: 'link_native_google_configuration',
        message: 'Google link adapter configuration failed',
        error: error,
        stackTrace: stackTrace,
      );
      _scheduleGoogleSessionReset();
      throw const AppException('auth.external_not_configured');
    } on DioException catch (error) {
      _logExternalAuthFailure(
        'link_native_google_dio',
        error,
        error.stackTrace,
      );
      _scheduleGoogleSessionReset();
      throw _mapDioException(
        error,
        fallbackMessage: _MobileExternalAuthRepositoryBase._genericFailedCode,
      );
    } catch (error, stackTrace) {
      _logExternalAuthFailure('link_native_google_unknown', error, stackTrace);
      _scheduleGoogleSessionReset();
      throw const AppException(
        _MobileExternalAuthRepositoryBase._genericFailedCode,
      );
    }
  }
}
