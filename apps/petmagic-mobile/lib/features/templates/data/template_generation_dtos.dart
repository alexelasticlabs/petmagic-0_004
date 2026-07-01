import 'package:petmagic_mobile/features/templates/data/templates_dto.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

class CompatibleGenerationTemplateDto {
  const CompatibleGenerationTemplateDto({
    required this.id,
    required this.title,
    required this.type,
    required this.isPremium,
    required this.isRecommended,
    required this.tokenCost,
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String type;
  final String? thumbnailUrl;
  final bool isPremium;
  final bool isRecommended;
  final int tokenCost;

  factory CompatibleGenerationTemplateDto.fromJson(Map<String, Object?> json) {
    return CompatibleGenerationTemplateDto(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'Image',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      isPremium: json['isPremium'] as bool? ?? false,
      isRecommended: json['isRecommended'] as bool? ?? false,
      tokenCost: (json['tokenCost'] as num?)?.toInt() ?? 0,
    );
  }

  CompatibleGenerationTemplate toDomain() => CompatibleGenerationTemplate(
    id: id,
    title: title,
    templateType: templateTypeFromApi(type),
    thumbnailUrl: thumbnailUrl,
    isPremium: isPremium,
    isRecommended: isRecommended,
    tokenCost: tokenCost,
  );
}

class CompatibleGenerationTemplatesDto {
  const CompatibleGenerationTemplatesDto({
    required this.resultId,
    required this.inputMediaType,
    required this.templates,
  });

  final String resultId;
  final String inputMediaType;
  final List<CompatibleGenerationTemplateDto> templates;

  factory CompatibleGenerationTemplatesDto.fromJson(Map<String, Object?> json) {
    return CompatibleGenerationTemplatesDto(
      resultId: json['resultId'] as String? ?? '',
      inputMediaType: json['inputMediaType'] as String? ?? 'image',
      templates: (json['templates'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => CompatibleGenerationTemplateDto.fromJson(
              Map<String, Object?>.from(item),
            ),
          )
          .toList(growable: false),
    );
  }

  CompatibleGenerationTemplates toDomain() => CompatibleGenerationTemplates(
    resultId: resultId,
    inputMediaType: templateTypeFromApi(inputMediaType),
    templates: templates.map((item) => item.toDomain()).toList(growable: false),
  );
}

class PetProfile {
  const PetProfile({
    required this.id,
    required this.name,
    required this.type,
    required this.photosCount,
    required this.generationsCount,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.breed,
    this.avatarMediaAssetId,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String type;
  final String? breed;
  final String? avatarMediaAssetId;
  final String? avatarUrl;
  final int photosCount;
  final int generationsCount;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  factory PetProfile.fromJson(Map<String, dynamic> json) {
    return PetProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'other',
      breed: json['breed'] as String?,
      avatarMediaAssetId: json['avatarMediaAssetId'] as String?,
      avatarUrl: _firstNonEmptyString(json, const [
        'avatarUrl',
        'avatarPhotoUrl',
        'avatarThumbnailUrl',
        'mainPhotoUrl',
        'photoUrl',
        'thumbnailUrl',
      ]),
      photosCount: (json['photosCount'] as num?)?.toInt() ?? 0,
      generationsCount: (json['generationsCount'] as num?)?.toInt() ?? 0,
      createdAtUtc:
          TemplateGenerationDto._dateTime(json['createdAtUtc']) ??
          DateTime.now().toUtc(),
      updatedAtUtc:
          TemplateGenerationDto._dateTime(json['updatedAtUtc']) ??
          DateTime.now().toUtc(),
    );
  }

  static String? _firstNonEmptyString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }
}

class PetPhoto {
  const PetPhoto({
    required this.id,
    required this.petId,
    required this.mediaAssetId,
    required this.url,
    required this.fileName,
    required this.contentType,
    required this.isFavorite,
    required this.isAvatar,
    required this.sortOrder,
    required this.createdAtUtc,
    this.thumbnailUrl,
    this.fileSizeBytes,
  });

  final String id;
  final String petId;
  final String mediaAssetId;
  final String url;
  final String? thumbnailUrl;
  final String fileName;
  final String contentType;
  final int? fileSizeBytes;
  final bool isFavorite;
  final bool isAvatar;
  final int sortOrder;
  final DateTime createdAtUtc;

  factory PetPhoto.fromJson(Map<String, dynamic> json) {
    return PetPhoto(
      id: json['id'] as String? ?? '',
      petId: json['petId'] as String? ?? '',
      mediaAssetId: json['mediaAssetId'] as String? ?? '',
      url: json['url'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      fileName: json['fileName'] as String? ?? '',
      contentType: json['contentType'] as String? ?? '',
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      isFavorite: json['isFavorite'] as bool? ?? false,
      isAvatar: json['isAvatar'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      createdAtUtc:
          TemplateGenerationDto._dateTime(json['createdAtUtc']) ??
          DateTime.now().toUtc(),
    );
  }
}

class TemplateGenerationDto {
  const TemplateGenerationDto({
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
    this.templateTitle,
    this.templateType,
    this.stage,
    this.progressPercent,
    this.estimatedDurationLabel,
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
  final String status;
  final int tokenCost;
  final TemplateAssetDto? sourceImageAsset;
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
  final String? templateTitle;
  final String? templateType;
  final String? stage;
  final int? progressPercent;
  final String? estimatedDurationLabel;
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

  factory TemplateGenerationDto.fromJson(Map<String, dynamic> json) {
    final rawSourceImageAsset = json['sourceImageAsset'];

    return TemplateGenerationDto(
      generationId: json['generationId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      templateId: json['templateId'] as String? ?? '',
      status: json['status'] as String? ?? 'Queued',
      tokenCost: (json['tokenCost'] as num?)?.toInt() ?? 0,
      sourceImageAsset: rawSourceImageAsset is Map
          ? TemplateAssetDto.fromJson(
              Map<String, Object?>.from(rawSourceImageAsset),
            )
          : null,
      normalizedImageUrl: json['normalizedImageUrl'] as String?,
      referenceMotionUrl: json['referenceMotionUrl'] as String?,
      outputUrl:
          (json['outputUrl'] as String?) ?? (json['mediaUrl'] as String?),
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      usedPreprocessingModel: json['usedPreprocessingModel'] as String?,
      usedKlingModel: json['usedKlingModel'] as String?,
      outputVideoDurationSeconds: (json['outputVideoDurationSeconds'] as num?)
          ?.toDouble(),
      failureCode: json['failureCode'] as String?,
      failureMessage: json['failureMessage'] as String?,
      createdAtUtc: _dateTime(json['createdAtUtc']) ?? DateTime.now().toUtc(),
      updatedAtUtc: _dateTime(json['updatedAtUtc']) ?? DateTime.now().toUtc(),
      startedAtUtc: _dateTime(json['startedAtUtc']),
      preprocessingCompletedAtUtc: _dateTime(
        json['preprocessingCompletedAtUtc'],
      ),
      motionGenerationCompletedAtUtc: _dateTime(
        json['motionGenerationCompletedAtUtc'],
      ),
      mediaImportCompletedAtUtc: _dateTime(json['mediaImportCompletedAtUtc']),
      completedAtUtc: _dateTime(json['completedAtUtc']),
      templateTitle: json['templateTitle'] as String?,
      templateType: json['templateType'] as String?,
      stage: json['stage'] as String?,
      progressPercent: (json['progressPercent'] as num?)?.toInt(),
      estimatedDurationLabel: json['estimatedDurationLabel'] as String?,
      chargedAtUtc: _dateTime(json['chargedAtUtc']),
      refundedAtUtc: _dateTime(json['refundedAtUtc']),
      userMediaExpired: json['userMediaExpired'] as bool? ?? false,
      isUnread: json['isUnread'] as bool? ?? false,
      queuePosition: (json['queuePosition'] as num?)?.toInt(),
      estimatedWaitSeconds: (json['estimatedWaitSeconds'] as num?)?.toInt(),
      estimatedCompletionAtUtc: _dateTime(
        json['estimatedCompletionAtUtc'] ?? json['estimatedCompletionAt'],
      ),
      estimatedTotalSeconds: (json['estimatedTotalSeconds'] as num?)?.toInt(),
      mediaType: _string(json['mediaType']),
      tier: _string(json['tier'] ?? json['priorityTier'] ?? json['userTier']),
      queueStatus: _string(json['queueStatus'] ?? json['queueState']),
      canCancel: json['canCancel'] as bool?,
      hasWatermark: json['hasWatermark'] as bool? ?? false,
      canRemoveWatermark: json['canRemoveWatermark'] as bool? ?? false,
      isWatermarkRemoved: json['isWatermarkRemoved'] as bool? ?? false,
      removeWatermarkCostCredits:
          (json['removeWatermarkCostCredits'] as num?)?.toInt() ?? 1,
      userPlan: json['userPlan'] as String? ?? 'free',
      watermarkMessage: json['watermarkMessage'] as String?,
      supportsGenerateSimilar:
          json['supportsGenerateSimilar'] as bool? ?? false,
      inputSourceType: json['inputSourceType'] as String? ?? 'user_upload',
      inputMediaAssetId: json['inputMediaAssetId'] as String?,
      resultMediaAssetId: json['resultMediaAssetId'] as String?,
      inputPreviewUrl: json['inputPreviewUrl'] as String?,
      resultPreviewUrl: json['resultPreviewUrl'] as String?,
      canCompareBeforeAfter: json['canCompareBeforeAfter'] as bool? ?? false,
      petId: json['petId'] as String?,
      petPhotoId: json['petPhotoId'] as String?,
    );
  }

  TemplateGenerationResult toDomain() {
    return TemplateGenerationResult(
      generationId: generationId,
      userId: userId,
      templateId: templateId,
      status: templateGenerationStatusFromApi(status),
      tokenCost: tokenCost,
      sourceImageAsset: sourceImageAsset?.toDomain(),
      normalizedImageUrl: normalizedImageUrl,
      referenceMotionUrl: referenceMotionUrl,
      outputUrl: outputUrl,
      attemptCount: attemptCount,
      usedPreprocessingModel: usedPreprocessingModel,
      usedKlingModel: usedKlingModel,
      outputVideoDurationSeconds: outputVideoDurationSeconds,
      failureCode: failureCode,
      failureMessage: failureMessage,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      templateTitle: templateTitle,
      templateType: templateType,
      stage: stage,
      progressPercent: progressPercent,
      estimatedDurationLabel: estimatedDurationLabel,
      startedAtUtc: startedAtUtc,
      preprocessingCompletedAtUtc: preprocessingCompletedAtUtc,
      motionGenerationCompletedAtUtc: motionGenerationCompletedAtUtc,
      mediaImportCompletedAtUtc: mediaImportCompletedAtUtc,
      completedAtUtc: completedAtUtc,
      chargedAtUtc: chargedAtUtc,
      refundedAtUtc: refundedAtUtc,
      userMediaExpired: userMediaExpired,
      isUnread: isUnread,
      queuePosition: queuePosition,
      estimatedWaitSeconds: estimatedWaitSeconds,
      estimatedCompletionAtUtc: estimatedCompletionAtUtc,
      estimatedTotalSeconds: estimatedTotalSeconds,
      mediaType: mediaType,
      tier: tier,
      queueStatus: queueStatus,
      canCancel: canCancel,
      hasWatermark: hasWatermark,
      canRemoveWatermark: canRemoveWatermark,
      isWatermarkRemoved: isWatermarkRemoved,
      removeWatermarkCostCredits: removeWatermarkCostCredits,
      userPlan: userPlan,
      watermarkMessage: watermarkMessage,
      supportsGenerateSimilar: supportsGenerateSimilar,
      inputSourceType: inputSourceType,
      inputMediaAssetId: inputMediaAssetId,
      resultMediaAssetId: resultMediaAssetId,
      inputPreviewUrl: inputPreviewUrl,
      resultPreviewUrl: resultPreviewUrl,
      canCompareBeforeAfter: canCompareBeforeAfter,
      petId: petId,
      petPhotoId: petPhotoId,
    );
  }

  static DateTime? _dateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value)?.toUtc();
  }

  static String? _string(Object? value) {
    if (value is! String) {
      return null;
    }

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class GenerationCancelResultDto {
  const GenerationCancelResultDto({
    required this.generation,
    required this.refunded,
    this.cancelledAtUtc,
  });

  final TemplateGenerationDto generation;
  final bool refunded;
  final DateTime? cancelledAtUtc;

  factory GenerationCancelResultDto.fromJson(Map<String, dynamic> json) {
    final rawGeneration = json['generation'];
    final generationJson = rawGeneration is Map
        ? Map<String, dynamic>.from(rawGeneration)
        : Map<String, dynamic>.from(json);
    generationJson['status'] ??= 'Cancelled';

    return GenerationCancelResultDto(
      generation: TemplateGenerationDto.fromJson(generationJson),
      refunded:
          json['refunded'] as bool? ??
          json['creditsRefunded'] as bool? ??
          false,
      cancelledAtUtc: TemplateGenerationDto._dateTime(
        json['cancelledAtUtc'] ?? json['canceledAtUtc'],
      ),
    );
  }

  GenerationCancelResult toDomain() => GenerationCancelResult(
    generation: generation.toDomain(),
    refunded: refunded,
    cancelledAtUtc: cancelledAtUtc,
  );
}

class RemoveGenerationWatermarkResult {
  const RemoveGenerationWatermarkResult({
    required this.watermarkRemoved,
    required this.creditsSpent,
    this.remainingCredits,
    this.mediaUrl,
  });

  final bool watermarkRemoved;
  final int creditsSpent;
  final int? remainingCredits;
  final String? mediaUrl;

  factory RemoveGenerationWatermarkResult.fromJson(Map<String, dynamic> json) {
    return RemoveGenerationWatermarkResult(
      watermarkRemoved: json['watermarkRemoved'] as bool? ?? false,
      creditsSpent: (json['creditsSpent'] as num?)?.toInt() ?? 0,
      remainingCredits: (json['remainingCredits'] as num?)?.toInt(),
      mediaUrl: json['mediaUrl'] as String?,
    );
  }
}

class GenerationMediaAccessResult {
  const GenerationMediaAccessResult({
    required this.mediaUrl,
    required this.hasWatermark,
    required this.fileName,
  });

  final String mediaUrl;
  final bool hasWatermark;
  final String fileName;

  factory GenerationMediaAccessResult.fromJson(Map<String, dynamic> json) {
    return GenerationMediaAccessResult(
      mediaUrl: json['mediaUrl'] as String? ?? '',
      hasWatermark: json['hasWatermark'] as bool? ?? false,
      fileName: json['fileName'] as String? ?? 'petmagic-result',
    );
  }
}
