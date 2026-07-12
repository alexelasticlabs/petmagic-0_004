import 'package:petmagic_mobile/features/templates/data/template_asset_dto.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

class TemplateItemDto {
  const TemplateItemDto({
    required this.templateId,
    required this.templateType,
    required this.title,
    required this.shortDescription,
    required this.petPhotoRequirements,
    required this.category,
    required this.effectivePromoBadge,
    required this.tags,
    required this.isPremium,
    required this.tokenCost,
    required this.thumbnailUrl,
    required this.animatedPreviewUrl,
    required this.feedLoopLowUrl,
    required this.feedLoopMediumUrl,
    required this.detailPreviewUrl,
    required this.mediaKind,
    required this.durationMs,
    required this.sizeBytes,
    required this.mediaVersion,
    required this.previewAsset,
    required this.musicDescription,
    required this.referenceVideoDurationSeconds,
    required this.supportsGenerationResultInput,
    required this.requiredInputMediaType,
    required this.recommendedAfterImageGeneration,
    required this.supportsGenerateSimilar,
    required this.defaultVariationStrength,
    required this.version,
    required this.updatedAtUtc,
  });

  final String templateId;
  final String templateType;
  final String title;
  final String shortDescription;
  final List<String> petPhotoRequirements;
  final String category;
  final String? effectivePromoBadge;
  final List<String> tags;
  final bool isPremium;
  final int tokenCost;
  final String? thumbnailUrl;
  final String? animatedPreviewUrl;
  final String? feedLoopLowUrl;
  final String? feedLoopMediumUrl;
  final String? detailPreviewUrl;
  final String? mediaKind;
  final int? durationMs;
  final int? sizeBytes;
  final int? mediaVersion;
  final TemplateAssetDto? previewAsset;
  final String? musicDescription;
  final double? referenceVideoDurationSeconds;
  final bool supportsGenerationResultInput;
  final String? requiredInputMediaType;
  final bool recommendedAfterImageGeneration;
  final bool supportsGenerateSimilar;
  final String defaultVariationStrength;
  final int version;
  final DateTime? updatedAtUtc;

