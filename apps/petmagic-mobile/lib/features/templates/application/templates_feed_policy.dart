import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

abstract final class TemplatesFeedPolicy {
  static const maxInMemoryFeedCaches = 6;

  static String? normalizeCategory(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static List<String> normalizeCategories(List<String> values) {
    final unique = <String>{};
    final ordered = <String>[];
    for (final value in values) {
      final normalized = normalizeCategory(value);
      if (normalized != null && unique.add(normalized.toLowerCase())) {
        ordered.add(normalized);
      }
    }
    return ordered;
  }

  static Map<String, TemplatesFeedPage> rememberPage(
    Map<String, TemplatesFeedPage> current,
    String queryKey,
    TemplatesFeedPage page,
  ) {
    final updated = Map<String, TemplatesFeedPage>.from(current)
      ..remove(queryKey)
      ..[queryKey] = page;
    while (updated.length > maxInMemoryFeedCaches) {
      updated.remove(updated.keys.first);
    }
    return updated;
  }

  static String? normalizeMediaUrl(String? rawUrl) {
    final trimmed = rawUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final sanitized = Uri.encodeFull(trimmed.replaceAll('\\', '/'));
    final parsed = Uri.tryParse(sanitized);
    if (parsed?.hasScheme == true) return parsed.toString();

    final baseUri = Uri.tryParse(AppConfig.apiBaseUrl);
    if (baseUri == null) return sanitized;
    if (sanitized.startsWith('//')) {
      final scheme = baseUri.scheme.isNotEmpty ? baseUri.scheme : 'http';
      return '$scheme:$sanitized';
    }
    final relativePath = sanitized.startsWith('/') ? sanitized : '/$sanitized';
    return baseUri.resolve(relativePath).toString();
  }
}
