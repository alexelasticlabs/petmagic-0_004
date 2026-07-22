import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';

String encodeTemplatePathSegment(String value) => Uri.encodeComponent(value);

class TemplatesRemoteErrorPolicy {
  const TemplatesRemoteErrorPolicy._();

  static bool isCancelledRequest(DioException error) {
    final innerError = error.error;
    if (innerError is RequestCancelledException) {
      return true;
    }
    if (innerError is DioException && isCancelledRequest(innerError)) {
      return true;
    }
    return CancelToken.isCancel(error) ||
        error.type == DioExceptionType.cancel ||
        _containsCancellationMarker(error.message) ||
        (innerError is AppException && innerError.isRequestCancelled) ||
        (innerError is String && _containsCancellationMarker(innerError));
  }

  static bool _containsCancellationMarker(String? value) {
    final message = value?.trim();
    return message != null &&
        message.isNotEmpty &&
        message.toLowerCase() == 'request_cancelled';
  }

  static String mapMessage(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'templates.connection_timeout';
    }
    if (error.type == DioExceptionType.receiveTimeout) {
      return 'templates.server_timeout';
    }
    try {
      final safePayloadMessage = NetworkErrorMapper.safePayloadMessage(
        NetworkErrorMapper.parseApiPayload(error),
      );
      if (safePayloadMessage != null) {
        return safePayloadMessage;
      }
    } catch (mappingError, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.Api',
        operation: 'detail_extract',
        message: 'API error payload mapping failed',
        context: {'stage': 'detail_extract'},
        error: mappingError,
        stackTrace: stackTrace,
      );
    }
    return 'templates.request_failed';
  }
}
