import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_dtos.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/shared/files/file_name_sanitizer.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';
import 'package:petmagic_mobile/shared/files/upload_media_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'template_generation_dtos.dart';

final templateGenerationSharedPreferencesProvider =
    Provider<SharedPreferencesAsync>((ref) => SharedPreferencesAsync());

final templateGenerationRepositoryProvider =
    Provider<TemplateGenerationRepository>((ref) {
      return TemplateGenerationRepository(
        dio: ref.watch(dioProvider),
        sessionStorage: ref.watch(authSessionStorageProvider),
        preferences: ref.watch(templateGenerationSharedPreferencesProvider),
        authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
        imageUploadOptimizer: const ImageUploadOptimizer(),
      );
    });

class TemplateGenerationRepository {
  TemplateGenerationRepository({
    required Dio dio,
    required AuthSessionStorage sessionStorage,
    required SharedPreferencesAsync preferences,
    ImageUploadOptimizer? imageUploadOptimizer,
    AuthSessionCoordinator? authSessionCoordinator,
  }) : _dio = dio,
       _preferences = preferences,
       _imageUploadOptimizer =
           imageUploadOptimizer ?? const ImageUploadOptimizer(),
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage);

  static const _generationsCachePrefix = 'templates_generations_v1:';
  static const _unreadCountCacheKey = 'templates_generations_unread_v1';
  static const _activeGenerationIdKey = 'templates_active_generation_id_v1';
  static const _activeGenerationCorrelationIdKey =
      'templates_active_generation_correlation_id_v1';
  static const _maxSourceImageBytes = 12 * 1024 * 1024;
  static const _maxPetPhotoBytes = UploadMediaPolicy.petPhotoMaxBytes;
  static const _cacheAllStatusKey = 'all';
  static const _cacheStatuses = <String>[
    _cacheAllStatusKey,
    'active',
    'completed',
    'failed',
  ];
  static final Random _correlationRandom = Random.secure();

  final Dio _dio;
  final SharedPreferencesAsync _preferences;
  final ImageUploadOptimizer _imageUploadOptimizer;
  final AuthSessionCoordinator _authSessionCoordinator;

  Future<TemplateGenerationResult> startGeneration({
    required String templateId,
    required XFile sourceImage,
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
    if (!_isAllowedImageContentType(declaredContentType) &&
        !_isGenericBinaryContentType(declaredContentType)) {
      throw const AppException('templates.source_image_type_not_allowed');
    }

    final fileSize = await _uploadImageSizeBytes(
      sourceImage.path,
      unavailableMessage: 'templates.source_image_unavailable',
    );
    if (fileSize <= 0) {
      throw const AppException('templates.source_image_empty');
    }
    if (fileSize > _maxSourceImageBytes) {
      throw const AppException('templates.source_image_too_large');
    }

    final contentType = await _detectSourceImageContentType(
      sourceImage.path,
      unavailableMessage: 'templates.source_image_unavailable',
    );
    if (contentType == null) {
      throw const AppException('templates.source_image_type_not_allowed');
    }

    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) async => _dio.post<Map<String, dynamic>>(
        '/api/templates/$encodedTemplateId/generations',
        data: FormData.fromMap({
          'sourceImage': await MultipartFile.fromFile(
            sourceImage.path,
            filename: fileName,
            contentType: MediaType.parse(contentType),
          ),
        }),
        options: authenticatedMultipartRequestOptions(
          session.accessToken,
          correlationId: correlationId,
        ),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );

    return TemplateGenerationDto.fromJson(response.data ?? const {}).toDomain();
  }

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

  Future<TemplateGenerationResult> startGenerationFromResult({
    required String parentGenerationResultId,
    required String templateId,
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/templates/generations/from-result',
        data: {
          'parentGenerationResultId': parentGenerationResultId,
          'templateId': templateId,
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

  Future<TemplateGenerationResult> startGenerationFromPet({
    required String petId,
    String? petPhotoId,
    required String templateId,
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

  Future<PetPhoto> uploadPetPhoto({
    required String petId,
    required XFile photo,
    CancelToken? cancelToken,
  }) async {
    OptimizedUploadFile? optimizedPhoto;
    try {
      optimizedPhoto = await _imageUploadOptimizer.optimizeForPetPhoto(
        photo,
        cancelToken: cancelToken,
      );
      final uploadFile = optimizedPhoto.file;
      final encodedPetId = _apiPathSegment(petId);
      final rawFileName = uploadFile.name.isNotEmpty
          ? uploadFile.name
          : uploadFile.path.split(Platform.pathSeparator).last;
      final fileName = _safeSourceImageFileName(rawFileName);
      final declaredContentType =
          uploadFile.mimeType ?? _resolveImageContentType(fileName);
      if (!_isAllowedImageContentType(declaredContentType) &&
          !_isGenericBinaryContentType(declaredContentType)) {
        throw const AppException('pets.photo_type_not_allowed');
      }

      final fileSize = await _uploadImageSizeBytes(
        uploadFile.path,
        unavailableMessage: 'pets.photo_type_not_allowed',
      );
      if (fileSize <= 0 || fileSize > _maxPetPhotoBytes) {
        throw const AppException('pets.photo_type_not_allowed');
      }

      final contentType = await _detectSourceImageContentType(
        uploadFile.path,
        unavailableMessage: 'pets.photo_type_not_allowed',
      );
      if (contentType == null) {
        throw const AppException('pets.photo_type_not_allowed');
      }

      final response = await _authorizedRequest<Map<String, dynamic>>(
        (session) async => _dio.post<Map<String, dynamic>>(
          '/api/pets/$encodedPetId/photos',
          data: FormData.fromMap({
            'photo': await MultipartFile.fromFile(
              uploadFile.path,
              filename: fileName,
              contentType: MediaType.parse(contentType),
            ),
          }),
          options: authenticatedMultipartRequestOptions(session.accessToken),
          cancelToken: cancelToken,
        ),
        retryTransientFailures: false,
      );

      return PetPhoto.fromJson(response.data ?? const {});
    } finally {
      await optimizedPhoto?.dispose();
    }
  }

  Future<List<PetPhoto>> fetchPetPhotos(
    String petId, {
    CancelToken? cancelToken,
  }) async {
    final encodedPetId = _apiPathSegment(petId);
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.get<List<dynamic>>(
        '/api/pets/$encodedPetId/photos',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );

    return (response.data ?? const [])
        .whereType<Map>()
        .map((item) => PetPhoto.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<PetPhoto> setPetPhotoAsAvatar({
    required String petId,
    required String photoId,
    CancelToken? cancelToken,
  }) async {
    final encodedPetId = _apiPathSegment(petId);
    final encodedPhotoId = _apiPathSegment(photoId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/pets/$encodedPetId/photos/$encodedPhotoId/set-avatar',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );

    return PetPhoto.fromJson(response.data ?? const {});
  }

  Future<PetPhoto> setPetPhotoFavorite({
    required String petId,
    required String photoId,
    required bool isFavorite,
    CancelToken? cancelToken,
  }) async {
    final encodedPetId = _apiPathSegment(petId);
    final encodedPhotoId = _apiPathSegment(photoId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/pets/$encodedPetId/photos/$encodedPhotoId/favorite',
        data: {'isFavorite': isFavorite},
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );

    return PetPhoto.fromJson(response.data ?? const {});
  }

  Future<void> deletePetPhoto({
    required String petId,
    required String photoId,
    CancelToken? cancelToken,
  }) async {
    final encodedPetId = _apiPathSegment(petId);
    final encodedPhotoId = _apiPathSegment(photoId);
    await _authorizedRequest<void>(
      (session) => _dio.delete<void>(
        '/api/pets/$encodedPetId/photos/$encodedPhotoId',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );
  }

  Future<List<TemplateGenerationResult>> fetchPetGenerations(
    String petId, {
    CancelToken? cancelToken,
  }) async {
    final encodedPetId = _apiPathSegment(petId);
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.get<List<dynamic>>(
        '/api/pets/$encodedPetId/generations',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );

    return (response.data ?? const [])
        .whereType<Map>()
        .map(
          (item) => TemplateGenerationDto.fromJson(
            Map<String, dynamic>.from(item),
          ).toDomain(),
        )
        .toList(growable: false);
  }

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

  Future<GenerationMediaAccessResult> fetchDownloadUrl(
    String generationId, {
    CancelToken? cancelToken,
  }) {
    final encodedGenerationId = _apiPathSegment(generationId);
    return _fetchMediaAccess(
      generationId,
      '/api/templates/generations/$encodedGenerationId/download',
      method: 'GET',
      cancelToken: cancelToken,
    );
  }

  Future<GenerationMediaAccessResult> fetchShareUrl(
    String generationId, {
    CancelToken? cancelToken,
  }) {
    final encodedGenerationId = _apiPathSegment(generationId);
    return _fetchMediaAccess(
      generationId,
      '/api/templates/generations/$encodedGenerationId/share',
      method: 'POST',
      cancelToken: cancelToken,
    );
  }

  Future<GenerationMediaAccessResult> _fetchMediaAccess(
    String generationId,
    String path, {
    required String method,
    CancelToken? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.request<Map<String, dynamic>>(
        path,
        options: authenticatedRequestOptions(
          session.accessToken,
        ).copyWith(method: method),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );

    return GenerationMediaAccessResult.fromJson(response.data ?? const {});
  }

  Future<List<TemplateGenerationResult>?> readCachedGenerations({
    String? status,
  }) async {
    try {
      final raw = await _preferences.getString(_cacheKeyForStatus(status));
      if (raw == null || raw.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return null;
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => TemplateGenerationDto.fromJson(
              Map<String, dynamic>.from(item),
            ).toDomain(),
          )
          .toList(growable: false);
    } on Object {
      return null;
    }
  }

  Future<TemplateGenerationResult?> readCachedGeneration(
    String generationId,
  ) async {
    for (final status in _cacheStatuses) {
      final items = await readCachedGenerations(
        status: status == _cacheAllStatusKey ? null : status,
      );
      if (items == null || items.isEmpty) {
        continue;
      }

      for (final item in items) {
        if (item.generationId == generationId) {
          return item;
        }
      }
    }

    return null;
  }

  Future<int?> readCachedUnreadGenerationCount() async {
    try {
      return await _preferences.getInt(_unreadCountCacheKey);
    } on Object {
      return null;
    }
  }

  Future<({String generationId, String correlationId})?>
  readActiveGeneration() async {
    try {
      final generationId = await _preferences.getString(_activeGenerationIdKey);
      if (generationId == null || generationId.trim().isEmpty) {
        return null;
      }

      final persistedCorrelationId = await _preferences.getString(
        _activeGenerationCorrelationIdKey,
      );
      final normalizedGenerationId = generationId.trim();
      final correlationId =
          persistedCorrelationId == null ||
              persistedCorrelationId.trim().isEmpty
          ? _createGenerationCorrelationId()
          : persistedCorrelationId.trim();
      if (persistedCorrelationId == null ||
          persistedCorrelationId.trim().isEmpty) {
        await rememberActiveGeneration(
          generationId: normalizedGenerationId,
          correlationId: correlationId,
        );
      }

      return (
        generationId: normalizedGenerationId,
        correlationId: correlationId,
      );
    } on Object {
      return null;
    }
  }

  Future<void> rememberActiveGeneration({
    required String generationId,
    String? correlationId,
  }) async {
    try {
      final normalizedGenerationId = generationId.trim();
      if (normalizedGenerationId.isEmpty) {
        return;
      }

      await _preferences.setString(
        _activeGenerationIdKey,
        normalizedGenerationId,
      );
      final trimmedCorrelationId = correlationId?.trim();
      final normalizedCorrelationId =
          trimmedCorrelationId == null || trimmedCorrelationId.isEmpty
          ? _createGenerationCorrelationId()
          : trimmedCorrelationId;
      await _preferences.setString(
        _activeGenerationCorrelationIdKey,
        normalizedCorrelationId,
      );
    } on Object {
      // Keep generation flow functional even if local persistence fails.
    }
  }

  Future<void> clearActiveGeneration(String generationId) async {
    try {
      final current = await _preferences.getString(_activeGenerationIdKey);
      if (current != null && current != generationId) {
        return;
      }

      await _preferences.remove(_activeGenerationIdKey);
      await _preferences.remove(_activeGenerationCorrelationIdKey);
    } on Object {
      // Keep cleanup best-effort.
    }
  }

  Future<void> clearLocalCache() async {
    for (final status in _cacheStatuses) {
      final key = _cacheKeyForStatus(
        status == _cacheAllStatusKey ? null : status,
      );
      try {
        await _preferences.remove(key);
      } on Object {
        // Keep best-effort semantics for logout cleanup.
      }
    }

    try {
      await _preferences.remove(_unreadCountCacheKey);
    } on Object {
      // Keep best-effort semantics for logout cleanup.
    }

    try {
      await _preferences.remove(_activeGenerationIdKey);
      await _preferences.remove(_activeGenerationCorrelationIdKey);
    } on Object {
      // Keep best-effort semantics for logout cleanup.
    }
  }

  String _createGenerationCorrelationId() {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final suffix = _correlationRandom.nextInt(1 << 24).toRadixString(16);
    return 'generation-$now-$suffix';
  }

  Future<List<TemplateGenerationResult>> fetchGenerations({
    String? status,
    int? skip,
    int? take,
    CancelToken? cancelToken,
  }) async {
    final queryParameters = <String, Object?>{};
    if (status != null && status.isNotEmpty) {
      queryParameters['status'] = status;
    }
    if (skip != null) {
      queryParameters['skip'] = skip;
    }
    if (take != null) {
      queryParameters['take'] = take;
    }

    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.get<List<dynamic>>(
        '/api/templates/generations',
        queryParameters: queryParameters,
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );

    final itemsJson = (response.data ?? const [])
        .whereType<Map>()
        .map(Map<String, Object?>.from)
        .toList(growable: false);

    await _writeCachedGenerations(status: status, items: itemsJson);

    return itemsJson
        .whereType<Map>()
        .map(
          (item) => TemplateGenerationDto.fromJson(
            Map<String, dynamic>.from(item),
          ).toDomain(),
        )
        .toList(growable: false);
  }

  Future<int> fetchUnreadGenerationCount({CancelToken? cancelToken}) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/templates/generations/unread-count',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );

    final count = (response.data?['count'] as num?)?.toInt() ?? 0;
    await _writeCachedUnreadGenerationCount(count);
    return count;
  }

  Future<void> markGenerationRead(
    String generationId, {
    CancelToken? cancelToken,
  }) async {
    final encodedGenerationId = _apiPathSegment(generationId);
    await _authorizedRequest<void>(
      (session) => _dio.post<void>(
        '/api/templates/generations/$encodedGenerationId/mark-read',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );

    await _markCachedGenerationRead(generationId);
  }

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

  Future<void> upsertCachedGeneration(
    TemplateGenerationResult generation,
  ) async {
    for (final status in _cacheStatuses) {
      try {
        final cacheStatus = status == _cacheAllStatusKey ? null : status;
        final key = _cacheKeyForStatus(cacheStatus);
        final raw = await _preferences.getString(key);
        if (raw == null || raw.isEmpty) {
          continue;
        }

        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          continue;
        }

        final updated = <Map<String, Object?>>[];
        for (final entry in decoded.whereType<Map>()) {
          final cachedGeneration = Map<String, Object?>.from(entry);
          if (cachedGeneration['generationId'] != generation.generationId) {
            updated.add(cachedGeneration);
          }
        }

        if (_matchesCachedGenerationStatus(generation, cacheStatus)) {
          updated.insert(0, _generationToCachedJson(generation));
        }

        updated.sort((left, right) {
          final leftUpdated = DateTime.tryParse(
            left['updatedAtUtc'] as String? ?? '',
          );
          final rightUpdated = DateTime.tryParse(
            right['updatedAtUtc'] as String? ?? '',
          );
          if (leftUpdated == null && rightUpdated == null) {
            return 0;
          }
          if (leftUpdated == null) {
            return 1;
          }
          if (rightUpdated == null) {
            return -1;
          }
          return rightUpdated.compareTo(leftUpdated);
        });

        final bounded = updated.take(50).toList(growable: false);
        await _preferences.setString(key, jsonEncode(bounded));
      } on Object {
        // Persistent cache updates are best-effort; realtime remains in memory.
      }
    }
  }

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
      'appVersion': '1.0.0',
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
  }) async {
    try {
      await _preferences.setString(
        _cacheKeyForStatus(status),
        jsonEncode(items),
      );
    } on Object {
      // Ignore local cache write errors to keep network flow stable.
    }
  }

  Future<void> _writeCachedUnreadGenerationCount(int count) async {
    try {
      await _preferences.setInt(_unreadCountCacheKey, count);
    } on Object {
      // Ignore local cache write errors to keep network flow stable.
    }
  }

  String _cacheKeyForStatus(String? status) {
    final normalized = (status == null || status.trim().isEmpty)
        ? _cacheAllStatusKey
        : status.trim().toLowerCase();
    return '$_generationsCachePrefix$normalized';
  }

  bool _matchesCachedGenerationStatus(
    TemplateGenerationResult generation,
    String? status,
  ) {
    if (status == null || status.isEmpty) {
      return true;
    }

    return switch (status.toLowerCase()) {
      'active' => !generation.isTerminal,
      'completed' => generation.isCompleted,
      'failed' => generation.isFailed,
      _ => true,
    };
  }

  Map<String, Object?> _generationToCachedJson(
    TemplateGenerationResult generation,
  ) {
    return {
      'generationId': generation.generationId,
      'userId': generation.userId,
      'templateId': generation.templateId,
      'status': generation.status.name,
      'tokenCost': generation.tokenCost,
      'sourceImageAsset': generation.sourceImageAsset == null
          ? null
          : {
              'url': generation.sourceImageAsset!.url,
              'fileName': generation.sourceImageAsset!.fileName,
              'contentType': generation.sourceImageAsset!.contentType,
              'fileSizeBytes': generation.sourceImageAsset!.fileSizeBytes,
              'durationSeconds': generation.sourceImageAsset!.durationSeconds,
            },
      'normalizedImageUrl': generation.normalizedImageUrl,
      'referenceMotionUrl': generation.referenceMotionUrl,
      'outputUrl': generation.outputUrl,
      'attemptCount': generation.attemptCount,
      'usedPreprocessingModel': generation.usedPreprocessingModel,
      'usedKlingModel': generation.usedKlingModel,
      'outputVideoDurationSeconds': generation.outputVideoDurationSeconds,
      'failureCode': generation.failureCode,
      'failureMessage': generation.failureMessage,
      'createdAtUtc': generation.createdAtUtc.toUtc().toIso8601String(),
      'updatedAtUtc': generation.updatedAtUtc.toUtc().toIso8601String(),
      'startedAtUtc': generation.startedAtUtc?.toUtc().toIso8601String(),
      'preprocessingCompletedAtUtc': generation.preprocessingCompletedAtUtc
          ?.toUtc()
          .toIso8601String(),
      'motionGenerationCompletedAtUtc': generation
          .motionGenerationCompletedAtUtc
          ?.toUtc()
          .toIso8601String(),
      'mediaImportCompletedAtUtc': generation.mediaImportCompletedAtUtc
          ?.toUtc()
          .toIso8601String(),
      'completedAtUtc': generation.completedAtUtc?.toUtc().toIso8601String(),
      'templateTitle': generation.templateTitle,
      'templateType': generation.templateType,
      'stage': generation.stage,
      'progressPercent': generation.progressPercent,
      'estimatedDurationLabel': generation.estimatedDurationLabel,
      'chargedAtUtc': generation.chargedAtUtc?.toUtc().toIso8601String(),
      'refundedAtUtc': generation.refundedAtUtc?.toUtc().toIso8601String(),
      'userMediaExpired': generation.userMediaExpired,
      'isUnread': generation.isUnread,
      'queuePosition': generation.queuePosition,
      'estimatedWaitSeconds': generation.estimatedWaitSeconds,
      'hasWatermark': generation.hasWatermark,
      'canRemoveWatermark': generation.canRemoveWatermark,
      'isWatermarkRemoved': generation.isWatermarkRemoved,
      'removeWatermarkCostCredits': generation.removeWatermarkCostCredits,
      'userPlan': generation.userPlan,
      'watermarkMessage': generation.watermarkMessage,
      'supportsGenerateSimilar': generation.supportsGenerateSimilar,
      'inputSourceType': generation.inputSourceType,
      'inputMediaAssetId': generation.inputMediaAssetId,
      'resultMediaAssetId': generation.resultMediaAssetId,
      'inputPreviewUrl': generation.inputPreviewUrl,
      'resultPreviewUrl': generation.resultPreviewUrl,
      'canCompareBeforeAfter': generation.canCompareBeforeAfter,
      'petId': generation.petId,
      'petPhotoId': generation.petPhotoId,
    };
  }

  Future<void> _markCachedGenerationRead(String generationId) async {
    for (final status in _cacheStatuses) {
      try {
        final key = _cacheKeyForStatus(
          status == _cacheAllStatusKey ? null : status,
        );
        final raw = await _preferences.getString(key);
        if (raw == null || raw.isEmpty) {
          continue;
        }

        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          continue;
        }

        var changed = false;
        final updated = decoded
            .map((entry) {
              if (entry is! Map) {
                return entry;
              }

              final generation = Map<String, Object?>.from(entry);
              if (generation['generationId'] != generationId) {
                return generation;
              }

              if (generation['isUnread'] == false) {
                return generation;
              }

              changed = true;
              return {...generation, 'isUnread': false};
            })
            .toList(growable: false);

        if (changed) {
          await _preferences.setString(key, jsonEncode(updated));
        }
      } on Object {
        // Keep mark-read cache mutation best-effort per bucket.
      }
    }

    final unread = await readCachedUnreadGenerationCount();
    if (unread != null && unread > 0) {
      await _writeCachedUnreadGenerationCount(unread - 1);
    }
  }

  Future<void> _removeCachedGeneration(String generationId) async {
    var removedUnread = false;

    for (final status in _cacheStatuses) {
      try {
        final key = _cacheKeyForStatus(
          status == _cacheAllStatusKey ? null : status,
        );
        final raw = await _preferences.getString(key);
        if (raw == null || raw.isEmpty) {
          continue;
        }

        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          continue;
        }

        var changed = false;
        final updated = <Map<String, Object?>>[];
        for (final entry in decoded.whereType<Map>()) {
          final generation = Map<String, Object?>.from(entry);
          if (generation['generationId'] == generationId) {
            changed = true;
            if (generation['isUnread'] == true) {
              removedUnread = true;
            }
            continue;
          }
          updated.add(generation);
        }

        if (changed) {
          await _preferences.setString(key, jsonEncode(updated));
        }
      } on Object {
        // Keep delete cache mutation best-effort per bucket.
      }
    }

    if (removedUnread) {
      final unread = await readCachedUnreadGenerationCount();
      if (unread != null && unread > 0) {
        await _writeCachedUnreadGenerationCount(unread - 1);
      }
    }
  }

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

  String _resolveImageContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.heic')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

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
  }) async {
    final header = await _sourceImageHeader(
      path,
      unavailableMessage: unavailableMessage,
    );
    if (_startsWith(header, const [0xFF, 0xD8, 0xFF])) {
      return 'image/jpeg';
    }
    if (_startsWith(header, const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ])) {
      return 'image/png';
    }
    if (header.length >= 12 &&
        _asciiEquals(header, 0, 'RIFF') &&
        _asciiEquals(header, 8, 'WEBP')) {
      return 'image/webp';
    }
    if (header.length >= 12 && _asciiEquals(header, 4, 'ftyp')) {
      final brand = String.fromCharCodes(header.skip(8).take(4)).toLowerCase();
      const heicBrands = {'heic', 'heix', 'hevc', 'hevx', 'heis', 'heim'};
      const heifBrands = {'mif1', 'msf1'};
      if (heicBrands.contains(brand)) {
        return 'image/heic';
      }
      if (heifBrands.contains(brand)) {
        return 'image/heif';
      }
    }

    return null;
  }

  Future<List<int>> _sourceImageHeader(
    String path, {
    required String unavailableMessage,
  }) async {
    try {
      final chunks = await File(path).openRead(0, 32).toList();
      return [for (final chunk in chunks) ...chunk];
    } on FileSystemException catch (error) {
      throw AppException(unavailableMessage, cause: error);
    }
  }

  bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) {
      return false;
    }
    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) {
        return false;
      }
    }
    return true;
  }

  bool _asciiEquals(List<int> bytes, int offset, String value) {
    if (bytes.length < offset + value.length) {
      return false;
    }
    for (var index = 0; index < value.length; index++) {
      if (bytes[offset + index] != value.codeUnitAt(index)) {
        return false;
      }
    }
    return true;
  }

  Future<int> _uploadImageSizeBytes(
    String path, {
    required String unavailableMessage,
  }) async {
    try {
      return await File(path).length();
    } on FileSystemException catch (error) {
      throw AppException(unavailableMessage, cause: error);
    }
  }
}
