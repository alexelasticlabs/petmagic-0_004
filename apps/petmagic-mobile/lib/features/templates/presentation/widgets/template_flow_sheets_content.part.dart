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
    final colors = context.petMagicColors;
    final duration = template.referenceVideoDurationSeconds;
    final title = _templateDisplayTitle(text, template.title);
    final description = _templateDisplayDescription(
      text,
      template.shortDescription,
      isVideo: template.isVideo,
    );
    final category = _templateDisplayCategory(text, template.category);
    final isPremiumTheme = template.isPremium;
    final requirements = template.effectivePetPhotoRequirements
        .map((item) => _templateDisplayRequirement(text, item))
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
                    child: TemplateMediaFrame(template: template),
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
                          _templateHeroTitle(text, isVideo: template.isVideo),
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
                          label:
                              '${template.tokenCost} ${text.walletBalanceUnit}',
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
                        label: text.templateFlowCostLabel,
                        value:
                            '${template.tokenCost} ${text.walletBalanceUnit}',
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.schedule_rounded,
                        iconColor: colors.blue,
                        label: text.templateDetailTimeLabel,
                        value: _templateEstimatedDuration(
                          text,
                          isVideo: template.isVideo,
                        ),
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
                        label: text.templateDetailFormatLabel,
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
                          text.templateFlowBestPhotoTitle,
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
                                _templateQualityWarning(text),
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
                          text,
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
                                  text,
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
