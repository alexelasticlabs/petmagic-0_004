part of 'template_flow_sheets.dart';

class _TemplateGenerationProgressContent extends ConsumerStatefulWidget {
  const _TemplateGenerationProgressContent({required this.template});

  final TemplateItem template;

  @override
  ConsumerState<_TemplateGenerationProgressContent> createState() =>
      _TemplateGenerationProgressContentState();
}

class _TemplateGenerationProgressContentState
    extends ConsumerState<_TemplateGenerationProgressContent> {
  String? _lastCompletedGenerationId;
  bool _isPremiumGateDismissed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final state = ref.watch(templateGenerationControllerProvider);
    final hasPremiumAccess = ref.watch(templatePremiumAccessProvider);
    final generation = state.generation;
    final isCompleted = generation?.isCompleted == true;
    final isFailed = generation?.isFailed == true || state.errorMessage != null;
    final shouldShowPremiumGate = widget.template.isVideo && !hasPremiumAccess;
    final completedGenerationId = generation?.generationId;

    if (isCompleted &&
        completedGenerationId != null &&
        completedGenerationId != _lastCompletedGenerationId) {
      _lastCompletedGenerationId = completedGenerationId;
      _isPremiumGateDismissed = false;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: isCompleted || isFailed
                  ? () => Navigator.of(context).pop()
                  : null,
              icon: const Icon(Icons.close_rounded),
              color: colors.textStrong,
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: isCompleted
                  ? shouldShowPremiumGate && !_isPremiumGateDismissed
                        ? GenerationCompletedPremiumGate(
                            key: ValueKey<String>(
                              'generation-premium-gate-${generation!.generationId}',
                            ),
                            onClose: () =>
                                setState(() => _isPremiumGateDismissed = true),
                            onLater: () =>
                                setState(() => _isPremiumGateDismissed = true),
                          )
                        : _GenerationResultView(
                            template: widget.template,
                            generation: generation!,
                          )
                  : _GenerationWorkingView(
                      template: widget.template,
                      generation: generation,
                      isFailed: isFailed,
                      errorMessage:
                          state.errorMessage ?? generation?.failureMessage,
                      queueRejection: state.queueRejection,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenerationWorkingView extends ConsumerWidget {
  const _GenerationWorkingView({
    required this.template,
    required this.generation,
    required this.isFailed,
    this.errorMessage,
    this.queueRejection,
  });

  final TemplateItem template;
  final TemplateGenerationResult? generation;
  final bool isFailed;
  final String? errorMessage;
  final GenerationWaitTooLongException? queueRejection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final progress = _progressValue(generation, isFailed);
    final isBalanceError =
        normalizeTemplateErrorKey(errorMessage) ==
        'templates.insufficient_balance';

    return Column(
      key: const ValueKey('generation-working'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isFailed
              ? text.templateFlowCreateFailedTitle
              : text.magicLoadingPreparing,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.textStrong,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isFailed
              ? isBalanceError
                    ? text.templateFlowCreateFailedBalanceHint
                    : text.templateFlowCreateFailedRetryHint
              : text.templateFlowCreateHint,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 34),
        SizedBox(
          width: 138,
          height: 138,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: isFailed ? 1 : progress,
                strokeWidth: 7,
                color: isFailed ? colors.danger : colors.accent,
                backgroundColor: colors.border.withValues(alpha: 0.6),
              ),
              Center(
                child: Text(
                  isFailed ? '!' : '${((progress ?? 0.35) * 100).round()}%',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _ProgressStep(
          label: text.templateFlowStepProcessPhoto,
          done: generation != null,
        ),
        _ProgressStep(
          label: text.templateFlowStepAnalyzePet,
          done:
              generation?.startedAtUtc != null ||
              generation?.preprocessingCompletedAtUtc != null,
        ),
        _ProgressStep(
          label: text.templateFlowStepCreateMagic,
          done:
              generation?.motionGenerationCompletedAtUtc != null ||
              generation?.isCompleted == true,
        ),
        _ProgressStep(
          label: text.templateFlowStepFinalTouches,
          done: generation?.isCompleted == true,
        ),
        const SizedBox(height: 22),
        if (isFailed) ...[
          if (errorMessage != null && errorMessage!.isNotEmpty)
            queueRejection == null
                ? Text(
                    _generationErrorText(text, errorMessage!),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                      height: 1.35,
                    ),
                  )
                : _GenerationWaitTooLongMessage(
                    rejection: queueRejection!,
                    isFreeUser:
                        !(ref
                                .watch(walletControllerProvider)
                                .wallet
                                ?.isPremium ??
                            false),
                  ),
          const SizedBox(height: 14),
          if (isBalanceError)
            FilledButton.icon(
              onPressed: () {
                final appNavigator = context.appNavigator;
                Navigator.of(context).pop();
                appNavigator.push(const WalletDestination());
              },
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: Text(text.templateFlowTopUpBalanceAction),
            )
          else
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(templateGenerationControllerProvider.notifier)
                  .startGeneration(template),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(text.retryAction),
            ),
        ] else
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceStrong.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border.withValues(alpha: 0.55)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: colors.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text.templateFlowResultReadySubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSoft,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GenerationWaitTooLongMessage extends StatelessWidget {
  const _GenerationWaitTooLongMessage({
    required this.rejection,
    required this.isFreeUser,
  });

  final GenerationWaitTooLongException rejection;
  final bool isFreeUser;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final retryAfterSeconds = rejection.retryAfterSeconds;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.56)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              text.templateFlowGenerationWaitTooLongTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colors.textStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text.templateFlowGenerationWaitTooLongMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                height: 1.35,
              ),
            ),
            if (retryAfterSeconds != null && retryAfterSeconds > 0) ...[
              const SizedBox(height: 8),
              Text(
                text.templateFlowGenerationWaitTooLongRetryAfter(
                  _formatLocalizedWaitDuration(text, retryAfterSeconds),
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSoft,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (isFreeUser && rejection.canUpgradeForPriority) ...[
              const SizedBox(height: 8),
              Text(
                text.templateFlowGenerationWaitTooLongPremiumHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.gold,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GenerationResultView extends StatelessWidget {
  const _GenerationResultView({
    required this.template,
    required this.generation,
  });

  final TemplateItem template;
  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final outputUrl =
        parseSafeGenerationMediaUri(generation.outputUrl)?.toString() ?? '';
    final shareSafeUrl = outputUrl.isEmpty
        ? ''
        : persistentSafeGenerationMediaUrl(outputUrl) ?? '';

    return Column(
      key: const ValueKey('generation-result'),
      children: [
        Text(
          text.templateFlowResultReadyTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.textStrong,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text.templateFlowResultReadySubtitle,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final resultCacheWidth = _templatePreviewCacheDimension(
                constraints.maxWidth,
                MediaQuery.devicePixelRatioOf(context),
              );

              return ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: outputUrl.isEmpty
                    ? _EmptyMediaBox(label: text.templateFlowResultUnavailable)
                    : template.isVideo
                    ? _NetworkVideoPreview(
                        url: outputUrl,
                        playbackIdentity: outputUrl,
                      )
                    : CachedNetworkImage(
                        imageUrl: outputUrl,
                        cacheKey: persistentSafeGenerationMediaUrl(outputUrl),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        memCacheWidth: resultCacheWidth,
                        maxWidthDiskCache: resultCacheWidth,
                        filterQuality: FilterQuality.medium,
                        placeholder: (context, url) => _EmptyMediaBox(
                          label: text.templateFlowLoadingResult,
                        ),
                        errorWidget: (context, url, error) => _EmptyMediaBox(
                          label: text.templateFlowResultLoadFailed,
                        ),
                      ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: shareSafeUrl.isEmpty
                    ? null
                    : () => SharePlus.instance.share(
                        ShareParams(text: '${template.title}\n$shareSafeUrl'),
                      ),
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(text.supportChatShareAction),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(text.templateFlowCreateMoreAction),
        ),
      ],
    );
  }
}
