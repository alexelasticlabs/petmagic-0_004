import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/network_utils.dart';
import 'package:petmagic_mobile/core/logging/log_correlation_context.dart';
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
        'message': _maskSensitiveValue('message', error.message),
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
      if (key.isEmpty) {
        continue;
      }

      final value = entry.value;
      if (value == null) {
        continue;
      }

      if (_isTransportPayloadKey(key)) {
        sanitized[key] = '***';
        continue;
      }

      if (_isSensitiveKey(key)) {
        sanitized[key] = _maskSensitiveValue(key, value.toString());
        continue;
      }

      if (_isRawUserDataKey(key)) {
        sanitized[key] = '***';
        continue;
      }

      if (_isLocalFilePathKey(key)) {
        sanitized[key] = '***';
        continue;
      }

      if (value is num || value is bool) {
        sanitized[key] = value;
        continue;
      }

      final text = value.toString();
      final masked = _maskSensitiveValue(key, text);
      sanitized[key] = masked.length > 256
          ? '${masked.substring(0, 256)}...'
          : masked;
    }

    return sanitized;
  }

  static String _sanitizeMessage(String value) {
    final masked = _maskSensitiveText(value);
    return masked.length > 512 ? '${masked.substring(0, 512)}...' : masked;
  }

  static String _maskSensitiveValue(String key, String value) {
    if (_isEmailKey(key)) {
      return _maskEmailValue(value);
    }

    if (_isSensitiveKey(key)) {
      return value.startsWith('Bearer ') ? 'Bearer ***' : '***';
    }

    if (_isRawUserDataKey(key)) {
      return '***';
    }

    if (_isLocalFilePathKey(key)) {
      return '***';
    }

    if (_isTransportPayloadKey(key)) {
      return '***';
    }

    final uri = Uri.tryParse(value);
    if (_isEndpointKey(key) && uri != null && uri.hasQuery) {
      return uri.replace(query: '').toString().replaceFirst(RegExp(r'\?$'), '');
    }

    if (uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.hasQuery) {
      return uri.replace(query: '***').toString();
    }

    return _maskSensitiveText(value);
  }

  static bool _isSensitiveKey(String key) {
    final normalizedKey = key.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );

    return normalizedKey.contains('authorization') ||
        normalizedKey.contains('token') ||
        normalizedKey.contains('secret') ||
        normalizedKey.contains('password') ||
        normalizedKey.contains('receipt') ||
        normalizedKey.contains('card') ||
        normalizedKey.contains('cvc') ||
        normalizedKey.contains('cvv') ||
        normalizedKey.contains('phone') ||
        normalizedKey.contains('email') ||
        normalizedKey.contains('signedurl') ||
        normalizedKey == 'ticket' ||
        normalizedKey == 'authticket' ||
        normalizedKey == 'externalauthticket' ||
        normalizedKey == 'sessionid' ||
        normalizedKey == 'checkoutsessionid' ||
        normalizedKey == 'stripesessionid';
  }

  static bool _isEmailKey(String key) {
    final normalizedKey = key.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return normalizedKey.contains('email');
  }

  static bool _isRawUserDataKey(String key) {
    final normalizedKey = key.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );

    return normalizedKey == 'name' ||
        normalizedKey == 'username' ||
        normalizedKey == 'displayname' ||
        normalizedKey == 'fullname' ||
        normalizedKey == 'firstname' ||
        normalizedKey == 'lastname' ||
        normalizedKey == 'sendername' ||
        normalizedKey == 'senderdisplayname' ||
        normalizedKey == 'recipientname' ||
        normalizedKey == 'recipientdisplayname' ||
        normalizedKey == 'contactname' ||
        normalizedKey == 'contactdisplayname' ||
        normalizedKey == 'address' ||
        normalizedKey == 'fulladdress' ||
        normalizedKey == 'streetaddress' ||
        normalizedKey == 'addressline' ||
        normalizedKey == 'addressline1' ||
        normalizedKey == 'addressline2' ||
        normalizedKey == 'city' ||
        normalizedKey == 'country' ||
        normalizedKey == 'region' ||
        normalizedKey == 'province' ||
        normalizedKey == 'postalcode' ||
        normalizedKey == 'zipcode';
  }

  static bool _isEndpointKey(String key) {
    final normalizedKey = key.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return normalizedKey == 'path' ||
        normalizedKey == 'endpoint' ||
        normalizedKey == 'route';
  }

  static bool _isLocalFilePathKey(String key) {
    final normalizedKey = key.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return normalizedKey.contains('filepath') ||
        normalizedKey.contains('localpath') ||
        normalizedKey.contains('sourcepath') ||
        normalizedKey.contains('imagepath') ||
        normalizedKey.contains('videopath') ||
        normalizedKey.contains('avatarpath');
  }

  static bool _isTransportPayloadKey(String key) {
    final normalizedKey = key.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );

    return normalizedKey == 'payload' ||
        normalizedKey == 'rawpayload' ||
        normalizedKey == 'apipayload' ||
        normalizedKey == 'providerpayload' ||
        normalizedKey == 'webhookpayload' ||
        normalizedKey == 'body' ||
        normalizedKey == 'requestbody' ||
        normalizedKey == 'responsebody' ||
        normalizedKey == 'requestdata' ||
        normalizedKey == 'responsedata' ||
        normalizedKey == 'formdata' ||
        normalizedKey == 'headers' ||
        normalizedKey == 'requestheaders' ||
        normalizedKey == 'responseheaders';
  }

  static String _maskEmailValue(String value) {
    final masked = _maskSensitiveText(value);
    return masked == value ? '***' : masked;
  }

  static String _maskSensitiveText(String value) {
    var masked = value;

    masked = masked.replaceAllMapped(
      RegExp(
        r'\bAuthorization\s*[:=]\s*([A-Za-z]+\s+)?[^\s,}\]]+',
        caseSensitive: false,
      ),
      (match) {
        final value = match.group(0)!;
        final separator = value.contains(':') ? ':' : '=';
        return 'Authorization$separator ${value.toLowerCase().contains('bearer') ? 'Bearer ***' : '***'}';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(
        r'''(["'])(authorization|cookie|set[_-]?cookie)\1(\s*[:=]\s*)(["'])(.*?)\4''',
        caseSensitive: false,
      ),
      (match) {
        final keyQuote = match.group(1) ?? '';
        final key = match.group(2) ?? '';
        final separator = match.group(3) ?? ':';
        final valueQuote = match.group(4) ?? '';
        return '$keyQuote$key$keyQuote$separator$valueQuote***$valueQuote';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(
        r'\b(cookie|set[_-]?cookie)\s*[:=]\s*[^\s,}\]]+',
        caseSensitive: false,
      ),
      (match) {
        final value = match.group(0)!;
        final key = value.split(RegExp(r'\s*[:=]\s*')).first;
        final separator = value.contains(':') ? ':' : '=';
        return '$key$separator ***';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(r'\bBearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
      (_) => 'Bearer ***',
    );

    masked = masked.replaceAllMapped(
      RegExp(r'\b[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b'),
      (_) => '***',
    );

    masked = masked.replaceAllMapped(
      RegExp(
        r'''(["']?)(access[_-]?token|refresh[_-]?token|id[_-]?token|auth[_-]?token|api[_-]?key|payment[_-]?intent[_-]?client[_-]?secret|client[_-]?secret|secret|password|receipt|signed[_-]?url|card[_-]?number|cvc|cvv|auth[_-]?ticket|external[_-]?auth[_-]?ticket|ticket|session[_-]?id|checkout[_-]?session[_-]?id|stripe[_-]?session[_-]?id)\1(\s*[:=]\s*)(["']?)[^,}\]\s"']+\4''',
        caseSensitive: false,
      ),
      (match) {
        final quote = match.group(1) ?? '';
        final key = match.group(2) ?? '';
        final separator = match.group(3) ?? ': ';
        final valueQuote = match.group(4) ?? '';
        return '$quote$key$quote$separator$valueQuote***$valueQuote';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(
        r'''(["']?)(user[_-]?name|display[_-]?name|full[_-]?name|first[_-]?name|last[_-]?name|sender[_-]?name|sender[_-]?display[_-]?name|recipient[_-]?name|recipient[_-]?display[_-]?name|contact[_-]?name|contact[_-]?display[_-]?name|address|full[_-]?address|street[_-]?address|address[_-]?line1?|address[_-]?line2|city|country|region|province|postal[_-]?code|zip[_-]?code)\1(\s*[:=]\s*)(["']?)[^,}\]\n"']+\4''',
        caseSensitive: false,
      ),
      (match) {
        final quote = match.group(1) ?? '';
        final key = match.group(2) ?? '';
        final separator = match.group(3) ?? ': ';
        final valueQuote = match.group(4) ?? '';
        return '$quote$key$quote$separator$valueQuote***$valueQuote';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(
        r'''(["']?)(file[_-]?path|local[_-]?path|source[_-]?path|image[_-]?path|video[_-]?path|avatar[_-]?path)\1(\s*[:=]\s*)(["']?)[^,}\]\s"']+\4''',
        caseSensitive: false,
      ),
      (match) {
        final quote = match.group(1) ?? '';
        final key = match.group(2) ?? '';
        final separator = match.group(3) ?? ': ';
        final valueQuote = match.group(4) ?? '';
        return '$quote$key$quote$separator$valueQuote***$valueQuote';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'),
      (match) {
        final email = match.group(0)!;
        final at = email.indexOf('@');
        if (at <= 0) {
          return '***';
        }

        return '${email[0]}***${email.substring(at)}';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(
        r'''(?:file://|/(?:private/)?var/|/data/user/|/storage/emulated/|/sdcard/|/tmp/|[A-Za-z]:\\)[^\s,}\]\)'"]+''',
        caseSensitive: false,
      ),
      (_) => '***',
    );

    masked = masked.replaceAllMapped(
      RegExp(r'https?://[^\s]+[?][^\s]+', caseSensitive: false),
      (match) {
        final uri = Uri.tryParse(match.group(0)!);
        if (uri == null || !uri.hasQuery) {
          return match.group(0)!;
        }

        return uri.replace(query: '***').toString();
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(r'\b(?:sk|rk)_(?:live|test)_[A-Za-z0-9_]+\b'),
      (_) => '***',
    );

    masked = masked.replaceAllMapped(
      RegExp(
        r'\b(?:pi|seti)_[A-Za-z0-9]+_secret_[A-Za-z0-9_]+\b',
        caseSensitive: false,
      ),
      (_) => '***',
    );

    masked = masked.replaceAllMapped(
      RegExp(r'\bek_(?:live|test)_[A-Za-z0-9_]+\b', caseSensitive: false),
      (_) => '***',
    );

    masked = masked.replaceAllMapped(
      RegExp(r'\bcs_(?:live|test)_[A-Za-z0-9_]+\b', caseSensitive: false),
      (_) => '***',
    );

    masked = masked.replaceAllMapped(
      RegExp(r'\b(?:\+?\d[\d\s().-]{7,}\d)\b'),
      (_) => '***',
    );

    return masked;
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
