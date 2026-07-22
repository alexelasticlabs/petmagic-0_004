const int _realtimePayloadStringMaxLength = 128;

/// Validated realtime invalidation payload used by catalog orchestration.
final class TemplateFeedInvalidation {
  const TemplateFeedInvalidation({
    required this.scope,
    this.templateId,
    this.category,
    this.mediaVersion,
    this.templateType,
    this.isPubliclyVisible,
    this.isCritical = false,
    this.reason,
  });

  final String scope;
  final String? templateId;
  final String? category;
  final int? mediaVersion;
  final String? templateType;
  final bool? isPubliclyVisible;
  final bool isCritical;
  final String? reason;

  bool get isFull => scope == 'full';
  bool get isTemplate => scope == 'template';
  bool get isCategory => scope == 'category';
  bool get isTemplateOfTheDay => scope == 'templateOfTheDay';
  bool get isUnavailable => isPubliclyVisible == false || isCritical;
  bool get hasMediaChange => mediaVersion != null;

  static TemplateFeedInvalidation? fromPayload(Map<String, Object?> payload) {
    if (payload.isEmpty) {
      return const TemplateFeedInvalidation(scope: 'full');
    }
    final scope = _readString(payload['scope']);
    if (scope == null) return null;
    return TemplateFeedInvalidation(
      scope: scope,
      templateId: _readString(payload['templateId']),
      category: _readString(payload['category']),
      mediaVersion: _readInt(payload['mediaVersion']),
      templateType: _readString(payload['templateType']),
      isPubliclyVisible: _readBool(payload['isPubliclyVisible']),
      isCritical: _readBool(payload['isCritical']) ?? false,
      reason: _readString(payload['reason']),
    );
  }

  static String? _readString(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    if (text.length > _realtimePayloadStringMaxLength) return null;
    return text.isEmpty ? null : text;
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String && value.length <= 20) {
      return int.tryParse(value);
    }
    return null;
  }

  static bool? _readBool(Object? value) {
    if (value is bool) return value;
    if (value is! String || value.length > 5) return null;
    return switch (value.trim().toLowerCase()) {
      'true' => true,
      'false' => false,
      _ => null,
    };
  }
}
