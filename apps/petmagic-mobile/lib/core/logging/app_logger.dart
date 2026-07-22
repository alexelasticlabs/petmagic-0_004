import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_crash_reporter.dart';
import 'package:petmagic_mobile/core/logging/log_correlation_context.dart';
import 'package:petmagic_mobile/core/logging/log_field_policy.dart';
import 'package:petmagic_mobile/core/logging/log_text_sanitizer.dart';
import 'package:petmagic_mobile/core/network/network_utils.dart';
import 'package:petmagic_mobile/core/network/request_identity.dart';

class AppLogger {
  const AppLogger._();

  static void debug({
    required String feature,
    required String operation,
    String message = '',
    String? requestId,
    String? correlationId,
    String? traceId,
    Map<String, Object?> context = const {},
  }) {
    _log(
      level: 500,
      feature: feature,
      operation: operation,
      message: message,
      requestId: requestId,
      correlationId: correlationId,
      traceId: traceId,
      context: context,
    );
  }

  static void info({
    required String feature,
    required String operation,
    String message = '',
    String? requestId,
    String? correlationId,
    String? traceId,
    Map<String, Object?> context = const {},
  }) {
    _log(
      level: 800,
      feature: feature,
      operation: operation,
      message: message,
      requestId: requestId,
      correlationId: correlationId,
      traceId: traceId,
      context: context,
    );
  }

