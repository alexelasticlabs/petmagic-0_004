import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/templates/data/generation_engagement_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_results.dart';

/// Implements engagement-facing repository methods while the concrete
/// repository remains responsible only for composition and orchestration.
mixin GenerationEngagementRepositoryDelegate {
  GenerationEngagementRemoteDataSource get engagementRemoteDataSource;

  Future<void> recordTemplateAnalyticsEvent({
    required String templateId,
    required String eventType,
    String source = 'mobile',
    String? generationId,
    Map<String, Object?>? metadata,
    RequestCancellation? cancelToken,
  }) => engagementRemoteDataSource.recordAnalytics(
    templateId: templateId,
    eventType: eventType,
    source: source,
    generationId: generationId,
    metadata: metadata ?? const {},
    cancelToken: cancelToken,
  );

  Future<RemoveGenerationWatermarkResult> removeWatermark(
    String generationId, {
    String paymentMethod = 'credit',
    RequestCancellation? cancelToken,
  }) => engagementRemoteDataSource.removeWatermark(
    generationId,
    paymentMethod: paymentMethod,
    cancelToken: cancelToken,
  );

  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? generationId,
    Map<String, Object?> metadata = const {},
    RequestCancellation? cancelToken,
  }) => engagementRemoteDataSource.recordAnalytics(
    templateId: templateId,
    eventType: eventType,
    source: 'mobile',
    generationId: generationId,
    metadata: metadata,
    cancelToken: cancelToken,
  );

  Future<void> submitGenerationFeedback({
    required String generationId,
    required int rating,
    List<String> selectedReasons = const [],
    String? comment,
    double? inputPhotoQualityScore,
  }) async {
    await engagementRemoteDataSource.submitGenerationFeedback(
      generationId: generationId,
      rating: rating,
      selectedReasons: selectedReasons,
      comment: comment,
      inputPhotoQualityScore: inputPhotoQualityScore,
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
    RequestCancellation? cancelToken,
    bool retryTransientFailures = false,
  }) => engagementRemoteDataSource.submitFeedback(
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

  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
    String? appVersion,
    String? locale,
  }) async {
    await engagementRemoteDataSource.registerPushToken(
      token: token,
      platform: platform,
      deviceId: deviceId,
      appVersion: appVersion,
      locale: locale,
      retryTransientFailures: false,
    );
  }

  Future<void> unregisterPushToken(String token) async {
    await engagementRemoteDataSource.unregisterPushToken(
      token,
      retryTransientFailures: false,
    );
  }
}
