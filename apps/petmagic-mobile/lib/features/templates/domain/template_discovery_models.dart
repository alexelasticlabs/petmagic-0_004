import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

final class TemplateDiscoverySection {
  const TemplateDiscoverySection({required this.category, required this.items});

  final String category;
  final List<TemplateItem> items;

  TemplateItem? get representative => items.isEmpty ? null : items.first;
}

final class TemplateDiscovery {
  const TemplateDiscovery({
    required this.sections,
    required this.generatedAtUtc,
  });

  final List<TemplateDiscoverySection> sections;
  final DateTime generatedAtUtc;
}
