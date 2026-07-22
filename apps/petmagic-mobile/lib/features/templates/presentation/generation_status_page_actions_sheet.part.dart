part of 'generation_status_page.dart';

extension _GenerationStatusPageActionsSheet on _GenerationStatusPageState {
  Future<void> _openActionsSheet(TemplateGenerationResult generation) async {
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
                        ] else if (generation.isFailed) ...[
                          _StatusSheetActionTile(
                            icon: Icons.image_search_rounded,
                            label: text.generationStatusPickAnotherPhotoAction,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              context.appNavigator.go(
                                _templatesDestinationForGeneration(generation),
                              );
                            },
                          ),
                          _StatusSheetActionTile(
                            icon: Icons.refresh_rounded,
                            label: text.generationStatusRetryAction,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _retrySoon(generation);
                            },
                          ),
                          _StatusSheetActionTile(
                            icon: Icons.support_agent_rounded,
                            label: text.generationStatusContactSupportAction,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              context.appNavigator.push(
                                const SupportChatDestination(),
                              );
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
