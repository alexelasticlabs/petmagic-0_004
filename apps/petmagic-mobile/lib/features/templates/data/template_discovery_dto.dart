import 'package:petmagic_mobile/features/templates/data/template_item_dto.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';

final class TemplateDiscoveryDto {
  const TemplateDiscoveryDto({
    required this.sections,
    required this.generatedAtUtc,
  });

  final List<TemplateDiscoverySectionDto> sections;
  final DateTime generatedAtUtc;

  factory TemplateDiscoveryDto.fromJson(Map<String, Object?> json) {
    final generatedAt = DateTime.tryParse(
      json['generatedAtUtc']?.toString() ?? '',
    );
    return TemplateDiscoveryDto(
      sections: (json['sections'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (section) => TemplateDiscoverySectionDto.fromJson(
              Map<String, Object?>.from(section),
            ),
          )
          .where((section) => section.category.isNotEmpty)
          .toList(growable: false),
      generatedAtUtc: (generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .toUtc(),
    );
  }

  Map<String, Object?> toJson() => {
    'sections': sections.map((section) => section.toJson()).toList(),
    'generatedAtUtc': generatedAtUtc.toUtc().toIso8601String(),
  };

  TemplateDiscovery toDomain() => TemplateDiscovery(
    sections: sections.map((section) => section.toDomain()).toList(),
    generatedAtUtc: generatedAtUtc,
  );
}

final class TemplateDiscoverySectionDto {
  const TemplateDiscoverySectionDto({
    required this.category,
    required this.items,
  });

  final String category;
  final List<TemplateItemDto> items;

  factory TemplateDiscoverySectionDto.fromJson(Map<String, Object?> json) {
    return TemplateDiscoverySectionDto(
      category: json['category']?.toString().trim() ?? '',
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => TemplateItemDto.fromJson(Map<String, Object?>.from(item)),
          )
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => {
    'category': category,
    'items': items.map((item) => item.toJson()).toList(),
  };

  TemplateDiscoverySection toDomain() => TemplateDiscoverySection(
    category: category,
    items: items.map((item) => item.toDomain()).toList(growable: false),
  );
}
