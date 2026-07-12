import 'package:petmagic_mobile/features/templates/data/templates_dto.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_results.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

class CompatibleGenerationTemplateDto {
  const CompatibleGenerationTemplateDto({
    required this.id,
    required this.title,
    required this.type,
    required this.isPremium,
    required this.isRecommended,
    required this.tokenCost,
    required this.version,
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String type;
  final String? thumbnailUrl;
  final bool isPremium;
  final bool isRecommended;
  final int tokenCost;
  final int version;

  factory CompatibleGenerationTemplateDto.fromJson(Map<String, Object?> json) {
    return CompatibleGenerationTemplateDto(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'Image',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      isPremium: json['isPremium'] as bool? ?? false,
      isRecommended: json['isRecommended'] as bool? ?? false,
      tokenCost: (json['tokenCost'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 0,
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
    version: version,
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

class TemplateGenerationGalleryPageDto {
  const TemplateGenerationGalleryPageDto({
    required this.items,
    required this.hasMore,
    required this.unreadCount,
    required this.appliedFilter,
    this.nextCursor,
    this.serverTimeUtc,
  });

  final List<TemplateGenerationDto> items;
  final String? nextCursor;
  final bool hasMore;
  final DateTime? serverTimeUtc;
  final int unreadCount;
  final String appliedFilter;

  factory TemplateGenerationGalleryPageDto.fromJson(Map<String, dynamic> json) {
    return TemplateGenerationGalleryPageDto(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                TemplateGenerationDto.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
      serverTimeUtc: DateTime.tryParse(json['serverTimeUtc'] as String? ?? ''),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      appliedFilter: json['appliedFilter'] as String? ?? 'all',
    );
  }

  TemplateGenerationGalleryPage toDomain() => TemplateGenerationGalleryPage(
    items: items.map((item) => item.toDomain()).toList(growable: false),
    nextCursor: nextCursor,
    hasMore: hasMore,
    serverTimeUtc: serverTimeUtc,
    unreadCount: unreadCount,
    appliedFilter: appliedFilter,
  );
}

class GalleryMediaDto {
  const GalleryMediaDto({
    required this.state,
    required this.mediaType,
    this.previewUrl,
    this.resultUrl,
    this.resultExpiresAtUtc,
    this.durationSeconds,
    this.hasWatermark = false,
    this.canRemoveWatermark = false,
    this.isWatermarkRemoved = false,
    this.canDownload = false,
    this.canShare = false,
    this.reasonCode,
    this.userMessageKey,
    this.retryAfterSeconds,
  });

  final GalleryMediaState state;
  final String mediaType;
  final String? previewUrl;
  final String? resultUrl;
  final DateTime? resultExpiresAtUtc;
  final double? durationSeconds;
  final bool hasWatermark;
  final bool canRemoveWatermark;
  final bool isWatermarkRemoved;
  final bool canDownload;
  final bool canShare;
  final String? reasonCode;
  final String? userMessageKey;
  final int? retryAfterSeconds;

  factory GalleryMediaDto.fromJson(Map<String, dynamic> json) {
    return GalleryMediaDto(
      state: galleryMediaStateFromApi(json['state'] as String?),
      mediaType: json['mediaType'] as String? ?? 'image',
      previewUrl: json['previewUrl'] as String?,
      resultUrl:
          (json['resultUrl'] as String?) ??
          (json['signedMediaUrl'] as String?) ??
          (json['mediaUrl'] as String?),
      resultExpiresAtUtc: _dateTime(json['resultExpiresAtUtc']),
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
      hasWatermark: json['hasWatermark'] as bool? ?? false,
      canRemoveWatermark: json['canRemoveWatermark'] as bool? ?? false,
      isWatermarkRemoved: json['isWatermarkRemoved'] as bool? ?? false,
      canDownload: json['canDownload'] as bool? ?? false,
      canShare: json['canShare'] as bool? ?? false,
      reasonCode: json['reasonCode'] as String?,
      userMessageKey: json['userMessageKey'] as String?,
      retryAfterSeconds: (json['retryAfterSeconds'] as num?)?.toInt(),
    );
  }

  GalleryMedia toDomain() => GalleryMedia(
    state: state,
    mediaType: mediaType,
    previewUrl: previewUrl,
    resultUrl: resultUrl,
    resultExpiresAtUtc: resultExpiresAtUtc,
    durationSeconds: durationSeconds,
    hasWatermark: hasWatermark,
    canRemoveWatermark: canRemoveWatermark,
    isWatermarkRemoved: isWatermarkRemoved,
    canDownload: canDownload,
    canShare: canShare,
    reasonCode: reasonCode,
    userMessageKey: userMessageKey,
    retryAfterSeconds: retryAfterSeconds,
  );

  static DateTime? _dateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value)?.toUtc();
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
    this.media,
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
  final GalleryMediaDto? media;

  factory TemplateGenerationDto.fromJson(Map<String, dynamic> json) {
    final rawSourceImageAsset = json['sourceImageAsset'];
    final rawMedia = json['media'];
    final media = rawMedia is Map
        ? GalleryMediaDto.fromJson(Map<String, dynamic>.from(rawMedia))
        : null;

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
          (json['outputUrl'] as String?) ??
          (json['mediaUrl'] as String?) ??
          media?.resultUrl,
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
      userMediaExpired:
          media?.state == GalleryMediaState.expired ||
          (json['userMediaExpired'] as bool? ?? false),
      isUnread: json['isUnread'] as bool? ?? false,
      queuePosition: (json['queuePosition'] as num?)?.toInt(),
      estimatedWaitSeconds: (json['estimatedWaitSeconds'] as num?)?.toInt(),
      estimatedCompletionAtUtc: _dateTime(
        json['estimatedCompletionAtUtc'] ?? json['estimatedCompletionAt'],
      ),
      estimatedTotalSeconds: (json['estimatedTotalSeconds'] as num?)?.toInt(),
      mediaType: _string(json['mediaType'] ?? media?.mediaType),
      tier: _string(json['tier'] ?? json['priorityTier'] ?? json['userTier']),
      queueStatus: _string(json['queueStatus'] ?? json['queueState']),
      canCancel: json['canCancel'] as bool?,
      hasWatermark:
          json['hasWatermark'] as bool? ?? media?.hasWatermark ?? false,
      canRemoveWatermark:
          json['canRemoveWatermark'] as bool? ??
          media?.canRemoveWatermark ??
          false,
      isWatermarkRemoved:
          json['isWatermarkRemoved'] as bool? ??
          media?.isWatermarkRemoved ??
          false,
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
      resultPreviewUrl:
          json['resultPreviewUrl'] as String? ?? media?.previewUrl,
      canCompareBeforeAfter: json['canCompareBeforeAfter'] as bool? ?? false,
      petId: json['petId'] as String?,
      petPhotoId: json['petPhotoId'] as String?,
      media: media,
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
      galleryMedia:
          media?.toDomain() ??
          GalleryMedia(
            state: _legacyGalleryMediaState(),
            mediaType: mediaType ?? 'image',
            previewUrl: resultPreviewUrl ?? outputUrl,
            resultUrl: outputUrl,
            durationSeconds: outputVideoDurationSeconds,
            hasWatermark: hasWatermark,
            canRemoveWatermark: canRemoveWatermark,
            isWatermarkRemoved: isWatermarkRemoved,
            canDownload: outputUrl != null && outputUrl!.isNotEmpty,
            canShare: outputUrl != null && outputUrl!.isNotEmpty,
          ),
    );
  }

  GalleryMediaState _legacyGalleryMediaState() {
    final parsedStatus = templateGenerationStatusFromApi(status);
    if (userMediaExpired) {
      return GalleryMediaState.expired;
    }
    if (parsedStatus == TemplateGenerationStatus.failed ||
        parsedStatus == TemplateGenerationStatus.cancelled) {
      return GalleryMediaState.failed;
    }
    if (parsedStatus != TemplateGenerationStatus.completed) {
      return parsedStatus == TemplateGenerationStatus.queued ||
              parsedStatus == TemplateGenerationStatus.submittingToProvider ||
              parsedStatus == TemplateGenerationStatus.providerQueued
          ? GalleryMediaState.pending
          : GalleryMediaState.processing;
    }
    return outputUrl == null || outputUrl!.isEmpty
        ? GalleryMediaState.storageUnavailable
        : GalleryMediaState.resultReady;
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
