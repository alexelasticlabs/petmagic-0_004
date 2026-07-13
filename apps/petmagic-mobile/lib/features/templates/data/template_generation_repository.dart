export 'package:petmagic_mobile/features/templates/application/generation_repository.dart'
    show GenerationRepository, templateGenerationRepositoryProvider;
export 'package:petmagic_mobile/features/pets/domain/pet_models.dart';
export 'package:petmagic_mobile/features/templates/domain/template_generation_results.dart';

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/network/dio_request_cancellation.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/core/files/local_media_file.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/core/network/request_identity.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/core/auth/auth_session.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_dtos.dart';
import 'package:petmagic_mobile/features/templates/data/generation_repository_error_mapper.dart';
import 'package:petmagic_mobile/features/templates/data/generation_engagement_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/generation_active_state_store.dart';
import 'package:petmagic_mobile/features/templates/data/generation_cache_codec.dart';
import 'package:petmagic_mobile/features/templates/data/generation_cache_storage.dart';
import 'package:petmagic_mobile/features/templates/data/generation_cache_reader.dart';
import 'package:petmagic_mobile/features/templates/data/generation_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/generation_source_upload_preparer.dart';
import 'package:petmagic_mobile/features/templates/data/pet_profile_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/template_image_upload_support.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_result_dto_mapper.dart';
import 'package:petmagic_mobile/features/templates/data/pet_dto_mapper.dart';
import 'package:petmagic_mobile/features/pets/domain/pet_models.dart';
import 'package:petmagic_mobile/features/templates/application/generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_results.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';
import 'package:petmagic_mobile/shared/files/upload_media_policy.dart';
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

