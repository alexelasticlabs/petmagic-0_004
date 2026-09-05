part of 'template_preview_page.dart';

extension _TemplatePreviewViewerActions on _TemplatePreviewPageState {
  Widget _buildPrimaryAction({
    required TemplateItem template,
    required bool isPremiumLocked,
  }) {
    final text = AppLocalizations.of(context);
    final label = isPremiumLocked
        ? text.templateUnlockPremiumAction
        : template.isVideo
        ? text.templateDetailUploadPhotoForVideoAction
        : text.templateFlowUploadPetPhotoAction;

    return SizedBox(
      width: double.infinity,
      height: 18 + MediaQuery.textScalerOf(context).scale(38),
      child: FilledButton.icon(
        key: const ValueKey('template-preview-cta'),
        onPressed: _isInteractionLocked ? null : _completeWithSelectedTemplate,
        style: FilledButton.styleFrom(
          backgroundColor: isPremiumLocked ? context.petMagicColors.gold : null,
          foregroundColor: isPremiumLocked ? const Color(0xFF30200A) : null,
          disabledBackgroundColor:
              (isPremiumLocked
                      ? context.petMagicColors.gold
                      : context.petMagicColors.accent)
                  .withValues(alpha: _isResolvingAction ? 0.55 : 1),
          disabledForegroundColor: const Color(
            0xFF10201A,
          ).withValues(alpha: 0.65),
          elevation: isPremiumLocked ? 5 : 2,
          shadowColor:
              (isPremiumLocked
                      ? context.petMagicColors.gold
                      : context.petMagicColors.accent)
                  .withValues(alpha: 0.3),
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        icon: AnimatedSwitcher(
          duration: _reduceMotion
              ? Duration.zero
              : _TemplatePreviewPageState._contentAnimationDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          child: _isResolvingAction
              ? const SizedBox.square(
                  key: ValueKey('template-preview-cta-loading'),
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  isPremiumLocked
                      ? Icons.workspace_premium_rounded
                      : Icons.add_photo_alternate_outlined,
                  key: ValueKey(
                    'template-preview-cta-icon:${template.templateId}',
                  ),
                ),
        ),
        label: AnimatedSwitcher(
          duration: _reduceMotion
              ? Duration.zero
              : _TemplatePreviewPageState._contentAnimationDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0.025 * _selectionDirection, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Text(
            label,
            key: ValueKey('template-preview-cta-label:${template.templateId}'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

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
    final repository = ref.read(templatesRepositoryProvider);
    request = repository
        .fetchTemplate(
          templateId,
          forceRefresh: retry,
          analyticsSource: _session.source.analyticsValue,
          minimumVersion: template.mediaVersion ?? template.version,
        )
        .then<TemplateItem?>((resolved) {
          final hydrated = resolved.withFeedMediaFrom(template);
          if (!mounted) {
            return hydrated;
          }
          final currentIndex = _items.indexWhere(
            (item) => item.templateId == templateId,
          );
          if (currentIndex >= 0) {
            _setViewerState(() => _items[currentIndex] = hydrated);
          }
          _detailResolvedIds.add(templateId);
          return hydrated;
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
