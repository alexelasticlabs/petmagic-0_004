final class PetGenerationSummary {
  const PetGenerationSummary({
    required this.generationId,
    required this.templateId,
    required this.createdAtUtc,
    required this.status,
    required this.stage,
    this.templateTitle,
    this.templateType,
    this.outputUrl,
    this.petId,
    this.petPhotoId,
  });

  final String generationId;
  final String templateId;
  final String? templateTitle;
  final String? templateType;
  final String? outputUrl;
  final String? petId;
  final String? petPhotoId;
  final DateTime createdAtUtc;
  final String status;
  final String stage;

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';
}
