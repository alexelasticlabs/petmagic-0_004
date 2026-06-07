import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/logging/log_correlation_context.dart';
import 'package:petmagic_mobile/core/network/api_logging_interceptor.dart';

void main() {
  test(
    'adds request and generated correlation ids to outgoing requests',
    () async {
      final adapter = _CapturingHttpClientAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(ApiLoggingInterceptor());

      await dio.get<void>('/wallet?token=secret');

      final options = adapter.capturedOptions;
      final requestId = options.headers['X-Request-ID'] as String?;
      final correlationId = options.headers['X-Correlation-ID'] as String?;

      expect(requestId, isNotNull);
      expect(correlationId, startsWith('flow-'));
      expect(options.extra['request_id'], requestId);
      expect(options.extra['correlation_id'], correlationId);
      expect(options.extra['request_started_utc_ms'], isA<int>());
    },
  );

  test('preserves caller supplied correlation id', () async {
    final adapter = _CapturingHttpClientAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(ApiLoggingInterceptor());

    await dio.post<void>(
      '/templates/generations',
      options: Options(
        headers: const {'X-Correlation-ID': 'generation-flow-1'},
      ),
    );

    final options = adapter.capturedOptions;
    expect(options.headers['X-Correlation-ID'], 'generation-flow-1');
    expect(options.extra['correlation_id'], 'generation-flow-1');
    expect(options.headers['X-Request-ID'], isNotNull);
  });

  test('uses ambient flow correlation id when no header is supplied', () async {
    final adapter = _CapturingHttpClientAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(ApiLoggingInterceptor());

    await LogCorrelationContext.runWithCorrelationId(
      'generation-flow-2',
      () => dio.get<void>('/wallet'),
    );

    final options = adapter.capturedOptions;
    expect(options.headers['X-Correlation-ID'], 'generation-flow-2');
    expect(options.extra['correlation_id'], 'generation-flow-2');
    expect(options.headers['X-Request-ID'], isNotNull);
  });

  test(
    'preserves caller supplied request id in headers and log context',
    () async {
      final adapter = _CapturingHttpClientAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(ApiLoggingInterceptor());

      await dio.get<void>(
        '/templates',
        options: Options(headers: const {'X-Request-ID': 'request-1'}),
      );

      final options = adapter.capturedOptions;
      expect(options.headers['X-Request-ID'], 'request-1');
      expect(options.extra['request_id'], 'request-1');
    },
  );

  test('replaces blank caller supplied request identity headers', () async {
    final adapter = _CapturingHttpClientAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(ApiLoggingInterceptor());

    await dio.get<void>(
      '/templates',
      options: Options(
        headers: const {'X-Request-ID': '   ', 'X-Correlation-ID': ''},
      ),
    );

    final options = adapter.capturedOptions;
    final requestId = options.headers['X-Request-ID'] as String?;
    final correlationId = options.headers['X-Correlation-ID'] as String?;

    expect(requestId, startsWith('m-'));
    expect(correlationId, startsWith('flow-'));
    expect(options.extra['request_id'], requestId);
    expect(options.extra['correlation_id'], correlationId);
  });
}

class _CapturingHttpClientAdapter implements HttpClientAdapter {
  RequestOptions? _capturedOptions;

  RequestOptions get capturedOptions {
    final options = _capturedOptions;
    if (options == null) {
      throw StateError('No request captured.');
    }
    return options;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _capturedOptions = options;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
