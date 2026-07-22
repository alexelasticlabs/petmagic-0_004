import 'package:petmagic_mobile/features/templates/data/templates_dto.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_results.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

part 'template_generation_result_dto.part.dart';

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
