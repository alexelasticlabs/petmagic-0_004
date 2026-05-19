import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

      final launched = await launchUrl(
        authUri,
        mode: LaunchMode.externalApplication,
      );
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
      throw _mapDioException(
        error,
        fallbackMessage: _genericFailedCode,
      );
    } finally {
      await subscription.cancel();
    }
  }

  bool _isExpectedCallback(Uri uri) {
    return uri.scheme == _callbackUri.scheme &&
        uri.host == _callbackUri.host &&
        uri.path == _callbackUri.path;
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
