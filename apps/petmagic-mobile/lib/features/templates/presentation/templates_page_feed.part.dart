part of 'templates_page.dart';

class _TemplateGridEntry {
  const _TemplateGridEntry({required this.template, this.templateOfTheDay});

  final TemplateItem template;
  final TemplateOfTheDayItem? templateOfTheDay;
}

_TemplateGridEntry? _buildFeaturedTemplateGridEntry({
  required TemplateOfTheDayItem? templateOfTheDay,
  required List<TemplateItem> visibleTemplates,
  required TemplateType? selectedType,
  required String? selectedCategory,
  required String? searchQuery,
}) {
  final featured = templateOfTheDay;
  if (featured == null ||
      !_matchesTemplateOfTheDayFilters(
        featured,
        selectedType: selectedType,
        selectedCategory: selectedCategory,
        searchQuery: searchQuery,
      )) {
    return null;
  }

  return _TemplateGridEntry(
    template: _mergeFeaturedTemplateWithVisibleItem(
      featured: featured,
      visibleTemplate: _findTemplateById(visibleTemplates, featured.templateId),
    ),
    templateOfTheDay: featured,
  );
}

TemplateItem _mergeFeaturedTemplateWithVisibleItem({
  required TemplateOfTheDayItem featured,
  required TemplateItem? visibleTemplate,
}) {
  final fallbackTemplate = featured.toFallbackTemplateItem();
  final template = visibleTemplate;
  if (template == null) {
    return fallbackTemplate;
  }

  return TemplateItem(
    templateId: template.templateId,
    templateType: template.templateType,
    title: featured.title.trim().isEmpty ? template.title : featured.title,
    shortDescription: featured.subtitle.trim().isEmpty
        ? template.shortDescription
        : featured.subtitle,
    petPhotoRequirements: template.petPhotoRequirements,
    category: featured.category.trim().isEmpty
        ? template.category
        : featured.category,
    tags: featured.tags.isNotEmpty ? featured.tags : template.tags,
    isPremium: featured.isPremium || template.isPremium,
    tokenCost: template.tokenCost,
    effectivePromoBadge: template.effectivePromoBadge,
    thumbnailUrl: template.thumbnailUrl ?? fallbackTemplate.thumbnailUrl,
    previewAsset: template.previewAsset ?? fallbackTemplate.previewAsset,
    musicDescription: template.musicDescription,
    referenceVideoDurationSeconds: template.referenceVideoDurationSeconds,
    supportsGenerationResultInput: template.supportsGenerationResultInput,
    requiredInputMediaType: template.requiredInputMediaType,
    recommendedAfterImageGeneration: template.recommendedAfterImageGeneration,
    supportsGenerateSimilar: template.supportsGenerateSimilar,
    defaultVariationStrength: template.defaultVariationStrength,
    version: template.version,
    updatedAtUtc: template.updatedAtUtc,
  );
}

bool _matchesTemplateOfTheDayFilters(
  TemplateOfTheDayItem template, {
  required TemplateType? selectedType,
  required String? selectedCategory,
  required String? searchQuery,
}) {
  if (selectedType != null && template.templateType != selectedType) {
    return false;
  }

  final normalizedCategory = selectedCategory?.trim().toLowerCase();
  if (normalizedCategory != null &&
      normalizedCategory.isNotEmpty &&
      template.category.trim().toLowerCase() != normalizedCategory) {
    return false;
  }

  final normalizedSearch = searchQuery?.trim().toLowerCase();
  if (normalizedSearch == null || normalizedSearch.isEmpty) {
    return true;
  }

  return [
        template.title,
        template.subtitle,
        template.category,
        ...template.tags,
      ]
      .map((value) => value.trim().toLowerCase())
      .any((value) => value.contains(normalizedSearch));
}

DateTime _templateOfTheDayCountdownTarget(TemplateOfTheDayItem featured) {
  return featured.expiresAtUtc?.toUtc() ??
      DateTime.utc(
        featured.date.year,
        featured.date.month,
        featured.date.day + 1,
      );
}

String _templateCardIdentity({
  required TemplateItem template,
  TemplateOfTheDayItem? featured,
}) {
  return featured == null
      ? '${template.templateId}|${template.mediaIdentity}'
      : '${template.templateId}|featured|${template.mediaIdentity}|${_templateOfTheDayDateValue(featured)}';
}

String _mapTemplatesError(AppLocalizations text, String raw) {
  final value = raw.toLowerCase();

  if (value.contains('templates.feed_response_empty')) {
    return text.templatesFeedEmptyError;
  }

  if (value.contains('templates.catalog_page_response_empty')) {
    return text.templatesFeedEmptyError;
  }

  if (value.contains('templates.connection_timeout')) {
    return text.templatesConnectionTimeoutError;
  }

  if (value.contains('templates.server_timeout')) {
    return text.templatesServerTimeoutError;
  }

  if (value.contains('templates.request_failed')) {
    return text.templatesRequestFailedError;
  }

  return text.templatesRequestFailedError;
}

String _generationStartErrorText(AppLocalizations text, String raw) {
  if (raw.contains('auth.sign_in_required')) {
    return text.authSignInRequired;
  }

  if (raw.contains('auth.session_expired')) {
    return text.authSessionExpired;
  }

  if (raw.contains('templates.premium_required')) {
    return text.templateFlowPremiumRequiredError;
  }

  if (raw.contains('templates.insufficient_balance')) {
    return text.templateFlowInsufficientBalanceError;
  }

  if (raw.contains('templates.generation_already_started')) {
    return text.templateFlowActiveGenerationLimitError;
  }

  if (raw.contains('templates.generation_wait_too_long')) {
    return text.templateFlowServerError;
  }

  if (raw.contains('templates.template_unavailable')) {
    return text.templateFlowTemplateUnavailableError;
  }

  if (raw.contains('templates.template_changed')) {
    return text.templateFlowTemplateChangedError;
  }

  if (raw.contains('templates.network_unavailable')) {
    return text.templateFlowNetworkError;
  }

  if (raw.contains('templates.server_unavailable')) {
    return text.templateFlowServerError;
  }

  return text.templateFlowStartFailedError;
}

bool _isAuthRequiredError(String? raw) {
  if (raw == null || raw.isEmpty) {
    return false;
  }

  return raw.contains('auth.sign_in_required') ||
      raw.contains('auth.session_expired');
}

String _templateOfTheDayDateValue(TemplateOfTheDayItem featured) {
  final date = featured.date.toUtc();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class _TemplatesLifecycleObserver with WidgetsBindingObserver {
  _TemplatesLifecycleObserver({
    required this.onStateChanged,
    required this.onMemoryPressure,
  });

  final ValueChanged<AppLifecycleState> onStateChanged;
  final VoidCallback onMemoryPressure;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onStateChanged(state);
  }

  @override
  void didHaveMemoryPressure() {
    onMemoryPressure();
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final bottomInset = petMagicBottomNavInset(
      context,
      extraSpacing: kPetMagicBottomContentInsetRelaxed,
    );

    return PetMagicAsyncStateView(
      icon: icon,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      padding: EdgeInsets.fromLTRB(28, 36, 28, bottomInset),
    );
  }
}