  factory TemplateItemDto.fromJson(Map<String, Object?> json) {
    final rawAsset = json['previewAsset'];
    final previewUrl = json['previewUrl'] as String?;
    final rawMedia = json['media'];
    final media = rawMedia is Map
        ? Map<String, Object?>.from(rawMedia)
        : const <String, Object?>{};
    final thumbnailUrl =
        _normalizeOptionalString(json['thumbnailUrl']) ??
        _normalizeOptionalString(media['thumbnailUrl']);
    final animatedPreviewUrl = _normalizeOptionalString(
      media['animatedPreviewUrl'],
    );
    final feedLoopLowUrl = _normalizeOptionalString(media['feedLoopLowUrl']);
    final feedLoopMediumUrl = _normalizeOptionalString(
      media['feedLoopMediumUrl'],
    );
    final detailPreviewUrl = _normalizeOptionalString(
      media['detailPreviewUrl'],
    );
    final mediaKind =
        _normalizeOptionalString(json['mediaKind']) ??
        _normalizeOptionalString(media['mediaKind']);
    final durationMs =
        (json['durationMs'] as num?)?.toInt() ??
        (media['durationMs'] as num?)?.toInt();
    final sizeBytes =
        (json['sizeBytes'] as num?)?.toInt() ??
        (media['sizeBytes'] as num?)?.toInt();
    final mediaVersion =
        (json['mediaVersion'] as num?)?.toInt() ??
        (media['mediaVersion'] as num?)?.toInt();

    TemplateAssetDto? parsedAsset;
    if (rawAsset is Map) {
      parsedAsset = TemplateAssetDto.fromJson(
        Map<String, Object?>.from(rawAsset),
      );
    } else if (previewUrl != null && previewUrl.trim().isNotEmpty) {
      final normalizedPreviewUrl = previewUrl.trim();
      final inferredContentType = _inferContentTypeFromUrl(
        normalizedPreviewUrl,
      );
      parsedAsset = TemplateAssetDto(
        url: normalizedPreviewUrl,
        fileName: normalizedPreviewUrl.split('/').last,
        contentType: inferredContentType,
        fileSizeBytes: null,
        durationSeconds: null,
      );
    } else {
      final mediaPreviewUrl =
          detailPreviewUrl ??
          feedLoopMediumUrl ??
          feedLoopLowUrl ??
          animatedPreviewUrl ??
          thumbnailUrl;
      if (mediaPreviewUrl != null && mediaPreviewUrl.isNotEmpty) {
        parsedAsset = TemplateAssetDto(
          url: mediaPreviewUrl,
          fileName: mediaPreviewUrl.split('/').last,
          contentType: _contentTypeFromMediaKind(mediaKind, mediaPreviewUrl),
          fileSizeBytes: sizeBytes,
          durationSeconds: durationMs == null ? null : durationMs / 1000,
        );
      }
    }

    final templateId =
        (json['templateId'] as String? ?? json['id'] as String? ?? '').trim();
    final templateType =
        (json['templateType'] as String? ?? json['type'] as String? ?? 'Image')
            .trim();

    return TemplateItemDto(
      templateId: templateId,
      templateType: templateType,
      title: json['title'] as String? ?? '',
      shortDescription: json['shortDescription'] as String? ?? '',
      petPhotoRequirements:
          (json['petPhotoRequirements'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false),
      category: _readCategory(json['category']),
      effectivePromoBadge: json['effectivePromoBadge'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      isPremium: _readPremiumFlag(json),
      tokenCost:
          (json['tokenCost'] as num?)?.toInt() ??
          (json['priceTokens'] as num?)?.toInt() ??
          0,
      thumbnailUrl: thumbnailUrl,
      animatedPreviewUrl: animatedPreviewUrl,
      feedLoopLowUrl: feedLoopLowUrl,
      feedLoopMediumUrl: feedLoopMediumUrl,
      detailPreviewUrl: detailPreviewUrl,
      mediaKind: mediaKind,
      durationMs: durationMs,
      sizeBytes: sizeBytes,
      mediaVersion: mediaVersion,
      previewAsset: parsedAsset,
      musicDescription: json['musicDescription'] as String?,
      referenceVideoDurationSeconds:
          (json['referenceVideoDurationSeconds'] as num?)?.toDouble(),
      supportsGenerationResultInput:
          json['supportsGenerationResultInput'] as bool? ?? false,
      requiredInputMediaType: (json['requiredInputMediaType'] as String?)
          ?.trim(),
      recommendedAfterImageGeneration:
          json['recommendedAfterImageGeneration'] as bool? ?? false,
      supportsGenerateSimilar: json['supportsGenerateSimilar'] as bool? ?? true,
      defaultVariationStrength: _normalizeVariationStrength(
        json['defaultVariationStrength'] as String?,
      ),
      version: (json['version'] as num?)?.toInt() ?? mediaVersion ?? 0,
      updatedAtUtc: _parseDateTime(
        json['updatedAtUtc'] as String? ?? json['updatedAt'] as String?,
      ),
    );
  }

  static DateTime? _parseDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw)?.toUtc();
  }

  static String? _normalizeOptionalString(Object? value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static String _readCategory(Object? rawCategory) {
    if (rawCategory is String) {
      return rawCategory;
    }

    if (rawCategory is Map) {
      final category = Map<String, Object?>.from(rawCategory);
      return _normalizeOptionalString(category['title']) ??
          _normalizeOptionalString(category['slug']) ??
          '';
    }

    return '';
  }

  static String _contentTypeFromMediaKind(String? mediaKind, String url) {
    final normalized = mediaKind?.trim().toLowerCase();
    if (normalized == 'video') {
      return 'video/mp4';
    }

    if (normalized == 'image') {
      return 'image/jpeg';
    }

    return _inferContentTypeFromUrl(url);
  }

  static bool _readPremiumFlag(Map<String, Object?> json) {
    return toBool(json['isPremium']) ??
        toBool(json['premium']) ??
        toBool(json['isPro']) ??
        false;
  }

  static bool? toBool(Object? value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }

    return null;
  }

