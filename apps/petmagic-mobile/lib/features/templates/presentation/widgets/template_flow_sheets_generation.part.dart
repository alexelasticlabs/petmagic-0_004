part of 'template_flow_sheets.dart';

const _kGenerationPremiumMascotAsset = 'assets/rewards/premium-upsell-dog.png';

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
    final wallet = ref.watch(
      walletControllerProvider.select((walletState) => walletState.wallet),
    );
    final generation = state.generation;
    final isCompleted = generation?.isCompleted == true;
    final isFailed = generation?.isFailed == true || state.errorMessage != null;
    final shouldShowPremiumGate =
        widget.template.isVideo && !(wallet?.isPremium ?? false);
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
                        ? _GenerationCompletedPremiumGate(
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
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenerationCompletedPremiumGate extends StatelessWidget {
  const _GenerationCompletedPremiumGate({
    required this.onClose,
    required this.onLater,
    super.key,
  });

  final VoidCallback onClose;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final rightInset = compact ? 124.0 : 162.0;
        final mascotHeight = compact ? 176.0 : 200.0;
        return DecoratedBox(
          key: const ValueKey('generation-completed-premium-gate'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(
                0xFFE0A91E,
              ).withValues(alpha: isLight ? 0.78 : 0.9),
              width: 1.15,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: PremiumBannerStyle.gradient(isLight),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 12,
                top: 8,
                child: IconButton(
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    color: isLight
                        ? const Color(0xFF514325)
                        : const Color(0xFFE1DED4),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 0,
                child: IgnorePointer(
                  child: Image.asset(
                    _kGenerationPremiumMascotAsset,
                    height: mascotHeight,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(18, 20, rightInset, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${text.generationStatusVideoReady}! 🎉',
                      style: TextStyle(
                        color: isLight
                            ? const Color(0xFF1E1608)
                            : const Color(0xFFEDE7D8),
                        fontSize: compact ? 27 : 32,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      text.templateFlowCompletedPremiumHeadline,
                      style: TextStyle(
                        color: isLight
                            ? const Color(0xFF3C3222)
                            : const Color(0xFFD2D8E5),
                        fontSize: compact ? 15.5 : 17.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      text.templateFlowCompletedPremiumMessage,
                      style: TextStyle(
                        color: isLight
                            ? const Color(0xFF3B3324)
                            : const Color(0xFFE3DFD2),
                        fontSize: compact ? 13.4 : 15.2,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    PremiumShimmerButton(
                      label: text.premiumContinueAction,
                      onTap: () => context.push(PremiumPage.routePath),
                      height: 46,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: onLater,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isLight
                                ? const Color(0xFFBCB29B)
                                : const Color(0xFF2A3651),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          text.templateFlowChooseAnotherTemplateAction,
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF3C3324)
                                : const Color(0xFFC6CEDD),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GenerationGoldShimmerButton extends StatefulWidget {
  const _GenerationGoldShimmerButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  State<_GenerationGoldShimmerButton> createState() =>
      _GenerationGoldShimmerButtonState();
}

class _GenerationGoldShimmerButtonState
    extends State<_GenerationGoldShimmerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState();
  }

  @override
  void deactivate() {
    _controller.stop();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _syncAnimationState();
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animateShimmer = PerformanceGuard.shouldAnimateRepeatingEffects(
      context,
    );

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE0A91E).withValues(alpha: 0.34),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: animateShimmer
                  ? AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final t = _controller.value;
                        final shimmerStart = -1.6 + (t * 2.8);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFF4C64D),
                                    Color(0xFFEAB13A),
                                  ],
                                ),
                              ),
                              child: child,
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment(shimmerStart, -1),
                                      end: Alignment(shimmerStart + 0.9, 1),
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withValues(alpha: 0.68),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.23, 0.5, 0.77],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      child: _buildButtonSurface(),
                    )
                  : DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF4C64D), Color(0xFFEAB13A)],
                        ),
                      ),
                      child: _buildButtonSurface(),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonSurface() {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          widget.label,
          style: const TextStyle(
            color: Color(0xFF261903),
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  void _syncAnimationState() {
    if (!PerformanceGuard.shouldAnimateRepeatingEffects(context)) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      return;
    }

    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }
}

class _GenerationWorkingView extends ConsumerWidget {
  const _GenerationWorkingView({
    required this.template,
    required this.generation,
    required this.isFailed,
    this.errorMessage,
  });

  final TemplateItem template;
  final TemplateGenerationResult? generation;
  final bool isFailed;
  final String? errorMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final progress = _progressValue(generation, isFailed);
    final isBalanceError = errorMessage == 'templates.insufficient_balance';

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
            Text(
              _generationErrorText(text, errorMessage!),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                height: 1.35,
              ),
            ),
          const SizedBox(height: 14),
          if (isBalanceError)
            FilledButton.icon(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.push(WalletPage.routePath);
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
                    ? _NetworkVideoPreview(url: outputUrl)
                    : CachedNetworkImage(
                        imageUrl: outputUrl,
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
                onPressed: outputUrl.isEmpty
                    ? null
                    : () => SharePlus.instance.share(
                        ShareParams(text: '${template.title}\n$outputUrl'),
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
