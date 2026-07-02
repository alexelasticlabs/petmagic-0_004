import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

enum TemplateGenerationStatus {
  queued,
  uploading,
  processing,
  preprocessing,
  generating,
  finalizing,
  submittingToProvider,
  providerQueued,
  providerProcessing,
  importingMedia,
  completed,
  failed,
  cancelled,
}

TemplateGenerationStatus templateGenerationStatusFromApi(String value) {
  return switch (value.trim().toLowerCase()) {
    '1' => TemplateGenerationStatus.queued,
    '2' => TemplateGenerationStatus.processing,
    '3' => TemplateGenerationStatus.completed,
    '4' => TemplateGenerationStatus.failed,
    '5' => TemplateGenerationStatus.cancelled,
    '6' => TemplateGenerationStatus.processing,
    '7' => TemplateGenerationStatus.submittingToProvider,
    '8' => TemplateGenerationStatus.providerQueued,
    '9' => TemplateGenerationStatus.providerProcessing,
    '10' => TemplateGenerationStatus.importingMedia,
    'uploading' => TemplateGenerationStatus.uploading,
    'processing' => TemplateGenerationStatus.processing,
    'preprocessing' => TemplateGenerationStatus.preprocessing,
    'generating' => TemplateGenerationStatus.generating,
    'finalizing' => TemplateGenerationStatus.finalizing,
    'submittingtoprovider' ||
    'submitting_to_provider' ||
    'submitting-to-provider' => TemplateGenerationStatus.submittingToProvider,
    'providerqueued' ||
    'provider_queued' ||
    'provider-queued' => TemplateGenerationStatus.providerQueued,
    'providerprocessing' ||
    'provider_processing' ||
    'provider-processing' => TemplateGenerationStatus.providerProcessing,
    'importingmedia' ||
    'importing_media' ||
    'importing-media' => TemplateGenerationStatus.importingMedia,
    'completed' => TemplateGenerationStatus.completed,
    'succeeded' => TemplateGenerationStatus.completed,
    'failed' => TemplateGenerationStatus.failed,
    'cancelled' || 'canceled' => TemplateGenerationStatus.cancelled,
    _ => TemplateGenerationStatus.queued,
  };
}

class TemplateGenerationResult {
  const TemplateGenerationResult({
    required this.generationId,
    required this.userId,
    required this.templateId,
    required this.status,
    required this.tokenCost,
    required this.attemptCount,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.userMediaExpired,
    this.templateTitle,
    this.templateType,
    this.stage,
    this.progressPercent,
    this.estimatedDurationLabel,
    this.sourceImageAsset,
    this.normalizedImageUrl,
    this.referenceMotionUrl,
    this.outputUrl,
    this.usedPreprocessingModel,
    this.usedKlingModel,
    this.outputVideoDurationSeconds,
    this.failureCode,
    this.failureMessage,
    this.startedAtUtc,
    this.preprocessingCompletedAtUtc,
    this.motionGenerationCompletedAtUtc,
    this.mediaImportCompletedAtUtc,
    this.completedAtUtc,
    this.chargedAtUtc,
    this.refundedAtUtc,
    this.isUnread = false,
    this.queuePosition,
    this.estimatedWaitSeconds,
    this.estimatedCompletionAtUtc,
    this.estimatedTotalSeconds,
    this.mediaType,
    this.tier,
    this.queueStatus,
    this.canCancel,
    this.localPreviewPath,
    this.localOutputPath,
    this.isLocalMediaReady = false,
    this.hasWatermark = false,
    this.canRemoveWatermark = false,
    this.isWatermarkRemoved = false,
    this.removeWatermarkCostCredits = 1,
    this.userPlan = 'free',
    this.watermarkMessage,
    this.supportsGenerateSimilar = false,
    this.inputSourceType = 'user_upload',
    this.inputMediaAssetId,
    this.resultMediaAssetId,
    this.inputPreviewUrl,
    this.resultPreviewUrl,
    this.canCompareBeforeAfter = false,
    this.petId,
    this.petPhotoId,
  });

  final String generationId;
  final String userId;
  final String templateId;
  final TemplateGenerationStatus status;
  final int tokenCost;
  final TemplateAsset? sourceImageAsset;
  final String? normalizedImageUrl;
  final String? referenceMotionUrl;
  final String? outputUrl;
  final int attemptCount;
  final String? usedPreprocessingModel;
  final String? usedKlingModel;
  final double? outputVideoDurationSeconds;
  final String? failureCode;
  final String? failureMessage;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final String? templateTitle;
  final String? templateType;
  final String? stage;
  final int? progressPercent;
  final String? estimatedDurationLabel;
  final DateTime? startedAtUtc;
  final DateTime? preprocessingCompletedAtUtc;
  final DateTime? motionGenerationCompletedAtUtc;
  final DateTime? mediaImportCompletedAtUtc;
  final DateTime? completedAtUtc;
  final DateTime? chargedAtUtc;
  final DateTime? refundedAtUtc;
  final bool userMediaExpired;
  final bool isUnread;
  final int? queuePosition;
  final int? estimatedWaitSeconds;
  final DateTime? estimatedCompletionAtUtc;
  final int? estimatedTotalSeconds;
  final String? mediaType;
  final String? tier;
  final String? queueStatus;
  final bool? canCancel;
  final String? localPreviewPath;
  final String? localOutputPath;
  final bool isLocalMediaReady;
  final bool hasWatermark;
  final bool canRemoveWatermark;
  final bool isWatermarkRemoved;
  final int removeWatermarkCostCredits;
  final String userPlan;
  final String? watermarkMessage;
  final bool supportsGenerateSimilar;
  final String inputSourceType;
  final String? inputMediaAssetId;
  final String? resultMediaAssetId;
  final String? inputPreviewUrl;
  final String? resultPreviewUrl;
  final bool canCompareBeforeAfter;
  final String? petId;
  final String? petPhotoId;

