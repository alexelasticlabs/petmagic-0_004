part of 'template_card.dart';

class _TemplateShadeOverlay extends StatelessWidget {
  const _TemplateShadeOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.08),
              Colors.black.withValues(alpha: 0.32),
              Colors.black.withValues(alpha: 0.68),
              Colors.black.withValues(alpha: 0.94),
            ],
            stops: const [0, 0.34, 0.56, 0.8, 1],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TemplateHeaderBadges extends StatelessWidget {
  const _TemplateHeaderBadges({
    required this.type,
    this.highlightBadgeLabel,
    this.promoBadgeValue,
    this.isFeatured = false,
  });

  final TemplateType type;
  final String? highlightBadgeLabel;
  final String? promoBadgeValue;
  final bool isFeatured;

  @override
  Widget build(BuildContext context) {
    final trimmedPromo = promoBadgeValue?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (highlightBadgeLabel != null &&
                  highlightBadgeLabel!.isNotEmpty)
                _HighlightBadge(
                  label: highlightBadgeLabel!,
                  isFeatured: isFeatured,
                ),
              if (trimmedPromo != null && trimmedPromo.isNotEmpty)
                _PromoBadge(value: trimmedPromo),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _MediaTypeBadge(type: type),
      ],
    );
  }
}

class _TemplateDetails extends StatelessWidget {
  const _TemplateDetails({
    required this.template,
    required this.hasPremiumAccess,
    required this.showGuestPreview,
    this.featuredData,
    required this.onPressed,
  });

