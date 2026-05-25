import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

enum TemplateGenerationStatus { queued, processing, completed, failed }

TemplateGenerationStatus templateGenerationStatusFromApi(String value) {
  return switch (value.toLowerCase()) {
    'processing' => TemplateGenerationStatus.processing,
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
  final DateTime? startedAtUtc;
  final DateTime? preprocessingCompletedAtUtc;
  final DateTime? motionGenerationCompletedAtUtc;
  final DateTime? mediaImportCompletedAtUtc;
  final DateTime? completedAtUtc;
  final bool userMediaExpired;

  bool get isTerminal =>
      status == TemplateGenerationStatus.completed ||
      status == TemplateGenerationStatus.failed;

  bool get isCompleted => status == TemplateGenerationStatus.completed;

  bool get isFailed => status == TemplateGenerationStatus.failed;
}
