import 'dart:math';

import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/logging/log_correlation_context.dart';
import 'package:petmagic_mobile/core/network/request_identity.dart';

class ApiLoggingInterceptor extends Interceptor {
  ApiLoggingInterceptor({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = _resolveOrCreateRequestId(options);
    final correlationId = _resolveOrCreateCorrelationId(options);
    options.extra['request_id'] = requestId;
    options.extra['correlation_id'] = correlationId;
    options.extra['request_started_utc_ms'] = DateTime.now()
        .toUtc()
        .millisecondsSinceEpoch;
    options.headers['X-Request-ID'] = requestId;
    options.headers['X-Correlation-ID'] = correlationId;

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (CancelToken.isCancel(err)) {
      handler.next(err);
      return;
    }

    final requestId = err.requestOptions.extra['request_id']?.toString();
    final correlationId = _correlationId(err.requestOptions);
    final elapsedMs = _elapsedMs(err.requestOptions);
    final traceId = _resolveTraceId(err.response?.headers);

    AppLogger.error(
      feature: 'Network',
      operation: 'request_failed',
      message: 'Network request failed',
      requestId: requestId,
      correlationId: correlationId,
      traceId: traceId,
      error: err.type.name,
      stackTrace: err.stackTrace,
      context: {
        'method': err.requestOptions.method,
        'path': _requestPath(err.requestOptions),
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
    return RequestIdentity.createRequestId(random: _random);
  }

  String _resolveOrCreateRequestId(RequestOptions options) {
    final existingHeader = options.headers['X-Request-ID'];
    if (existingHeader is String && existingHeader.trim().isNotEmpty) {
      return existingHeader.trim();
    }

    final existingExtra = options.extra['request_id'];
    if (existingExtra is String && existingExtra.trim().isNotEmpty) {
      return existingExtra.trim();
    }

    return _createRequestId();
  }

  String _resolveOrCreateCorrelationId(RequestOptions options) {
    final existingHeader = options.headers['X-Correlation-ID'];
    if (existingHeader is String && existingHeader.trim().isNotEmpty) {
      return existingHeader.trim();
    }

    final existingExtra = options.extra['correlation_id'];
    if (existingExtra is String && existingExtra.trim().isNotEmpty) {
      return existingExtra.trim();
    }

    final activeCorrelationId = LogCorrelationContext.currentCorrelationId;
    if (activeCorrelationId != null) {
      return activeCorrelationId;
    }

    return RequestIdentity.createCorrelationId(random: _random);
  }

  String? _correlationId(RequestOptions options) {
    final value =
        options.headers['X-Correlation-ID'] ?? options.extra['correlation_id'];
    return value is String && value.isNotEmpty ? value : null;
  }

  String _requestPath(RequestOptions options) {
    if (options.path.isNotEmpty) {
      return _stripQuery(options.path);
    }

    return _stripQuery(options.uri.path);
  }

  String _stripQuery(String value) {
    final queryIndex = value.indexOf('?');
    if (queryIndex < 0) {
      return value;
    }

    return value.substring(0, queryIndex);
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
}
