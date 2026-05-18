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
    required this.category,
    required this.effectivePromoBadge,
    required this.tags,
    required this.isPremium,
    required this.tokenCost,
    required this.previewAsset,
    required this.musicDescription,
    required this.referenceVideoDurationSeconds,
  });

  final String templateId;
  final String templateType;
  final String title;
  final String shortDescription;
  final String category;
  final String? effectivePromoBadge;
  final List<String> tags;
  final bool isPremium;
  final int tokenCost;
  final TemplateAssetDto? previewAsset;
  final String? musicDescription;
  final double? referenceVideoDurationSeconds;

  factory TemplateItemDto.fromJson(Map<String, Object?> json) {
    final rawAsset = json['previewAsset'];

    return TemplateItemDto(
      templateId: json['templateId'] as String? ?? '',
      templateType: json['templateType'] as String? ?? 'Image',
      title: json['title'] as String? ?? '',
      shortDescription: json['shortDescription'] as String? ?? '',
      category: json['category'] as String? ?? '',
      effectivePromoBadge: json['effectivePromoBadge'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      isPremium: json['isPremium'] as bool? ?? false,
      tokenCost: (json['tokenCost'] as num?)?.toInt() ?? 0,
      previewAsset: rawAsset is Map
          ? TemplateAssetDto.fromJson(Map<String, Object?>.from(rawAsset))
          : null,
      musicDescription: json['musicDescription'] as String?,
      referenceVideoDurationSeconds:
          (json['referenceVideoDurationSeconds'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() => {
    'templateId': templateId,
    'templateType': templateType,
    'title': title,
    'shortDescription': shortDescription,
    'category': category,
    'effectivePromoBadge': effectivePromoBadge,
    'tags': tags,
    'isPremium': isPremium,
    'tokenCost': tokenCost,
    'previewAsset': previewAsset?.toJson(),
    'musicDescription': musicDescription,
    'referenceVideoDurationSeconds': referenceVideoDurationSeconds,
  };

  TemplateItem toDomain() => TemplateItem(
    templateId: templateId,
    templateType: templateTypeFromApi(templateType),
    title: title,
    shortDescription: shortDescription,
    category: category,
    effectivePromoBadge: effectivePromoBadge,
    tags: tags,
    isPremium: isPremium,
    tokenCost: tokenCost,
    previewAsset: previewAsset?.toDomain(),
    musicDescription: musicDescription,
    referenceVideoDurationSeconds: referenceVideoDurationSeconds,
  );
}

class TemplatesFeedDto {
  const TemplatesFeedDto({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<TemplateItemDto> items;
  final String? nextCursor;
  final bool hasMore;

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
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => {
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'nextCursor': nextCursor,
    'hasMore': hasMore,
  };

  TemplatesFeedPage toDomain() => TemplatesFeedPage(
    items: items.map((item) => item.toDomain()).toList(growable: false),
    nextCursor: nextCursor,
    hasMore: hasMore,
  );
}
