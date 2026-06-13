import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

enum TemplateGenerationStatus {
  queued,
  uploading,
  processing,
  preprocessing,
  generating,
  finalizing,
  succeeded,
  completed,
  failed,
}

TemplateGenerationStatus templateGenerationStatusFromApi(String value) {
  return switch (value.toLowerCase()) {
    'uploading' => TemplateGenerationStatus.uploading,
    'processing' => TemplateGenerationStatus.processing,
    'preprocessing' => TemplateGenerationStatus.preprocessing,
    'generating' => TemplateGenerationStatus.generating,
    'finalizing' => TemplateGenerationStatus.finalizing,
    'succeeded' => TemplateGenerationStatus.succeeded,
    'completed' => TemplateGenerationStatus.completed,
    'failed' => TemplateGenerationStatus.failed,
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
    this.localPreviewPath,
    this.localOutputPath,
    this.isLocalMediaReady = false,
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
  final String? localPreviewPath;
  final String? localOutputPath;
  final bool isLocalMediaReady;

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
    String? localPreviewPath,
    bool clearLocalPreviewPath = false,
    String? localOutputPath,
    bool clearLocalOutputPath = false,
    bool? isLocalMediaReady,
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
      localPreviewPath: clearLocalPreviewPath
          ? null
          : localPreviewPath ?? this.localPreviewPath,
      localOutputPath: clearLocalOutputPath
          ? null
          : localOutputPath ?? this.localOutputPath,
      isLocalMediaReady: isLocalMediaReady ?? this.isLocalMediaReady,
    );
  }

  bool get isTerminal =>
      status == TemplateGenerationStatus.succeeded ||
      status == TemplateGenerationStatus.completed ||
      status == TemplateGenerationStatus.failed;

  bool get isCompleted =>
      status == TemplateGenerationStatus.succeeded ||
      status == TemplateGenerationStatus.completed;

  bool get isFailed => status == TemplateGenerationStatus.failed;

  int get effectiveProgressPercent {
    final explicit = progressPercent;
    if (explicit != null) {
      return explicit.clamp(0, 100);
    }

    return switch (status) {
      TemplateGenerationStatus.succeeded ||
      TemplateGenerationStatus.completed => 100,
      TemplateGenerationStatus.failed => 100,
      TemplateGenerationStatus.finalizing => 90,
      TemplateGenerationStatus.generating => 65,
      TemplateGenerationStatus.preprocessing ||
      TemplateGenerationStatus.processing => 30,
      TemplateGenerationStatus.uploading => 15,
      TemplateGenerationStatus.queued => 10,
    };
  }
}
