part of 'template_preview_page.dart';

extension _TemplatePreviewViewerActions on _TemplatePreviewPageState {
  Future<TemplateItem?> _resolveTemplateDetails(
    int index, {
    bool retry = false,
  }) {
    if (index < 0 || index >= _items.length) {
      return Future<TemplateItem?>.value(null);
    }
    final template = _items[index];
    final templateId = template.templateId;
    if (_detailResolvedIds.contains(templateId)) {
      return Future<TemplateItem?>.value(template);
    }
    final existing = _detailRequests[templateId];
    if (existing != null) {
      return existing;
    }
    if (!retry && _detailAttemptedIds.contains(templateId)) {
      return Future<TemplateItem?>.value(template);
    }

    _detailAttemptedIds.add(templateId);
    late final Future<TemplateItem?> request;
    request = ref
        .read(templatesRepositoryProvider)
        .fetchTemplate(
          templateId,
          forceRefresh: true,
          analyticsSource: _session.source.analyticsValue,
        )
        .then<TemplateItem?>((resolved) {
          if (!mounted) {
            return resolved;
          }
          final currentIndex = _items.indexWhere(
            (item) => item.templateId == templateId,
          );
          if (currentIndex >= 0) {
            _setViewerState(() => _items[currentIndex] = resolved);
          }
          _detailResolvedIds.add(templateId);
          return resolved;
        })
        .catchError((Object error, StackTrace stackTrace) {
          AppLogger.warn(
            feature: 'Templates.PreviewViewer',
            operation: 'resolve_selected_template',
            message:
                'Selected template detail fetch failed; using feed payload.',
            context: {'templateId': templateId, 'source': _session.source.name},
            error: error,
            stackTrace: stackTrace,
          );
          return null;
        })
        .whenComplete(() {
          if (identical(_detailRequests[templateId], request)) {
            _detailRequests.remove(templateId);
          }
        });
    _detailRequests[templateId] = request;
    return request;
  }

  Future<void> _completeWithSelectedTemplate() async {
    if (_isInteractionLocked) {
      return;
    }
    final selectedId = _selectedTemplate.templateId;
    _setViewerState(() => _isResolvingAction = true);
    final selectedIndex = _items.indexWhere(
      (item) => item.templateId == selectedId,
    );
    final resolved = await _resolveTemplateDetails(selectedIndex, retry: true);
    if (!mounted || !_canContinueViewerAction) {
      return;
    }
    if (_selectedTemplate.templateId != selectedId) {
      _setViewerState(() => _isResolvingAction = false);
      return;
    }
    if (resolved == null || resolved.templateId != selectedId) {
      _setViewerState(() => _isResolvingAction = false);
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).templatesRequestFailedError,
            ),
          ),
        );
      return;
    }
    final selected = resolved;
    final hasPremiumAccess =
        widget.hasPremiumAccess || ref.read(templatePremiumAccessProvider);
    if (selected.isPremium && !hasPremiumAccess) {
      _setViewerState(() => _isResolvingAction = false);
      final isAuthenticated =
          widget.isAuthenticated ||
          ref.read(appLaunchControllerProvider).isAuthenticated;
      await _handleUnlockPremium(isAuthenticated);
      return;
    }
    Navigator.of(context).pop(
      TemplatePreviewResult(
        action: TemplateDetailAction.upload,
        selectedTemplate: selected,
      ),
    );
  }

  Future<void> _showDetails() async {
    if (_isInteractionLocked || _isDetailsOpen) {
      return;
    }
    final selectedId = _selectedTemplate.templateId;
    _setViewerState(() => _isOpeningDetails = true);
    final selectedIndex = _items.indexWhere(
      (item) => item.templateId == selectedId,
    );
    await _resolveTemplateDetails(selectedIndex, retry: true);
    if (!mounted || !_canContinueViewerAction) {
      return;
    }
    if (_selectedTemplate.templateId != selectedId) {
      _setViewerState(() => _isOpeningDetails = false);
      return;
    }
    final template = _selectedTemplate;
    final hasPremiumAccess =
        widget.hasPremiumAccess || ref.read(templatePremiumAccessProvider);
    final isAuthenticated =
        widget.isAuthenticated ||
        ref.read(appLaunchControllerProvider).isAuthenticated;
    _setViewerState(() {
      _isOpeningDetails = false;
      _isDetailsOpen = true;
    });
    final action = await showTemplateDetailSheet(
      context,
      template,
      isPremiumLocked: template.isPremium && !hasPremiumAccess,
      onUnlockPremium: template.isPremium && !hasPremiumAccess
          ? () => Navigator.of(context).pop(TemplateDetailAction.unlockPremium)
          : null,
    );
    if (!mounted) {
      return;
    }
    _setViewerState(() => _isDetailsOpen = false);
    if (action == TemplateDetailAction.upload) {
      await _completeWithSelectedTemplate();
    } else if (action == TemplateDetailAction.unlockPremium &&
        !(widget.hasPremiumAccess || ref.read(templatePremiumAccessProvider))) {
      await _handleUnlockPremium(isAuthenticated);
    }
  }

  Future<void> _handleUnlockPremium(bool isAuthenticated) async {
    if (_isUnlockingPremium) {
      return;
    }
    final managesOverlayState = !_isDetailsOpen;
    _setViewerState(() {
      _isUnlockingPremium = true;
      if (managesOverlayState) {
        _isDetailsOpen = true;
      }
    });
    try {
      if (isAuthenticated) {
        if (!mounted) {
          return;
        }
        await context.appNavigator.push<void>(const PremiumDestination());
        return;
      }

      await showAuthRequiredSheet(
        context,
        redirectPath: const PremiumDestination().location,
      );
    } finally {
      if (mounted) {
        _setViewerState(() {
          _isUnlockingPremium = false;
          if (managesOverlayState) {
            _isDetailsOpen = false;
          }
        });
      }
    }
  }
}
