part of 'templates_page.dart';

extension _TemplatesPageTemplateActions on _TemplatesPageState {
  Future<bool> _handleTemplateSelected(
    TemplateItem template, {
    TemplateOfTheDayItem? templateOfTheDay,
    TemplatePreviewSession? previewSession,
    List<TemplateItem>? previewItems,
    TemplatePreviewSource source = TemplatePreviewSource.catalog,
    bool initialDetailResolved = false,
  }) async {
    final session =
        previewSession ??
        (previewItems == null
            ? TemplatePreviewSession.single(template, source: source)
            : TemplatePreviewSession.fromSelection(
                items: previewItems,
                selectedTemplate: template,
                source: source,
                initialDetailResolved: initialDetailResolved,
                loadMore:
                    source == TemplatePreviewSource.catalog ||
                        source == TemplatePreviewSource.featured
                    ? _createTemplatePreviewPageLoader()
                    : null,
              ));

    final isAuthenticated = ref
        .read(appLaunchControllerProvider)
        .isAuthenticated;
    final hasPremiumAccess = ref.read(templatePremiumAccessProvider);
    final rawResult = await context.appNavigator.push<Object?>(
      TemplatePreviewDestination(
        templateId: session.initialTemplate.templateId,
        payload: TemplatePreviewRouteArgs(
          template: session.initialTemplate,
          hasPremiumAccess: hasPremiumAccess,
          isAuthenticated: isAuthenticated,
          session: session,
        ),
      ),
    );
    if (!mounted) {
      return false;
    }

    final TemplateItem selectedTemplate;
    if (rawResult is TemplatePreviewResult &&
        rawResult.action == TemplateDetailAction.upload) {
      selectedTemplate = rawResult.selectedTemplate;
    } else if (rawResult == TemplateDetailAction.upload) {
      // Keep compatibility with older navigator fakes and any restored route.
      selectedTemplate = template;
    } else {
      return false;
    }

    final selectedFeatured =
        templateOfTheDay?.templateId == selectedTemplate.templateId
        ? templateOfTheDay
        : null;
    await _startTemplateUploadFlow(
      selectedTemplate,
      templateOfTheDay: selectedFeatured,
    );
    return true;
  }

  TemplatePreviewPageLoader? _createTemplatePreviewPageLoader() {
    final state = ref.read(templatesControllerProvider);
    var nextCursor = state.nextCursor;
    var currentPage = state.currentPage;
    var hasMore = state.hasMore;
    if (!hasMore || nextCursor == null || nextCursor.trim().isEmpty) {
      return null;
    }

    final baseQuery = state.query.copyWith(resetPage: true);
    final repository = ref.read(templatesRepositoryProvider);
    return () async {
      final cursor = nextCursor;
      if (!hasMore || cursor == null || cursor.trim().isEmpty) {
        return const TemplatePreviewPageBatch(items: [], hasMore: false);
      }

      final page = await repository.fetchFeed(
        baseQuery.copyWith(page: currentPage + 1, cursor: cursor),
      );
      currentPage = page.page;
      final advancedCursor =
          page.nextCursor != null &&
          page.nextCursor!.trim().isNotEmpty &&
          page.nextCursor != cursor;
      nextCursor = page.nextCursor;
      hasMore = page.hasMore && advancedCursor;
      return TemplatePreviewPageBatch(items: page.items, hasMore: hasMore);
    };
  }

  Future<void> _handleTemplateOfTheDaySelected(
    TemplateOfTheDayItem featured,
    List<TemplateItem> previewItems,
  ) async {
    unawaited(_recordTemplateOfTheDayAnalytics(featured, 'clicked'));

    final visibleTemplate =
        _findTemplateById(previewItems, featured.templateId) ??
        _findTemplateById(
          ref.read(templatesControllerProvider).items,
          featured.templateId,
        );
    if (visibleTemplate != null) {
      await _openTemplateOfTheDayTemplate(
        featured,
        visibleTemplate,
        previewItems: previewItems,
      );
      return;
    }

    try {
      final template = await ref
          .read(templatesRepositoryProvider)
          .fetchTemplate(
            featured.templateId,
            forceRefresh: true,
            analyticsSource: TemplatePreviewSource.featured.analyticsValue,
          );
      if (!mounted) {
        return;
      }

      await _openTemplateOfTheDayTemplate(
        featured,
        template,
        previewItems: previewItems,
        initialDetailResolved: true,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.TemplateOfTheDay',
        operation: 'load_detail_for_selection',
        message:
            'Template of the Day detail fetch failed; using fallback template',
        context: {'templateId': featured.templateId},
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }

      await _openTemplateOfTheDayTemplate(
        featured,
        featured.toFallbackTemplateItem(),
        previewItems: previewItems,
      );
    }
  }

