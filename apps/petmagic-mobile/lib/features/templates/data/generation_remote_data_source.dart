import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:petmagic_mobile/core/auth/auth_session.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/files/local_media_file.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_request_cancellation.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/templates/data/generation_repository_error_mapper.dart';
import 'package:petmagic_mobile/features/templates/data/generation_source_upload_preparer.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_dtos.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';

/// Owns generation command/query REST transport and DTO mapping.
final class GenerationRemoteDataSource {
  const GenerationRemoteDataSource({
    required Dio dio,
    required AuthSessionCoordinator authSessionCoordinator,
    required GenerationRepositoryErrorMapper errorMapper,
    required GenerationSourceUploadPreparer sourceUploadPreparer,
  }) : _dio = dio,
       _authSessionCoordinator = authSessionCoordinator,
       _errorMapper = errorMapper,
       _sourceUploadPreparer = sourceUploadPreparer;

  final Dio _dio;
  final AuthSessionCoordinator _authSessionCoordinator;
  final GenerationRepositoryErrorMapper _errorMapper;
  final GenerationSourceUploadPreparer _sourceUploadPreparer;

  Future<TemplateGenerationResult> startGeneration({
    required String templateId,
    required LocalMediaFile sourceImage,
    int? expectedTemplateVersion,
    String? correlationId,
    RequestCancellation? cancelToken,
    required bool retryTransientFailures,
  }) async {
    final normalizedCorrelationId = correlationId?.trim();
    final prepared = await _sourceUploadPreparer.prepare(
      sourceImage,
      cancelToken: cancelToken,
    );
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (session) async => _dio.post<Map<String, dynamic>>(
          '/api/templates/${Uri.encodeComponent(templateId)}/generations',
          data: FormData.fromMap({
            'sourceImage': await MultipartFile.fromFile(
              prepared.file.path,
              filename: prepared.fileName,
              contentType: MediaType.parse(prepared.contentType),
            ),
            if (expectedTemplateVersion != null && expectedTemplateVersion > 0)
              'expectedTemplateVersion': expectedTemplateVersion,
          }),
          options: authenticatedMultipartRequestOptions(
            session.accessToken,
            correlationId: correlationId,
            extraHeaders:
                normalizedCorrelationId == null ||
                    normalizedCorrelationId.isEmpty
                ? null
                : {'Idempotency-Key': normalizedCorrelationId},
          ),
          cancelToken: cancelToken.toDioCancelToken(),
        ),
        retryTransientFailures: retryTransientFailures,
      );
      return TemplateGenerationDto.fromJson(
        response.data ?? const {},
      ).toDomain();
    } finally {
      await prepared.dispose();
    }
  }

  Future<TemplateGenerationResult> fetchGeneration(
    String generationId, {
    String? correlationId,
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/templates/generations/${Uri.encodeComponent(generationId)}',
        options: authenticatedRequestOptions(
          session.accessToken,
          correlationId: correlationId,
        ),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
    );
    return TemplateGenerationDto.fromJson(response.data ?? const {}).toDomain();
  }

  Future<GenerationCancelResult> cancelGeneration(
    String generationId, {
    String? correlationId,
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/templates/generations/${Uri.encodeComponent(generationId)}/cancel',
        options: authenticatedRequestOptions(
          session.accessToken,
          correlationId: correlationId,
        ),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );
    return GenerationCancelResultDto.fromJson(
      response.data ?? const {},
    ).toDomain();
  }

  Future<CompatibleGenerationTemplates> fetchCompatibleTemplates(
    String resultId, {
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/templates/generation-results/${Uri.encodeComponent(resultId)}/compatible-templates',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
    );
    return CompatibleGenerationTemplatesDto.fromJson(
      response.data ?? const {},
    ).toDomain();
  }

  Future<TemplateGenerationResult> startGenerationFromResult({
    required String parentGenerationResultId,
    required String templateId,
    int? expectedTemplateVersion,
    String? correlationId,
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/templates/generations/from-result',
        data: {
          'parentGenerationResultId': parentGenerationResultId,
          'templateId': templateId,
          if (expectedTemplateVersion != null && expectedTemplateVersion > 0)
            'expectedTemplateVersion': expectedTemplateVersion,
        },
        options: authenticatedRequestOptions(
          session.accessToken,
          correlationId: correlationId,
        ),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );
    return TemplateGenerationDto.fromJson(response.data ?? const {}).toDomain();
  }

  Future<TemplateGenerationResult> generateSimilar({
    required String sourceGenerationId,
    required String variationStrength,
    String? correlationId,
    RequestCancellation? cancelToken,
  }) async {
    final idempotencyKey =
        'similar-$sourceGenerationId-${DateTime.now().microsecondsSinceEpoch}';
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/templates/generations/${Uri.encodeComponent(sourceGenerationId)}/generate-similar',
        data: {'variationStrength': variationStrength},
        options: authenticatedRequestOptions(
          session.accessToken,
          correlationId: correlationId,
          extraHeaders: {'Idempotency-Key': idempotencyKey},
        ),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );

    final newGenerationId = response.data?['generationId'] as String? ?? '';
    if (newGenerationId.isEmpty) {
      throw const AppException('templates.generate_similar_empty_response');
    }
    return fetchGeneration(
      newGenerationId,
      correlationId: correlationId,
      cancelToken: cancelToken,
    );
  }

  Future<TemplateGenerationResult> startGenerationFromPet({
    required String petId,
    String? petPhotoId,
    required String templateId,
    int? expectedTemplateVersion,
    String? correlationId,
    RequestCancellation? cancelToken,
  }) async {
    final idempotencyKey =
        'pet-$petId-${petPhotoId ?? 'auto'}-$templateId-${DateTime.now().microsecondsSinceEpoch}';
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/templates/generations/from-pet',
        data: {
          'petId': petId,
          if (petPhotoId != null && petPhotoId.isNotEmpty)
            'petPhotoId': petPhotoId,
          'templateId': templateId,
          if (expectedTemplateVersion != null && expectedTemplateVersion > 0)
            'expectedTemplateVersion': expectedTemplateVersion,
        },
        options: authenticatedRequestOptions(
          session.accessToken,
          correlationId: correlationId,
          extraHeaders: {'Idempotency-Key': idempotencyKey},
        ),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );
    return TemplateGenerationDto.fromJson(response.data ?? const {}).toDomain();
  }

  Future<void> deleteGeneration(
    String generationId, {
    RequestCancellation? cancelToken,
    required bool retryTransientFailures,
  }) {
    return _authorizedRequest<void>(
      (session) => _dio.delete<void>(
        '/api/templates/generations/${Uri.encodeComponent(generationId)}',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: retryTransientFailures,
    );
  }

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request, {
    bool retryTransientFailures = true,
  }) {
    return _authSessionCoordinator.authorizedRequest(
      request: request,
      mapError: _errorMapper.map,
      requestFailedMessage: 'templates.generation_failed',
      sessionExpiredMessage: 'auth.session_expired',
      transientRetryAttempts: retryTransientFailures ? 2 : 1,
    );
  }
}
