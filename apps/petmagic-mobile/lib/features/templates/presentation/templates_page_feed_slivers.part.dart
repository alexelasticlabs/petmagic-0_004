part of 'templates_page.dart';

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
  final void Function(TemplateItem template, List<TemplateItem> previewItems)
  onTemplateSelected;
  final void Function(
    TemplateOfTheDayItem featured,
    List<TemplateItem> previewItems,
  )
  onTemplateOfTheDaySelected;

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
        if (featuredEntry == null ||
            template.templateId != featuredEntry.template.templateId)
          _TemplateGridEntry(template: template),
    ];
    final previewItems = List<TemplateItem>.unmodifiable(
      visibleEntries.map((entry) => entry.template),
    );

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
                  childAspectRatio: templateCardAspectRatio,
                ),
                itemBuilder: (context, index) {
                  final entry = visibleEntries[index];
                  final template = entry.template;
                  final featured = entry.templateOfTheDay;
                  if (featured != null) {
                    return TemplateCard(
                      key: ValueKey(
                        _templateCardIdentity(
                          template: template,
                          featured: featured,
                        ),
                      ),
                      template: template,
                      hasPremiumAccess: hasPremiumAccess,
                      imageCacheWidth: imageCacheWidth,
                      playbackManager: playbackManager,
                      featuredData: TemplateCardFeaturedData(
                        badgeLabel: text.templateOfTheDayFeedBadge,
                        actionLabel: text.templateTryAction,
                        countdownTarget: _templateOfTheDayCountdownTarget(
                          featured,
                        ),
                        popularityCount: featured.popularityCount,
                        isNew: featured.isNew,
                      ),
                      onPressed: () => widget.onTemplateOfTheDaySelected(
                        featured,
                        previewItems,
                      ),
                    );
                  }
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
                        ? widget.onTemplateOfTheDaySelected(
                            featured,
                            previewItems,
                          )
                        : widget.onTemplateSelected(template, previewItems),
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
