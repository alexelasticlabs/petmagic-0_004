part of 'template_flow_sheets.dart';

class TemplateDetailContent extends StatelessWidget {
  const TemplateDetailContent({
    required this.template,
    required this.scrollController,
    this.isPremiumLocked = false,
    this.onUnlockPremium,
    super.key,
  });

  final TemplateItem template;
  final ScrollController scrollController;
  final bool isPremiumLocked;
  final VoidCallback? onUnlockPremium;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final colors = context.petMagicColors;
    final duration = template.referenceVideoDurationSeconds;
    final title = _templateDisplayTitle(locale, template.title);
    final description = _templateDisplayDescription(
      locale,
      template.shortDescription,
      isVideo: template.isVideo,
    );
    final category = _templateDisplayCategory(locale, template.category);
    final isPremiumTheme = template.isPremium;
    final requirements = template.effectivePetPhotoRequirements
        .map((item) => _templateDisplayRequirement(locale, item))
        .take(4)
        .toList(growable: false);

    return CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top bar ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: colors.textStrong,
                    ),
                    const Spacer(),
                    if (template.isPremium)
                      _Pill(
                        icon: Icons.workspace_premium_rounded,
                        label: text.premiumLabel,
                        color: colors.gold,
                      ),
                  ],
                ),
              ),

              // ── Adaptive media preview ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isPremiumTheme
                          ? colors.gold.withValues(alpha: 0.55)
                          : colors.border.withValues(alpha: 0.46),
                      width: isPremiumTheme ? 1.2 : 1,
                    ),
                    boxShadow: [
                      if (isPremiumTheme)
                        BoxShadow(
                          color: colors.gold.withValues(alpha: 0.2),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _AdaptiveTemplateMediaFrame(template: template),
                  ),
                ),
              ),

              // ── Title & description ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Eyebrow label
                    Row(
                      children: [
                        Icon(
                          template.isVideo
                              ? Icons.auto_awesome_rounded
                              : Icons.auto_fix_high_rounded,
                          color: colors.accent,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _templateHeroTitle(locale, isVideo: template.isVideo),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.accent,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.textStrong,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSoft,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Tags row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(
                          leading: const PawSparkIcon(size: 15),
                          label: '${template.tokenCost} PawSpark',
                          color: isPremiumTheme ? colors.gold : colors.gold,
                        ),
                        _Pill(
                          icon: template.isVideo
                              ? Icons.videocam_rounded
                              : Icons.image_rounded,
                          label: template.isVideo
                              ? text.videoLabel
                              : text.imageLabel,
                          color: colors.accent,
                        ),
                        _Pill(
                          icon: Icons.category_rounded,
                          label: category,
                          color: colors.blue,
                        ),
                        if (template.isVideo && duration != null)
                          _Pill(
                            icon: Icons.timer_rounded,
                            label: formatDuration(duration),
                            color: colors.purple,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Info cards ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.generating_tokens_rounded,
                        iconColor: colors.gold,
                        label: _isRussian(locale) ? 'Стоимость' : 'Cost',
                        value: '${template.tokenCost} PawSpark',
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.schedule_rounded,
                        iconColor: colors.blue,
                        label: _isRussian(locale) ? 'Время' : 'Time',
                        value: template.isVideo
                            ? (_isRussian(locale) ? '2–5 мин' : '2-5 min')
                            : (_isRussian(locale) ? '30–60 сек' : '30-60 sec'),
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoCard(
                        icon: template.isVideo
                            ? Icons.videocam_rounded
                            : Icons.image_rounded,
                        iconColor: colors.accent,
                        label: _isRussian(locale) ? 'Формат' : 'Format',
                        value: template.isVideo
                            ? (template.isVideo
                                  ? text.videoLabel
                                  : text.imageLabel)
                            : text.imageLabel,
                        colors: colors,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Requirements section ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.checklist_rounded,
                          color: colors.textStrong,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _templateBestResultTitle(locale),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: colors.textStrong,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceStrong.withValues(
                          alpha: isPremiumTheme ? 0.8 : 0.72,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isPremiumTheme
                              ? colors.gold.withValues(alpha: 0.28)
                              : colors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            for (int i = 0; i < requirements.length; i++) ...[
                              _RequirementRow(label: requirements[i]),
                              if (i < requirements.length - 1)
                                Divider(
                                  height: 14,
                                  thickness: 0.5,
                                  color: colors.border.withValues(alpha: 0.4),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Quality warning
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: isPremiumTheme
                            ? colors.gold.withValues(alpha: 0.12)
                            : colors.gold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isPremiumTheme
                              ? colors.gold.withValues(alpha: 0.4)
                              : colors.gold.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.tips_and_updates_rounded,
                              color: colors.gold,
                              size: 17,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                _templateQualityWarning(locale),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colors.textSoft,
                                      height: 1.4,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── CTA ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isPremiumLocked) ...[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0x40F3C65A),
                              colors.surfaceStrong.withValues(alpha: 0.96),
                              const Color(0x2AA46B12),
                            ],
                            stops: const [0, 0.64, 1],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xBFE6BB64),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0x66D9A741),
                              blurRadius: 20,
                              spreadRadius: 0.5,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.workspace_premium_rounded,
                                    color: colors.gold,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      text.templateFlowPremiumLockedTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: colors.textStrong,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                text.templateFlowPremiumLockedMessage,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colors.textSoft,
                                      height: 1.4,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              _PremiumUnlockCtaButton(
                                label: text.templateUnlockPremiumAction,
                                onPressed: onUnlockPremium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.icon(
                      onPressed: isPremiumLocked
                          ? null
                          : () => Navigator.of(
                              context,
                            ).pop(TemplateDetailAction.upload),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.1,
                            ),
                      ),
                      icon: Icon(
                        isPremiumLocked
                            ? Icons.lock_outline_rounded
                            : Icons.add_photo_alternate_outlined,
                      ),
                      label: Text(
                        isPremiumLocked
                            ? text.templateFlowUploadPetPhotoLockedAction
                            : _templateUploadActionLabel(
                                locale,
                                isVideo: template.isVideo,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumUnlockCtaButton extends StatefulWidget {
  const _PremiumUnlockCtaButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_PremiumUnlockCtaButton> createState() =>
      _PremiumUnlockCtaButtonState();
}

class _PremiumUnlockCtaButtonState extends State<_PremiumUnlockCtaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleSmall;
    const ctaTextColor = Color(0xFF251102);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glowAlpha = 0.34 + (_pulse.value * 0.42);
        return Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: widget.onPressed,
              child: Ink(
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFF0A41C),
                      Color(0xFFF3C65A),
                      Color(0xFFF9E18C),
                    ],
                    stops: [0, 0.54, 1],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFF9E8B6).withValues(alpha: 0.88),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE4901F).withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(
                        0xFFF7D67A,
                      ).withValues(alpha: glowAlpha),
                      blurRadius: 22,
                      spreadRadius: 0.6,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0x3DFFF3D2),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xAAFFF0C0)),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: ctaTextColor,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle?.copyWith(
                            color: ctaTextColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.08,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TemplateGenerationProgressContent extends ConsumerWidget {
  const _TemplateGenerationProgressContent({required this.template});

  final TemplateItem template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.petMagicColors;
    final state = ref.watch(templateGenerationControllerProvider);
    final generation = state.generation;
    final isCompleted = generation?.isCompleted == true;
    final isFailed = generation?.isFailed == true || state.errorMessage != null;

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
                  ? _GenerationResultView(
                      template: template,
                      generation: generation!,
                    )
                  : _GenerationWorkingView(
                      template: template,
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
    final outputUrl = generation.outputUrl ?? '';

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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: outputUrl.isEmpty
                ? _EmptyMediaBox(label: text.templateFlowResultUnavailable)
                : template.isVideo
                ? _NetworkVideoPreview(url: outputUrl)
                : CachedNetworkImage(
                    imageUrl: outputUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) =>
                        _EmptyMediaBox(label: text.templateFlowLoadingResult),
                    errorWidget: (context, url, error) => _EmptyMediaBox(
                      label: text.templateFlowResultLoadFailed,
                    ),
                  ),
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

// Adaptive media frame — detects the real aspect ratio of the preview
// asset (image or video) and renders it at the correct proportions.
class _AdaptiveTemplateMediaFrame extends StatefulWidget {
  const _AdaptiveTemplateMediaFrame({required this.template});

  final TemplateItem template;

  @override
  State<_AdaptiveTemplateMediaFrame> createState() =>
      _AdaptiveTemplateMediaFrameState();
}

class _AdaptiveTemplateMediaFrameState
    extends State<_AdaptiveTemplateMediaFrame> {
  // null = not yet known (show 9:16 skeleton), non-null = detected ratio
  double? _detectedRatio;

  @override
  void initState() {
    super.initState();
    _resolveImageRatio();
  }

  @override
  void didUpdateWidget(covariant _AdaptiveTemplateMediaFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.template.previewAsset?.url !=
        widget.template.previewAsset?.url) {
      _detectedRatio = null;
      _resolveImageRatio();
    }
  }

  void _resolveImageRatio() {
    final asset = widget.template.previewAsset;
    if (asset == null ||
        asset.url.isEmpty ||
        (widget.template.isVideo && isVideoPreview(asset))) {
      // For videos the ratio is reported back via [_onVideoRatioDetected].
      return;
    }
    // Use ImageStream to get the real pixel dimensions of the image.
    final provider = NetworkImage(asset.url);
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      stream.removeListener(listener);
      if (!mounted) return;
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (h > 0) {
        setState(() => _detectedRatio = w / h);
      }
    }, onError: (error, stackTrace) => stream.removeListener(listener));
    stream.addListener(listener);
  }

  void _onVideoRatioDetected(double ratio) {
    if (!mounted) return;
    if (_detectedRatio != ratio) {
      setState(() => _detectedRatio = ratio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final asset = widget.template.previewAsset;
    final ratio = _detectedRatio ?? 9 / 16;

    Widget media;
    if (asset == null || asset.url.isEmpty) {
      media = _TemplatePreviewPlaceholder(
        isVideo: widget.template.isVideo,
        title: _templatePreviewMissingTitle(locale),
        subtitle: _templatePreviewMissingSubtitle(
          locale,
          isVideo: widget.template.isVideo,
        ),
      );
    } else if (widget.template.isVideo && isVideoPreview(asset)) {
      media = _NetworkVideoPreview(
        url: asset.url,
        onRatioDetected: _onVideoRatioDetected,
      );
    } else {
      media = CachedNetworkImage(
        imageUrl: asset.url,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        placeholder: (context, url) =>
            _EmptyMediaBox(label: text.templateFlowLoadingPreview),
        errorWidget: (context, url, error) => _TemplatePreviewPlaceholder(
          isVideo: widget.template.isVideo,
          title: _templatePreviewMissingTitle(locale),
          subtitle: _templatePreviewMissingSubtitle(
            locale,
            isVideo: widget.template.isVideo,
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: AspectRatio(
        key: ValueKey(ratio),
        aspectRatio: ratio,
        child: ClipRRect(borderRadius: BorderRadius.circular(22), child: media),
      ),
    );
  }
}

class _NetworkVideoPreview extends StatefulWidget {
  const _NetworkVideoPreview({required this.url, this.onRatioDetected});

  final String url;
  final void Function(double ratio)? onRatioDetected;

  @override
  State<_NetworkVideoPreview> createState() => _NetworkVideoPreviewState();
}

class _NetworkVideoPreviewState extends State<_NetworkVideoPreview> {
  VideoPlayerController? _controller;
  bool _failedToLoad = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _NetworkVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _controller = null;
      _initialize();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() => _failedToLoad = false);
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    controller.setVolume(0);
    controller.setLooping(true);
    try {
      await controller.initialize();
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }
      await controller.play();
      setState(() {});
      final size = controller.value.size;
      if (size.height > 0) {
        widget.onRatioDetected?.call(size.width / size.height);
      }
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _controller = null;
          _failedToLoad = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final locale = Localizations.localeOf(context);
    if (_failedToLoad) {
      return _TemplatePreviewPlaceholder(
        isVideo: true,
        title: _templatePreviewMissingTitle(locale),
        subtitle: _templatePreviewMissingSubtitle(locale, isVideo: true),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return _EmptyMediaBox(
        label: _isRussian(locale) ? 'Загружаем видео...' : 'Loading video...',
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: IconButton.filledTonal(
              onPressed: () async {
                if (controller.value.isPlaying) {
                  await controller.pause();
                } else {
                  await controller.play();
                }
                if (mounted) {
                  setState(() {});
                }
              },
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfirmMetaRow extends StatelessWidget {
  const _ConfirmMetaRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.showCheck = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
          ),
        ),
        const PawSparkIcon(size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (showCheck) ...[
          const SizedBox(width: 5),
          Icon(Icons.check_circle_rounded, color: colors.accent, size: 14),
        ],
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Row(
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          color: colors.accent,
          size: 18,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textSoft,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: done ? colors.accent : colors.textMuted,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: done ? colors.textSoft : colors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    this.icon,
    this.leading,
    required this.label,
    required this.color,
  });

  final IconData? icon;
  final Widget? leading;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null)
              leading!
            else if (icon != null)
              Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.colors,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final PetMagicColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.textStrong,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _EmptyMediaBox extends StatelessWidget {
  const _EmptyMediaBox({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return ColoredBox(
      color: colors.surfaceStrong,
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TemplatePreviewPlaceholder extends StatelessWidget {
  const _TemplatePreviewPlaceholder({
    required this.isVideo,
    required this.title,
    required this.subtitle,
  });

  final bool isVideo;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceStrong.withValues(alpha: 0.96),
            colors.surfaceGlass.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVideo ? Icons.movie_creation_outlined : Icons.pets_rounded,
                size: 38,
                color: colors.accent,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