final dioTemplateGenerationRepositoryProvider =
    Provider<TemplateGenerationRepository>((ref) {
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
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage) {
    _engagementRemoteDataSource = GenerationEngagementRemoteDataSource(
      dio: dio,
      authSessionCoordinator: _authSessionCoordinator,
      errorMapper: _errorMapper,
    );
    _generationRemoteDataSource = GenerationRemoteDataSource(
      dio: dio,
      authSessionCoordinator: _authSessionCoordinator,
      errorMapper: _errorMapper,
      sourceUploadPreparer: GenerationSourceUploadPreparer(
        imageUploadOptimizer: _imageUploadOptimizer,
      ),
    );
    _petProfileRemoteDataSource = PetProfileRemoteDataSource(
      dio: dio,
      authSessionCoordinator: _authSessionCoordinator,
      errorMapper: _errorMapper,
    );
    _cacheStorage = GenerationCacheStorage(preferences: _preferences);
    _cacheReader = GenerationCacheReader(
      sessionStorage: _sessionStorage,
      preferences: _preferences,
      storage: _cacheStorage,
    );
    _activeStateStore = GenerationActiveStateStore(
      preferences: _preferences,
      secureStorage: _secureStorage,
      readScope: _cacheReader.readScope,
      readCacheString: _cacheStorage.readString,
      scopeFingerprint: GenerationCacheReader.scopeFingerprint,
      createCorrelationId: _createGenerationCorrelationId,
    );
  }

  static const _unreadCountCacheKey = 'templates_generations_unread_v1';
  static const _maxPetPhotoBytes = UploadMediaPolicy.petPhotoMaxBytes;
  final Dio _dio;
  final AuthSessionStore _sessionStorage;
  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secureStorage;
  final ImageUploadOptimizer _imageUploadOptimizer;
  final AuthSessionCoordinator _authSessionCoordinator;
  final GenerationRepositoryErrorMapper _errorMapper =
      const GenerationRepositoryErrorMapper();
  late final GenerationEngagementRemoteDataSource _engagementRemoteDataSource;
  late final GenerationRemoteDataSource _generationRemoteDataSource;
  late final PetProfileRemoteDataSource _petProfileRemoteDataSource;
  late final GenerationActiveStateStore _activeStateStore;
  late final GenerationCacheStorage _cacheStorage;
  late final GenerationCacheReader _cacheReader;

  @override
  TemplateGenerationResult parseRealtimePayload(Map<String, dynamic> payload) {
    return TemplateGenerationDto.fromJson(payload).toDomain();
  }

  @override
  Future<TemplateGenerationResult> startGeneration({
    required String templateId,
    required LocalMediaFile sourceImage,
    int? expectedTemplateVersion,
    String? correlationId,
    RequestCancellation? cancelToken,
  }) async {
    return _generationRemoteDataSource.startGeneration(
      templateId: templateId,
      sourceImage: sourceImage,
      expectedTemplateVersion: expectedTemplateVersion,
      correlationId: correlationId,
      cancelToken: cancelToken,
      retryTransientFailures: false,
    );
  }

  @override
  Future<TemplateGenerationResult> fetchGeneration(
    String generationId, {
    String? correlationId,
    RequestCancellation? cancelToken,
  }) => _generationRemoteDataSource.fetchGeneration(
    generationId,
    correlationId: correlationId,
    cancelToken: cancelToken,
  );

  @override
  Future<GenerationCancelResult> cancelGeneration(
    String generationId, {
    String? correlationId,
    RequestCancellation? cancelToken,
  }) async {
    final result = await _generationRemoteDataSource.cancelGeneration(
      generationId,
      correlationId: correlationId,
      cancelToken: cancelToken,
    );
    await _upsertCachedGeneration(this, result.generation);
    if (result.generation.isTerminal) {
      await clearActiveGeneration(result.generation.generationId);
    }

    return result;
  }

  @override
  Future<CompatibleGenerationTemplates> fetchCompatibleTemplates(
    String resultId, {
    RequestCancellation? cancelToken,
  }) => _generationRemoteDataSource.fetchCompatibleTemplates(
    resultId,
    cancelToken: cancelToken,
  );

  @override
  Future<TemplateGenerationResult> startGenerationFromResult({
    required String parentGenerationResultId,
    required String templateId,
    int? expectedTemplateVersion,
    String? correlationId,
    RequestCancellation? cancelToken,
  }) => _generationRemoteDataSource.startGenerationFromResult(
    parentGenerationResultId: parentGenerationResultId,
    templateId: templateId,
    expectedTemplateVersion: expectedTemplateVersion,
    correlationId: correlationId,
    cancelToken: cancelToken,
  );

  @override
  Future<TemplateGenerationResult> generateSimilar({
    required String sourceGenerationId,
    String variationStrength = 'medium',
    String? correlationId,
    RequestCancellation? cancelToken,
  }) => _generationRemoteDataSource.generateSimilar(
    sourceGenerationId: sourceGenerationId,
    variationStrength: variationStrength,
    correlationId: correlationId,
    cancelToken: cancelToken,
  );

  @override
  Future<TemplateGenerationResult> startGenerationFromPet({
    required String petId,
    String? petPhotoId,
    required String templateId,
    int? expectedTemplateVersion,
    String? correlationId,
    RequestCancellation? cancelToken,
  }) => _generationRemoteDataSource.startGenerationFromPet(
    petId: petId,
    petPhotoId: petPhotoId,
    templateId: templateId,
    expectedTemplateVersion: expectedTemplateVersion,
    correlationId: correlationId,
    cancelToken: cancelToken,
  );

  Future<List<PetProfile>> fetchPets({RequestCancellation? cancelToken}) =>
      _petProfileRemoteDataSource.fetchPets(cancelToken: cancelToken);

  Future<PetProfile> createPet({
    required String name,
    required String type,
    String? breed,
    RequestCancellation? cancelToken,
  }) => _petProfileRemoteDataSource.createPet(
    name: name,
    type: type,
    breed: breed,
    cancelToken: cancelToken,
  );

  Future<PetProfile> updatePet({
    required String petId,
    required String name,
    required String type,
    String? breed,
    RequestCancellation? cancelToken,
  }) => _petProfileRemoteDataSource.updatePet(
    petId: petId,
    name: name,
    type: type,
    breed: breed,
    cancelToken: cancelToken,
  );

  Future<void> deletePet(String petId, {RequestCancellation? cancelToken}) =>
      _petProfileRemoteDataSource.deletePet(petId, cancelToken: cancelToken);

  Future<PetPhoto> uploadPetPhoto({
    required String petId,
    required XFile photo,
    RequestCancellation? cancelToken,
  }) => _uploadPetPhoto(
    this,
    petId: petId,
    photo: photo,
    cancelToken: cancelToken,
  );

  Future<List<PetPhoto>> fetchPetPhotos(
    String petId, {
    RequestCancellation? cancelToken,
  }) => _fetchPetPhotos(this, petId: petId, cancelToken: cancelToken);

  Future<PetPhoto> setPetPhotoAsAvatar({
    required String petId,
    required String photoId,
    RequestCancellation? cancelToken,
  }) => _setPetPhotoAsAvatar(
    this,
    petId: petId,
    photoId: photoId,
    cancelToken: cancelToken,
  );

  Future<PetPhoto> setPetPhotoFavorite({
    required String petId,
    required String photoId,
    required bool isFavorite,
    RequestCancellation? cancelToken,
  }) => _setPetPhotoFavorite(
    this,
    petId: petId,
    photoId: photoId,
    isFavorite: isFavorite,
    cancelToken: cancelToken,
  );

  Future<void> deletePetPhoto({
    required String petId,
    required String photoId,
    RequestCancellation? cancelToken,
  }) => _deletePetPhoto(
    this,
    petId: petId,
    photoId: photoId,
    cancelToken: cancelToken,
  );

  Future<List<TemplateGenerationResult>> fetchPetGenerations(
    String petId, {
    RequestCancellation? cancelToken,
  }) => _fetchPetGenerations(this, petId: petId, cancelToken: cancelToken);

  @override
  Future<void> recordTemplateAnalyticsEvent({
    required String templateId,
    required String eventType,
    String source = 'mobile',
    String? generationId,
    Map<String, Object?>? metadata,
    RequestCancellation? cancelToken,
  }) => _engagementRemoteDataSource.recordAnalytics(
    templateId: templateId,
    eventType: eventType,
    source: source,
    generationId: generationId,
    metadata: metadata ?? const {},
    cancelToken: cancelToken,
  );

  @override
  Future<RemoveGenerationWatermarkResult> removeWatermark(
    String generationId, {
    String paymentMethod = 'credit',
    RequestCancellation? cancelToken,
  }) => _engagementRemoteDataSource.removeWatermark(
    generationId,
    paymentMethod: paymentMethod,
    cancelToken: cancelToken,
  );

  @override
  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? generationId,
    Map<String, Object?> metadata = const {},
    RequestCancellation? cancelToken,
  }) => _engagementRemoteDataSource.recordAnalytics(
    templateId: templateId,
    eventType: eventType,
    source: 'mobile',
    generationId: generationId,
    metadata: metadata,
    cancelToken: cancelToken,
  );

  @override
  Future<GenerationMediaAccessResult> fetchDownloadUrl(
    String generationId, {
    RequestCancellation? cancelToken,
  }) => _fetchDownloadUrl(this, generationId, cancelToken: cancelToken);

  @override
  Future<GenerationMediaAccessResult> fetchShareUrl(
    String generationId, {
    RequestCancellation? cancelToken,
  }) => _fetchShareUrl(this, generationId, cancelToken: cancelToken);

  @override
  Future<List<TemplateGenerationResult>?> readCachedGenerations({
    String? status,
  }) => _cacheReader.readGenerations(status: status);

  @override
  Future<TemplateGenerationResult?> readCachedGeneration(String generationId) =>
      _cacheReader.readGeneration(generationId);

  @override
  Future<int?> readCachedUnreadGenerationCount() =>
      _cacheReader.readUnreadCount();

  @override
  Future<({String generationId, String correlationId})?>
  readActiveGeneration() => _activeStateStore.read();

  @override
  Future<void> rememberActiveGeneration({
    required String generationId,
    String? correlationId,
  }) => _activeStateStore.remember(
    generationId: generationId,
    correlationId: correlationId,
  );

  @override
  Future<void> clearActiveGeneration(String generationId) =>
      _activeStateStore.clear(generationId);

  @override
  Future<void> clearLocalCache() => _activeStateStore.clearAll();

  String _createGenerationCorrelationId() =>
      RequestIdentity.createCorrelationId().replaceFirst(
        'flow-',
        'generation-',
      );

  Future<String?> _readCacheScope() => _cacheReader.readScope();

  @override
  Future<List<TemplateGenerationResult>> fetchGenerations({
    String? status,
    int? skip,
    int? take,
    RequestCancellation? cancelToken,
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
    RequestCancellation? cancelToken,
  }) => _fetchGenerationPage(
    this,
    status: status,
    cursor: cursor,
    take: take,
    cancelToken: cancelToken,
  );

  @override
  Future<int> fetchUnreadGenerationCount({RequestCancellation? cancelToken}) =>
      _fetchUnreadGenerationCount(this, cancelToken: cancelToken);

  @override
  Future<void> markGenerationRead(
    String generationId, {
    RequestCancellation? cancelToken,
  }) => _markGenerationRead(this, generationId, cancelToken: cancelToken);

  @override
  Future<void> deleteGeneration(
    String generationId, {
    RequestCancellation? cancelToken,
  }) async {
    await _generationRemoteDataSource.deleteGeneration(
      generationId,
      cancelToken: cancelToken,
      retryTransientFailures: false,
    );
    await _removeCachedGenerationImpl(this, generationId);
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
    await _engagementRemoteDataSource.submitGenerationFeedback(
      generationId: generationId,
      rating: rating,
      selectedReasons: selectedReasons,
      comment: comment,
      inputPhotoQualityScore: inputPhotoQualityScore,
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
    RequestCancellation? cancelToken,
    bool retryTransientFailures = false,
  }) => _engagementRemoteDataSource.submitFeedback(
    type: type,
    category: category,
    rating: rating,
    message: message,
    generationId: generationId,
    templateId: templateId,
    petId: petId,
    sourceScreen: sourceScreen,
    cancelToken: cancelToken,
    retryTransientFailures: retryTransientFailures,
  );

  @override
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
    String? appVersion,
    String? locale,
  }) async {
    await _engagementRemoteDataSource.registerPushToken(
      token: token,
      platform: platform,
      deviceId: deviceId,
      appVersion: appVersion,
      locale: locale,
      retryTransientFailures: false,
    );
  }

  @override
  Future<void> unregisterPushToken(String token) async {
    await _engagementRemoteDataSource.unregisterPushToken(
      token,
      retryTransientFailures: false,
    );
  }

  Future<void> _writeCachedGenerations({
    required String? status,
    required List<Map<String, Object?>> items,
  }) => _writeCachedGenerationsImpl(this, status: status, items: items);

  bool _matchesCachedGenerationStatus(
    TemplateGenerationResult generation,
    String? status,
  ) => GenerationCacheCodec.matchesStatus(generation, status);

  Map<String, Object?> _generationToCachedJson(
    TemplateGenerationResult generation,
  ) => GenerationCacheCodec.generationToJson(generation);

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
  }) => _errorMapper.map(error, fallbackMessage: fallbackMessage);

  String _apiPathSegment(String value) => Uri.encodeComponent(value);
}
