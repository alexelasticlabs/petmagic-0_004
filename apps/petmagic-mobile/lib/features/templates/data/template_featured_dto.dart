import 'package:petmagic_mobile/features/templates/data/template_asset_dto.dart';
import 'package:petmagic_mobile/features/templates/data/template_item_dto.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

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
      isPremium: TemplateItemDto.toBool(json['isPremium']) ?? false,
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
      isNew: TemplateItemDto.toBool(json['isNew']) ?? false,
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