  static void warn({
    required String feature,
    required String operation,
    String message = '',
    String? requestId,
    String? correlationId,
    String? traceId,
    Map<String, Object?> context = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      level: 900,
      feature: feature,
      operation: operation,
      message: message,
      requestId: requestId,
      correlationId: correlationId,
      traceId: traceId,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error({
    required String feature,
    required String operation,
    String message = '',
    String? requestId,
    String? correlationId,
    String? traceId,
    Map<String, Object?> context = const {},
    Object? error,
    StackTrace? stackTrace,
    bool reportToCrashlytics = true,
  }) {
    _log(
      level: 1000,
      feature: feature,
      operation: operation,
      message: message,
      requestId: requestId,
      correlationId: correlationId,
      traceId: traceId,
      context: context,
      error: error,
      stackTrace: stackTrace,
      reportToCrashlytics: reportToCrashlytics,
    );
  }

  static void _log({
    required int level,
    required String feature,
    required String operation,
    required String message,
    String? requestId,
    String? correlationId,
    String? traceId,
    Map<String, Object?> context = const {},
    Object? error,
    StackTrace? stackTrace,
    bool reportToCrashlytics = true,
  }) {
    if (!kDebugMode && level < 800) {
      return;
    }

    final payload = _buildPayload(
      feature: feature,
      operation: operation,
      requestId: requestId,
      correlationId: _resolveCorrelationId(correlationId),
      traceId: traceId,
      context: context,
    );
    final contextSuffix = payload.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    final safeMessage = _sanitizeMessage(message);
    final resolvedMessage = safeMessage.isEmpty
        ? contextSuffix
        : '$safeMessage${contextSuffix.isEmpty ? '' : ' | $contextSuffix'}';

    developer.log(
      resolvedMessage,
      name: 'PetMagic.$feature',
      level: level,
      error: _sanitizeError(error),
      stackTrace: kDebugMode ? stackTrace : null,
    );

    if (level >= 1000 && reportToCrashlytics) {
      AppCrashReporter.recordNonFatal(
        errorType: error?.runtimeType.toString() ?? 'LoggedError',
        reason: '$feature.$operation',
        message: resolvedMessage,
        context: payload,
        stackTrace: stackTrace,
      );
    }
  }

  static Map<String, Object> _buildPayload({
    required String feature,
    required String operation,
    String? requestId,
    String? correlationId,
    String? traceId,
    Map<String, Object?> context = const {},
  }) {
    final resolvedCorrelationId = _resolveCorrelationId(correlationId);
    return <String, Object>{
      'feature': feature,
      'operation': operation,
      if (requestId != null && requestId.isNotEmpty) 'request_id': requestId,
      'correlation_id': ?resolvedCorrelationId,
      if (traceId != null && traceId.isNotEmpty) 'trace_id': traceId,
      ..._sanitizeContext(context),
    };
  }

  static String? _resolveCorrelationId(String? correlationId) {
    final explicit = correlationId?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    return LogCorrelationContext.currentCorrelationId ??
        RequestIdentity.createCorrelationId();
  }

  static Object? _sanitizeError(Object? error) {
    if (error == null) {
      return null;
    }
    if (error is AppException) {
      return {
        'type': error.runtimeType.toString(),
        'message': LogTextSanitizer.normalize(
          _maskSensitiveValue('message', error.message),
        ),
        if (error.statusCode != null) 'status_code': error.statusCode!,
      };
    }
    if (error is DioException) {
      final responseStatusCode = error.response?.statusCode;
      return {
        'type': error.runtimeType.toString(),
        'dio_type': error.type.name,
        'method': error.requestOptions.method,
        'path': _requestPath(error.requestOptions),
        'status_code': ?responseStatusCode,
      };
    }
    return {'type': error.runtimeType.toString()};
  }

  static String _requestPath(RequestOptions options) {
    if (options.path.isNotEmpty) {
      return stripQuery(options.path);
    }
    return stripQuery(options.uri.path);
  }

  static Map<String, Object> _sanitizeContext(Map<String, Object?> context) {
    final sanitized = <String, Object>{};
    for (final entry in context.entries) {
      final key = entry.key.trim();
      final value = entry.value;
      if (key.isEmpty || value == null) {
        continue;
      }
      if (LogFieldPolicy.isTransportPayload(key)) {
        sanitized[key] = '***';
        continue;
      }
      if (LogFieldPolicy.isSensitive(key)) {
        sanitized[key] = _maskSensitiveValue(key, value.toString());
        continue;
      }
      if (LogFieldPolicy.isStableIdentifier(key) ||
          LogFieldPolicy.isRawUserData(key) ||
          LogFieldPolicy.isUserFileName(key) ||
          LogFieldPolicy.isLocalFilePath(key)) {
        sanitized[key] = '***';
        continue;
      }
      if (value is num || value is bool) {
        sanitized[key] = value;
        continue;
      }
      final masked = LogTextSanitizer.normalize(
        _maskSensitiveValue(key, value.toString()),
      );
      sanitized[key] = masked.length > 256
          ? '${masked.substring(0, 256)}...'
          : masked;
    }
    return sanitized;
  }

  static String _sanitizeMessage(String value) {
    final masked = LogTextSanitizer.normalize(
      LogTextSanitizer.maskSensitiveText(value),
    );
    return masked.length > 512 ? '${masked.substring(0, 512)}...' : masked;
  }

  static String _maskSensitiveValue(String key, String value) {
    if (LogFieldPolicy.isEmail(key)) {
      final masked = LogTextSanitizer.maskSensitiveText(value);
      return masked == value ? '***' : masked;
    }
    if (LogFieldPolicy.isRemoteMediaUrl(key)) {
      return LogTextSanitizer.maskRemoteMediaUrl(value);
    }
    if (LogFieldPolicy.isSensitiveNavigationUrl(key)) {
      return '***';
    }
    if (LogFieldPolicy.isSensitive(key)) {
      return value.startsWith('Bearer ') ? 'Bearer ***' : '***';
    }
    if (LogFieldPolicy.isStableIdentifier(key) ||
        LogFieldPolicy.isRawUserData(key) ||
        LogFieldPolicy.isLocalFilePath(key) ||
        LogFieldPolicy.isTransportPayload(key)) {
      return '***';
    }

    final uri = Uri.tryParse(value);
    if (LogFieldPolicy.isEndpoint(key) && uri != null) {
      if (LogTextSanitizer.isHttpUrl(uri)) {
        return LogTextSanitizer.stripUrlCredentialsQueryAndFragment(uri);
      }
      if (uri.hasQuery || uri.hasFragment) {
        return value.split(RegExp(r'[?#]')).first;
      }
    }
    if (uri != null &&
        LogTextSanitizer.isHttpUrl(uri) &&
        uri.userInfo.isNotEmpty) {
      return LogTextSanitizer.stripUrlCredentialsQueryAndFragment(uri);
    }
    if (uri != null &&
        LogTextSanitizer.isHttpUrl(uri) &&
        (uri.hasQuery || uri.hasFragment)) {
      return LogTextSanitizer.maskUrlQueryAndFragment(uri);
    }
    return LogTextSanitizer.maskSensitiveText(value);
  }

  @visibleForTesting
  static Map<String, Object> sanitizeContextForTesting(
    Map<String, Object?> context,
  ) {
    return _sanitizeContext(context);
  }

  @visibleForTesting
  static Object? sanitizeErrorForTesting(Object? error) {
    return _sanitizeError(error);
  }

  @visibleForTesting
  static String sanitizeMessageForTesting(String message) {
    return _sanitizeMessage(message);
  }

  @visibleForTesting
  static Map<String, Object> buildPayloadForTesting({
    required String feature,
    required String operation,
    String? requestId,
    String? correlationId,
    String? traceId,
    Map<String, Object?> context = const {},
  }) {
    return _buildPayload(
      feature: feature,
      operation: operation,
      requestId: requestId,
      correlationId: correlationId,
      traceId: traceId,
      context: context,
    );
  }
}
