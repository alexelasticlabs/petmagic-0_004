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

class _TemplateFeedSlivers extends ConsumerStatefulWidget {
  const _TemplateFeedSlivers({
    required this.bottomInset,
    required this.templateOfTheDay,
    required this.selectedType,
    required this.selectedCategory,
    required this.searchQuery,
    required this.onTemplateSelected,
    required this.onTemplateOfTheDaySelected,
  });

  final double bottomInset;
  final TemplateOfTheDayItem? templateOfTheDay;
  final TemplateType? selectedType;
  final String? selectedCategory;
  final String? searchQuery;
  final ValueChanged<TemplateItem> onTemplateSelected;
  final ValueChanged<TemplateOfTheDayItem> onTemplateOfTheDaySelected;

  @override
  ConsumerState<_TemplateFeedSlivers> createState() =>
      _TemplateFeedSliversState();
}

class _TemplateFeedSliversState extends ConsumerState<_TemplateFeedSlivers> {
  TemplateFeedKind? _configuredFeedKind;
  TemplateFeedPlaybackEnvironment? _configuredEnvironment;
  String? _configuredFeedScopeKey;
  TemplateFeedKind? _pendingFeedKind;
  TemplateFeedPlaybackEnvironment? _pendingEnvironment;
  String? _pendingFeedScopeKey;
  bool _configurationScheduled = false;

  void _schedulePlaybackConfiguration({
    required TemplateFeedPlaybackManager manager,
    required TemplateFeedKind feedKind,
    required TemplateFeedPlaybackEnvironment environment,
    required String feedScopeKey,
  }) {
    if (_configuredFeedKind == feedKind &&
        _configuredEnvironment == environment &&
        _configuredFeedScopeKey == feedScopeKey) {
      return;
    }

    _pendingFeedKind = feedKind;
    _pendingEnvironment = environment;
    _pendingFeedScopeKey = feedScopeKey;
    if (_configurationScheduled) {
      return;
    }

    _configurationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _configurationScheduled = false;
      if (!mounted) {
        return;
      }

      final nextFeedKind = _pendingFeedKind;
      final nextEnvironment = _pendingEnvironment;
      final nextFeedScopeKey = _pendingFeedScopeKey;
      if (nextFeedKind == null ||
          nextEnvironment == null ||
          nextFeedScopeKey == null) {
        return;
      }

      _configuredFeedKind = nextFeedKind;
      _configuredEnvironment = nextEnvironment;
      _configuredFeedScopeKey = nextFeedScopeKey;
      manager.configure(
        feedKind: nextFeedKind,
        environment: nextEnvironment,
        feedScopeKey: nextFeedScopeKey,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      templatesControllerProvider.select(
        (state) => (
          items: state.items,
          isInitialLoading: state.isInitialLoading,
          isEmpty: state.isEmpty,
          isLoadingMore: state.isLoadingMore,
          errorMessage: state.errorMessage,
        ),
      ),
    );
    final hasPremiumAccess = ref.watch(templatePremiumAccessProvider);
    final controller = ref.read(templatesControllerProvider.notifier);
    final playbackManager = ref.watch(templateFeedPlaybackManagerProvider);
    final playbackEnvironment = ref.watch(
      templateFeedPlaybackEnvironmentProvider,
    );
    final feedKind = widget.selectedType == TemplateType.video
        ? TemplateFeedKind.videoOnly
        : TemplateFeedKind.mixed;
    final feedScopeKey = Object.hash(
      widget.selectedType,
      widget.selectedCategory,
      widget.searchQuery,
    ).toString();
    _schedulePlaybackConfiguration(
      manager: playbackManager,
      feedKind: feedKind,
      environment: playbackEnvironment,
      feedScopeKey: feedScopeKey,
    );
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((state) => state.hasInternet),
    );

    if (state.isInitialLoading) {
      return const SliverMagicLoadingScreen();
    }

