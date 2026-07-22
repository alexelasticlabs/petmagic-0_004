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
    TemplateGenerationResult generation,
    bool createVideo,
  ) async {
    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: generation.templateId,
            eventType: createVideo
                ? 'create_video_clicked'
                : 'use_as_input_clicked',
            generationId: generation.generationId,
          );
    } on Object {
      // Best-effort analytics must not block navigation.
    }

    if (!mounted) {
      return;
    }
    context.appNavigator.push(
      GenerationResultInputDestination(generation.generationId),
    );
  }

  Future<void> _showRemoveWatermarkSheet(
    TemplateGenerationResult generation,
  ) async {
    final text = AppLocalizations.of(context);
    unawaited(_recordWatermarkAnalytics(generation, 'remove_clicked'));
    unawaited(_recordWatermarkAnalytics(generation, 'paywall_viewed'));
    final action = await showModalBottomSheet<_RemoveWatermarkAction>(
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
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      text.generationStatusRemoveWatermarkSheetTitle,
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(
                            color: colors.textStrong,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      text.generationStatusRemoveWatermarkSheetBody(
                        generation.removeWatermarkCostCredits,
                      ),
                      style: Theme.of(sheetContext).textTheme.bodyMedium
                          ?.copyWith(color: colors.textSoft, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop(_RemoveWatermarkAction.credit),
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(
                        text.generationStatusRemoveWatermarkUseCredit(
                          generation.removeWatermarkCostCredits,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop(_RemoveWatermarkAction.premium),
                      icon: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 18,
                      ),
                      label: Text(text.generationStatusUpgradePremium),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == _RemoveWatermarkAction.premium) {
      context.appNavigator.push(const PremiumDestination());
      return;
    }

    await _removeWatermark(generation);
  }

  Future<void> _removeWatermark(TemplateGenerationResult generation) async {
    if (_isRemovingWatermark) {
      return;
    }

    final text = AppLocalizations.of(context);
    _setPageState(() => _isRemovingWatermark = true);
    try {
      final result = await ref
          .read(templateGenerationRepositoryProvider)
          .removeWatermark(generation.generationId);
      if (!mounted) {
        return;
      }

      _showInfo(
        result.watermarkRemoved
            ? text.generationStatusWatermarkRemoved
            : text.generationStatusRemoveWatermarkFailed,
      );
      await _load(silent: true);
    } on RequestCancelledException {
      return;
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      if (error.statusCode == 402) {
        await _showWatermarkNoCreditsSheet();
      } else {
        _showInfo(text.generationStatusRemoveWatermarkFailed);
      }
    } on Object {
      if (!mounted) {
        return;
      }

      _showInfo(text.generationStatusRemoveWatermarkFailed);
    } finally {
      if (mounted) {
        _setPageState(() => _isRemovingWatermark = false);
      }
    }
  }

  Future<void> _showWatermarkNoCreditsSheet() async {
    final text = AppLocalizations.of(context);
    final action = await showModalBottomSheet<_RemoveWatermarkAction>(
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
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      text.generationStatusRemoveWatermarkSheetTitle,
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(
                            color: colors.textStrong,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      text.generationStatusRemoveWatermarkNoCredits,
                      style: Theme.of(sheetContext).textTheme.bodyMedium
                          ?.copyWith(color: colors.textSoft, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop(_RemoveWatermarkAction.credits),
                      icon: const Icon(Icons.account_balance_wallet_rounded),
                      label: Text(text.walletBuySparkTitle),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop(_RemoveWatermarkAction.premium),
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: Text(text.generationStatusUpgradePremium),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == _RemoveWatermarkAction.credits) {
      context.appNavigator.push(const WalletDestination());
      return;
    }

    context.appNavigator.push(const PremiumDestination());
  }

  Future<void> _recordWatermarkAnalytics(
    TemplateGenerationResult generation,
    String eventType, {
    String? unlockMethod,
    int? creditsSpent,
  }) async {
    final metadata = <String, Object?>{
      'generationId': generation.generationId,
      'templateId': generation.templateId,
      'mediaType': isVideoGeneration(generation) ? 'video' : 'image',
      'userPlan': generation.userPlan,
    };
    if (unlockMethod != null) {
      metadata['unlockMethod'] = unlockMethod;
    }
    if (creditsSpent != null) {
      metadata['creditsSpent'] = creditsSpent;
    }

    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: generation.templateId,
            eventType: eventType,
            generationId: generation.generationId,
            metadata: metadata,
          );
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.GenerationStatusResultActions',
        operation: 'record_result_analytics_event',
        message: 'Analytics event recording failed for generation result.',
        error: error,
        stackTrace: stackTrace,
        context: {
          'eventType': eventType,
          'hasUnlockMethod': unlockMethod != null,
          'hasCreditsSpent': creditsSpent != null,
          'isVideoGeneration': isVideoGeneration(generation),
        },
      );
    }
  }
}
