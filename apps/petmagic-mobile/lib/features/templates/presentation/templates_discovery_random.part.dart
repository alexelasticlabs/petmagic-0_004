part of 'templates_discovery_page.dart';

extension _DiscoveryRandomActions on _TemplatesDiscoveryPageState {
  bool get _canPickRandom => mounted && _isAppResumed && _isTabActive == true;

  void _cancelRandomRequest() {
    _randomRequestEpoch++;
    _randomRepository?.cancelPendingRandomTemplateRequest();
    _randomRepository = null;
  }

  Future<void> _openRandomTemplate() async {
    if (!_canPickRandom || _randomSheetOpen) return;
    _setRandomSheetOpen(true);
    TemplateItem? selected;
    try {
      selected = await showRandomTemplateSettingsSheet(
        context,
        initialType: null,
        initialCategory: null,
        categories: ref
            .read(templateDiscoveryControllerProvider)
            .sections
            .map((section) => section.category)
            .toList(),
        onFind: _findDiscoveryRandomTemplate,
      );
      if (!_canPickRandom) selected = null;
    } finally {
      _cancelRandomRequest();
      _setRandomSheetOpen(false);
    }
    if (!mounted || selected == null || !_canPickRandom) return;
    await context.appNavigator.push<void>(
      TemplatesDestination(
        payload: TemplatePreviewSession.single(
          selected,
          source: TemplatePreviewSource.random,
        ),
      ),
    );
  }

  Future<TemplateItem?> _findDiscoveryRandomTemplate(
    RandomTemplateSettings settings,
  ) async {
    if (!_canPickRandom) return null;
    final epoch = _randomRequestEpoch;
    final repository = ref.read(templatesRepositoryProvider);
    _randomRepository = repository;
    try {
      final template = await repository.fetchRandomTemplate(
        mode: randomModeForTemplateType(settings.type),
        category: settings.category,
        includePremium: ref.read(templatePremiumAccessProvider),
        access: settings.access,
      );
      return _canPickRandom && epoch == _randomRequestEpoch ? template : null;
    } finally {
      if (epoch == _randomRequestEpoch) _randomRepository = null;
    }
  }
}