    if (state.errorMessage != null && state.items.isEmpty) {
      final unavailableKind = classifyAppUnavailable(
        raw: state.errorMessage,
        hasInternet: hasInternet,
      );
      if (unavailableKind != null) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: PetMagicUnavailableView(
            kind: unavailableKind,
            onRetry: () => controller.loadInitial(forceRefresh: true),
            padding: EdgeInsets.fromLTRB(28, 36, 28, widget.bottomInset),
          ),
        );
      }

      return SliverFillRemaining(
        hasScrollBody: false,
        child: _StateMessage(
          icon: Icons.cloud_off_rounded,
          title: text.templatesErrorTitle,
          message: _mapTemplatesError(text, state.errorMessage!),
          actionLabel: text.retryAction,
          onAction: () => controller.loadInitial(forceRefresh: true),
        ),
      );
    }

    if (state.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _StateMessage(
          icon: Icons.auto_awesome_motion_rounded,
          title: text.emptyTemplatesTitle,
          message: text.emptyTemplatesMessage,
          actionLabel: text.retryAction,
          onAction: () => controller.loadInitial(forceRefresh: true),
        ),
      );
    }

    final featuredEntry = _buildFeaturedTemplateGridEntry(
      templateOfTheDay: widget.templateOfTheDay,
      visibleTemplates: state.items,
      selectedType: widget.selectedType,
      selectedCategory: widget.selectedCategory,
      searchQuery: widget.searchQuery,
    );
    final visibleEntries = <_TemplateGridEntry>[
      ?featuredEntry,
      for (final template in state.items)
        if (template.templateId != widget.templateOfTheDay?.templateId)
          _TemplateGridEntry(template: template),
    ];

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final logicalCardWidth = (constraints.crossAxisExtent - 5) / 2;
              final imageCacheWidth =
                  templateCardImageCacheWidthForLogicalWidth(
                    logicalCardWidth,
                    MediaQuery.devicePixelRatioOf(context),
                  );

              return SliverGrid.builder(
                itemCount: visibleEntries.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.72,
                ),
                itemBuilder: (context, index) {
                  final entry = visibleEntries[index];
                  final template = entry.template;
                  final featured = entry.templateOfTheDay;
                  final templateIdentity = _templateCardIdentity(
                    template: template,
                    featured: featured,
                  );
                  final card = TemplateCard(
                    key: ValueKey(templateIdentity),
                    template: template,
                    hasPremiumAccess: hasPremiumAccess,
                    imageCacheWidth: imageCacheWidth,
                    playbackManager: playbackManager,
                    highlightBadgeLabel: featured != null
                        ? text.templateOfTheDayFeedBadge
                        : null,
                    featuredData: featured == null
                        ? null
                        : TemplateCardFeaturedData(
                            badgeLabel: text.templateOfTheDayFeedBadge,
                            actionLabel: text.templateOfTheDayTryAction,
                            countdownTarget: _templateOfTheDayCountdownTarget(
                              featured,
                            ),
                            popularityCount: featured.popularityCount,
                            isNew: featured.isNew,
                          ),
                    onPressed: () => featured != null
                        ? widget.onTemplateOfTheDaySelected(featured)
                        : widget.onTemplateSelected(template),
                  );
                  if (index >= 6) {
                    return card;
                  }

                  return TweenAnimationBuilder<double>(
                    key: ValueKey('template-item-$templateIdentity'),
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 130 + (index % 6) * 20),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      final clamped = value.clamp(0.0, 1.0);
                      return Opacity(
                        opacity: clamped,
                        child: Transform.translate(
                          offset: Offset(0, (1 - clamped) * 8),
                          child: child,
                        ),
                      );
                    },
                    child: card,
                  );
                },
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, widget.bottomInset),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: state.isLoadingMore
                  ? Center(
                      child: CircularProgressIndicator.adaptive(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.accent,
                        ),
                      ),
                    )
                  : state.errorMessage != null
                  ? TextButton.icon(
                      onPressed: controller.loadMore,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(text.retryAction),
                    )
                  : const SizedBox(height: 28),
            ),
          ),
        ),
      ],
    );
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