  TemplateGenerationResult copyWith({
    String? generationId,
    String? userId,
    String? templateId,
    TemplateGenerationStatus? status,
    int? tokenCost,
    TemplateAsset? sourceImageAsset,
    String? normalizedImageUrl,
    String? referenceMotionUrl,
    String? outputUrl,
    int? attemptCount,
    String? usedPreprocessingModel,
    String? usedKlingModel,
    double? outputVideoDurationSeconds,
    String? failureCode,
    String? failureMessage,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    String? templateTitle,
    String? templateType,
    String? stage,
    int? progressPercent,
    String? estimatedDurationLabel,
    DateTime? startedAtUtc,
    DateTime? preprocessingCompletedAtUtc,
    DateTime? motionGenerationCompletedAtUtc,
    DateTime? mediaImportCompletedAtUtc,
    DateTime? completedAtUtc,
    DateTime? chargedAtUtc,
    DateTime? refundedAtUtc,
    bool? userMediaExpired,
    bool? isUnread,
    int? queuePosition,
    int? estimatedWaitSeconds,
    DateTime? estimatedCompletionAtUtc,
    int? estimatedTotalSeconds,
    String? mediaType,
    String? tier,
    String? queueStatus,
    bool? canCancel,
    String? localPreviewPath,
    bool clearLocalPreviewPath = false,
    String? localOutputPath,
    bool clearLocalOutputPath = false,
    bool? isLocalMediaReady,
    bool? hasWatermark,
    bool? canRemoveWatermark,
    bool? isWatermarkRemoved,
    int? removeWatermarkCostCredits,
    String? userPlan,
    String? watermarkMessage,
    bool? supportsGenerateSimilar,
    String? inputSourceType,
    String? inputMediaAssetId,
    String? resultMediaAssetId,
    String? inputPreviewUrl,
    String? resultPreviewUrl,
    bool? canCompareBeforeAfter,
    String? petId,
    String? petPhotoId,
  }) {
    return TemplateGenerationResult(
      generationId: generationId ?? this.generationId,
      userId: userId ?? this.userId,
      templateId: templateId ?? this.templateId,
      status: status ?? this.status,
      tokenCost: tokenCost ?? this.tokenCost,
      sourceImageAsset: sourceImageAsset ?? this.sourceImageAsset,
      normalizedImageUrl: normalizedImageUrl ?? this.normalizedImageUrl,
      referenceMotionUrl: referenceMotionUrl ?? this.referenceMotionUrl,
      outputUrl: outputUrl ?? this.outputUrl,
      attemptCount: attemptCount ?? this.attemptCount,
      usedPreprocessingModel:
          usedPreprocessingModel ?? this.usedPreprocessingModel,
      usedKlingModel: usedKlingModel ?? this.usedKlingModel,
      outputVideoDurationSeconds:
          outputVideoDurationSeconds ?? this.outputVideoDurationSeconds,
      failureCode: failureCode ?? this.failureCode,
      failureMessage: failureMessage ?? this.failureMessage,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      templateTitle: templateTitle ?? this.templateTitle,
      templateType: templateType ?? this.templateType,
      stage: stage ?? this.stage,
      progressPercent: progressPercent ?? this.progressPercent,
      estimatedDurationLabel:
          estimatedDurationLabel ?? this.estimatedDurationLabel,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      preprocessingCompletedAtUtc:
          preprocessingCompletedAtUtc ?? this.preprocessingCompletedAtUtc,
      motionGenerationCompletedAtUtc:
          motionGenerationCompletedAtUtc ?? this.motionGenerationCompletedAtUtc,
      mediaImportCompletedAtUtc:
          mediaImportCompletedAtUtc ?? this.mediaImportCompletedAtUtc,
      completedAtUtc: completedAtUtc ?? this.completedAtUtc,
      chargedAtUtc: chargedAtUtc ?? this.chargedAtUtc,
      refundedAtUtc: refundedAtUtc ?? this.refundedAtUtc,
      userMediaExpired: userMediaExpired ?? this.userMediaExpired,
      isUnread: isUnread ?? this.isUnread,
      queuePosition: queuePosition ?? this.queuePosition,
      estimatedWaitSeconds: estimatedWaitSeconds ?? this.estimatedWaitSeconds,
      estimatedCompletionAtUtc:
          estimatedCompletionAtUtc ?? this.estimatedCompletionAtUtc,
      estimatedTotalSeconds:
          estimatedTotalSeconds ?? this.estimatedTotalSeconds,
      mediaType: mediaType ?? this.mediaType,
      tier: tier ?? this.tier,
      queueStatus: queueStatus ?? this.queueStatus,
      canCancel: canCancel ?? this.canCancel,
      localPreviewPath: clearLocalPreviewPath
          ? null
          : localPreviewPath ?? this.localPreviewPath,
      localOutputPath: clearLocalOutputPath
          ? null
          : localOutputPath ?? this.localOutputPath,
      isLocalMediaReady: isLocalMediaReady ?? this.isLocalMediaReady,
      hasWatermark: hasWatermark ?? this.hasWatermark,
      canRemoveWatermark: canRemoveWatermark ?? this.canRemoveWatermark,
      isWatermarkRemoved: isWatermarkRemoved ?? this.isWatermarkRemoved,
      removeWatermarkCostCredits:
          removeWatermarkCostCredits ?? this.removeWatermarkCostCredits,
      userPlan: userPlan ?? this.userPlan,
      watermarkMessage: watermarkMessage ?? this.watermarkMessage,
      supportsGenerateSimilar:
          supportsGenerateSimilar ?? this.supportsGenerateSimilar,
      inputSourceType: inputSourceType ?? this.inputSourceType,
      inputMediaAssetId: inputMediaAssetId ?? this.inputMediaAssetId,
      resultMediaAssetId: resultMediaAssetId ?? this.resultMediaAssetId,
      inputPreviewUrl: inputPreviewUrl ?? this.inputPreviewUrl,
      resultPreviewUrl: resultPreviewUrl ?? this.resultPreviewUrl,
      canCompareBeforeAfter:
          canCompareBeforeAfter ?? this.canCompareBeforeAfter,
      petId: petId ?? this.petId,
      petPhotoId: petPhotoId ?? this.petPhotoId,
    );
  }

