import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:url_launcher/url_launcher.dart';

final appLinksProvider = Provider<AppLinks>((ref) {
  return AppLinks();
});

final externalAuthRepositoryProvider = Provider<ExternalAuthRepository>((ref) {
  return MobileExternalAuthRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    appLinks: ref.watch(appLinksProvider),
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
  }) : _dio = dio,
       _sessionStorage = sessionStorage,
       _appLinks = appLinks;

  static final Uri _callbackUri = Uri(
    scheme: 'petmagic',
    host: 'auth',
    path: '/external',
  );

  final Dio _dio;
  final AuthSessionStorage _sessionStorage;
  final AppLinks _appLinks;

  @override
  Future<AuthSession> authenticate(ExternalAuthProvider provider) async {
    if (provider == ExternalAuthProvider.google) {
      try {
        return await _authenticateWithNativeGoogle();
      } on AppException catch (error) {
        if (error.message == _cancelledCode) {
          rethrow;
        }

        return _authenticateWithBrowserFlow(provider);
      } catch (_) {
        return _authenticateWithBrowserFlow(provider);
      }
    }

    return _authenticateWithBrowserFlow(provider);
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

  bool _isExpectedCallback(Uri uri) {
    return uri.scheme == _callbackUri.scheme &&
        uri.host == _callbackUri.host &&
        uri.path == _callbackUri.path;
  }

  Future<bool> _launchAuthUri(Uri authUri) async {
    final launchedInApp = await launchUrl(
      authUri,
      mode: LaunchMode.inAppBrowserView,
    );
    if (launchedInApp) {
      return true;
    }

    return launchUrl(authUri, mode: LaunchMode.externalApplication);
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
          title != null && title.startsWith('auth.') ? title : detail,
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
}
