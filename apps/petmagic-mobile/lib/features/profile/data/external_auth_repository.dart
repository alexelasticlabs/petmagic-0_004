import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:url_launcher/url_launcher.dart';

final appLinksProvider = Provider<AppLinks>((ref) {
  return AppLinks();
});

final externalAuthRepositoryProvider = Provider<ExternalAuthRepository>((ref) {
  return MobileExternalAuthRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    appLinks: ref.watch(appLinksProvider),
    authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
  );
});

enum ExternalAuthProvider {
  google('Google'),
  apple('Apple');

  const ExternalAuthProvider(this.apiValue);

  final String apiValue;
}

abstract class ExternalAuthRepository {
  Future<AuthSession> authenticate(ExternalAuthProvider provider);

  Future<List<MobileLinkedAccount>> link(ExternalAuthProvider provider);

  Future<void> clearSession(ExternalAuthProvider provider);
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
    required AuthSessionStorage sessionStorage,
    required AppLinks appLinks,
    AuthSessionCoordinator? authSessionCoordinator,
    Future<bool> Function(Uri uri, LaunchMode mode)? launchUrlDelegate,
  }) : _dio = dio,
       _sessionStorage = sessionStorage,
       _appLinks = appLinks,
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage),
       _launchUrl =
           launchUrlDelegate ?? ((uri, mode) => launchUrl(uri, mode: mode));

  static final Uri _callbackUri = Uri(
    scheme: 'petmagic',
    host: 'auth',
    path: '/external',
  );

  final Dio _dio;
  final AuthSessionStorage _sessionStorage;
  final AppLinks _appLinks;
  final AuthSessionCoordinator _authSessionCoordinator;
  final Future<bool> Function(Uri uri, LaunchMode mode) _launchUrl;

  @override
  Future<AuthSession> authenticate(ExternalAuthProvider provider) async {
    if (provider == ExternalAuthProvider.google) {
      return _authenticateWithNativeGoogle();
    }

    return _authenticateWithBrowserFlow(provider);
  }

  @override
  Future<List<MobileLinkedAccount>> link(ExternalAuthProvider provider) {
    return _linkWithBrowserFlow(provider);
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {
    if (provider != ExternalAuthProvider.google) {
      return;
    }

    await _resetGoogleSession(GoogleSignIn(scopes: const ['email']));
  }

  Future<AuthSession> _authenticateWithNativeGoogle() async {
    GoogleSignIn? googleSignIn;

    try {
      final configResponse = await _dio.get<Map<String, dynamic>>(
        '/api/auth/external/google/mobile-config',
      );
      final serverClientId =
          configResponse.data?['serverClientId'] as String? ??
          configResponse.data?['ServerClientId'] as String?;
      if (serverClientId == null || serverClientId.isEmpty) {
        throw const AppException(_genericFailedCode);
      }

      googleSignIn = GoogleSignIn(
        scopes: const ['email'],
        serverClientId: serverClientId,
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        throw const AppException(_cancelledCode);
      }

      final authentication = await account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AppException(_genericFailedCode);
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/external/google/native',
        data: {'idToken': idToken},
      );

      final session = AuthSession.fromJson(response.data ?? const {});
      await _sessionStorage.save(session);
      return session;
    } on AppException {
      await _resetGoogleSession(googleSignIn);
      rethrow;
    } on DioException catch (error) {
      await _resetGoogleSession(googleSignIn);
      throw _mapDioException(error, fallbackMessage: _genericFailedCode);
    } catch (_) {
      await _resetGoogleSession(googleSignIn);
      throw const AppException(_genericFailedCode);
    }
  }

  Future<void> _resetGoogleSession(GoogleSignIn? googleSignIn) async {
    if (googleSignIn == null) {
      return;
    }

    try {
      await googleSignIn.disconnect();
    } catch (_) {
      try {
        await googleSignIn.signOut();
      } catch (_) {
        // Best-effort cleanup only.
      }
    }
  }

  Future<AuthSession> _authenticateWithBrowserFlow(
    ExternalAuthProvider provider,
  ) async {
    final completer = Completer<Uri>();
    late final StreamSubscription<Uri> subscription;

    subscription = _appLinks.uriLinkStream.listen(
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
        queryParameters: {'redirectUri': _callbackUri.toString()},
      );

      final launched = await _launchAuthUri(authUri);
      if (!launched) {
        throw const AppException(_launchFailedCode);
      }

      final callbackUri = await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw const AppException(_timedOutCode),
      );

      final errorCode = callbackUri.queryParameters['error'];
      if (errorCode != null && errorCode.isNotEmpty) {
        throw AppException(errorCode);
      }

      final ticket = callbackUri.queryParameters['ticket'];
      if (ticket == null || ticket.isEmpty) {
        throw const AppException(_invalidSessionCode);
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/external/exchange',
        data: {'ticket': ticket},
      );

      final session = AuthSession.fromJson(response.data ?? const {});
      await _sessionStorage.save(session);
      return session;
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: _genericFailedCode);
    } finally {
      await subscription.cancel();
    }
  }

  Future<List<MobileLinkedAccount>> _linkWithBrowserFlow(
    ExternalAuthProvider provider,
  ) async {
    final session = await _readAuthorizedSession();
    final prepareResponse = await _dio.post<Map<String, dynamic>>(
      '/api/auth/me/linked-accounts/${provider.apiValue}/prepare',
      options: Options(
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
        },
      ),
    );
    final ticket =
        prepareResponse.data?['ticket'] as String? ??
        prepareResponse.data?['Ticket'] as String?;
    if (ticket == null || ticket.isEmpty) {
      throw const AppException(_invalidSessionCode);
    }

    final completer = Completer<Uri>();
    late final StreamSubscription<Uri> subscription;

    subscription = _appLinks.uriLinkStream.listen(
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

      final callbackUri = await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw const AppException(_timedOutCode),
      );

      final errorCode = callbackUri.queryParameters['error'];
      if (errorCode != null && errorCode.isNotEmpty) {
        throw AppException(errorCode);
      }

      if (callbackUri.queryParameters['linked'] != '1') {
        throw const AppException(_genericFailedCode);
      }

      return _fetchLinkedAccounts();
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: _genericFailedCode);
    } finally {
      await subscription.cancel();
    }
  }

  bool _isExpectedCallback(Uri uri) {
    return uri.scheme == _callbackUri.scheme &&
        uri.host == _callbackUri.host &&
        uri.path == _callbackUri.path;
  }

  Future<bool> _launchAuthUri(Uri authUri) async {
    final launchedInApp = await _launchUrl(
      authUri,
      LaunchMode.inAppBrowserView,
    );
    if (launchedInApp) {
      return true;
    }

    return _launchUrl(authUri, LaunchMode.externalApplication);
  }

  Future<AuthSession> _readAuthorizedSession() async {
    return _authSessionCoordinator.requireValidSession(
      mapError: _mapDioException,
      sessionExpiredMessage: 'auth.session_expired',
    );
  }

  Future<List<MobileLinkedAccount>> _fetchLinkedAccounts() async {
    final session = await _readAuthorizedSession();
    final response = await _dio.get<List<dynamic>>(
      '/api/auth/me/linked-accounts',
      options: Options(
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
        },
      ),
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
    final payload = NetworkErrorMapper.parseApiPayload(error);
    if (payload.flattened != null) {
      return NetworkErrorMapper.fromMessage(error, payload.flattened!);
    }

    final title = payload.title;
    final detail = payload.detail;
    if (detail != null) {
      return NetworkErrorMapper.fromMessage(
        error,
        title != null && title.startsWith('auth.') ? title : detail,
      );
    }

    if (title != null) {
      return NetworkErrorMapper.fromMessage(error, title);
    }

    return NetworkErrorMapper.fallback(error, fallbackMessage: fallbackMessage);
  }
}
