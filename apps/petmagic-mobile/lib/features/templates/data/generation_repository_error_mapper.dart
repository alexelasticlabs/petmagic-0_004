import 'dart:io';

import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';

/// Maps transport failures, including structured queue rejection metadata,
/// without coupling repository orchestration to response parsing details.
final class GenerationRepositoryErrorMapper {
  const GenerationRepositoryErrorMapper();

  AppException map(DioException error, {required String fallbackMessage}) {
    if (CancelToken.isCancel(error)) {
      return const RequestCancelledException();
    }

    final queueRejection = _mapQueueRejection(error);
    if (queueRejection != null) {
      return queueRejection;
    }
    if (NetworkErrorMapper.isConnectivityIssue(error)) {
      return NetworkErrorMapper.fromMessage(
        error,
        'templates.network_unavailable',
      );
    }
    if (NetworkErrorMapper.isServerError(error)) {
      return NetworkErrorMapper.fromMessage(
        error,
        'templates.server_unavailable',
      );
    }
    return AppException(
      NetworkErrorMapper.safePayloadMessage(
            NetworkErrorMapper.parseApiPayload(error),
          ) ??
          fallbackMessage,
      statusCode: error.response?.statusCode,
      cause: error,
    );
  }

  GenerationWaitTooLongException? _mapQueueRejection(DioException error) {
    if (error.response?.statusCode != 503) {
      return null;
    }
    final data = error.response?.data;
    if (data is! Map) {
      return null;
    }

    final payload = Map<Object?, Object?>.from(data);
    final code =
        _readString(payload, 'code') ??
        _readString(payload, 'title') ??
        _readString(payload, 'detail') ??
        _readString(payload, 'type');
    final hasWaitTooLongCode =
        code?.toUpperCase().contains('GENERATION_WAIT_TOO_LONG') ?? false;
    final estimatedWaitSeconds = _readInt(payload, 'estimatedWaitSeconds');
    final maxAllowedWaitSeconds = _readInt(payload, 'maxAllowedWaitSeconds');
    final mediaType = _readString(payload, 'mediaType');
    final tier = _readString(payload, 'tier');
    final hasStructuredWaitMetadata =
        estimatedWaitSeconds != null &&
        maxAllowedWaitSeconds != null &&
        (mediaType != null || tier != null);
    if (!hasWaitTooLongCode && !hasStructuredWaitMetadata) {
      return null;
    }

    return GenerationWaitTooLongException(
      statusCode: error.response?.statusCode,
      cause: error,
      mediaType: mediaType,
      tier: tier,
      estimatedWaitSeconds: estimatedWaitSeconds,
      maxAllowedWaitSeconds: maxAllowedWaitSeconds,
      retryAfterSeconds:
          _readInt(payload, 'retryAfterSeconds') ?? _retryAfterSeconds(error),
      canRetry: _readBool(payload, 'canRetry') ?? true,
      canUpgradeForPriority:
          _readBool(payload, 'canUpgradeForPriority') ?? false,
    );
  }

  String? _readString(Map<Object?, Object?> payload, String key) {
    final value = payload[key];
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _readInt(Map<Object?, Object?> payload, String key) {
    final value = payload[key];
    if (value is num) {
      return value.toInt();
    }
    return value is String ? int.tryParse(value.trim()) : null;
  }

  bool? _readBool(Map<Object?, Object?> payload, String key) {
    final value = payload[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return switch (value.trim().toLowerCase()) {
        'true' || '1' || 'yes' => true,
        'false' || '0' || 'no' => false,
        _ => null,
      };
    }
    return null;
  }

  int? _retryAfterSeconds(DioException error) {
    final value = error.response?.headers.value(HttpHeaders.retryAfterHeader);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final seconds = int.tryParse(value.trim());
    if (seconds != null) {
      return seconds;
    }
    try {
      return HttpDate.parse(
        value,
      ).difference(DateTime.now().toUtc()).inSeconds.clamp(0, 24 * 60 * 60);
    } on FormatException {
      return null;
    }
  }
}
