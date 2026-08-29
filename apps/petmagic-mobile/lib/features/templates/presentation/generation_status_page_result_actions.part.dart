part of 'generation_status_page.dart';

extension _GenerationStatusPageResultActions on _GenerationStatusPageState {
  void _retrySoon(TemplateGenerationResult generation) {
    _showInfo(AppLocalizations.of(context).generationStatusRetrySoonMessage);
    context.appNavigator.go(_templatesDestinationForGeneration(generation));
  }

  TemplatesDestination _templatesDestinationForGeneration(
    TemplateGenerationResult generation,
  ) {
    final petId = generation.petId?.trim();
    if (petId == null || petId.isEmpty) {
      return const TemplatesDestination();
    }

    final petPhotoId = generation.petPhotoId?.trim();
    return TemplatesDestination(petId: petId, petPhotoId: petPhotoId);
  }

  bool _canGenerateSimilar(TemplateGenerationResult generation) {
    return generation.isCompleted &&
        generation.supportsGenerateSimilar &&
        !generation.userMediaExpired &&
        !_isGeneratingSimilar;
  }

  Future<void> _deleteGeneration(TemplateGenerationResult generation) async {
    if (_isDeleting) {
      return;
    }

    final text = AppLocalizations.of(context);

    _setPageState(() => _isDeleting = true);
    try {
      await ref
          .read(generationHistoryControllerProvider.notifier)
          .deleteGeneration(generation.generationId);

      if (!mounted) {
        return;
      }

      _showInfo(text.generationStatusDeletedMessage);
      context.appNavigator.go(const CreationsDestination());
    } on Object {
      if (!mounted) {
        return;
      }

      _showInfo(text.generationStatusDeleteFailedMessage);
    } finally {
      if (mounted) {
        _setPageState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _generateSimilar(TemplateGenerationResult generation) async {
    if (!_canGenerateSimilar(generation)) {
      _showInfo(_sourceUnavailableMessage(AppLocalizations.of(context)));
      return;
    }

    final text = AppLocalizations.of(context);
    unawaited(
      _recordGenerateSimilarAnalytics(generation, 'generate_similar_clicked'),
    );
    if (isVideoGeneration(generation)) {
      final confirmed = await _showGenerateSimilarVideoSheet(generation);
      if (confirmed != true) {
        return;
      }
      unawaited(
        _recordGenerateSimilarAnalytics(
          generation,
          'generate_similar_confirmed',
        ),
      );
    } else {
      _showInfo(_generateSimilarImageCostMessage(text));
    }

    _setPageState(() => _isGeneratingSimilar = true);
    _showInfo(_similarLoadingLabel(text));
    try {
      final next = await ref
          .read(templateGenerationRepositoryProvider)
          .generateSimilar(sourceGenerationId: generation.generationId);
      unawaited(
        ref
            .read(walletControllerProvider.notifier)
            .syncSnapshot(forceRefresh: true),
      );

      if (!mounted) {
        return;
      }

      context.appNavigator.go(GenerationDestination(next.generationId));
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      _showInfo(_generateSimilarErrorMessage(text, error));
    } on Object {
      if (!mounted) {
        return;
      }
      _showInfo(_generateSimilarGenericErrorMessage(text));
    } finally {
      if (mounted) {
        _setPageState(() => _isGeneratingSimilar = false);
      }
    }
  }

  Future<void> _recordGenerateSimilarAnalytics(
    TemplateGenerationResult generation,
    String eventType,
  ) async {
    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: generation.templateId,
            eventType: eventType,
            generationId: generation.generationId,
            metadata: {
              'sourceGenerationId': generation.generationId,
              'templateId': generation.templateId,
              'templateType': generation.templateType,
              'petId': generation.petId,
              'variationStrength': 'medium',
              'creditsCost': isVideoGeneration(generation) ? 5 : 1,
              'userPlan': generation.userPlan,
            },
          );
    } on Object {
      // Best-effort analytics must not block generation.
    }
  }

  Future<bool?> _showGenerateSimilarVideoSheet(
    TemplateGenerationResult generation,
  ) {
    final text = AppLocalizations.of(context);
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colors = sheetContext.petMagicColors;
        final bottomInset = petMagicScrollableBottomInset(sheetContext);
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.85),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _similarActionLabel(text),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _generateSimilarVideoCostMessage(text),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: colors.textSoft),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: Text(_generateSimilarConfirmLabel(text)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: Text(_cancelLabel(text)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openUseResultFlow(
    TemplateGenerationResult generation, {
    String? selectedTemplateId,
  }) async {
    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: generation.templateId,
            eventType: selectedTemplateId == null
                ? 'use_as_input_clicked'
                : 'result_recommendation_clicked',
            generationId: generation.generationId,
            metadata: selectedTemplateId == null
                ? const <String, Object?>{}
                : {'selectedTemplateId': selectedTemplateId},
          );
    } on Object {
      // Best-effort analytics must not block navigation.
    }

    if (!mounted) {
      return;
    }
    context.appNavigator.push(
      GenerationResultInputDestination(
        generation.generationId,
        selectedTemplateId: selectedTemplateId,
      ),
    );
  }
}
