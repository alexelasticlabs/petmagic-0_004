part of 'templates_page.dart';

extension _TemplatesPageTemplateActions on _TemplatesPageState {
  Future<void> _handleTemplateSelected(
    TemplateItem template, {
    TemplateOfTheDayItem? templateOfTheDay,
    bool fetchLatestDetails = true,
  }) async {
    final previewTemplate = fetchLatestDetails
        ? await _fetchTemplateDetailsOrFallback(template)
        : template;
    if (!mounted) {
      return;
    }

    final isAuthenticated = ref
        .read(appLaunchControllerProvider)
        .isAuthenticated;
    final hasPremiumAccess = ref.read(templatePremiumAccessProvider);
    final action = await context.push<TemplateDetailAction>(
      TemplatePreviewPage.routePath,
      extra: TemplatePreviewRouteArgs(
        template: previewTemplate,
        hasPremiumAccess: hasPremiumAccess,
        isAuthenticated: isAuthenticated,
      ),
    );
    if (!mounted || action != TemplateDetailAction.upload) {
      return;
    }

    await _startTemplateUploadFlow(
      previewTemplate,
      templateOfTheDay: templateOfTheDay,
    );
  }

  Future<TemplateItem> _fetchTemplateDetailsOrFallback(
    TemplateItem template,
  ) async {
    try {
      return await ref
          .read(templatesRepositoryProvider)
          .fetchTemplate(template.templateId, forceRefresh: true);
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'templates',
        operation: 'fetch_template_detail_before_preview',
        message:
            'Failed to fetch template detail before preview; using feed payload.',
        context: {'templateId': template.templateId},
        error: error,
        stackTrace: stackTrace,
      );
      return template;
    }
  }

  Future<void> _handleTemplateOfTheDaySelected(
    TemplateOfTheDayItem featured,
  ) async {
    unawaited(_recordTemplateOfTheDayAnalytics(featured, 'clicked'));

    final visibleTemplate = _findTemplateById(
      ref.read(templatesControllerProvider).items,
      featured.templateId,
    );
    if (visibleTemplate != null) {
      await _openTemplateOfTheDayTemplate(featured, visibleTemplate);
      return;
    }

    try {
      final template = await ref
          .read(templatesRepositoryProvider)
          .fetchTemplate(featured.templateId, forceRefresh: true);
      if (!mounted) {
        return;
      }

      await _openTemplateOfTheDayTemplate(
        featured,
        template,
        fetchLatestDetails: false,
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
        fetchLatestDetails: false,
      );
    }
  }

  Future<void> _openTemplateOfTheDayTemplate(
    TemplateOfTheDayItem featured,
    TemplateItem template, {
    bool fetchLatestDetails = true,
  }) async {
    unawaited(_recordTemplateOfTheDayAnalytics(featured, 'opened'));
    await _handleTemplateSelected(
      template,
      templateOfTheDay: featured,
      fetchLatestDetails: fetchLatestDetails,
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

    await _handleTemplateSelected(template, fetchLatestDetails: false);
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
