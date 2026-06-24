import 'dart:math';

import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/logging/log_correlation_context.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/network_utils.dart';
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
    final response = err.response;

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
        'origin': _requestOrigin(err.requestOptions),
        'status': response?.statusCode ?? 0,
        'duration_ms': elapsedMs,
        'error_type': err.type.name,
        'anonymous_request':
            err.requestOptions.extra[anonymousRequestExtraKey] == true,
        'authorization_present': _hasAuthorizationHeader(err.requestOptions),
        'response_content_type': _headerValue(
          response?.headers,
          Headers.contentTypeHeader,
        ),
        'response_server': _headerValue(response?.headers, 'server'),
        'response_via': _headerValue(response?.headers, 'via'),
        'response_cf_ray': _headerValue(response?.headers, 'cf-ray'),
        'response_ngrok': _headerValue(response?.headers, 'ngrok-trace-id'),
        'problem_title': _problemString(response?.data, 'title'),
        'problem_detail': _problemString(response?.data, 'detail'),
        'validation_fields': _validationFields(response?.data),
        'validation_keys': _validationKeys(response?.data),
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
      return stripQuery(options.path);
    }

    return stripQuery(options.uri.path);
  }

  String _requestOrigin(RequestOptions options) {
    final uri = options.uri;
    if (uri.hasScheme && uri.hasAuthority) {
      return uri.origin;
    }

    final baseUrl = options.baseUrl.trim();
    if (baseUrl.isEmpty) {
      return 'unknown';
    }

    final parsed = Uri.tryParse(baseUrl);
    if (parsed != null && parsed.hasScheme && parsed.hasAuthority) {
      return parsed.origin;
    }

    return baseUrl;
  }

  bool _hasAuthorizationHeader(RequestOptions options) {
    return options.headers.keys.any(
      (key) => key.toLowerCase() == 'authorization',
    );
  }

  String? _headerValue(Headers? headers, String name) {
    final value = headers?.value(name)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? _problemString(Object? data, String key) {
    if (data is! Map) {
      return null;
    }

    final value = data[key];
    if (value is! String) {
      return null;
    }

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _validationFields(Object? data) {
    final errors = _validationErrors(data);
    if (errors == null || errors.isEmpty) {
      return null;
    }

    return errors.keys
        .map((key) => key.toString().trim())
        .where((key) => key.isNotEmpty)
        .take(12)
        .join(',');
  }

  String? _validationKeys(Object? data) {
    final errors = _validationErrors(data);
    if (errors == null || errors.isEmpty) {
      return null;
    }

    final keys = <String>{};
    for (final value in errors.values) {
      if (value is! List) {
        continue;
      }

      for (final message in value.whereType<String>()) {
        final trimmed = message.trim();
        if (NetworkErrorMapper.isSafeMessageKey(trimmed)) {
          keys.add(trimmed);
        }
      }
    }

    return keys.isEmpty ? null : keys.take(12).join(',');
  }

  Map? _validationErrors(Object? data) {
    if (data is! Map) {
      return null;
    }

    final errors = data['errors'];
    return errors is Map ? errors : null;
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