  Future<void> _openTemplateOfTheDayTemplate(
    TemplateOfTheDayItem featured,
    TemplateItem template, {
    required List<TemplateItem> previewItems,
    bool initialDetailResolved = false,
  }) async {
    unawaited(_recordTemplateOfTheDayAnalytics(featured, 'opened'));
    await _handleTemplateSelected(
      template,
      templateOfTheDay: featured,
      previewItems: previewItems,
      source: TemplatePreviewSource.featured,
      initialDetailResolved: initialDetailResolved,
    );
  }

  Future<void> _handleRandomTemplatePressed() async {
    if (!mounted || !_canUseVisibleTemplatesUi) {
      return;
    }

    final activeQuery = ref.read(templatesControllerProvider).query;
    final categories = ref.read(templatesControllerProvider).categories;
    final template = await showRandomTemplateSettingsSheet(
      context,
      initialType: activeQuery.type,
      initialCategory: activeQuery.category,
      categories: categories,
      onFind: _findRandomTemplate,
    );
    if (!mounted || !_canUseVisibleTemplatesUi || template == null) {
      return;
    }

    await _handleTemplateSelected(
      template,
      source: TemplatePreviewSource.random,
    );
  }

  Future<TemplateItem?> _findRandomTemplate(
    RandomTemplateSettings settings,
  ) async {
    if (!mounted || !_canUseVisibleTemplatesUi) {
      return null;
    }

    final mode = randomModeForTemplateType(settings.type);

    _setPageState(() {
      _isRandomTemplateLoading = true;
    });

    final hasPremiumAccess = ref.read(templatePremiumAccessProvider);
    final randomRepository = ref.read(templatesRepositoryProvider);
    _activeRandomTemplateRepository = randomRepository;

    try {
      final template = await randomRepository.fetchRandomTemplate(
        mode: mode,
        category: settings.category,
        includePremium: hasPremiumAccess,
        access: settings.access,
      );
      if (identical(_activeRandomTemplateRepository, randomRepository)) {
        _activeRandomTemplateRepository = null;
      }

      if (!mounted || !_canUseVisibleTemplatesUi) {
        return null;
      }

      return template;
    } finally {
      if (identical(_activeRandomTemplateRepository, randomRepository)) {
        _activeRandomTemplateRepository = null;
      }

      if (mounted && _canUseVisibleTemplatesUi) {
        _setPageState(() {
          _isRandomTemplateLoading = false;
        });
      } else {
        _isRandomTemplateLoading = false;
      }
    }
  }

  bool get _canUseVisibleTemplatesUi =>
      mounted && _isAppResumed && _isTabActive == true;

  void _cancelPendingRandomTemplateRequest({bool clearLoadingState = true}) {
    final repository = _activeRandomTemplateRepository;
    _activeRandomTemplateRepository = null;
    repository?.cancelPendingRandomTemplateRequest();
    if (!_isRandomTemplateLoading) {
      return;
    }

    if (clearLoadingState && mounted) {
      _setPageState(() {
        _isRandomTemplateLoading = false;
      });
      return;
    }

    _isRandomTemplateLoading = false;
  }

  void _trackTemplateOfTheDayViewed(TemplateOfTheDayItem? featured) {
    if (featured == null) {
      return;
    }

    final key =
        '${featured.templateId}:${_templateOfTheDayDateValue(featured)}:templates';
    if (!_trackedTemplateOfTheDayViews.add(key)) {
      return;
    }

    _runAfterBuild(() {
      unawaited(_recordTemplateOfTheDayAnalytics(featured, 'viewed'));
    });
  }

  Future<void> _recordTemplateOfTheDayAnalytics(
    TemplateOfTheDayItem featured,
    String eventType, {
    String? generationId,
    Map<String, Object?>? extraMetadata,
  }) async {
    try {
      final wallet = ref.read(walletControllerProvider).wallet;
      await ref
          .read(templatesRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: featured.templateId,
            eventType: eventType,
            source: featured.source,
            generationId: generationId,
            metadata: <String, Object?>{
              'templateId': featured.templateId,
              'type': featured.templateType.apiValue.toLowerCase(),
              'source': featured.source,
              'isPremium': featured.isPremium,
              'userPlan': wallet?.isPremium == true ? 'premium' : 'free',
              'date': _templateOfTheDayDateValue(featured),
              'screen': 'templates',
              ...?extraMetadata,
            },
          );
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.TemplateOfTheDay',
        operation: 'analytics',
        message: 'Could not record Template of the Day analytics event.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'eventType': eventType,
          'templateId': featured.templateId,
        },
      );
    }
  }
}
