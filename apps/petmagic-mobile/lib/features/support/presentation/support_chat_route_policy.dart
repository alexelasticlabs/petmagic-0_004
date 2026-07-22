class SupportChatRoutePolicy {
  const SupportChatRoutePolicy._();

  static const int maxInitialMessageQueryLength = 500;
  static const int maxRelatedGenerationIdQueryLength = 128;
  static final RegExp _relatedGenerationIdPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$',
  );

  static String buildRoute({
    required String routePath,
    required String initialMessageQueryParam,
    required String relatedGenerationIdQueryParam,
    String? initialMessage,
    String? relatedGenerationId,
  }) {
    final queryParameters = <String, String>{};
    final normalizedInitialMessage = normalizeInitialMessage(initialMessage);
    if (normalizedInitialMessage != null &&
        normalizedInitialMessage.isNotEmpty) {
      queryParameters[initialMessageQueryParam] = normalizedInitialMessage;
    }
    final normalizedGenerationId = normalizeRelatedGenerationId(
      relatedGenerationId,
    );
    if (normalizedGenerationId != null && normalizedGenerationId.isNotEmpty) {
      queryParameters[relatedGenerationIdQueryParam] = normalizedGenerationId;
    }

    return Uri(
      path: routePath,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
  }

  static String? normalizeInitialMessage(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized.length <= maxInitialMessageQueryLength
        ? normalized
        : normalized.substring(0, maxInitialMessageQueryLength);
  }

  static String? normalizeRelatedGenerationId(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (normalized.length > maxRelatedGenerationIdQueryLength ||
        !_relatedGenerationIdPattern.hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }
}
