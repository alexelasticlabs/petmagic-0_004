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
                        leading: const PremiumCrownIcon(size: 15),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: const _TemplateScrollHint(),
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
                              ...PremiumBannerStyle.gradient(
                                Theme.of(context).brightness ==
                                    Brightness.light,
                              ),
                            ],
                            stops: const [0, 0.55, 1],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(
                              0xFFE0A91E,
                            ).withValues(alpha: 0.76),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF081538,
                              ).withValues(alpha: 0.26),
                              blurRadius: 14,
                              spreadRadius: 0.5,
                              offset: const Offset(0, 8),
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
                                  const PremiumCrownIcon(size: 18),
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
                    if (template.isPremium && !isPremiumLocked)
                      _PremiumTemplateUploadButton(
                        label: _templateUploadActionLabel(
                          locale,
                          isVideo: template.isVideo,
                        ),
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(TemplateDetailAction.upload),
                      )
                    else
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

class _TemplateScrollHint extends StatelessWidget {
  const _TemplateScrollHint();

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final colors = context.petMagicColors;
    final hintLabel = _isRussian(locale)
        ? 'Листайте вниз, чтобы продолжить'
        : 'Scroll down to continue';

    return IgnorePointer(
      ignoring: true,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceStrong.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 17,
                  color: colors.textSoft,
                ),
                const SizedBox(width: 4),
                Text(
                  hintLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
                        child: const PremiumCrownIcon(size: 14),
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

class _PremiumTemplateUploadButton extends StatelessWidget {
  const _PremiumTemplateUploadButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleSmall;
    const ctaTextColor = Color(0xFF251102);

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onPressed,
          child: Ink(
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFE8AA38),
                  Color(0xFFEFCB72),
                  Color(0xFFF5DE97),
                ],
                stops: [0, 0.58, 1],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: const Color(0xFFF9E8B6).withValues(alpha: 0.82),
                width: 1.15,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD8A64B).withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
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
                      Icons.add_photo_alternate_outlined,
                      color: ctaTextColor,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
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
  }
}

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
    final isRu =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';

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
                      isRu ? 'Видео готово! 🎉' : 'Video is ready! 🎉',
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
                      isRu
                          ? 'Хотите создавать больше?'
                          : 'Want to create more?',
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
                      isRu
                          ? 'Premium даёт 40 PowSpark каждую неделю,\nPremium-шаблоны и экспорт без водяного знака.'
                          : 'Premium gives 40 PowSpark every week,\nPremium templates and watermark-free export.',
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
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              child: AnimatedBuilder(
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
                            colors: [Color(0xFFF4C64D), Color(0xFFEAB13A)],
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
                child: Center(
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
                ),
              ),
            ),
          ),
        ),
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

// Stable media frame for template preview.
// Keeps a fixed aspect ratio from first paint to avoid visible layout jumps.
class _AdaptiveTemplateMediaFrame extends StatelessWidget {
  const _AdaptiveTemplateMediaFrame({required this.template});

  final TemplateItem template;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final asset = template.previewAsset;
    final ratio = template.isVideo ? 9 / 16 : 3 / 4;

    Widget media;
    if (asset == null || asset.url.isEmpty) {
      media = _TemplatePreviewPlaceholder(
        isVideo: template.isVideo,
        title: _templatePreviewMissingTitle(locale),
        subtitle: _templatePreviewMissingSubtitle(
          locale,
          isVideo: template.isVideo,
        ),
      );
    } else if (template.isVideo && isVideoPreview(asset)) {
      media = _NetworkVideoPreview(url: asset.url);
    } else {
      media = CachedNetworkImage(
        imageUrl: asset.url,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        placeholder: (context, url) =>
            _EmptyMediaBox(label: text.templateFlowLoadingPreview),
        errorWidget: (context, url, error) => _TemplatePreviewPlaceholder(
          isVideo: template.isVideo,
          title: _templatePreviewMissingTitle(locale),
          subtitle: _templatePreviewMissingSubtitle(
            locale,
            isVideo: template.isVideo,
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: ratio,
      child: ClipRRect(borderRadius: BorderRadius.circular(22), child: media),
    );
  }
}

class _NetworkVideoPreview extends StatefulWidget {
  const _NetworkVideoPreview({required this.url});

  final String url;

  @override
  State<_NetworkVideoPreview> createState() => _NetworkVideoPreviewState();
}

class _NetworkVideoPreviewState extends State<_NetworkVideoPreview> {
  VideoPlayerController? _controller;
  bool _failedToLoad = false;
  int _initializeRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _NetworkVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      final previous = _controller;
      _controller = null;
      _failedToLoad = false;
      unawaited(previous?.dispose());
      _initialize();
    }
  }

  @override
  void dispose() {
    _initializeRequestVersion++;
    final controller = _controller;
    _controller = null;
    unawaited(controller?.dispose());
    super.dispose();
  }

  Future<void> _initialize() async {
    final requestVersion = ++_initializeRequestVersion;
    final url = widget.url;
    setState(() => _failedToLoad = false);
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.setVolume(0);
    controller.setLooping(true);
    try {
      await controller.initialize();
      if (!_isCurrentVideoRequest(requestVersion, url, controller)) {
        await controller.dispose();
        return;
      }
      await controller.play();
      if (!_isCurrentVideoRequest(requestVersion, url, controller)) {
        await controller.dispose();
        return;
      }
      setState(() {});
    } catch (_) {
      await controller.dispose();
      if (_isCurrentVideoRequest(requestVersion, url, controller)) {
        setState(() {
          _controller = null;
          _failedToLoad = true;
        });
      }
    }
  }

  bool _isCurrentVideoRequest(
    int requestVersion,
    String url,
    VideoPlayerController controller,
  ) {
    return mounted &&
        requestVersion == _initializeRequestVersion &&
        widget.url == url &&
        _controller == controller;
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
          fit: BoxFit.cover,
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
