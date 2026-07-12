export 'package:petmagic_mobile/features/templates/application/generation_repository.dart'
    show GenerationRepository, templateGenerationRepositoryProvider;
export 'package:petmagic_mobile/features/pets/domain/pet_models.dart';
export 'package:petmagic_mobile/features/templates/domain/template_generation_results.dart';

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/core/network/request_identity.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/core/auth/auth_session.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_dtos.dart';
import 'package:petmagic_mobile/features/pets/domain/pet_models.dart';
import 'package:petmagic_mobile/features/templates/application/generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_results.dart';
import 'package:petmagic_mobile/shared/files/file_name_sanitizer.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';
import 'package:petmagic_mobile/shared/files/media_signature.dart';
import 'package:petmagic_mobile/shared/files/upload_media_policy.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'template_generation_dtos.dart';

part 'template_generation_repository_cache.part.dart';
part 'template_generation_repository_media.part.dart';
part 'template_generation_repository_pets.part.dart';

final templateGenerationSharedPreferencesProvider =
    Provider<SharedPreferencesAsync>((ref) => SharedPreferencesAsync());

final templateGenerationSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final dioTemplateGenerationRepositoryProvider = Provider<GenerationRepository>((
  ref,
) {
  return TemplateGenerationRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    preferences: ref.watch(templateGenerationSharedPreferencesProvider),
    secureStorage: ref.watch(templateGenerationSecureStorageProvider),
    authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
    imageUploadOptimizer: const ImageUploadOptimizer(),
  );
});

