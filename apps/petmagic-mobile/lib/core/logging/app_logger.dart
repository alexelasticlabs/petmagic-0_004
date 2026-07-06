import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
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
        'message': _normalizeLogText(
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

      if (_isStableIdentifierKey(key)) {
        sanitized[key] = '***';
        continue;
      }

      if (_isRawUserDataKey(key)) {
        sanitized[key] = '***';
        continue;
      }

      if (_isUserFileNameKey(key)) {
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
      final masked = _normalizeLogText(_maskSensitiveValue(key, text));
      sanitized[key] = masked.length > 256
          ? '${masked.substring(0, 256)}...'
          : masked;
    }

    return sanitized;
  }

  static String _sanitizeMessage(String value) {
    final masked = _normalizeLogText(_maskSensitiveText(value));
    return masked.length > 512 ? '${masked.substring(0, 512)}...' : masked;
  }

  static String _maskSensitiveValue(String key, String value) {
    if (_isEmailKey(key)) {
      return _maskEmailValue(value);
    }

    if (_isRemoteMediaUrlKey(key)) {
      return _maskRemoteMediaUrl(value);
    }

    if (_isSensitiveNavigationUrlKey(key)) {
      return '***';
    }

    if (_isSensitiveKey(key)) {
      return value.startsWith('Bearer ') ? 'Bearer ***' : '***';
    }

    if (_isStableIdentifierKey(key)) {
      return '***';
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
    if (_isEndpointKey(key) && uri != null) {
      if (_isHttpUrl(uri)) {
        return _stripUrlCredentialsQueryAndFragment(uri);
      }

      if (uri.hasQuery || uri.hasFragment) {
        return value.split(RegExp(r'[?#]')).first;
      }
    }

    if (uri != null && _isHttpUrl(uri) && uri.userInfo.isNotEmpty) {
      return _stripUrlCredentialsQueryAndFragment(uri);
    }

    if (uri != null && _isHttpUrl(uri) && (uri.hasQuery || uri.hasFragment)) {
      return _maskUrlQueryAndFragment(uri);
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
        normalizedKey.contains('jwt') ||
        normalizedKey.contains('cookie') ||
        normalizedKey.contains('credential') ||
        normalizedKey.contains('signature') ||
        normalizedKey.contains('secret') ||
        normalizedKey.contains('verificationdata') ||
        normalizedKey.contains('password') ||
        normalizedKey.contains('receipt') ||
        normalizedKey.contains('card') ||
        normalizedKey.contains('cvc') ||
        normalizedKey.contains('cvv') ||
        normalizedKey.contains('phone') ||
        normalizedKey.contains('email') ||
        normalizedKey.contains('signedurl') ||
        _isSensitiveNavigationUrlKey(key) ||
        normalizedKey == 'ticket' ||
        normalizedKey == 'authticket' ||
        normalizedKey == 'externalauthticket' ||
        normalizedKey == 'sessionid' ||
        normalizedKey == 'checkoutsessionid' ||
        normalizedKey == 'stripesessionid' ||
        normalizedKey == 'purchasetoken' ||
        normalizedKey == 'purchaseid' ||
        normalizedKey == 'paymentintentid' ||
        normalizedKey == 'setupintentid' ||
        normalizedKey == 'customerid' ||
        normalizedKey == 'subscriptionid' ||
        normalizedKey == 'externalpaymentid' ||
        normalizedKey == 'externalsubscriptionid' ||
        normalizedKey == 'signedtransactioninfo';
  }

  static bool _isStableIdentifierKey(String key) {
    final normalizedKey = key.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );

    return normalizedKey == 'userid' ||
        normalizedKey == 'profileuserid' ||
        normalizedKey == 'owneruserid' ||
        normalizedKey == 'subjectid' ||
        normalizedKey == 'accountid' ||
        normalizedKey == 'accountscope' ||
        normalizedKey == 'userscope' ||
        normalizedKey == 'scope' ||
        normalizedKey == 'petid' ||
        normalizedKey == 'petphotoid' ||
        normalizedKey == 'generationid' ||
        normalizedKey == 'templateid' ||
        normalizedKey == 'assignmentid' ||
        normalizedKey == 'conversationid' ||
        normalizedKey == 'messageid' ||
        normalizedKey == 'ticketid' ||
        normalizedKey == 'attachmentid' ||
        normalizedKey == 'feedbackid' ||
        normalizedKey == 'reportid' ||
        normalizedKey == 'moderationid' ||
        normalizedKey == 'orderid' ||
        _isCompoundStableDomainIdentifierKey(normalizedKey);
  }

  static bool _isCompoundStableDomainIdentifierKey(String normalizedKey) {
    if (normalizedKey == 'requestid' ||
        normalizedKey == 'correlationid' ||
        normalizedKey == 'traceid') {
      return false;
    }

    return (normalizedKey.contains('user') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('account') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('pet') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('generation') &&
            normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('template') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('assignment') &&
            normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('conversation') &&
            normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('message') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('ticket') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('attachment') &&
            normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('purchase') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('subscription') &&
            normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('feedback') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('report') && normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('moderation') &&
            normalizedKey.endsWith('id')) ||
        (normalizedKey.contains('order') && normalizedKey.endsWith('id')) ||
        _isCompoundStableDomainIdentifierListKey(normalizedKey);
  }

  static bool _isCompoundStableDomainIdentifierListKey(String normalizedKey) {
    if (normalizedKey == 'requestids' ||
        normalizedKey == 'correlationids' ||
        normalizedKey == 'traceids') {
      return false;
    }

    return (normalizedKey.contains('user') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('account') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('pet') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('generation') &&
            normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('template') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('assignment') &&
            normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('conversation') &&
            normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('message') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('ticket') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('attachment') &&
            normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('purchase') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('subscription') &&
            normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('feedback') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('report') && normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('moderation') &&
            normalizedKey.endsWith('ids')) ||
        (normalizedKey.contains('order') && normalizedKey.endsWith('ids'));
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

  static bool _isUserFileNameKey(String key) {
    final normalizedKey = key.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );

    return normalizedKey == 'filename' ||
        normalizedKey == 'filenames' ||
        normalizedKey.endsWith('filename') ||
        normalizedKey.endsWith('filenames');
  }

  static bool _isEndpointKey(String key) {
    final normalizedKey = key.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return normalizedKey == 'path' ||
        normalizedKey == 'endpoint' ||
        normalizedKey == 'route' ||
        normalizedKey == 'baseurl' ||
        normalizedKey == 'apiurl' ||
        normalizedKey == 'apibaseurl' ||
        normalizedKey == 'publicbaseurl';
  }

  static bool _isRemoteMediaUrlKey(String key) {
    final normalizedKey = key.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return normalizedKey == 'attachmenturl' ||
        normalizedKey == 'attachmenturls' ||
        normalizedKey == 'fileurl' ||
        normalizedKey == 'fileurls' ||
        normalizedKey == 'mediaurl' ||
        normalizedKey == 'mediaurls' ||
        normalizedKey == 'imageurl' ||
        normalizedKey == 'imageurls' ||
        normalizedKey == 'videourl' ||
        normalizedKey == 'videourls' ||
        normalizedKey == 'avatarurl' ||
        normalizedKey == 'avatarurls' ||
        normalizedKey == 'thumbnailurl' ||
        normalizedKey == 'thumbnailurls' ||
        normalizedKey == 'previewurl' ||
        normalizedKey == 'previewurls' ||
        normalizedKey == 'outputurl' ||
        normalizedKey == 'outputurls' ||
        normalizedKey == 'downloadurl' ||
        normalizedKey == 'downloadurls' ||
        normalizedKey == 'uploadurl' ||
        normalizedKey == 'uploadurls';
  }

  static bool _isSensitiveNavigationUrlKey(String key) {
    final normalizedKey = key.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return normalizedKey == 'checkouturl' ||
        normalizedKey == 'paymenturl' ||
        normalizedKey == 'billingportalurl' ||
        normalizedKey == 'customerportalurl' ||
        normalizedKey == 'redirecturl' ||
        normalizedKey == 'callbackurl' ||
        normalizedKey == 'returnurl' ||
        normalizedKey == 'successurl' ||
        normalizedKey == 'cancelurl';
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
        normalizedKey == 'verificationdata' ||
        normalizedKey == 'serververificationdata' ||
        normalizedKey == 'localverificationdata' ||
        normalizedKey == 'signedtransactioninfo' ||
        normalizedKey == 'signedpayload' ||
        normalizedKey == 'body' ||
        normalizedKey == 'rawbody' ||
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
      RegExp(
        r'\b(x[_-]?api[_-]?key|api[_-]?key|x[_-]?fal[_-]?key|fal[_-]?key|stripe[_-]?signature|x[_-]?goog[_-]?signature|x[_-]?webhook[_-]?signature)\s*[:=]\s*[^\s,}\]]+',
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
        r'''(["']?)(access[_-]?token|refresh[_-]?token|id[_-]?token|auth[_-]?token|jwt|api[_-]?key|credential|signature|payment[_-]?intent[_-]?client[_-]?secret|payment[_-]?intent[_-]?ids?|setup[_-]?intent[_-]?ids?|client[_-]?secret|secret|password|receipt|signed[_-]?url|checkout[_-]?url|payment[_-]?url|billing[_-]?portal[_-]?url|customer[_-]?portal[_-]?url|redirect[_-]?url|callback[_-]?url|return[_-]?url|success[_-]?url|cancel[_-]?url|user[_-]?ids?|profile[_-]?user[_-]?ids?|owner[_-]?user[_-]?ids?|subject[_-]?ids?|account[_-]?ids?|account[_-]?scope|user[_-]?scope|scope|pet[_-]?ids?|pet[_-]?photo[_-]?ids?|generation[_-]?ids?|template[_-]?ids?|assignment[_-]?ids?|conversation[_-]?ids?|message[_-]?ids?|ticket[_-]?ids?|attachment[_-]?ids?|feedback[_-]?ids?|report[_-]?ids?|moderation[_-]?ids?|order[_-]?ids?|card[_-]?number|cvc|cvv|auth[_-]?ticket|external[_-]?auth[_-]?ticket|ticket|session[_-]?ids?|checkout[_-]?session[_-]?ids?|stripe[_-]?session[_-]?ids?|purchase[_-]?token|purchase[_-]?ids?|server[_-]?verification[_-]?data|local[_-]?verification[_-]?data|verification[_-]?data|signed[_-]?transaction[_-]?info|external[_-]?payment[_-]?ids?|external[_-]?subscription[_-]?ids?|subscription[_-]?ids?|customer[_-]?ids?)\1(\s*[:=]\s*)(["']?)[^}\]\s"']+\4''',
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
        r'''(["']?)([a-z0-9_-]*(?:user[_-]?ids?|account[_-]?ids?|pet[_-]?ids?|generation(?:[_-]?result)?[_-]?ids?|template[_-]?ids?|assignment[_-]?ids?|conversation[_-]?ids?|message[_-]?ids?|ticket[_-]?ids?|attachment[_-]?ids?|purchase[_-]?ids?|subscription[_-]?ids?|feedback[_-]?ids?|report[_-]?ids?|moderation[_-]?ids?|order[_-]?ids?))\1(\s*[:=]\s*)(["']?)[^}\]\s"']+\4''',
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
        r'''(["']?)(attachment[_-]?urls?|file[_-]?urls?|media[_-]?urls?|image[_-]?urls?|video[_-]?urls?|avatar[_-]?urls?|thumbnail[_-]?urls?|preview[_-]?urls?|output[_-]?urls?|download[_-]?urls?|upload[_-]?urls?)\1(\s*[:=]\s*)(["']?)(https?://[^,}\]\s"']+)\4''',
        caseSensitive: false,
      ),
      (match) {
        final quote = match.group(1) ?? '';
        final key = match.group(2) ?? '';
        final separator = match.group(3) ?? ': ';
        final valueQuote = match.group(4) ?? '';
        final value = match.group(5) ?? '';
        return '$quote$key$quote$separator$valueQuote${_maskRemoteMediaUrl(value)}$valueQuote';
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
        r'''(["']?)([a-z0-9_-]*file[_-]?names?)\1(\s*[:=]\s*)(?:(["'])([^"']*)\4|([^}\]\s"']+))''',
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
      RegExp(r'https?://[^\s]+[?#][^\s]+', caseSensitive: false),
      (match) {
        final uri = Uri.tryParse(match.group(0)!);
        if (uri == null || (!uri.hasQuery && !uri.hasFragment)) {
          return match.group(0)!;
        }

        return _maskUrlQueryAndFragment(uri);
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

  static String _maskRemoteMediaUrl(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return '***';
    }

    final hasPath = uri.pathSegments.any((segment) => segment.isNotEmpty);
    final sanitized = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: hasPath ? '/***' : '',
    );
    final normalized = sanitized.toString();
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  static String _maskUrlQueryAndFragment(Uri uri) {
    final sanitized = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/***',
    );
    return sanitized.toString();
  }

  static bool _isHttpUrl(Uri uri) {
    return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  static String _stripUrlCredentialsQueryAndFragment(Uri uri) {
    final sanitized = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    );
    return sanitized.toString().replaceFirst(RegExp(r'\?$'), '');
  }

  static String _normalizeLogText(String value) {
    final normalizedControls = value.replaceAll(
      RegExp(r'[\u0000-\u001F\u007F]+'),
      ' ',
    );
    return normalizedControls.replaceAll(RegExp(r' {2,}'), ' ').trim();
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
