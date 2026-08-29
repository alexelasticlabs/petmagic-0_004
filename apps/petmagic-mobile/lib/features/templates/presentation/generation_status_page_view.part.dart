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
    final isActiveGeneration = generation != null && !generation.isTerminal;
    final isConnectionLost = !ref
        .watch(networkStatusControllerProvider)
        .hasInternet;
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
                  title: isActiveGeneration
                      ? text.generationStatusActiveTitle
                      : generation?.templateTitle ?? text.generationStatusTitle,
                  subtitle: generation == null || isActiveGeneration
                      ? null
                      : '${typeLabel(text, generation)} • ${generation.tokenCost} ${text.walletBalanceUnit}',
                  onBack: _handleBackNavigation,
                  onMenu: generation == null || isActiveGeneration
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
                  if (generation.isCompleted) ...[
                    _CompletedStatus(generation: generation),
                    const SizedBox(height: 12),
                    _ResultCard(
                      generation: generation,
                      onOpenViewer: () => _openFullscreenPreview(generation),
                    ),
                    const SizedBox(height: 10),
                    if (!isVideoGeneration(generation) &&
                        generation.canCompareBeforeAfter) ...[
                      _CompareActionCard(
                        label: text.generationStatusCompareWithOriginalAction,
                        onTap: () => unawaited(_openCompareViewer(generation)),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if ((_compatibleTemplates?.templates ?? const [])
                        .isNotEmpty) ...[
                      _ContinueWithResultSection(
                        templates: _compatibleTemplates!.templates,
                        onTemplateSelected: (template) => unawaited(
                          _openUseResultFlow(
                            generation,
                            selectedTemplateId: template.id,
                          ),
                        ),
                        onShowAll: () =>
                            unawaited(_openUseResultFlow(generation)),
                      ),
                      const SizedBox(height: 14),
                    ],
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
                    const SizedBox(height: 8),
                    _TechnicalDetailsAction(
                      onTap: () => _openGenerationDetailsSheet(generation),
                    ),
                  ] else if (generation.isFailed) ...[
                    _FailureCard(generation: generation),
                    const SizedBox(height: 22),
                    _FailedActions(
                      isPhotoFailure: isPhotoFailure(generation),
                      onPickAnotherPhoto: () => context.appNavigator.go(
                        _templatesDestinationForGeneration(generation),
                      ),
                      onRetry: () => _retrySoon(generation),
                      onSupport: () => context.appNavigator.push(
                        const SupportChatDestination(),
                      ),
                    ),
                    const SizedBox(height: 22),
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
                  ] else if (generation.isCancelled) ...[
                    _StatusHero(generation: generation),
                    const SizedBox(height: 14),
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
                    _ActiveGenerationCard(
                      generation: generation,
                      isConnectionLost: isConnectionLost,
                    ),
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
                    const SizedBox(height: 10),
                    _ActiveSecondaryActions(
                      onDetails: () => _openGenerationDetailsSheet(generation),
                      onSupport: () => context.appNavigator.push(
                        const SupportChatDestination(),
                      ),
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
