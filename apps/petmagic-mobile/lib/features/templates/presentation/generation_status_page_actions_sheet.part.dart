part of 'generation_status_page.dart';

extension _GenerationStatusPageActionsSheet on _GenerationStatusPageState {
  Future<void> _openActionsSheet(TemplateGenerationResult generation) async {
    if (generation.isFailed) {
      await _openFailedActionsSheet(generation);
      return;
    }
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = petMagicScrollableBottomInset(sheetContext);
        final maxSheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.8;
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
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxSheetHeight),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (generation.isCompleted) ...[
                          _StatusSheetActionTile(
                            icon: Icons.download_rounded,
                            label: generation.isWatermarkRemoved
                                ? text.generationStatusDownloadWithoutWatermark
                                : generation.hasWatermark
                                ? text.generationStatusSaveWithWatermark
                                : text.generationStatusSaveAction,
                            onTap: _isMediaActionInFlight
                                ? null
                                : () {
                                    Navigator.of(sheetContext).pop();
                                    unawaited(_saveToGallery(generation));
                                  },
                          ),
                          _StatusSheetActionTile(
                            icon: Icons.share_rounded,
                            label: generation.hasWatermark
                                ? text.generationStatusShareWithWatermark
                                : text.supportChatShareAction,
                            onTap: _isMediaActionInFlight
                                ? null
                                : () {
                                    Navigator.of(sheetContext).pop();
                                    unawaited(_shareResult(generation));
                                  },
                          ),
                          if (generation.canRemoveWatermark) ...[
                            _StatusSheetActionTile(
                              icon: Icons.cleaning_services_rounded,
                              label: _isRemovingWatermark
                                  ? text.generationStatusRemovingWatermark
                                  : text.generationStatusRemoveWatermark,
                              onTap: _isRemovingWatermark
                                  ? null
                                  : () {
                                      Navigator.of(sheetContext).pop();
                                      unawaited(
                                        _showRemoveWatermarkSheet(generation),
                                      );
                                    },
                            ),
                            _StatusSheetActionTile(
                              icon: Icons.workspace_premium_rounded,
                              label: text.generationStatusUpgradePremium,
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                context.appNavigator.push(
                                  const PremiumDestination(),
                                );
                              },
                            ),
                          ],
                          _StatusSheetActionTile(
                            icon: Icons.auto_awesome_rounded,
                            label: _similarActionLabel(text),
                            onTap: !_canGenerateSimilar(generation)
                                ? null
                                : () {
                                    Navigator.of(sheetContext).pop();
                                    unawaited(_generateSimilar(generation));
                                  },
                          ),
                          _StatusSheetActionTile(
                            icon: Icons.link_rounded,
                            label: text.generationStatusCopyLinkAction,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              unawaited(_copyResultLink(generation));
                            },
                          ),
                          _StatusSheetActionTile(
                            icon: Icons.delete_outline_rounded,
                            label: text.generationStatusDeleteAction,
                            onTap: _isDeleting
                                ? null
                                : () {
                                    Navigator.of(sheetContext).pop();
                                    unawaited(_deleteGeneration(generation));
                                  },
                            isDestructive: true,
                          ),
                          _StatusSheetActionTile(
                            icon: Icons.flag_outlined,
                            label: text.generationStatusReportProblemAction,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              unawaited(_showReportProblemSheet(generation));
                            },
                          ),
                        ] else ...[
                          _StatusSheetActionTile(
                            icon: Icons.photo_library_outlined,
                            label: text.generationStatusOpenGalleryAction,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              context.appNavigator.go(
                                const CreationsDestination(),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openGenerationDetailsSheet(
    TemplateGenerationResult generation,
  ) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.border.withValues(alpha: 0.8)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    text.generationStatusTechnicalDetailsAction,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GenerationDetailsList(generation: generation),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFailedActionsSheet(TemplateGenerationResult generation) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return showPetMagicModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      constraints: BoxConstraints.tightFor(height: screenHeight),
      builder: (sheetContext, bottomInset) => _GenerationFailureActionsSheet(
        bottomInset: bottomInset,
        onRetry: () {
          Navigator.of(sheetContext).pop();
          _retrySoon(generation);
        },
        onPickPhoto: () {
          Navigator.of(sheetContext).pop();
          context.appNavigator.go(
            _templatesDestinationForGeneration(generation),
          );
        },
        onSupport: () {
          Navigator.of(sheetContext).pop();
          context.appNavigator.push(const SupportChatDestination());
        },
      ),
    );
  }

  RequestCancellation? _startMediaAction() {
    if (_activeMediaActionCancelToken != null) {
      return null;
    }

    _stopPolling();
    _cancelActiveLoad();
    final cancelToken = RequestCancellation();
    _activeMediaActionCancelToken = cancelToken;
    if (mounted) {
      _setPageState(() => _isMediaActionInFlight = true);
    } else {
      _isMediaActionInFlight = true;
    }
    return cancelToken;
  }
}

class _GenerationDetailsList extends StatelessWidget {
  const _GenerationDetailsList({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final rows = [
      (
        text.templateFlowTemplateLabel,
        generation.templateTitle ?? text.generationStatusUntitledFallback,
      ),
      (
        text.generationStatusStartedLabel,
        formatGenerationDateTime(
          generation.createdAtUtc,
          Localizations.localeOf(context),
        ),
      ),
      (text.generationStatusTypeLabel, typeLabel(text, generation)),
      (
        text.templateFlowCostLabel,
        '${generation.tokenCost} ${text.walletBalanceUnit}',
      ),
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.$1,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row.$2,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
