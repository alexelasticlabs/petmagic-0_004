import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';

void main() {
  test('parseApiPayload flattens validation errors and keeps detail/title', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/test'),
      response: Response<Map<String, Object?>>(
        requestOptions: RequestOptions(path: '/api/test'),
        statusCode: 400,
        data: const {
          'errors': {
            'email': ['Invalid email'],
            'password': ['Too short'],
          },
          'detail': 'Validation failed.',
          'title': 'Bad Request',
        },
      ),
    );

    final payload = NetworkErrorMapper.parseApiPayload(error);

    expect(payload.flattened, 'Invalid email Too short');
    expect(payload.detail, 'Validation failed.');
    expect(payload.title, 'Bad Request');
  });

  test('isConnectionUnavailable detects only connection issues', () {
    final connectionError = DioException(
      requestOptions: RequestOptions(path: '/api/test'),
      type: DioExceptionType.connectionError,
    );
    final receiveTimeout = DioException(
      requestOptions: RequestOptions(path: '/api/test'),
      type: DioExceptionType.receiveTimeout,
    );

    expect(NetworkErrorMapper.isConnectionUnavailable(connectionError), isTrue);
    expect(NetworkErrorMapper.isConnectionUnavailable(receiveTimeout), isFalse);
  });

  test('connectivity mapping does not hide non-network unknown errors', () {
    final requestOptions = RequestOptions(path: '/api/test');
    final unknownTypeError = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.unknown,
      error: const FormatException('invalid response shape'),
    );
    final socketError = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.unknown,
      error: const SocketException('connection reset'),
    );

    expect(NetworkErrorMapper.isConnectivityIssue(unknownTypeError), isFalse);
    expect(NetworkErrorMapper.isConnectivityIssue(socketError), isTrue);
  });

  test('safePayloadMessage accepts only localization keys', () {
    const payload = ApiErrorPayload(
      flattened: 'https://signed.example/file.jpg?signature=secret',
      detail: 'Validation failed for /tmp/petmagic/avatar.jpg',
      title: 'profile.action_failed',
    );

    expect(
      NetworkErrorMapper.safePayloadMessage(payload),
      'profile.action_failed',
    );
    expect(NetworkErrorMapper.isSafeMessageKey('auth.session_expired'), isTrue);
    expect(NetworkErrorMapper.isSafeMessageKey('Validation failed.'), isFalse);
    expect(
      NetworkErrorMapper.isSafeMessageKey(
        'https://signed.example/file.jpg?signature=secret',
      ),
      isFalse,
    );
  });

  test('safePayloadMessage prefers validation error localization keys', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/auth/register'),
      response: Response<Map<String, Object?>>(
        requestOptions: RequestOptions(path: '/api/auth/register'),
        statusCode: 400,
        data: const {
          'title': 'One or more validation errors occurred.',
          'errors': {
            'Password': ['auth.password_policy_invalid'],
          },
        },
      ),
    );

    final payload = NetworkErrorMapper.parseApiPayload(error);

    expect(payload.validationMessageKey, 'auth.password_policy_invalid');
    expect(
      NetworkErrorMapper.safePayloadMessage(payload),
      'auth.password_policy_invalid',
    );
  });

  test('fallback keeps status code and can skip cause', () {
    final error = DioException.badResponse(
      statusCode: 503,
      requestOptions: RequestOptions(path: '/api/test'),
      response: Response<Map<String, Object?>>(
        requestOptions: RequestOptions(path: '/api/test'),
        statusCode: 503,
        data: const {'title': 'Service unavailable'},
      ),
    );

    final mapped = NetworkErrorMapper.fallback(
      error,
      fallbackMessage: 'fallback.message',
      includeCause: false,
    );

    expect(mapped.message, 'fallback.message');
    expect(mapped.statusCode, 503);
    expect(mapped.cause, isNull);
  });
}
