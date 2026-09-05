import 'package:petmagic_mobile/features/templates/data/template_item_dto.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';

final class TemplateDiscoveryDto {
  const TemplateDiscoveryDto({
    required this.sections,
    required this.generatedAtUtc,
    this.schemaVersion = 1,
    this.revision,
    this.page,
  });

  final List<TemplateDiscoverySectionDto> sections;
  final DateTime generatedAtUtc;
  final int schemaVersion;
  final int? revision;
  final TemplateDiscoveryPageSettings? page;

  factory TemplateDiscoveryDto.fromJson(Map<String, Object?> json) {
    final generatedAt = DateTime.tryParse(
      json['generatedAtUtc']?.toString() ?? '',
    );
    final schemaVersion = _readInt(json['schemaVersion']) ?? 1;
    final supportsSettings = schemaVersion == 2;
    final pageJson = json['page'];
    return TemplateDiscoveryDto(
      schemaVersion: schemaVersion,
      revision: supportsSettings ? _readInt(json['revision']) : null,
      page: supportsSettings && pageJson is Map
          ? TemplateDiscoveryPageSettings(
              title: _readText(pageJson['title']),
              subtitle: _readText(pageJson['subtitle'], allowEmpty: true),
              searchEnabled: _readBool(pageJson['searchEnabled']),
              carouselEnabled: _readBool(pageJson['carouselEnabled']),
              autoplayEnabled: _readBool(pageJson['autoplayEnabled']),
              autoplayIntervalMs:
                  (_readInt(pageJson['autoplayIntervalMs']) ?? 7000).clamp(
                    5000,
                    30000,
                  ),
            )
          : null,
      sections: (json['sections'] is List ? json['sections'] as List : const [])
          .whereType<Map>()
          .map(
            (section) => TemplateDiscoverySectionDto.fromJson(
              Map<String, Object?>.from(section),
              supportsSettings: supportsSettings,
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
    'schemaVersion': schemaVersion,
    'revision': revision,
    if (page case final settings?)
      'page': {
        'title': settings.title,
        'subtitle': settings.subtitle,
        'searchEnabled': settings.searchEnabled,
        'carouselEnabled': settings.carouselEnabled,
        'autoplayEnabled': settings.autoplayEnabled,
        'autoplayIntervalMs': settings.autoplayIntervalMs,
      },
  };

  TemplateDiscovery toDomain() => TemplateDiscovery(
    sections: sections.map((section) => section.toDomain()).toList(),
    generatedAtUtc: generatedAtUtc,
    schemaVersion: schemaVersion,
    revision: revision,
    page: page,
  );
}

final class TemplateDiscoverySectionDto {
  const TemplateDiscoverySectionDto({
    required this.category,
    required this.items,
    this.sectionId,
    this.categoryId,
    this.title,
    this.subtitle,
    this.showInCarousel = true,
    this.showAsRail = true,
  });

  final String category;
  final List<TemplateItemDto> items;
  final String? sectionId;
  final String? categoryId;
  final String? title;
  final String? subtitle;
  final bool showInCarousel;
  final bool showAsRail;

  factory TemplateDiscoverySectionDto.fromJson(
    Map<String, Object?> json, {
    bool supportsSettings = true,
  }) {
    return TemplateDiscoverySectionDto(
      category: json['category']?.toString().trim() ?? '',
      sectionId: supportsSettings ? _readText(json['sectionId']) : null,
      categoryId: supportsSettings ? _readText(json['categoryId']) : null,
      title: supportsSettings ? _readText(json['title']) : null,
      subtitle: supportsSettings ? _readText(json['subtitle']) : null,
      showInCarousel: !supportsSettings || _readBool(json['showInCarousel']),
      showAsRail: !supportsSettings || _readBool(json['showAsRail']),
      items: (json['items'] is List ? json['items'] as List : const [])
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
    'sectionId': sectionId,
    'categoryId': categoryId,
    'title': title,
    'subtitle': subtitle,
    'showInCarousel': showInCarousel,
    'showAsRail': showAsRail,
  };

  TemplateDiscoverySection toDomain() => TemplateDiscoverySection(
    category: category,
    items: items.map((item) => item.toDomain()).toList(growable: false),
    sectionId: sectionId,
    categoryId: categoryId,
    title: title,
    subtitle: subtitle,
    showInCarousel: showInCarousel,
    showAsRail: showAsRail,
  );
}

String? _readText(Object? value, {bool allowEmpty = false}) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty && !allowEmpty ? null : text;
}

int? _readInt(Object? value) => value is int ? value : null;

bool _readBool(Object? value) => value is bool ? value : true;
