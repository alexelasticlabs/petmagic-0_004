import 'package:flutter/foundation.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';

/// Owns normalization and configured-endpoint policy independently from
/// resolver lifecycle and network probing.
final class ApiBaseUrlPolicy {
  const ApiBaseUrlPolicy(this.configuredBaseUrls);

  final List<String> configuredBaseUrls;

  String? normalize(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }

    if (!kDebugMode && scheme != 'https') {
      return null;
    }

    if (!kDebugMode) {
      return AppConfig.normalizeProductionBaseUrl(trimmed);
    }

    final authority = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    return '$scheme://$authority';
  }

  bool isConfiguredCandidate(String baseUrl) {
    final normalized = normalize(baseUrl);
    if (normalized == null) {
      return false;
    }

    return configuredBaseUrls.any(
      (configured) => normalize(configured) == normalized,
    );
  }

  String configuredFallback() {
    for (final configured in configuredBaseUrls) {
      final normalized = normalize(configured);
      if (normalized != null) {
        return normalized;
      }
    }

    return AppConfig.apiBaseUrl;
  }

  String logSafeOrigin(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      return 'invalid';
    }

    return uri.hasPort ? '${uri.scheme}://${uri.host}:${uri.port}' : uri.origin;
  }
}