  final TemplateItem template;
  final bool hasPremiumAccess;
  final bool showGuestPreview;
  final TemplateCardFeaturedData? featuredData;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final metaStyle = Theme.of(context).textTheme.labelMedium;
    final tags = template.tags.take(2).toList(growable: false);
    final musicDescription = template.musicDescription?.trim();
    final showMusicDescription =
        template.isVideo &&
        musicDescription != null &&
        musicDescription.isNotEmpty;
    final isPremiumLocked = template.isPremium && !hasPremiumAccess;
    final isFeatured = featuredData != null;
    final actionLabel = isPremiumLocked
        ? text.templateUnlockPremiumAction
        : featuredData?.actionLabel ?? text.templateTryAction;
    final featuredCountdownLabel = isFeatured
        ? _formatFeaturedCountdown(featuredData!.countdownTarget)
        : null;
    final featuredPopularityLabel = isFeatured
        ? _formatFeaturedPopularity(
            context,
            featuredData!.popularityCount,
            showTodayFallback: featuredData!.showPopularityTodayFallback,
          )
        : null;
    final colors = context.petMagicColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isFeatured)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (featuredCountdownLabel != null)
                _TemplateFeaturedMetaChip(
                  icon: Icons.timer_outlined,
                  label: featuredCountdownLabel,
                  accent: colors.accent,
                ),
              if (featuredPopularityLabel != null)
                _TemplateFeaturedMetaChip(
                  icon: Icons.pets_rounded,
                  label: featuredPopularityLabel,
                  accent: colors.gold,
                ),
            ],
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _TokenChip(cost: template.tokenCost),
              if (showGuestPreview)
                _TemplateStatusChip(label: text.templateGuestPreview),
            ],
          ),
        const SizedBox(height: 6),
        Text(
          template.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle?.copyWith(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            height: 1.04,
            letterSpacing: -0.12,
            shadows: [
              const Shadow(
                color: Color.fromRGBO(3, 7, 15, 0.62),
                blurRadius: 20,
                offset: Offset(0, 7),
              ),
            ],
          ),
        ),
        if (showMusicDescription) ...[
          const SizedBox(height: 4),
          _MusicDescription(text: musicDescription),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 4),
          SizedBox(
            height: 21,
            child: ClipRect(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: [
                    for (var index = 0; index < tags.length; index++) ...[
                      if (index > 0) const SizedBox(width: 6),
                      _TagChip(label: tags[index]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 4),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (template.isVideo) ...[
              Text(
                formatDuration(template.referenceVideoDurationSeconds),
                style: metaStyle?.copyWith(
                  color: Color.fromRGBO(228, 238, 251, 0.9),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const _MetaDot(),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 92),
              child: Text(
                template.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metaStyle?.copyWith(
                  color: const Color.fromRGBO(228, 238, 251, 0.9),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (template.isPremium) _AccessTag(label: text.premiumLabel),
          ],
        ),
        const SizedBox(height: 6),
        _TemplateActionButton(
          label: actionLabel,
          isPremiumLockCta: isPremiumLocked,
          isPremiumTemplateCta: template.isPremium || isFeatured,
          onPressed: onPressed,
        ),
      ],
    );
  }
}

class _TemplateActionButton extends StatelessWidget {
  const _TemplateActionButton({
    required this.label,
    required this.onPressed,
    this.isPremiumLockCta = false,
    this.isPremiumTemplateCta = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isPremiumLockCta;
  final bool isPremiumTemplateCta;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge;
    final colors = context.petMagicColors;
    final usePremiumStyle = isPremiumLockCta || isPremiumTemplateCta;
    final useSoftPremiumStyle = isPremiumTemplateCta && !isPremiumLockCta;
    final foregroundColor = usePremiumStyle
        ? colors.on(
            isPremiumLockCta
                ? const Color(0xFFF3C65A)
                : const Color(0xFFEFCB72),
          )
        : colors.on(colors.accent);
    return PetMagicInteractiveSurface(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      scaleDown: 0.975,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isPremiumLockCta
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFF0A41C),
                    Color(0xFFF3C65A),
                    Color(0xFFF9E18C),
                  ],
                  stops: [0, 0.54, 1],
                )
              : useSoftPremiumStyle
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFE8AA38),
                    Color(0xFFEFCB72),
                    Color(0xFFF5DE97),
                  ],
                  stops: [0, 0.58, 1],
                )
              : const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xD910C878), Color(0xCCF2C96A)],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: usePremiumStyle
                ? const Color(0xFFF9E8B6).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.14),
            width: usePremiumStyle ? 1.3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (isPremiumLockCta
                          ? const Color(0xFFE4901F)
                          : useSoftPremiumStyle
                          ? const Color(0xFFD8A64B)
                          : const Color(0xFF10C878))
                      .withValues(alpha: 0.24),
              blurRadius: useSoftPremiumStyle ? 10 : 14,
              offset: Offset(0, useSoftPremiumStyle ? 6 : 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle?.copyWith(
                    color: foregroundColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: usePremiumStyle ? 22 : null,
                height: usePremiumStyle ? 22 : null,
                decoration: usePremiumStyle
                    ? BoxDecoration(
                        color: const Color(0x3DFFF3D2),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xAAFFF0C0)),
                      )
                    : null,
                child: isPremiumLockCta
                    ? const PremiumCrownIcon(size: 13.5)
                    : Icon(
                        Icons.arrow_forward_rounded,
                        color: foregroundColor,
                        size: usePremiumStyle ? 13.5 : 16,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateStatusChip extends StatelessWidget {
  const _TemplateStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.accent.withValues(alpha: 0.18),
            colors.gold.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withValues(alpha: 0.26)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.accent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MediaSkeletonPlaceholder extends StatelessWidget {
  const _MediaSkeletonPlaceholder();

  @override
  Widget build(BuildContext context) => const PetMagicImageSkeleton();
}

class _MediaErrorPlaceholder extends StatelessWidget {
  const _MediaErrorPlaceholder({required this.isVideo, this.onRetry});

  final bool isVideo;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceStrong.withValues(alpha: 0.92),
            colors.surface.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final detailsReserve = constraints.maxHeight < 250 ? 118.0 : 132.0;
          final mediaHeight = (constraints.maxHeight - detailsReserve).clamp(
            76.0,
            constraints.maxHeight,
          );

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: mediaHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVideo
                            ? Icons.videocam_off_rounded
                            : Icons.broken_image_outlined,
                        color: colors.textMuted,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        text.templateFlowPreviewUnavailable,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.textSoft,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (onRetry != null) ...[
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: Text(
                            text.retryAction,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
