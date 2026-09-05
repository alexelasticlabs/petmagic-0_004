import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

final class TemplateDiscoverySection {
  const TemplateDiscoverySection({
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
  final List<TemplateItem> items;
  final String? sectionId;
  final String? categoryId;
  final String? title;
  final String? subtitle;
  final bool showInCarousel;
  final bool showAsRail;

  String get identity => sectionId ?? category;
  String get displayTitle => title ?? category;

  TemplateItem? get representative => items.isEmpty ? null : items.first;
}

final class TemplateDiscovery {
  const TemplateDiscovery({
    required this.sections,
    required this.generatedAtUtc,
    this.schemaVersion = 1,
    this.revision,
    this.page,
  });

  final List<TemplateDiscoverySection> sections;
  final DateTime generatedAtUtc;
  final int schemaVersion;
  final int? revision;
  final TemplateDiscoveryPageSettings? page;
}

final class TemplateDiscoveryPageSettings {
  const TemplateDiscoveryPageSettings({
    this.title,
    this.subtitle,
    this.searchEnabled = true,
    this.carouselEnabled = true,
    this.autoplayEnabled = true,
    this.autoplayIntervalMs = 7000,
  });

  final String? title;
  final String? subtitle;
  final bool searchEnabled;
  final bool carouselEnabled;
  final bool autoplayEnabled;
  final int autoplayIntervalMs;

  Duration get autoAdvanceInterval =>
      Duration(milliseconds: autoplayIntervalMs.clamp(5000, 30000));
}
