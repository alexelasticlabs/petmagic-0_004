import 'dart:async';

import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_request_cancellation.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/profile/application/external_auth_gateway.dart';
import 'package:petmagic_mobile/features/profile/data/profile_dto_mapper.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ExternalAuthErrorMapper =
    AppException Function(
      DioException error, {
      required String fallbackMessage,
    });

/// Owns browser OAuth launch and deep-link callback lifecycle for account link.
final class ExternalBrowserLinkFlow {
  ExternalBrowserLinkFlow({
    required Dio dio,
    required Stream<Uri> uriLinkStream,
    required Future<bool> Function(Uri uri, LaunchMode mode) launchUrl,
    required Future<AuthSession> Function() readAuthorizedSession,
    required ExternalAuthErrorMapper mapDioException,
  }) : _dio = dio,
       _uriLinkStream = uriLinkStream,
       _launchUrl = launchUrl,
       _readAuthorizedSession = readAuthorizedSession,
       _mapDioException = mapDioException;

  static const _callbackFailedCode = 'auth.external_callback_failed';
  static const _launchFailedCode = 'auth.external_launch_failed';
  static const _timedOutCode = 'auth.external_timed_out';
  static const _invalidSessionCode = 'auth.external_ticket_invalid';
  static const _genericFailedCode = 'auth.external_invalid';
  static const _cancelledCode = 'auth.external_cancelled';
  static final Uri _callbackUri = Uri(
    scheme: AppConfig.deepLinkScheme,
    host: 'auth',
    path: '/external',
  );

  final Dio _dio;
  final Stream<Uri> _uriLinkStream;
  final Future<bool> Function(Uri uri, LaunchMode mode) _launchUrl;
  final Future<AuthSession> Function() _readAuthorizedSession;
  final ExternalAuthErrorMapper _mapDioException;

  Future<List<MobileLinkedAccount>> link(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) async {
    final session = await _readAuthorizedSession();
    final prepareResponse = await _dio.post<Map<String, dynamic>>(
      '/api/auth/me/linked-accounts/${provider.apiValue}/prepare',
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken.toDioCancelToken(),
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
      if (!await _launchAuthUri(authUri)) {
        throw const AppException(_launchFailedCode);
      }

      final callbackUri = await _waitForCallback(
        completer.future,
        cancelToken: cancelToken,
      );
      final errorCode = callbackUri.queryParameters['error'];
      if (errorCode != null && errorCode.isNotEmpty) {
        throw AppException(_safeCallbackErrorCode(errorCode));
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

  Future<Uri> _waitForCallback(
    Future<Uri> callback, {
    RequestCancellation? cancelToken,
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
      cancelToken.whenCancelled.then(
        (_) => throw const RequestCancelledException(),
      ),
    ]);
  }

  bool _isExpectedCallback(Uri uri) {
    return uri.scheme == _callbackUri.scheme &&
        uri.host == _callbackUri.host &&
        uri.path == _callbackUri.path;
  }

  String _safeCallbackErrorCode(String rawCode) {
    return switch (rawCode.trim()) {
      _cancelledCode ||
      _callbackFailedCode ||
      _launchFailedCode ||
      _timedOutCode ||
      _invalidSessionCode ||
      'auth.external_not_configured' ||
      'auth.external_token_invalid' ||
      _genericFailedCode => rawCode.trim(),
      _ => _genericFailedCode,
    };
  }

  Future<bool> _launchAuthUri(Uri authUri) async {
    try {
      if (await _launchUrl(authUri, LaunchMode.inAppBrowserView)) {
        return true;
      }
    } on Object {
      // Fall back to the external browser below.
    }
    try {
      return await _launchUrl(authUri, LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  Future<List<MobileLinkedAccount>> _fetchLinkedAccounts({
    RequestCancellation? cancelToken,
  }) async {
    final session = await _readAuthorizedSession();
    final response = await _dio.get<List<dynamic>>(
      '/api/auth/me/linked-accounts',
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken.toDioCancelToken(),
    );
    return (response.data ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(mapMobileLinkedAccountDto)
        .toList(growable: false);
  }
}
