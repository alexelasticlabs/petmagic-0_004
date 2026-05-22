import 'package:dio/dio.dart';

import 'package:petmagic_mobile/core/errors/app_exception.dart';

class ApiErrorPayload {
  const ApiErrorPayload({this.flattened, this.detail, this.title});

  final String? flattened;
  final String? detail;
  final String? title;
}

class NetworkErrorMapper {
  const NetworkErrorMapper._();

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

    final flattened = _flattenValidationErrors(data['errors']);
    final detail = _clean(data['detail'] as String?);
    final title = _clean(data['title'] as String?);

    return ApiErrorPayload(flattened: flattened, detail: detail, title: title);
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

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
