import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

class TemplateAssetDto {
  const TemplateAssetDto({
    required this.url,
    required this.fileName,
    required this.contentType,
    this.fileSizeBytes,
    this.durationSeconds,
  });

  final String url;
  final String fileName;
  final String contentType;
  final int? fileSizeBytes;
  final double? durationSeconds;

  factory TemplateAssetDto.fromJson(Map<String, Object?> json) {
    return TemplateAssetDto(
      url: json['url'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      contentType: json['contentType'] as String? ?? '',
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() => {
    'url': url,
    'fileName': fileName,
    'contentType': contentType,
    'fileSizeBytes': fileSizeBytes,
    'durationSeconds': durationSeconds,
  };

  TemplateAsset toDomain() => TemplateAsset(
    url: url,
    fileName: fileName,
    contentType: contentType,
    fileSizeBytes: fileSizeBytes,
    durationSeconds: durationSeconds,
  );
}

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
      category: json['category'] as String? ?? '',
      effectivePromoBadge: json['effectivePromoBadge'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      isPremium: _readPremiumFlag(json),
      tokenCost:
          (json['tokenCost'] as num?)?.toInt() ??
          (json['priceTokens'] as num?)?.toInt() ??
          0,
      thumbnailUrl: json['thumbnailUrl'] as String?,
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
      version: (json['version'] as num?)?.toInt() ?? 0,
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

  static bool _readPremiumFlag(Map<String, Object?> json) {
    return _toBool(json['isPremium']) ??
        _toBool(json['premium']) ??
        _toBool(json['isPro']) ??
        false;
  }

  static bool? _toBool(Object? value) {
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

class TemplatesFeedDto {
  const TemplatesFeedDto({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    required this.page,
  });

  final List<TemplateItemDto> items;
  final bool hasMore;
  final String? nextCursor;
  final int page;

  factory TemplatesFeedDto.fromJson(Map<String, Object?> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];

    return TemplatesFeedDto(
      items: rawItems
          .whereType<Map>()
          .map(
            (item) => TemplateItemDto.fromJson(Map<String, Object?>.from(item)),
          )
          .toList(growable: false),
      nextCursor: json['nextCursor'] as String?,
      page: (json['page'] as num?)?.toInt() ?? 1,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => {
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'nextCursor': nextCursor,
    'page': page,
    'hasMore': hasMore,
  };

  TemplatesFeedPage toDomain() => TemplatesFeedPage(
    items: items.map((item) => item.toDomain()).toList(growable: false),
    nextCursor: nextCursor,
    hasMore: hasMore,
    page: page,
  );
}

class TemplatesCatalogVersionDto {
  const TemplatesCatalogVersionDto({required this.version});

  final int version;

  factory TemplatesCatalogVersionDto.fromJson(Map<String, Object?> json) {
    return TemplatesCatalogVersionDto(
      version: (json['version'] as num?)?.toInt() ?? 0,
    );
  }
}

class TemplatesCatalogChangesDto {
  const TemplatesCatalogChangesDto({
    required this.fromVersion,
    required this.toVersion,
    required this.upserts,
    required this.deletedIds,
    required this.needsFullResync,
  });

  final int fromVersion;
  final int toVersion;
  final List<TemplateItemDto> upserts;
  final List<String> deletedIds;
  final bool needsFullResync;

  factory TemplatesCatalogChangesDto.fromJson(Map<String, Object?> json) {
    final rawUpserts = json['upserts'] as List<dynamic>? ?? const [];
    final rawDeletedIds = json['deletedIds'] as List<dynamic>? ?? const [];

    return TemplatesCatalogChangesDto(
      fromVersion: (json['fromVersion'] as num?)?.toInt() ?? 0,
      toVersion: (json['toVersion'] as num?)?.toInt() ?? 0,
      upserts: rawUpserts
          .whereType<Map>()
          .map(
            (item) => TemplateItemDto.fromJson(Map<String, Object?>.from(item)),
          )
          .toList(growable: false),
      deletedIds: rawDeletedIds.map((item) => item.toString()).toList(),
      needsFullResync: json['needsFullResync'] as bool? ?? false,
    );
  }

  TemplatesCatalogChanges toDomain() {
    return TemplatesCatalogChanges(
      fromVersion: fromVersion,
      toVersion: toVersion,
      upserts: upserts.map((item) => item.toDomain()).toList(growable: false),
      deletedIds: deletedIds,
      needsFullResync: needsFullResync,
    );
  }
}

class PublicTemplateOfTheDayDto {
  const PublicTemplateOfTheDayDto({required this.template});

  final TemplateOfTheDayItemDto? template;

  factory PublicTemplateOfTheDayDto.fromJson(Map<String, Object?> json) {
    final rawTemplate = json['template'];
    return PublicTemplateOfTheDayDto(
      template: rawTemplate is Map
          ? TemplateOfTheDayItemDto.fromJson(
              Map<String, Object?>.from(rawTemplate),
            )
          : null,
    );
  }

  TemplateOfTheDayItem? toDomain() => template?.toDomain();
}

class PublicRandomTemplateDto {
  const PublicRandomTemplateDto({required this.template});

  final TemplateItemDto? template;

  factory PublicRandomTemplateDto.fromJson(Map<String, Object?> json) {
    final rawTemplate = json['template'];
    return PublicRandomTemplateDto(
      template: rawTemplate is Map
          ? TemplateItemDto.fromJson(Map<String, Object?>.from(rawTemplate))
          : null,
    );
  }

  TemplateItem? toDomain() => template?.toDomain();
}

class TemplateOfTheDayItemDto {
  const TemplateOfTheDayItemDto({
    required this.templateId,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.type,
    required this.isPremium,
    required this.requiredPlan,
    required this.date,
    required this.source,
    required this.category,
    required this.tags,
    required this.tokenCost,
    this.thumbnailUrl,
    this.previewMediaUrl,
    this.previewAsset,
    this.isNew = false,
    this.popularityCount,
    this.expiresAtUtc,
  });

  final String templateId;
  final String title;
  final String subtitle;
  final String badgeText;
  final String type;
  final String? thumbnailUrl;
  final String? previewMediaUrl;
  final bool isPremium;
  final String requiredPlan;
  final DateTime date;
  final String source;
  final String category;
  final List<String> tags;
  final int tokenCost;
  final TemplateAssetDto? previewAsset;
  final bool isNew;
  final int? popularityCount;
  final DateTime? expiresAtUtc;

  factory TemplateOfTheDayItemDto.fromJson(Map<String, Object?> json) {
    final rawPreviewAsset = json['previewAsset'];
    return TemplateOfTheDayItemDto(
      templateId: (json['templateId'] as String? ?? '').trim(),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      badgeText: json['badgeText'] as String? ?? '',
      type: json['type'] as String? ?? 'Image',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      previewMediaUrl: json['previewMediaUrl'] as String?,
      isPremium: TemplateItemDto._toBool(json['isPremium']) ?? false,
      requiredPlan: json['requiredPlan'] as String? ?? 'free',
      date: _parseDate(json['date'] as String?),
      source: json['source'] as String? ?? 'auto',
      category: json['category'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false),
      tokenCost:
          (json['tokenCost'] as num?)?.toInt() ??
          (json['priceTokens'] as num?)?.toInt() ??
          0,
      previewAsset: rawPreviewAsset is Map
          ? TemplateAssetDto.fromJson(
              Map<String, Object?>.from(rawPreviewAsset),
            )
          : null,
      isNew: TemplateItemDto._toBool(json['isNew']) ?? false,
      popularityCount: (json['popularityCount'] as num?)?.toInt(),
      expiresAtUtc: _parseOptionalDateTime(json['expiresAt'] as String?),
    );
  }

  TemplateOfTheDayItem toDomain() => TemplateOfTheDayItem(
    templateId: templateId,
    title: title,
    subtitle: subtitle,
    badgeText: badgeText,
    templateType: templateTypeFromApi(type),
    thumbnailUrl: thumbnailUrl,
    previewMediaUrl: previewMediaUrl,
    isPremium: isPremium,
    requiredPlan: requiredPlan,
    date: date,
    source: source,
    category: category,
    tags: tags,
    tokenCost: tokenCost,
    previewAsset: previewAsset?.toDomain(),
    isNew: isNew,
    popularityCount: popularityCount,
    expiresAtUtc: expiresAtUtc,
  );

  static DateTime _parseDate(String? raw) {
    final normalized = raw?.trim();
    if (normalized != null &&
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
      final parts = normalized.split('-').map(int.parse).toList();
      return DateTime.utc(parts[0], parts[1], parts[2]);
    }

    final parsed = normalized == null ? null : DateTime.tryParse(normalized);
    return (parsed ?? DateTime.now()).toUtc();
  }

  static DateTime? _parseOptionalDateTime(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return DateTime.tryParse(normalized)?.toUtc();
  }
}
