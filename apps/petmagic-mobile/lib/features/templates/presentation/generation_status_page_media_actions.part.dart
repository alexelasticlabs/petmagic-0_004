part of 'generation_status_page.dart';

extension _GenerationStatusPageMediaActions on _GenerationStatusPageState {
  void _handleBackNavigation() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    context.appNavigator.go(const CreationsDestination());
  }

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

  void _completeMediaAction(RequestCancellation cancelToken) {
    if (!identical(_activeMediaActionCancelToken, cancelToken)) {
      return;
    }

    _activeMediaActionCancelToken = null;
    if (mounted) {
      _setPageState(() => _isMediaActionInFlight = false);
      _startPolling();
    } else {
      _isMediaActionInFlight = false;
    }
  }

  void _cancelActiveMediaAction() {
    final cancelToken = _activeMediaActionCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('generation_status_media_action_cancelled');
    }
    _activeMediaActionCancelToken = null;
    _isMediaActionInFlight = false;
  }

  Future<void> _saveToGallery(TemplateGenerationResult generation) async {
    final mediaActionCancelToken = _startMediaAction();
    if (mediaActionCancelToken == null) {
      return;
    }

    final text = AppLocalizations.of(context);

    try {
      final localOutputPath = await usableLocalMediaPath(
        generation.localOutputPath,
      );
      if (!mounted) {
        return;
      }
      String safeOutputUrl = '';
      String fileName;
      if (localOutputPath == null) {
        final access = await ref
            .read(templateGenerationRepositoryProvider)
            .fetchDownloadUrl(
              generation.generationId,
              cancelToken: mediaActionCancelToken,
            );
        final outputUrl = access.mediaUrl;
        if (outputUrl.isEmpty) {
          _showInfo(text.generationStatusResultUnavailableForSave);
          return;
        }
        final safeOutputUri = parseSafeGenerationMediaUri(outputUrl);
        if (safeOutputUri == null) {
          _showInfo(text.generationStatusResultUnavailableForSave);
          return;
        }
        safeOutputUrl = safeOutputUri.toString();
        fileName = access.fileName.isEmpty
            ? _buildOutputFileName(generation, safeOutputUrl)
            : access.fileName;
      } else {
        final safeOutputUri = parseSafeGenerationMediaUri(generation.outputUrl);
        safeOutputUrl = safeOutputUri?.toString() ?? '';
        fileName = _buildOutputFileName(
          generation,
          safeOutputUrl.isEmpty ? localOutputPath : safeOutputUrl,
        );
      }

      final wasSaved = await ref
          .read(generationStatusMediaActionsProvider)
          .saveToGallery(
            mediaUrl: safeOutputUrl,
            fileName: fileName,
            isVideo: isVideoGeneration(generation),
            albumName: 'PetMagic',
            cancelToken: mediaActionCancelToken,
            localPath: localOutputPath,
          );

      if (!mounted) {
        return;
      }

      if (!wasSaved) {
        _showInfo(text.generationStatusFileSaveFailedMessage);
        return;
      }

      _showInfo(text.generationStatusSavedToGalleryMessage);
    } on RequestCancelledException {
      return;
    } on Object {
      if (!mounted) {
        return;
      }

      _showInfo(text.generationStatusFileSaveFailedMessage);
    } finally {
      _completeMediaAction(mediaActionCancelToken);
    }
  }

  Future<void> _shareResult(TemplateGenerationResult generation) async {
    final mediaActionCancelToken = _startMediaAction();
    if (mediaActionCancelToken == null) {
      return;
    }

    final text = AppLocalizations.of(context);

    try {
      final localOutputPath = await usableLocalMediaPath(
        generation.localOutputPath,
      );
      if (!mounted) {
        return;
      }
      if (localOutputPath != null) {
        final safeOutputUri = parseSafeGenerationMediaUri(generation.outputUrl);
        final safeOutputUrl = safeOutputUri?.toString() ?? '';
        await ref
            .read(generationStatusMediaActionsProvider)
            .share(
              mediaUrl: safeOutputUrl,
              fileName: _buildOutputFileName(
                generation,
                safeOutputUrl.isEmpty ? localOutputPath : safeOutputUrl,
              ),
              title:
                  generation.templateTitle ?? text.generationStatusResultTitle,
              cancelToken: mediaActionCancelToken,
              localPath: localOutputPath,
            );
        return;
      }

      final access = await ref
          .read(templateGenerationRepositoryProvider)
          .fetchShareUrl(
            generation.generationId,
            cancelToken: mediaActionCancelToken,
          );
      final safeShareUri = parseSafeGenerationShareUri(access.shareUrl);
      if (safeShareUri == null) {
        _showInfo(text.generationStatusResultUnavailableForShare);
        return;
      }
      String safeOutputUrl = '';
      String fileName;
      final outputUrl = access.mediaUrl;
      if (outputUrl.isEmpty) {
        _showInfo(text.generationStatusResultUnavailableForShare);
        return;
      }
      final safeOutputUri = parseSafeGenerationMediaUri(outputUrl);
      if (safeOutputUri == null) {
        _showInfo(text.generationStatusResultUnavailableForShare);
        return;
      }
      safeOutputUrl = safeOutputUri.toString();
      fileName = access.fileName.isEmpty
          ? _buildOutputFileName(generation, safeOutputUrl)
          : access.fileName;

      await ref
          .read(generationStatusMediaActionsProvider)
          .share(
            mediaUrl: safeOutputUrl,
            fileName: fileName,
            title: generation.templateTitle ?? text.generationStatusResultTitle,
            cancelToken: mediaActionCancelToken,
            shareText: safeShareUri.toString(),
            localPath: localOutputPath,
          );
    } on RequestCancelledException {
      return;
    } on Object {
      if (!mounted) {
        return;
      }

      _showInfo(text.generationStatusShareFailedMessage);
    } finally {
      _completeMediaAction(mediaActionCancelToken);
    }
  }

  Future<void> _copyResultLink(TemplateGenerationResult generation) async {
    final text = AppLocalizations.of(context);
    final mediaActionCancelToken = _startMediaAction();
    if (mediaActionCancelToken == null) {
      return;
    }

    try {
      final access = await ref
          .read(templateGenerationRepositoryProvider)
          .fetchShareUrl(
            generation.generationId,
            cancelToken: mediaActionCancelToken,
          );
      final safeUri = parseSafeGenerationShareUri(access.shareUrl);
      if (safeUri == null) {
        _showInfo(text.generationStatusResultUnavailableForShare);
        return;
      }

      await Clipboard.setData(ClipboardData(text: safeUri.toString()));
      if (!mounted) {
        return;
      }

      _showInfo(text.generationStatusLinkCopiedMessage);
    } on RequestCancelledException {
      return;
    } on Object {
      if (!mounted) {
        return;
      }

      _showInfo(text.generationStatusShareFailedMessage);
    } finally {
      _completeMediaAction(mediaActionCancelToken);
    }
  }

  Future<void> _openCompareViewer(TemplateGenerationResult generation) async {
    final text = AppLocalizations.of(context);
    final beforeUrl = generation.inputPreviewUrl?.trim();
    if (beforeUrl == null || beforeUrl.isEmpty) {
      _showInfo(text.generationStatusCompareBeforeUnavailable);
      return;
    }

    final afterUrl = generation.resultPreviewUrl?.trim();
    if (afterUrl == null || afterUrl.isEmpty) {
      _showInfo(text.generationStatusCompareResultUnavailable);
      return;
    }

    final safeBeforeUri = parseSafeGenerationMediaUri(beforeUrl);
    final safeAfterUri = parseSafeGenerationMediaUri(afterUrl);
    if (safeBeforeUri == null || safeAfterUri == null) {
      _showInfo(text.generationStatusCompareOpenFailed);
      return;
    }

    await _recordCompareAnalytics(generation, 'compare_clicked');
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _BeforeAfterCompareViewer(
          generation: generation,
          beforeUrl: safeBeforeUri.toString(),
          afterUrl: safeAfterUri.toString(),
          onViewed: () => _recordCompareAnalytics(generation, 'compare_viewed'),
          onSliderMoved: () =>
              _recordCompareAnalytics(generation, 'compare_slider_moved'),
          onClosed: () => _recordCompareAnalytics(generation, 'compare_closed'),
          onShare: () async {
            await _recordCompareAnalytics(generation, 'compare_share_clicked');
            await _shareResult(generation);
          },
        ),
      ),
    );
  }

  Future<void> _openFullscreenPreview(
    TemplateGenerationResult generation,
  ) async {
    final localOutputFile = _localMediaFile(generation.localOutputPath);
    if (localOutputFile != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _FullscreenResultViewer(
            generation: generation,
            mediaUrl: generation.outputUrl ?? '',
            localFilePath: localOutputFile.path,
          ),
        ),
      );
      return;
    }

    final outputUrl = generation.outputUrl;
    if (outputUrl == null || outputUrl.isEmpty) {
      _showInfo(AppLocalizations.of(context).templateFlowResultUnavailable);
      return;
    }

    final safeUri = parseSafeGenerationMediaUri(outputUrl);
    if (safeUri == null) {
      _showInfo(AppLocalizations.of(context).templateFlowResultUnavailable);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenResultViewer(
          generation: generation,
          mediaUrl: safeUri.toString(),
          localFilePath: null,
        ),
      ),
    );
  }

  Future<void> _recordCompareAnalytics(
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
              'generationId': generation.generationId,
              'templateId': generation.templateId,
              'petId': generation.petId,
              'inputSourceType': generation.inputSourceType,
              'userPlan': generation.userPlan,
              'hasWatermark': generation.hasWatermark,
            },
          );
    } on Object {
      // Best-effort analytics must not block compare interactions.
    }
  }

  void _showInfo(String message) {
    if (!mounted) {
      return;
    }

    PetMagicToast.show(context, message: message, tone: PetMagicToastTone.info);
  }

  String _buildOutputFileName(
    TemplateGenerationResult generation,
    String outputUrl,
  ) {
    final normalizedTitle = sanitizeFileName(
      generation.templateTitle,
      fallback: 'petmagic_result',
    );
    final normalizedGenerationId = sanitizeFileName(
      generation.generationId,
      fallback: 'generation',
    );
    final extensionFromRemote = extensionFromUrl(outputUrl);
    final extension = extensionFromRemote.isEmpty
        ? _defaultOutputExtension(generation)
        : extensionFromRemote;
    return '${normalizedTitle}_$normalizedGenerationId.$extension';
  }

  String _defaultOutputExtension(TemplateGenerationResult generation) {
    return isVideoGeneration(generation) ? 'mp4' : 'jpg';
  }
}

class _StatusSheetActionTile extends StatelessWidget {
  const _StatusSheetActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final toneColor = isDestructive ? colors.error : colors.textStrong;

    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: Icon(icon, color: toneColor),
        title: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: toneColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        enabled: onTap != null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
