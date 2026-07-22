part of 'generation_status_page.dart';

extension _GenerationStatusPageView on _GenerationStatusPageState {
  Widget _buildPage(BuildContext context) {
    ref.listen<AppLaunchState>(
      appLaunchControllerProvider,
      (previous, next) => _handleLaunchStateChanged(previous, next),
    );
    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (!_isPageActive ||
          !_canUsePrivateStatusApi ||
          previous?.hasInternet == next.hasInternet) {
        return;
      }

      if (!next.hasInternet) {
        _pauseRealtime();
        _stopPolling();
        return;
      }

      unawaited(_resumeRealtimeIfNeeded());
      _startPolling();
      unawaited(_load(silent: true));
    });

    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final generation = _generation;
    final bottomInset = petMagicBottomNavInset(
      context,
      extraSpacing: kPetMagicBottomContentInsetRelaxed,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.backgroundTop, colors.backgroundBottom],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: RefreshIndicator.adaptive(
            color: colors.accent,
            onRefresh: () async {
              await PetMagicHaptics.medium();
              await _load();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(18, 12, 18, bottomInset),
              children: [
                _Header(
                  title:
                      generation?.templateTitle ?? text.generationStatusTitle,
                  subtitle: generation == null
                      ? null
                      : '${typeLabel(text, generation)} • ${generation.tokenCost} ${text.walletBalanceUnit}',
                  onBack: _handleBackNavigation,
                  onMenu: generation == null
                      ? null
                      : () => _openActionsSheet(generation),
                ),
                const SizedBox(height: 18),
                if (_isLoading && generation == null)
                  const _LoadingCard()
                else if (_errorMessage != null && generation == null)
                  _ErrorCard(
                    message: _statusLoadErrorText(text, _errorMessage!),
                    onRetry: () => _load(),
                  )
                else if (generation != null) ...[
                  _StatusHero(generation: generation),
                  const SizedBox(height: 14),
                  if (generation.isCompleted) ...[
                    _ResultCard(
                      generation: generation,
                      onOpenViewer: () => _openFullscreenPreview(generation),
                    ),
                    const SizedBox(height: 10),
                    if (!isVideoGeneration(generation) &&
                        generation.canCompareBeforeAfter) ...[
                      _CompareActionCard(
                        label: text.generationStatusCompareAction,
                        onTap: () => unawaited(_openCompareViewer(generation)),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (!isVideoGeneration(generation))
                      _ResultInputActions(
                        onCreateVideo:
                            (generation.outputUrl?.trim().isNotEmpty ?? false)
                            ? () => unawaited(
                                _openUseResultFlow(generation, true),
                              )
                            : null,
                        onUseAsInput:
                            (generation.outputUrl?.trim().isNotEmpty ?? false)
                            ? () => unawaited(
                                _openUseResultFlow(generation, false),
                              )
                            : null,
                        hasWatermark: generation.hasWatermark,
                        isWatermarkRemoved: generation.isWatermarkRemoved,
                        watermarkMessage: generation.watermarkMessage,
                      )
                    else
                      _ReadyActionsRow(
                        onGenerateSimilar: _canGenerateSimilar(generation)
                            ? () => unawaited(_generateSimilar(generation))
                            : null,
                        onUseAsInput:
                            !isVideoGeneration(generation) &&
                                (generation.outputUrl?.trim().isNotEmpty ??
                                    false)
                            ? () => unawaited(
                                _openUseResultFlow(generation, false),
                              )
                            : null,
                        onSave: _isMediaActionInFlight
                            ? null
                            : () => unawaited(_saveToGallery(generation)),
                        onShare: _isMediaActionInFlight
                            ? null
                            : () => unawaited(_shareResult(generation)),
                        hasWatermark: generation.hasWatermark,
                        isWatermarkRemoved: generation.isWatermarkRemoved,
                        canRemoveWatermark: generation.canRemoveWatermark,
                        watermarkMessage: generation.watermarkMessage,
                        removeWatermarkCostCredits:
                            generation.removeWatermarkCostCredits,
                        isRemovingWatermark: _isRemovingWatermark,
                        onRemoveWatermark: generation.canRemoveWatermark
                            ? () => unawaited(
                                _showRemoveWatermarkSheet(generation),
                              )
                            : null,
                        onUpgrade: () => context.appNavigator.push(
                          const PremiumDestination(),
                        ),
                        isGeneratingSimilar: _isGeneratingSimilar,
                      ),
                    const SizedBox(height: 10),
                    _DetailsCard(
                      title: text.generationStatusDetailsTitle,
                      rows: [
                        (
                          text.templateFlowTemplateLabel,
                          generation.templateTitle ??
                              text.generationStatusUntitledFallback,
                        ),
                        (
                          text.generationStatusCreatedLabel,
                          formatGenerationDateTime(
                            generation.completedAtUtc ??
                                generation.updatedAtUtc,
                            Localizations.localeOf(context),
                          ),
                        ),
                        (
                          text.generationStatusTypeLabel,
                          typeLabel(text, generation),
                        ),
                        (
                          text.templateFlowCostLabel,
                          '${generation.tokenCost} ${text.walletBalanceUnit}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_hasSubmittedFeedback)
                      _FeedbackSubmittedCard(
                        message: text.generationStatusFeedbackThanksMessage,
                      )
                    else
                      _FeedbackCard(
                        isSubmitting: _isSubmittingFeedback,
                        title: text.generationStatusFeedbackTitle,
                        excellentLabel: text.generationStatusFeedbackExcellent,
                        okayLabel: text.generationStatusFeedbackOkay,
                        badLabel: text.generationStatusFeedbackBad,
                        onRatingSelected: _handleRatingSelected,
                      ),
                  ] else if (generation.isFailed) ...[
                    _FailureCard(generation: generation),
                    const SizedBox(height: 14),
                    _FailedActions(
                      onPickAnotherPhoto: () => context.appNavigator.go(
                        _templatesDestinationForGeneration(generation),
                      ),
                      onRetry: () => _retrySoon(generation),
                      onSupport: () => context.appNavigator.push(
                        const SupportChatDestination(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_hasSubmittedFeedback)
                      _FeedbackSubmittedCard(
                        message: text.generationStatusFeedbackThanksMessage,
                      )
                    else
                      _FailedFeedbackCard(
                        isSubmitting: _isSubmittingFeedback,
                        onSubmit: (category) => unawaited(
                          _submitStructuredFeedback(
                            generation: generation,
                            type: 'GenerationFailure',
                            category: category,
                            rating: -1,
                            sourceScreen: 'generation_status_failed',
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    _DetailsCard(
                      title: text.generationStatusDetailsTitle,
                      rows: [
                        (
                          text.templateFlowTemplateLabel,
                          generation.templateTitle ??
                              text.generationStatusUntitledFallback,
                        ),
                        (
                          text.generationStatusTypeLabel,
                          typeLabel(text, generation),
                        ),
                        (
                          text.generationStatusAttemptLabel,
                          '${generation.attemptCount}',
                        ),
                        (
                          text.templateFlowCostLabel,
                          '${generation.tokenCost} ${text.walletBalanceUnit}',
                        ),
                      ],
                    ),
                  ] else if (generation.isCancelled) ...[
                    _CancelledCard(generation: generation),
                    const SizedBox(height: 14),
                    _ActiveActions(
                      onContinue: () =>
                          context.appNavigator.go(const CreationsDestination()),
                    ),
                    const SizedBox(height: 14),
                    _DetailsCard(
                      title: text.generationStatusDetailsTitle,
                      rows: [
                        (
                          text.templateFlowTemplateLabel,
                          generation.templateTitle ??
                              text.generationStatusUntitledFallback,
                        ),
                        (
                          text.generationStatusTypeLabel,
                          typeLabel(text, generation),
                        ),
                        (
                          text.templateFlowCostLabel,
                          '${generation.tokenCost} ${text.walletBalanceUnit}',
                        ),
                      ],
                    ),
                  ] else ...[
                    _ActiveGenerationCard(generation: generation),
                    const SizedBox(height: 14),
                    if (generation.canCancelQueued) ...[
                      _QueuedCancelAction(
                        isCancelling: _isCancellingGeneration,
                        onCancel: _isCancellingGeneration
                            ? null
                            : () => unawaited(
                                _confirmAndCancelQueuedGeneration(generation),
                              ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _ActiveActions(
                      onContinue: () =>
                          context.appNavigator.go(const CreationsDestination()),
                    ),
                    const SizedBox(height: 14),
                    _DetailsCard(
                      title: text.generationStatusDetailsTitle,
                      rows: [
                        (
                          text.templateFlowTemplateLabel,
                          generation.templateTitle ??
                              text.generationStatusUntitledFallback,
                        ),
                        (
                          text.generationStatusStartedLabel,
                          formatGenerationDateTime(
                            generation.createdAtUtc,
                            Localizations.localeOf(context),
                          ),
                        ),
                        (
                          text.generationStatusTypeLabel,
                          typeLabel(text, generation),
                        ),
                        (
                          text.templateFlowCostLabel,
                          '${generation.tokenCost} ${text.walletBalanceUnit}',
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
