export 'package:petmagic_mobile/features/profile/application/external_auth_gateway.dart'
    show
        ExternalAuthProvider,
        ExternalAuthRepository,
        externalAuthRepositoryProvider;
import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/network/dio_request_cancellation.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/auth/google_sign_in_adapter.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_dto_mapper.dart';
import 'package:petmagic_mobile/features/profile/data/external_browser_link_flow.dart';
import 'package:petmagic_mobile/features/profile/application/external_auth_gateway.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

part 'external_auth_google_flow.part.dart';
part 'external_auth_apple_flow.part.dart';

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

abstract class _MobileExternalAuthRepositoryBase {
  static const _genericFailedCode = 'auth.external_invalid';
  static const _cancelledCode = 'auth.external_cancelled';
  _MobileExternalAuthRepositoryBase({
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
       _googleSignInAdapter =
           googleSignInAdapter ?? PluginGoogleSignInAdapter.shared,
       _appleSignIn =
           appleSignInDelegate ??
           (() => SignInWithApple.getAppleIDCredential(
             scopes: const [
               AppleIDAuthorizationScopes.email,
               AppleIDAuthorizationScopes.fullName,
             ],
           )) {
    _browserLinkFlow = ExternalBrowserLinkFlow(
      dio: dio,
      uriLinkStream: uriLinkStream ?? appLinks.uriLinkStream,
      launchUrl:
          launchUrlDelegate ?? ((uri, mode) => launchUrl(uri, mode: mode)),
      readAuthorizedSession: _readAuthorizedSession,
      mapDioException: _mapDioException,
    );
  }

  final Dio _dio;
  final AuthSessionStore _sessionStorage;
  final AuthSessionCoordinator _authSessionCoordinator;
  final GoogleSignInAdapter _googleSignInAdapter;
  final Future<AuthorizationCredentialAppleID> Function() _appleSignIn;
  late final ExternalBrowserLinkFlow _browserLinkFlow;

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

  Future<AuthSession> _readAuthorizedSession() async {
    return _authSessionCoordinator.requireValidSession(
      mapError: _mapDioException,
      sessionExpiredMessage: 'auth.session_expired',
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

class MobileExternalAuthRepository extends _MobileExternalAuthRepositoryBase
    with _ExternalAuthGoogleFlow, _ExternalAuthAppleFlow
    implements ExternalAuthRepository {
  MobileExternalAuthRepository({
    required super.dio,
    required super.sessionStorage,
    required super.appLinks,
    super.authSessionCoordinator,
    super.launchUrlDelegate,
    super.googleSignInAdapter,
    super.appleSignInDelegate,
    super.uriLinkStream,
  });
  @override
  Future<AuthSession> authenticate(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) async {
    if (provider == ExternalAuthProvider.google) {
      return _authenticateWithNativeGoogle(cancelToken: cancelToken);
    }

    return _authenticateWithNativeApple(cancelToken: cancelToken);
  }

  @override
  Future<List<MobileLinkedAccount>> link(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) {
    if (provider == ExternalAuthProvider.google) {
      return _linkGoogleNatively(cancelToken: cancelToken);
    }

    return _browserLinkFlow.link(provider, cancelToken: cancelToken);
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {
    if (provider != ExternalAuthProvider.google) {
      return;
    }

    await _resetGoogleSession();
  }
}
