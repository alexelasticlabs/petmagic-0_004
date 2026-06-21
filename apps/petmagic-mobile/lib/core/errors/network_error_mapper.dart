import 'package:dio/dio.dart';

import 'package:petmagic_mobile/core/errors/app_exception.dart';

class ApiErrorPayload {
  const ApiErrorPayload({
    this.flattened,
    this.detail,
    this.title,
    this.validationMessageKey,
  });

  final String? flattened;
  final String? detail;
  final String? title;
  final String? validationMessageKey;
}

class NetworkErrorMapper {
  const NetworkErrorMapper._();

  static final RegExp _safeMessageKeyPattern = RegExp(
    r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$',
  );

  static bool isConnectivityIssue(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.response == null;
  }

  static bool isConnectionUnavailable(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout;
  }

  static bool isServerError(DioException error) {
    final statusCode = error.response?.statusCode;
    return statusCode != null && statusCode >= 500;
  }

  static ApiErrorPayload parseApiPayload(DioException error) {
    final data = error.response?.data;
    if (data is! Map) {
      return const ApiErrorPayload();
    }

    final rawErrors = data['errors'];
    final flattened = _flattenValidationErrors(rawErrors);
    final validationMessageKey = _firstSafeValidationMessage(rawErrors);
    final detail = _clean(data['detail'] as String?);
    final title = _clean(data['title'] as String?);

    return ApiErrorPayload(
      flattened: flattened,
      detail: detail,
      title: title,
      validationMessageKey: validationMessageKey,
    );
  }

  static String? safePayloadMessage(ApiErrorPayload payload) {
    for (final value in [
      payload.validationMessageKey,
      payload.title,
      payload.detail,
      payload.flattened,
    ]) {
      if (value != null && isSafeMessageKey(value)) {
        return value;
      }
    }
    return null;
  }

  static bool isSafeMessageKey(String value) {
    final trimmed = value.trim();
    return trimmed.length <= 96 && _safeMessageKeyPattern.hasMatch(trimmed);
  }

  static AppException fromMessage(
    DioException error,
    String message, {
    bool includeCause = true,
    int? statusCode,
  }) {
    return AppException(
      message,
      statusCode: statusCode ?? error.response?.statusCode,
      cause: includeCause ? error : null,
    );
  }

  static AppException fallback(
    DioException error, {
    required String fallbackMessage,
    bool includeCause = true,
  }) {
    return fromMessage(error, fallbackMessage, includeCause: includeCause);
  }

  static String? _flattenValidationErrors(Object? rawErrors) {
    if (rawErrors is! Map) {
      return null;
    }

    final flattened = rawErrors.values
        .whereType<List<dynamic>>()
        .expand((value) => value.whereType<String>())
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' ');

    return _clean(flattened);
  }

  static String? _firstSafeValidationMessage(Object? rawErrors) {
    if (rawErrors is! Map) {
      return null;
    }

    for (final value in rawErrors.values) {
      if (value is! List) {
        continue;
      }

      for (final message in value.whereType<String>()) {
        final cleaned = _clean(message);
        if (cleaned != null && isSafeMessageKey(cleaned)) {
          return cleaned;
        }
      }
    }

    return null;
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
