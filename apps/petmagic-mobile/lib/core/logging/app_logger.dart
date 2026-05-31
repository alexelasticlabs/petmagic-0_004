import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void debug({
    required String feature,
    required String operation,
    String message = '',
    String? requestId,
    String? traceId,
    Map<String, Object?> context = const {},
  }) {
    _log(
      level: 500,
      feature: feature,
      operation: operation,
      message: message,
      requestId: requestId,
      traceId: traceId,
      context: context,
    );
  }

  static void info({
    required String feature,
    required String operation,
    String message = '',
    String? requestId,
    String? traceId,
    Map<String, Object?> context = const {},
  }) {
    _log(
      level: 800,
      feature: feature,
      operation: operation,
      message: message,
      requestId: requestId,
      traceId: traceId,
      context: context,
    );
  }

  static void warn({
    required String feature,
    required String operation,
    String message = '',
    String? requestId,
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
    String? traceId,
    Map<String, Object?> context = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      level: 1000,
      feature: feature,
      operation: operation,
      message: message,
      requestId: requestId,
      traceId: traceId,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void _log({
    required int level,
    required String feature,
    required String operation,
    required String message,
    String? requestId,
    String? traceId,
    Map<String, Object?> context = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode && level < 800) {
      return;
    }

    final payload = <String, Object>{
      'feature': feature,
      'operation': operation,
      if (requestId != null && requestId.isNotEmpty) 'request_id': requestId,
      if (traceId != null && traceId.isNotEmpty) 'trace_id': traceId,
      ..._sanitizeContext(context),
    };

    final contextSuffix = payload.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    final resolvedMessage = message.isEmpty
        ? contextSuffix
        : '$message${contextSuffix.isEmpty ? '' : ' | $contextSuffix'}';

    developer.log(
      resolvedMessage,
      name: 'PetMagic.$feature',
      level: level,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static Map<String, Object> _sanitizeContext(Map<String, Object?> context) {
    final sanitized = <String, Object>{};
    for (final entry in context.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }

      final value = entry.value;
      if (value == null) {
        continue;
      }

      if (value is num || value is bool) {
        sanitized[key] = value;
        continue;
      }

      final text = value.toString();
      sanitized[key] = text.length > 256
          ? '${text.substring(0, 256)}...'
          : text;
    }

    return sanitized;
  }
}
