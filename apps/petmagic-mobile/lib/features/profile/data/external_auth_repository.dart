export 'package:petmagic_mobile/features/profile/application/external_auth_gateway.dart'
    show
        ExternalAuthProvider,
        ExternalAuthRepository,
        externalAuthRepositoryProvider;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/auth/google_sign_in_adapter.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/application/external_auth_gateway.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

final appLinksProvider = Provider<AppLinks>((ref) {
  return AppLinks();
});

final mobileExternalAuthRepositoryProvider = Provider<ExternalAuthRepository>((
  ref,
) {
  return MobileExternalAuthRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    appLinks: ref.watch(appLinksProvider),
    authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
  );
});

void _logExternalAuthFailure(
  String stage,
  Object error,
  StackTrace stackTrace,
) {
  AppLogger.warn(
    feature: 'Profile.ExternalAuth',
    operation: stage,
    message: 'External auth step failed',
    context: {'stage': stage},
    error: error,
    stackTrace: stackTrace,
  );
}

class MobileExternalAuthRepository implements ExternalAuthRepository {
  static const _callbackFailedCode = 'auth.external_callback_failed';
  static const _launchFailedCode = 'auth.external_launch_failed';
  static const _timedOutCode = 'auth.external_timed_out';
  static const _invalidSessionCode = 'auth.external_ticket_invalid';
  static const _genericFailedCode = 'auth.external_invalid';
  static const _cancelledCode = 'auth.external_cancelled';
  MobileExternalAuthRepository({
    required Dio dio,
    required AuthSessionStore sessionStorage,
    required AppLinks appLinks,
    AuthSessionCoordinator? authSessionCoordinator,
    Future<bool> Function(Uri uri, LaunchMode mode)? launchUrlDelegate,
    GoogleSignInAdapter? googleSignInAdapter,
    Future<AuthorizationCredentialAppleID> Function()? appleSignInDelegate,
    Stream<Uri>? uriLinkStream,
  }) : _dio = dio,
       _sessionStorage = sessionStorage,
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage),
       _launchUrl =
           launchUrlDelegate ?? ((uri, mode) => launchUrl(uri, mode: mode)),
       _googleSignInAdapter =
           googleSignInAdapter ?? PluginGoogleSignInAdapter.shared,
       _appleSignIn =
           appleSignInDelegate ??
           (() => SignInWithApple.getAppleIDCredential(
             scopes: const [
               AppleIDAuthorizationScopes.email,
               AppleIDAuthorizationScopes.fullName,
             ],
           )),
       _uriLinkStream = uriLinkStream ?? appLinks.uriLinkStream;

  static final Uri _callbackUri = Uri(
    scheme: AppConfig.deepLinkScheme,
    host: 'auth',
    path: '/external',
  );

  final Dio _dio;
  final AuthSessionStore _sessionStorage;
  final AuthSessionCoordinator _authSessionCoordinator;
  final Future<bool> Function(Uri uri, LaunchMode mode) _launchUrl;
  final GoogleSignInAdapter _googleSignInAdapter;
  final Future<AuthorizationCredentialAppleID> Function() _appleSignIn;
  final Stream<Uri> _uriLinkStream;

  @override
  Future<AuthSession> authenticate(
    ExternalAuthProvider provider, {
    CancelToken? cancelToken,
  }) async {
    if (provider == ExternalAuthProvider.google) {
      return _authenticateWithNativeGoogle(cancelToken: cancelToken);
    }

    return _authenticateWithNativeApple(cancelToken: cancelToken);
  }

  @override
  Future<List<MobileLinkedAccount>> link(
    ExternalAuthProvider provider, {
    CancelToken? cancelToken,
  }) {
    if (provider == ExternalAuthProvider.google) {
      return _linkGoogleNatively(cancelToken: cancelToken);
    }

    return _linkWithBrowserFlow(provider, cancelToken: cancelToken);
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {
    if (provider != ExternalAuthProvider.google) {
      return;
    }

    await _resetGoogleSession();
  }

  Future<AuthSession> _authenticateWithNativeGoogle({
    CancelToken? cancelToken,
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
        throw const AppException(_genericFailedCode);
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
        cancelToken: cancelToken,
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
      await _resetGoogleSession();
      rethrow;
    } on GoogleSignInException catch (error, stackTrace) {
      _logGoogleSignInException(error, stackTrace);
      final mapped = _mapGoogleSignInException(error);
      _trackSocialAuthEvent(
        'social_login_failed',
        provider: ExternalAuthProvider.google,
        status: _classifyGoogleSignInFailure(error),
      );
      await _resetGoogleSession();
      throw mapped;
    } on GoogleSignInConfigurationException catch (error, stackTrace) {
      _logExternalAuthFailure(
        'authenticate_native_google_configuration',
        error,
        stackTrace,
      );
      throw const AppException(_genericFailedCode);
    } on DioException catch (error) {
      await _resetGoogleSession();
      final mapped = _mapDioException(
        error,
        fallbackMessage: _genericFailedCode,
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
      await _resetGoogleSession();
      throw const AppException(_genericFailedCode);
    }
  }

  AppException _mapGoogleSignInException(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.interrupted => const AppException(
        _cancelledCode,
      ),
      _ => const AppException(_genericFailedCode),
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
    AppLogger.warn(
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
    CancelToken? cancelToken,
  }) async {
    try {
      final configResponse = await _dio.get<Map<String, dynamic>>(
        '/api/auth/external/google/mobile-config',
        cancelToken: cancelToken,
      );
      final serverClientId =
          configResponse.data?['serverClientId'] as String? ??
          configResponse.data?['ServerClientId'] as String?;
      if (serverClientId == null || serverClientId.isEmpty) {
        throw const AppException(_genericFailedCode);
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

  Future<AuthSession> _authenticateWithNativeApple({
    CancelToken? cancelToken,
  }) async {
    try {
      final credential = await _appleSignIn();
      final identityToken = credential.identityToken;
      final authorizationCode = credential.authorizationCode;
      if (identityToken == null ||
          identityToken.isEmpty ||
          authorizationCode.isEmpty) {
        throw const AppException(_genericFailedCode);
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/apple',
        data: {
          'identityToken': identityToken,
          'authorizationCode': authorizationCode,
        },
        options: Options(headers: {'X-Client-Platform': 'mobile'}),
        cancelToken: cancelToken,
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
        throw const AppException(_cancelledCode);
      }

      _trackSocialAuthEvent(
        'social_login_failed',
        provider: ExternalAuthProvider.apple,
        status: 'provider_failure',
      );
      throw const AppException(_genericFailedCode);
    } on AppException {
      rethrow;
    } on DioException catch (error) {
      final mapped = _mapDioException(
        error,
        fallbackMessage: _genericFailedCode,
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
      throw const AppException(_genericFailedCode);
    }
  }

  Future<void> _resetGoogleSession() async {
    try {
      await _googleSignInAdapter.disconnect();
    } catch (error, stackTrace) {
      _logExternalAuthFailure('google_disconnect_cleanup', error, stackTrace);
      try {
        await _googleSignInAdapter.signOut();
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
    CancelToken? cancelToken,
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
        throw const AppException(_genericFailedCode);
      }

      final response = await _dio.post<List<dynamic>>(
        '/api/auth/me/linked-accounts/google/native',
        data: {'idToken': idToken},
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      );

      return (response.data ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(MobileLinkedAccount.fromJson)
          .toList(growable: false);
    } on AppException {
      await _resetGoogleSession();
      rethrow;
    } on GoogleSignInException catch (error, stackTrace) {
      _logGoogleSignInException(error, stackTrace);
      await _resetGoogleSession();
      throw _mapGoogleSignInException(error);
    } on GoogleSignInConfigurationException catch (error, stackTrace) {
      _logExternalAuthFailure(
        'link_native_google_configuration',
        error,
        stackTrace,
      );
      await _resetGoogleSession();
      throw const AppException(_genericFailedCode);
    } on DioException catch (error) {
      _logExternalAuthFailure(
        'link_native_google_dio',
        error,
        error.stackTrace,
      );
      await _resetGoogleSession();
      throw _mapDioException(error, fallbackMessage: _genericFailedCode);
    } catch (error, stackTrace) {
      _logExternalAuthFailure('link_native_google_unknown', error, stackTrace);
      await _resetGoogleSession();
      throw const AppException(_genericFailedCode);
    }
  }

  Future<List<MobileLinkedAccount>> _linkWithBrowserFlow(
    ExternalAuthProvider provider, {
    CancelToken? cancelToken,
  }) async {
    final session = await _readAuthorizedSession();
    final prepareResponse = await _dio.post<Map<String, dynamic>>(
      '/api/auth/me/linked-accounts/${provider.apiValue}/prepare',
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken,
    );
    final ticket =
        prepareResponse.data?['ticket'] as String? ??
        prepareResponse.data?['Ticket'] as String?;
    if (ticket == null || ticket.isEmpty) {
      throw const AppException(_invalidSessionCode);
    }

    final completer = Completer<Uri>();
    late final StreamSubscription<Uri> subscription;

    subscription = _uriLinkStream.listen(
      (uri) {
        if (_isExpectedCallback(uri) && !completer.isCompleted) {
          completer.complete(uri);
        }
      },
      onError: (Object _) {
        if (!completer.isCompleted) {
          completer.completeError(const AppException(_callbackFailedCode));
        }
      },
    );

    try {
      final authUri = Uri.parse(_dio.options.baseUrl).replace(
        path: '/api/auth/external/${provider.apiValue}',
        queryParameters: {
          'redirectUri': _callbackUri.toString(),
          'mode': 'link',
          'linkTicket': ticket,
        },
      );

      final launched = await _launchAuthUri(authUri);
      if (!launched) {
        throw const AppException(_launchFailedCode);
      }

      final callbackUri = await _waitForExternalAuthCallback(
        completer.future,
        cancelToken: cancelToken,
      );

      final errorCode = callbackUri.queryParameters['error'];
      if (errorCode != null && errorCode.isNotEmpty) {
        throw AppException(_safeExternalCallbackErrorCode(errorCode));
      }

      if (callbackUri.queryParameters['linked'] != '1') {
        throw const AppException(_genericFailedCode);
      }

      return _fetchLinkedAccounts(cancelToken: cancelToken);
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: _genericFailedCode);
    } finally {
      await subscription.cancel();
    }
  }

  Future<Uri> _waitForExternalAuthCallback(
    Future<Uri> callback, {
    CancelToken? cancelToken,
  }) {
    final timedCallback = callback.timeout(
      const Duration(minutes: 3),
      onTimeout: () => throw const AppException(_timedOutCode),
    );

    if (cancelToken == null) {
      return timedCallback;
    }

    return Future.any<Uri>([
      timedCallback,
      cancelToken.whenCancel.then(
        (_) => throw const RequestCancelledException(),
      ),
    ]);
  }

  bool _isExpectedCallback(Uri uri) {
    return uri.scheme == _callbackUri.scheme &&
        uri.host == _callbackUri.host &&
        uri.path == _callbackUri.path;
  }

  String _safeExternalCallbackErrorCode(String rawCode) {
    final value = rawCode.trim();
    return switch (value) {
      _cancelledCode ||
      _callbackFailedCode ||
      _launchFailedCode ||
      _timedOutCode ||
      _invalidSessionCode ||
      'auth.external_not_configured' ||
      'auth.external_token_invalid' ||
      _genericFailedCode => value,
      _ => _genericFailedCode,
    };
  }

  void _trackSocialAuthEvent(
    String eventName, {
    required ExternalAuthProvider provider,
    required String status,
  }) {
    AppLogger.info(
      feature: 'Profile.ExternalAuth',
      operation: eventName,
      message: eventName,
      context: {
        'event': eventName,
        'provider': provider.apiValue,
        'status': status,
      },
    );
  }

  String _classifyMappedFailure(String code) {
    return switch (code) {
      _cancelledCode => 'user_cancellation',
      'auth.external_token_invalid' ||
      'auth.external_email_not_verified' ||
      _genericFailedCode => 'validation_failure',
      'network.unavailable' ||
      'network.timeout' ||
      'network.cancelled' => 'network_failure',
      _ => 'backend_failure',
    };
  }

  Future<bool> _launchAuthUri(Uri authUri) async {
    bool launchedInApp = false;
    try {
      launchedInApp = await _launchUrl(authUri, LaunchMode.inAppBrowserView);
    } on Object {
      launchedInApp = false;
    }
    if (launchedInApp) {
      return true;
    }

    try {
      return await _launchUrl(authUri, LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  Future<AuthSession> _readAuthorizedSession() async {
    return _authSessionCoordinator.requireValidSession(
      mapError: _mapDioException,
      sessionExpiredMessage: 'auth.session_expired',
    );
  }

  Future<List<MobileLinkedAccount>> _fetchLinkedAccounts({
    CancelToken? cancelToken,
  }) async {
    final session = await _readAuthorizedSession();
    final response = await _dio.get<List<dynamic>>(
      '/api/auth/me/linked-accounts',
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken,
    );

    return (response.data ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(MobileLinkedAccount.fromJson)
        .toList(growable: false);
  }

  AppException _mapDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
    if (CancelToken.isCancel(error)) {
      return const RequestCancelledException();
    }

    if (NetworkErrorMapper.isConnectivityIssue(error)) {
      return NetworkErrorMapper.fromMessage(error, 'network.unavailable');
    }

    final payload = NetworkErrorMapper.parseApiPayload(error);
    final safeMessage = NetworkErrorMapper.safePayloadMessage(payload);
    if (safeMessage != null) {
      return NetworkErrorMapper.fromMessage(error, safeMessage);
    }

    return NetworkErrorMapper.fallback(error, fallbackMessage: fallbackMessage);
  }
}