  bool get isTerminal =>
      status == TemplateGenerationStatus.completed ||
      status == TemplateGenerationStatus.failed ||
      status == TemplateGenerationStatus.cancelled;

  bool get isCompleted => status == TemplateGenerationStatus.completed;

  bool get isFailed => status == TemplateGenerationStatus.failed;

  bool get isCancelled => status == TemplateGenerationStatus.cancelled;

  bool get isWaitingInQueue =>
      status == TemplateGenerationStatus.queued ||
      status == TemplateGenerationStatus.submittingToProvider ||
      status == TemplateGenerationStatus.providerQueued;

  bool get isActivelyGenerating =>
      status == TemplateGenerationStatus.processing ||
      status == TemplateGenerationStatus.preprocessing ||
      status == TemplateGenerationStatus.generating ||
      status == TemplateGenerationStatus.providerProcessing;

  bool get canCancelQueued =>
      status == TemplateGenerationStatus.queued && (canCancel ?? true);

  int get effectiveProgressPercent {
    final explicit = progressPercent;
    if (explicit != null) {
      return explicit.clamp(0, 100);
    }

    return switch (status) {
      TemplateGenerationStatus.completed => 100,
      TemplateGenerationStatus.failed => 100,
      TemplateGenerationStatus.cancelled => 100,
      TemplateGenerationStatus.finalizing => 90,
      TemplateGenerationStatus.importingMedia => 90,
      TemplateGenerationStatus.generating => 65,
      TemplateGenerationStatus.providerProcessing => 65,
      TemplateGenerationStatus.preprocessing ||
      TemplateGenerationStatus.processing => 30,
      TemplateGenerationStatus.providerQueued => 24,
      TemplateGenerationStatus.submittingToProvider => 18,
      TemplateGenerationStatus.uploading => 15,
      TemplateGenerationStatus.queued => 10,
    };
  }
}

class GenerationCancelResult {
  const GenerationCancelResult({
    required this.generation,
    this.refunded = false,
    this.cancelledAtUtc,
  });

  final TemplateGenerationResult generation;
  final bool refunded;
  final DateTime? cancelledAtUtc;
}

class CompatibleGenerationTemplate {
  const CompatibleGenerationTemplate({
    required this.id,
    required this.title,
    required this.templateType,
    required this.isPremium,
    required this.isRecommended,
    required this.tokenCost,
    required this.version,
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final TemplateType templateType;
  final String? thumbnailUrl;
  final bool isPremium;
  final bool isRecommended;
  final int tokenCost;
  final int version;

  bool get isVideo => templateType == TemplateType.video;
}

class CompatibleGenerationTemplates {
  const CompatibleGenerationTemplates({
    required this.resultId,
    required this.inputMediaType,
    required this.templates,
  });

  final String resultId;
  final TemplateType inputMediaType;
  final List<CompatibleGenerationTemplate> templates;
}
