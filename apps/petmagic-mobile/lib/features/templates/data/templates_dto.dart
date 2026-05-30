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
      isPremium: json['isPremium'] as bool? ?? false,
      tokenCost:
          (json['tokenCost'] as num?)?.toInt() ??
          (json['priceTokens'] as num?)?.toInt() ??
          0,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      previewAsset: parsedAsset,
      musicDescription: json['musicDescription'] as String?,
      referenceVideoDurationSeconds:
          (json['referenceVideoDurationSeconds'] as num?)?.toDouble(),
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
