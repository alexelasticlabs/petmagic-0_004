import 'dart:math';

import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';

class ApiLoggingInterceptor extends Interceptor {
  ApiLoggingInterceptor({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = _createRequestId();
    options.extra['request_id'] = requestId;
    options.extra['request_started_utc_ms'] = DateTime.now()
        .toUtc()
        .millisecondsSinceEpoch;
    options.headers.putIfAbsent('X-Request-ID', () => requestId);

    AppLogger.debug(
      feature: 'Network',
      operation: 'request_started',
      requestId: requestId,
      context: {
        'method': options.method,
        'path': options.path,
        'query_keys': options.queryParameters.keys.join(','),
        'payload_type': _payloadType(options.data),
        'payload_size': _payloadSize(options.data),
      },
    );

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final requestId = response.requestOptions.extra['request_id']?.toString();
    final elapsedMs = _elapsedMs(response.requestOptions);
    final traceId = _resolveTraceId(response.headers);

    AppLogger.info(
      feature: 'Network',
      operation: 'response_completed',
      requestId: requestId,
      traceId: traceId,
      context: {
        'method': response.requestOptions.method,
        'path': response.requestOptions.path,
        'status': response.statusCode ?? 0,
        'duration_ms': elapsedMs,
      },
    );

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestId = err.requestOptions.extra['request_id']?.toString();
    final elapsedMs = _elapsedMs(err.requestOptions);
    final traceId = _resolveTraceId(err.response?.headers);

    AppLogger.error(
      feature: 'Network',
      operation: 'request_failed',
      message: 'Network request failed',
      requestId: requestId,
      traceId: traceId,
      error: err,
      stackTrace: err.stackTrace,
      context: {
        'method': err.requestOptions.method,
        'path': err.requestOptions.path,
        'status': err.response?.statusCode ?? 0,
        'duration_ms': elapsedMs,
        'error_type': err.type.name,
      },
    );

    handler.next(err);
  }

  int _elapsedMs(RequestOptions requestOptions) {
    final startedAt = requestOptions.extra['request_started_utc_ms'];
    if (startedAt is! int) {
      return 0;
    }

    return DateTime.now().toUtc().millisecondsSinceEpoch - startedAt;
  }

  String _createRequestId() {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final suffix = _random.nextInt(1 << 20).toRadixString(16).padLeft(5, '0');
    return 'm-$now-$suffix';
  }

  String? _resolveTraceId(Headers? headers) {
    if (headers == null) {
      return null;
    }

    final fromResponse =
        headers.value('x-trace-id') ?? headers.value('trace-id');
    if (fromResponse != null && fromResponse.isNotEmpty) {
      return fromResponse;
    }

    final traceParent = headers.value('traceparent');
    if (traceParent == null || traceParent.isEmpty) {
      return null;
    }

    final parts = traceParent.split('-');
    if (parts.length < 2) {
      return null;
    }

    return parts[1];
  }

  String _payloadType(Object? payload) {
    if (payload == null) {
      return 'none';
    }
    if (payload is Map<String, dynamic>) {
      return 'map';
    }
    if (payload is List) {
      return 'list';
    }
    return payload.runtimeType.toString();
  }

  int _payloadSize(Object? payload) {
    if (payload == null) {
      return 0;
    }
    if (payload is Map) {
      return payload.length;
    }
    if (payload is List) {
      return payload.length;
    }
    return payload.toString().length;
  }
}
