import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';

/// Serializes generation snapshots for local persistence and strips secrets
/// from signed media URLs before they reach SharedPreferences.
abstract final class GenerationCacheCodec {
  static bool matchesStatus(
    TemplateGenerationResult generation,
    String? status,
  ) {
    if (status == null || status.isEmpty) return true;
    return switch (status.toLowerCase()) {
      'active' => !generation.isTerminal,
      'completed' => generation.isCompleted,
      'failed' => generation.isFailed,
      _ => true,
    };
  }

  static Map<String, Object?> generationToJson(
    TemplateGenerationResult generation,
  ) {
    return sanitizeMap({
      'generationId': generation.generationId,
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
      'refundState': generation.refundState,
      'userMediaExpired': generation.userMediaExpired,
      'isUnread': generation.isUnread,
      'queuePosition': generation.queuePosition,
      'estimatedWaitSeconds': generation.estimatedWaitSeconds,
      'estimatedCompletionAtUtc': generation.estimatedCompletionAtUtc
          ?.toUtc()
          .toIso8601String(),
      'estimatedTotalSeconds': generation.estimatedTotalSeconds,
      'mediaType': generation.mediaType,
      'media': {
        'state': generation.galleryMedia.state.name,
        'mediaType': generation.galleryMedia.mediaType,
        'previewUrl': generation.galleryMedia.previewUrl,
        'resultUrl': generation.galleryMedia.resultUrl,
        'resultExpiresAtUtc': generation.galleryMedia.resultExpiresAtUtc
            ?.toUtc()
            .toIso8601String(),
        'durationSeconds': generation.galleryMedia.durationSeconds,
        'hasWatermark': generation.galleryMedia.hasWatermark,
        'canRemoveWatermark': generation.galleryMedia.canRemoveWatermark,
        'isWatermarkRemoved': generation.galleryMedia.isWatermarkRemoved,
        'canDownload': generation.galleryMedia.canDownload,
        'canShare': generation.galleryMedia.canShare,
        'reasonCode': generation.galleryMedia.reasonCode,
        'userMessageKey': generation.galleryMedia.userMessageKey,
        'retryAfterSeconds': generation.galleryMedia.retryAfterSeconds,
      },
      'tier': generation.tier,
      'queueStatus': generation.queueStatus,
      'canCancel': generation.canCancel,
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
    });
  }

  static List<Object?> sanitizeList(List<Object?> items) =>
      items.map((item) => _sanitizeValue(item)).toList(growable: false);

  static Map<String, Object?> sanitizeMap(Map item) =>
      Map<String, Object?>.fromEntries(
        item.entries.where((entry) => entry.key != 'userId').map((entry) {
          final key = entry.key.toString();
          return MapEntry(key, _sanitizeValue(entry.value, key: key));
        }),
      );

  static Map<String, dynamic> withScope(
    Map<String, dynamic> item,
    String scope,
  ) => <String, dynamic>{...item, 'userId': scope};

  static Object? _sanitizeValue(Object? value, {String? key}) {
    if (value == null) return null;
    if (value is String && _isMediaUrlKey(key)) {
      return persistentSafeGenerationMediaUrl(value);
    }
    if (value is String && _isMediaFileNameKey(key)) {
      return persistentSafeMediaFileName(value);
    }
    if (value is Map) return sanitizeMap(value);
    if (value is List) {
      return value
          .map((item) => _sanitizeValue(item, key: key))
          .toList(growable: false);
    }
    return value;
  }

  static bool _isMediaUrlKey(String? key) {
    final normalized = key?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return false;
    return normalized == 'url' ||
        normalized.endsWith('url') ||
        normalized.endsWith('urls') ||
        normalized.endsWith('mediaurl');
  }

  static bool _isMediaFileNameKey(String? key) =>
      key?.trim().toLowerCase() == 'filename';
}
