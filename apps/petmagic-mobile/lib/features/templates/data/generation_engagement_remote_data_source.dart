import 'dart:io';

import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/auth/auth_session.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_request_cancellation.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/templates/data/generation_repository_error_mapper.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_result_dto_mapper.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_results.dart';

/// Owns analytics, feedback, watermark and push-token REST transport.
final class GenerationEngagementRemoteDataSource {
  const GenerationEngagementRemoteDataSource({
    required Dio dio,
    required AuthSessionCoordinator authSessionCoordinator,
    required GenerationRepositoryErrorMapper errorMapper,
  }) : _dio = dio,
       _authSessionCoordinator = authSessionCoordinator,
       _errorMapper = errorMapper;

  final Dio _dio;
  final AuthSessionCoordinator _authSessionCoordinator;
  final GenerationRepositoryErrorMapper _errorMapper;

  Future<void> recordAnalytics({
    required String templateId,
    required String eventType,
    required String source,
    String? generationId,
    Map<String, Object?> metadata = const {},
    RequestCancellation? cancelToken,
  }) async {
    await _authorizedRequest<void>(
      (session) => _dio.post<void>(
        '/api/templates/${Uri.encodeComponent(templateId)}/analytics/events',
        data: {
          'eventType': eventType,
          'source': source,
          if (generationId != null && generationId.isNotEmpty)
            'generationId': generationId,
          if (metadata.isNotEmpty) 'metadata': metadata,
        },
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );
  }

  Future<RemoveGenerationWatermarkResult> removeWatermark(
    String generationId, {
    required String paymentMethod,
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/templates/generations/${Uri.encodeComponent(generationId)}/remove-watermark',
        data: {'paymentMethod': paymentMethod},
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );
    return mapRemoveGenerationWatermarkResultDto(response.data ?? const {});
  }

  Future<void> submitGenerationFeedback({
    required String generationId,
    required int rating,
    List<String> selectedReasons = const [],
    String? comment,
    double? inputPhotoQualityScore,
    bool retryTransientFailures = false,
  }) async {
    final category = selectedReasons.isNotEmpty
        ? selectedReasons.first
        : switch (rating) {
            3 => 'good',
            2 => 'okay',
            _ => 'bad',
          };
    await submitFeedback(
      type: 'GenerationResult',
      category: category,
      rating: switch (rating) {
        3 => 1,
        2 => 0,
        _ => -1,
      },
      message: comment,
      generationId: generationId,
      sourceScreen: 'generation_status',
      retryTransientFailures: retryTransientFailures,
    );
  }

  Future<String> submitFeedback({
    required String type,
    required String category,
    int? rating,
    String? message,
    String? generationId,
    String? templateId,
    String? petId,
    required String sourceScreen,
    RequestCancellation? cancelToken,
    required bool retryTransientFailures,
  }) async {
    final data = <String, Object?>{
      'type': type,
      'category': category,
      'sourceScreen': sourceScreen,
      'appVersion': AppConfig.appVersion,
      'platform': Platform.operatingSystem,
      'deviceModel': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
      'rating': ?rating,
      'message': ?_nonEmpty(message),
      'generationId': ?_nonEmpty(generationId),
      'templateId': ?_nonEmpty(templateId),
      'petId': ?_nonEmpty(petId),
    };
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/feedback',
        data: data,
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: retryTransientFailures,
    );
    return response.data?['feedbackId'] as String? ?? '';
  }

  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
    String? appVersion,
    String? locale,
    bool retryTransientFailures = false,
  }) {
    return _authorizedRequest<void>(
      (session) => _dio.put<void>(
        '/api/templates/notifications/push-token',
        data: {
          'token': token,
          'platform': platform,
          if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
          if (appVersion != null && appVersion.isNotEmpty)
            'appVersion': appVersion,
          if (locale != null && locale.isNotEmpty) 'locale': locale,
        },
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: retryTransientFailures,
    );
  }

  Future<void> unregisterPushToken(
    String token, {
    bool retryTransientFailures = false,
  }) {
    return _authorizedRequest<void>(
      (session) => _dio.delete<void>(
        '/api/templates/notifications/push-token',
        data: {'token': token},
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: retryTransientFailures,
    );
  }

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request, {
    required bool retryTransientFailures,
  }) {
    return _authSessionCoordinator.authorizedRequest(
      request: request,
      mapError: _errorMapper.map,
      requestFailedMessage: 'templates.generation_failed',
      sessionExpiredMessage: 'auth.session_expired',
      transientRetryAttempts: retryTransientFailures ? 2 : 1,
    );
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