class TemplateGenerationRepository implements GenerationRepository {
  TemplateGenerationRepository({
    required Dio dio,
    required AuthSessionStore sessionStorage,
    required SharedPreferencesAsync preferences,
    FlutterSecureStorage? secureStorage,
    ImageUploadOptimizer? imageUploadOptimizer,
    AuthSessionCoordinator? authSessionCoordinator,
  }) : _dio = dio,
       _sessionStorage = sessionStorage,
       _preferences = preferences,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _imageUploadOptimizer =
           imageUploadOptimizer ?? const ImageUploadOptimizer(),
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage);

  static const _generationsCachePrefix = 'templates_generations_v1:';
  static const _generationsCacheUpdatedAtPrefix =
      'templates_generations_updated_at_v1:';
  static const _unreadCountCacheKey = 'templates_generations_unread_v1';
  static const _unreadCountCacheUpdatedAtKey =
      'templates_generations_unread_updated_at_v1';
  static const _activeGenerationIdKey = 'templates_active_generation_id_v1';
  static const _activeGenerationCorrelationIdKey =
      'templates_active_generation_correlation_id_v1';
  static const _activeGenerationSecureScopeKey =
      'petmagic_mobile_templates_active_generation_scope_v2';
  static const _activeGenerationIdSecureStorageKey =
      'petmagic_mobile_templates_active_generation_id_v2';
  static const _activeGenerationCorrelationIdSecureStorageKey =
      'petmagic_mobile_templates_active_generation_correlation_id_v2';
  static const _maxSourceImageBytes = 12 * 1024 * 1024;
  static const _maxPetPhotoBytes = UploadMediaPolicy.petPhotoMaxBytes;
  static const _cacheAllStatusKey = 'all';
  static const _cacheStatuses = <String>[
    _cacheAllStatusKey,
    'active',
    'completed',
    'failed',
  ];
  final Dio _dio;
  final AuthSessionStore _sessionStorage;
  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secureStorage;
  final ImageUploadOptimizer _imageUploadOptimizer;
  final AuthSessionCoordinator _authSessionCoordinator;
  Future<String?>? _cacheScopeFuture;

  @override
  TemplateGenerationResult parseRealtimePayload(Map<String, dynamic> payload) {
    return TemplateGenerationDto.fromJson(payload).toDomain();
  }

  @override
  Future<TemplateGenerationResult> startGeneration({
    required String templateId,
    required XFile sourceImage,
    int? expectedTemplateVersion,
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    final encodedTemplateId = _apiPathSegment(templateId);
    final rawFileName = sourceImage.name.isNotEmpty
        ? sourceImage.name
        : sourceImage.path.split(Platform.pathSeparator).last;
    final fileName = _safeSourceImageFileName(rawFileName);
    final declaredContentType =
        sourceImage.mimeType ?? _resolveImageContentType(fileName);
    await _validateSourceImageUploadFile(
      filePath: sourceImage.path,
      declaredContentType: declaredContentType,
    );

    OptimizedUploadFile? optimizedSource;
    try {
      optimizedSource = await _imageUploadOptimizer.optimizeGenerationSource(
        XFile(sourceImage.path, name: fileName, mimeType: declaredContentType),
        cancelToken: cancelToken,
      );
      final uploadFile = optimizedSource.file;
      final uploadRawFileName = uploadFile.name.isNotEmpty
          ? uploadFile.name
          : uploadFile.path.split(Platform.pathSeparator).last;
      final uploadFileName = _safeSourceImageFileName(uploadRawFileName);
      final uploadDeclaredContentType =
          uploadFile.mimeType ?? _resolveImageContentType(uploadFileName);
      final uploadContentType = await _validateSourceImageUploadFile(
        filePath: uploadFile.path,
        declaredContentType: uploadDeclaredContentType,
      );

      final response = await _authorizedRequest<Map<String, dynamic>>(
        (session) async => _dio.post<Map<String, dynamic>>(
          '/api/templates/$encodedTemplateId/generations',
          data: FormData.fromMap({
            'sourceImage': await MultipartFile.fromFile(
              uploadFile.path,
              filename: uploadFileName,
              contentType: MediaType.parse(uploadContentType),
            ),
            if (expectedTemplateVersion != null && expectedTemplateVersion > 0)
              'expectedTemplateVersion': expectedTemplateVersion,
          }),
          options: authenticatedMultipartRequestOptions(
            session.accessToken,
            correlationId: correlationId,
          ),
          cancelToken: cancelToken,
        ),
        retryTransientFailures: false,
      );

      return TemplateGenerationDto.fromJson(
        response.data ?? const {},
      ).toDomain();
    } finally {
      await optimizedSource?.dispose();
    }
  }

  Future<String> _validateSourceImageUploadFile({
    required String filePath,
    required String declaredContentType,
  }) async {
    if (!_isAllowedImageContentType(declaredContentType) &&
        !_isGenericBinaryContentType(declaredContentType)) {
      throw const AppException('templates.source_image_type_not_allowed');
    }

    final fileSize = await _uploadImageSizeBytes(
      filePath,
      unavailableMessage: 'templates.source_image_unavailable',
    );
    if (fileSize <= 0) {
      throw const AppException('templates.source_image_empty');
    }
    if (fileSize > _maxSourceImageBytes) {
      throw const AppException('templates.source_image_too_large');
    }

    final contentType = await _detectSourceImageContentType(
      filePath,
      unavailableMessage: 'templates.source_image_unavailable',
    );
    if (contentType == null || !_isAllowedImageContentType(contentType)) {
      throw const AppException('templates.source_image_type_not_allowed');
    }

    return contentType;
  }

  @override
  Future<TemplateGenerationResult> fetchGeneration(
    String generationId, {
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    final encodedGenerationId = _apiPathSegment(generationId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/templates/generations/$encodedGenerationId',
        options: authenticatedRequestOptions(
          session.accessToken,
          correlationId: correlationId,
        ),
        cancelToken: cancelToken,
      ),
    );

    return TemplateGenerationDto.fromJson(response.data ?? const {}).toDomain();
  }

  @override
  Future<GenerationCancelResult> cancelGeneration(
    String generationId, {
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    final encodedGenerationId = _apiPathSegment(generationId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/templates/generations/$encodedGenerationId/cancel',
        options: authenticatedRequestOptions(
          session.accessToken,
          correlationId: correlationId,
        ),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );

    final result = GenerationCancelResultDto.fromJson(
      response.data ?? const {},
    ).toDomain();
    await _upsertCachedGeneration(this, result.generation);
    if (result.generation.isTerminal) {
      await clearActiveGeneration(result.generation.generationId);
    }

    return result;
  }

  @override
  Future<CompatibleGenerationTemplates> fetchCompatibleTemplates(
    String resultId, {
    CancelToken? cancelToken,
  }) async {
    final encodedResultId = _apiPathSegment(resultId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/templates/generation-results/$encodedResultId/compatible-templates',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );

    return CompatibleGenerationTemplatesDto.fromJson(
      response.data ?? const {},
    ).toDomain();
  }

  @override
  Future<TemplateGenerationResult> startGenerationFromResult({
    required String parentGenerationResultId,
    required String templateId,
    int? expectedTemplateVersion,
    String? correlationId,
    CancelToken? cancelToken,
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
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );

    return TemplateGenerationDto.fromJson(response.data ?? const {}).toDomain();
  }

  @override
  Future<TemplateGenerationResult> generateSimilar({
    required String sourceGenerationId,
    String variationStrength = 'medium',
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    final encodedSourceGenerationId = _apiPathSegment(sourceGenerationId);
    final idempotencyKey =
        'similar-$sourceGenerationId-${DateTime.now().microsecondsSinceEpoch}';
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/templates/generations/$encodedSourceGenerationId/generate-similar',
        data: {'variationStrength': variationStrength},
        options: authenticatedRequestOptions(
          session.accessToken,
          correlationId: correlationId,
          extraHeaders: {'Idempotency-Key': idempotencyKey},
        ),
        cancelToken: cancelToken,
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

  @override
  Future<TemplateGenerationResult> startGenerationFromPet({
    required String petId,
    String? petPhotoId,
    required String templateId,
    int? expectedTemplateVersion,
    String? correlationId,
    CancelToken? cancelToken,
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
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );

    return TemplateGenerationDto.fromJson(response.data ?? const {}).toDomain();
  }

  @override
  Future<List<PetProfile>> fetchPets({CancelToken? cancelToken}) async {
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.get<List<dynamic>>(
        '/api/pets',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );

    return (response.data ?? const [])
        .whereType<Map>()
        .map((item) => PetProfile.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<PetProfile> createPet({
    required String name,
    required String type,
    String? breed,
    CancelToken? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/pets',
        data: {'name': name, 'type': type, 'breed': ?breed},
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );

    return PetProfile.fromJson(response.data ?? const {});
  }

  @override
  Future<PetProfile> updatePet({
    required String petId,
    required String name,
    required String type,
    String? breed,
    CancelToken? cancelToken,
  }) async {
    final encodedPetId = _apiPathSegment(petId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.put<Map<String, dynamic>>(
        '/api/pets/$encodedPetId',
        data: {'name': name, 'type': type, 'breed': ?breed},
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );

    return PetProfile.fromJson(response.data ?? const {});
  }

  @override
  Future<void> deletePet(String petId, {CancelToken? cancelToken}) async {
    final encodedPetId = _apiPathSegment(petId);
    await _authorizedRequest<void>(
      (session) => _dio.delete<void>(
        '/api/pets/$encodedPetId',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );
  }

  @override
  Future<PetPhoto> uploadPetPhoto({
    required String petId,
    required XFile photo,
    CancelToken? cancelToken,
  }) => _uploadPetPhoto(
    this,
    petId: petId,
    photo: photo,
    cancelToken: cancelToken,
  );

  @override
  Future<List<PetPhoto>> fetchPetPhotos(
    String petId, {
    CancelToken? cancelToken,
  }) => _fetchPetPhotos(this, petId: petId, cancelToken: cancelToken);

  @override
  Future<PetPhoto> setPetPhotoAsAvatar({
    required String petId,
    required String photoId,
    CancelToken? cancelToken,
  }) => _setPetPhotoAsAvatar(
    this,
    petId: petId,
    photoId: photoId,
    cancelToken: cancelToken,
  );

  @override
  Future<PetPhoto> setPetPhotoFavorite({
    required String petId,
    required String photoId,
    required bool isFavorite,
    CancelToken? cancelToken,
  }) => _setPetPhotoFavorite(
    this,
    petId: petId,
    photoId: photoId,
    isFavorite: isFavorite,
    cancelToken: cancelToken,
  );

  @override
  Future<void> deletePetPhoto({
    required String petId,
    required String photoId,
    CancelToken? cancelToken,
  }) => _deletePetPhoto(
    this,
    petId: petId,
    photoId: photoId,
    cancelToken: cancelToken,
  );

  @override
  Future<List<TemplateGenerationResult>> fetchPetGenerations(
    String petId, {
    CancelToken? cancelToken,
  }) => _fetchPetGenerations(this, petId: petId, cancelToken: cancelToken);

  @override
  Future<void> recordTemplateAnalyticsEvent({
    required String templateId,
    required String eventType,
    String source = 'mobile',
    String? generationId,
    Map<String, Object?>? metadata,
    CancelToken? cancelToken,
  }) async {
    final encodedTemplateId = _apiPathSegment(templateId);
    await _authorizedRequest<void>(
      (session) => _dio.post<void>(
        '/api/templates/$encodedTemplateId/analytics/events',
        data: {
          'eventType': eventType,
          'source': source,
          if (generationId != null && generationId.isNotEmpty)
            'generationId': generationId,
          if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
        },
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );
  }

  @override
  Future<RemoveGenerationWatermarkResult> removeWatermark(
    String generationId, {
    String paymentMethod = 'credit',
    CancelToken? cancelToken,
  }) async {
    final encodedGenerationId = _apiPathSegment(generationId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/templates/generations/$encodedGenerationId/remove-watermark',
        data: {'paymentMethod': paymentMethod},
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );

    return RemoveGenerationWatermarkResult.fromJson(response.data ?? const {});
  }

  @override
  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? generationId,
    Map<String, Object?> metadata = const {},
    CancelToken? cancelToken,
  }) async {
    final encodedTemplateId = _apiPathSegment(templateId);
    await _authorizedRequest<void>(
      (session) => _dio.post<void>(
        '/api/templates/$encodedTemplateId/analytics/events',
        data: {
          'eventType': eventType,
          'source': 'mobile',
          if (generationId != null && generationId.isNotEmpty)
            'generationId': generationId,
          if (metadata.isNotEmpty) 'metadata': metadata,
        },
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );
  }

  @override
  Future<GenerationMediaAccessResult> fetchDownloadUrl(
    String generationId, {
    CancelToken? cancelToken,
  }) => _fetchDownloadUrl(this, generationId, cancelToken: cancelToken);

  @override
  Future<GenerationMediaAccessResult> fetchShareUrl(
    String generationId, {
    CancelToken? cancelToken,
  }) => _fetchShareUrl(this, generationId, cancelToken: cancelToken);

  @override
  Future<List<TemplateGenerationResult>?> readCachedGenerations({
    String? status,
  }) => _readCachedGenerations(this, status: status);

  @override
  Future<TemplateGenerationResult?> readCachedGeneration(String generationId) =>
      _readCachedGeneration(this, generationId);

  @override
  Future<int?> readCachedUnreadGenerationCount() =>
      _readCachedUnreadGenerationCount(this);

  @override
  Future<({String generationId, String correlationId})?>
  readActiveGeneration() => _readActiveGeneration(this);

  @override
  Future<void> rememberActiveGeneration({
    required String generationId,
    String? correlationId,
  }) => _rememberActiveGeneration(
    this,
    generationId: generationId,
    correlationId: correlationId,
  );

  @override
  Future<void> clearActiveGeneration(String generationId) =>
      _clearActiveGeneration(this, generationId);

  @override
  Future<void> clearLocalCache() => _clearLocalCache(this);

  String _createGenerationCorrelationId() =>
      _buildGenerationCorrelationId(this);

  Future<String?> _readCacheScope() =>
      _cacheScopeFuture ??= _resolveGenerationCacheScope(this);

  @override
  Future<List<TemplateGenerationResult>> fetchGenerations({
    String? status,
    int? skip,
    int? take,
    CancelToken? cancelToken,
  }) => _fetchGenerations(
    this,
    status: status,
    skip: skip,
    take: take,
    cancelToken: cancelToken,
  );

  @override
  Future<TemplateGenerationGalleryPage> fetchGenerationPage({
    String? status,
    String? cursor,
    int? take,
    CancelToken? cancelToken,
  }) => _fetchGenerationPage(
    this,
    status: status,
    cursor: cursor,
    take: take,
    cancelToken: cancelToken,
  );

  @override
  Future<int> fetchUnreadGenerationCount({CancelToken? cancelToken}) =>
      _fetchUnreadGenerationCount(this, cancelToken: cancelToken);

  @override
  Future<void> markGenerationRead(
    String generationId, {
    CancelToken? cancelToken,
  }) => _markGenerationRead(this, generationId, cancelToken: cancelToken);

  @override
  Future<void> deleteGeneration(
    String generationId, {
    CancelToken? cancelToken,
  }) async {
    final encodedGenerationId = _apiPathSegment(generationId);
    await _authorizedRequest<void>(
      (session) => _dio.delete<void>(
        '/api/templates/generations/$encodedGenerationId',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );

    await _removeCachedGeneration(generationId);
  }

  @override
  Future<void> upsertCachedGeneration(TemplateGenerationResult generation) =>
      _upsertCachedGeneration(this, generation);

  @override
  Future<void> submitGenerationFeedback({
    required String generationId,
    required int rating,
    List<String> selectedReasons = const [],
    String? comment,
    double? inputPhotoQualityScore,
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
      retryTransientFailures: false,
    );
  }

  @override
  Future<String> submitFeedback({
    required String type,
    required String category,
    int? rating,
    String? message,
    String? generationId,
    String? templateId,
    String? petId,
    String sourceScreen = 'settings',
    CancelToken? cancelToken,
    bool retryTransientFailures = false,
  }) async {
    final feedbackMessage = _nonEmptyOptional(message);
    final feedbackGenerationId = _nonEmptyOptional(generationId);
    final feedbackTemplateId = _nonEmptyOptional(templateId);
    final feedbackPetId = _nonEmptyOptional(petId);
    final data = <String, Object?>{
      'type': type,
      'category': category,
      'sourceScreen': sourceScreen,
      'appVersion': AppConfig.appVersion,
      'platform': Platform.operatingSystem,
      'deviceModel': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
    };
    if (rating != null) {
      data['rating'] = rating;
    }
    if (feedbackMessage != null) {
      data['message'] = feedbackMessage;
    }
    if (feedbackGenerationId != null) {
      data['generationId'] = feedbackGenerationId;
    }
    if (feedbackTemplateId != null) {
      data['templateId'] = feedbackTemplateId;
    }
    if (feedbackPetId != null) {
      data['petId'] = feedbackPetId;
    }

    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/feedback',
        data: data,
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: retryTransientFailures,
    );

    return response.data?['feedbackId'] as String? ?? '';
  }

  String? _nonEmptyOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
    String? appVersion,
    String? locale,
  }) async {
    await _authorizedRequest<void>(
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
      retryTransientFailures: false,
    );
  }

  @override
  Future<void> unregisterPushToken(String token) async {
    await _authorizedRequest<void>(
      (session) => _dio.delete<void>(
        '/api/templates/notifications/push-token',
        data: {'token': token},
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );
  }

  Future<void> _writeCachedGenerations({
    required String? status,
    required List<Map<String, Object?>> items,
  }) => _writeCachedGenerationsImpl(this, status: status, items: items);

  Future<void> _writeCachedUnreadGenerationCount(int count) =>
      _writeCachedUnreadGenerationCountImpl(this, count);

  bool _matchesCachedGenerationStatus(
    TemplateGenerationResult generation,
    String? status,
  ) => _matchesCachedGenerationStatusImpl(this, generation, status);

  Map<String, Object?> _generationToCachedJson(
    TemplateGenerationResult generation,
  ) => _generationToCachedJsonImpl(this, generation);

  Future<void> _markCachedGenerationRead(String generationId) =>
      _markCachedGenerationReadImpl(this, generationId);

  Future<void> _removeCachedGeneration(String generationId) =>
      _removeCachedGenerationImpl(this, generationId);

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request, {
    bool retryTransientFailures = true,
  }) async {
    return _authSessionCoordinator.authorizedRequest(
      request: request,
      mapError: _mapDioException,
      requestFailedMessage: 'templates.generation_failed',
      sessionExpiredMessage: 'auth.session_expired',
      transientRetryAttempts: retryTransientFailures ? 2 : 1,
    );
  }

  AppException _mapDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
    final generationQueueRejection = _mapGenerationQueueRejection(error);
    if (generationQueueRejection != null) {
      return generationQueueRejection;
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

  GenerationWaitTooLongException? _mapGenerationQueueRejection(
    DioException error,
  ) {
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
          _readInt(payload, 'retryAfterSeconds') ??
          _retryAfterHeaderSeconds(error),
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
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  bool? _readBool(Map<Object?, Object?> payload, String key) {
    final value = payload[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  int? _retryAfterHeaderSeconds(DioException error) {
    final value = error.response?.headers.value(HttpHeaders.retryAfterHeader);
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final seconds = int.tryParse(value.trim());
    if (seconds != null) {
      return seconds;
    }

    try {
      final retryAt = HttpDate.parse(value);
      return retryAt
          .difference(DateTime.now().toUtc())
          .inSeconds
          .clamp(0, 24 * 60 * 60);
    } on FormatException {
      return null;
    }
  }

  String _resolveImageContentType(String fileName) =>
      _resolveImageContentTypeImpl(this, fileName);

  String _safeSourceImageFileName(String rawFileName) {
    final basename = rawFileName
        .replaceAll(r'\', '/')
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .lastOrNull;
    return sanitizeFileName(basename, fallback: 'petmagic_source_image.jpg');
  }

  String _apiPathSegment(String value) {
    return Uri.encodeComponent(value);
  }

  bool _isAllowedImageContentType(String contentType) {
    final normalized = _normalizedContentType(contentType);
    return normalized == 'image/jpeg' ||
        normalized == 'image/png' ||
        normalized == 'image/webp' ||
        normalized == 'image/heic' ||
        normalized == 'image/heif';
  }

  bool _isGenericBinaryContentType(String contentType) {
    final normalized = _normalizedContentType(contentType);
    return normalized == 'application/octet-stream' ||
        normalized == 'binary/octet-stream' ||
        normalized == 'application/x-binary';
  }

  String _normalizedContentType(String contentType) =>
      contentType.split(';').first.trim().toLowerCase();

  Future<String?> _detectSourceImageContentType(
    String path, {
    required String unavailableMessage,
  }) => _detectSourceImageContentTypeImpl(
    this,
    path,
    unavailableMessage: unavailableMessage,
  );

  Future<List<int>> _sourceImageHeader(
    String path, {
    required String unavailableMessage,
  }) => _sourceImageHeaderImpl(
    this,
    path,
    unavailableMessage: unavailableMessage,
  );

  Future<int> _uploadImageSizeBytes(
    String path, {
    required String unavailableMessage,
  }) => _uploadImageSizeBytesImpl(
    this,
    path,
    unavailableMessage: unavailableMessage,
  );
}
