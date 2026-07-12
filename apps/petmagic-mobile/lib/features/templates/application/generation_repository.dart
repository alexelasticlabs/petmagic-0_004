import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/features/pets/domain/pet_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_results.dart';

final templateGenerationRepositoryProvider = Provider<GenerationRepository>((
  ref,
) {
  throw StateError(
    'GenerationRepository is not bound. Add the app composition overrides.',
  );
});

abstract interface class GenerationRepository {
  TemplateGenerationResult parseRealtimePayload(Map<String, dynamic> payload);

  Future<TemplateGenerationResult> startGeneration({
    required String templateId,
    required XFile sourceImage,
    int? expectedTemplateVersion,
    String? correlationId,
    CancelToken? cancelToken,
  });
  Future<TemplateGenerationResult> fetchGeneration(
    String generationId, {
    String? correlationId,
    CancelToken? cancelToken,
  });
  Future<GenerationCancelResult> cancelGeneration(
    String generationId, {
    String? correlationId,
    CancelToken? cancelToken,
  });
  Future<CompatibleGenerationTemplates> fetchCompatibleTemplates(
    String resultId, {
    CancelToken? cancelToken,
  });
  Future<TemplateGenerationResult> startGenerationFromResult({
    required String parentGenerationResultId,
    required String templateId,
    int? expectedTemplateVersion,
    String? correlationId,
    CancelToken? cancelToken,
  });
  Future<TemplateGenerationResult> generateSimilar({
    required String sourceGenerationId,
    String variationStrength = 'medium',
    String? correlationId,
    CancelToken? cancelToken,
  });
  Future<TemplateGenerationResult> startGenerationFromPet({
    required String petId,
    String? petPhotoId,
    required String templateId,
    int? expectedTemplateVersion,
    String? correlationId,
    CancelToken? cancelToken,
  });
  Future<List<PetProfile>> fetchPets({CancelToken? cancelToken});
  Future<PetProfile> createPet({
    required String name,
    required String type,
    String? breed,
    CancelToken? cancelToken,
  });
  Future<PetProfile> updatePet({
    required String petId,
    required String name,
    required String type,
    String? breed,
    CancelToken? cancelToken,
  });
  Future<void> deletePet(String petId, {CancelToken? cancelToken});
  Future<PetPhoto> uploadPetPhoto({
    required String petId,
    required XFile photo,
    CancelToken? cancelToken,
  });
  Future<List<PetPhoto>> fetchPetPhotos(
    String petId, {
    CancelToken? cancelToken,
  });
  Future<PetPhoto> setPetPhotoAsAvatar({
    required String petId,
    required String photoId,
    CancelToken? cancelToken,
  });
  Future<PetPhoto> setPetPhotoFavorite({
    required String petId,
    required String photoId,
    required bool isFavorite,
    CancelToken? cancelToken,
  });
  Future<void> deletePetPhoto({
    required String petId,
    required String photoId,
    CancelToken? cancelToken,
  });
  Future<List<TemplateGenerationResult>> fetchPetGenerations(
    String petId, {
    CancelToken? cancelToken,
  });
  Future<void> recordTemplateAnalyticsEvent({
    required String templateId,
    required String eventType,
    String source = 'mobile',
    String? generationId,
    Map<String, Object?>? metadata,
    CancelToken? cancelToken,
  });
  Future<RemoveGenerationWatermarkResult> removeWatermark(
    String generationId, {
    String paymentMethod = 'credit',
    CancelToken? cancelToken,
  });
  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? generationId,
    Map<String, Object?> metadata = const {},
    CancelToken? cancelToken,
  });
  Future<GenerationMediaAccessResult> fetchDownloadUrl(
    String generationId, {
    CancelToken? cancelToken,
  });
  Future<GenerationMediaAccessResult> fetchShareUrl(
    String generationId, {
    CancelToken? cancelToken,
  });
  Future<List<TemplateGenerationResult>?> readCachedGenerations({
    String? status,
  });
  Future<TemplateGenerationResult?> readCachedGeneration(String generationId);
  Future<int?> readCachedUnreadGenerationCount();
  Future<({String generationId, String correlationId})?> readActiveGeneration();
  Future<void> rememberActiveGeneration({
    required String generationId,
    String? correlationId,
  });
  Future<void> clearActiveGeneration(String generationId);
  Future<void> clearLocalCache();
  Future<List<TemplateGenerationResult>> fetchGenerations({
    String? status,
    int? skip,
    int? take,
    CancelToken? cancelToken,
  });
  Future<TemplateGenerationGalleryPage> fetchGenerationPage({
    String? status,
    String? cursor,
    int? take,
    CancelToken? cancelToken,
  });
  Future<int> fetchUnreadGenerationCount({CancelToken? cancelToken});
  Future<void> markGenerationRead(
    String generationId, {
    CancelToken? cancelToken,
  });
  Future<void> deleteGeneration(
    String generationId, {
    CancelToken? cancelToken,
  });
  Future<void> upsertCachedGeneration(TemplateGenerationResult generation);
  Future<void> submitGenerationFeedback({
    required String generationId,
    required int rating,
    List<String> selectedReasons = const [],
    String? comment,
    double? inputPhotoQualityScore,
  });
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
  });
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
    String? appVersion,
    String? locale,
  });
  Future<void> unregisterPushToken(String token);
}