  static String _inferContentTypeFromUrl(String url) {
    final normalized = url.toLowerCase();
    final uri = Uri.tryParse(normalized);
    final path = (uri?.path ?? normalized).toLowerCase();

    if (isVideoUrl(normalized)) {
      return 'video/mp4';
    }
    if (path.endsWith('.webm')) {
      return 'video/webm';
    }
    if (path.endsWith('.mov')) {
      return 'video/quicktime';
    }
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (path.endsWith('.png')) {
      return 'image/png';
    }
    return 'application/octet-stream';
  }

  static String _normalizeVariationStrength(String? raw) {
    final normalized = raw?.trim();
    return normalized == null || normalized.isEmpty ? 'medium' : normalized;
  }

  static TemplateType? _parseRequiredInputMediaType(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return templateTypeFromApi(normalized);
  }

  Map<String, Object?> toJson() => {
    'templateId': templateId,
    'templateType': templateType,
    'title': title,
    'shortDescription': shortDescription,
    'petPhotoRequirements': petPhotoRequirements,
    'category': category,
    'effectivePromoBadge': effectivePromoBadge,
    'tags': tags,
    'isPremium': isPremium,
    'tokenCost': tokenCost,
    'thumbnailUrl': thumbnailUrl,
    'animatedPreviewUrl': animatedPreviewUrl,
    'feedLoopLowUrl': feedLoopLowUrl,
    'feedLoopMediumUrl': feedLoopMediumUrl,
    'detailPreviewUrl': detailPreviewUrl,
    'mediaKind': mediaKind,
    'durationMs': durationMs,
    'sizeBytes': sizeBytes,
    'mediaVersion': mediaVersion,
    'previewAsset': previewAsset?.toJson(),
    'musicDescription': musicDescription,
    'referenceVideoDurationSeconds': referenceVideoDurationSeconds,
    'supportsGenerationResultInput': supportsGenerationResultInput,
    'requiredInputMediaType': requiredInputMediaType,
    'recommendedAfterImageGeneration': recommendedAfterImageGeneration,
    'supportsGenerateSimilar': supportsGenerateSimilar,
    'defaultVariationStrength': defaultVariationStrength,
    'version': version,
    'updatedAtUtc': updatedAtUtc?.toIso8601String(),
  };

  TemplateItem toDomain() => TemplateItem(
    templateId: templateId,
    templateType: templateTypeFromApi(templateType),
    title: title,
    shortDescription: shortDescription,
    petPhotoRequirements: petPhotoRequirements,
    category: category,
    effectivePromoBadge: effectivePromoBadge,
    tags: tags,
    isPremium: isPremium,
    tokenCost: tokenCost,
    thumbnailUrl: thumbnailUrl,
    animatedPreviewUrl: animatedPreviewUrl,
    feedLoopLowUrl: feedLoopLowUrl,
    feedLoopMediumUrl: feedLoopMediumUrl,
    detailPreviewUrl: detailPreviewUrl,
    mediaKind: mediaKind,
    durationMs: durationMs,
    sizeBytes: sizeBytes,
    mediaVersion: mediaVersion,
    previewAsset: previewAsset?.toDomain(),
    musicDescription: musicDescription,
    referenceVideoDurationSeconds: referenceVideoDurationSeconds,
    supportsGenerationResultInput: supportsGenerationResultInput,
    requiredInputMediaType: _parseRequiredInputMediaType(
      requiredInputMediaType,
    ),
    recommendedAfterImageGeneration: recommendedAfterImageGeneration,
    supportsGenerateSimilar: supportsGenerateSimilar,
    defaultVariationStrength: defaultVariationStrength,
    version: version,
    updatedAtUtc: updatedAtUtc,
  );
}
