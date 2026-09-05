part of 'template_preview_page.dart';

class _TemplatePreviewScrim extends StatelessWidget {
  const _TemplatePreviewScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.18, 0.5, 0.7, 1],
          colors: [
            Colors.black.withValues(alpha: 0.28),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.82),
            Colors.black.withValues(alpha: 0.96),
          ],
        ),
      ),
    );
  }
}

class _TemplatePreviewIconButton extends StatelessWidget {
  const _TemplatePreviewIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        color: onPressed == null ? Colors.white54 : Colors.white,
        iconSize: 21,
        icon: isLoading
            ? const SizedBox.square(
                key: ValueKey('template-preview-icon-loading'),
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
      ),
    );
  }
}

class _TemplatePreviewSummary extends StatelessWidget {
  const _TemplatePreviewSummary({
    required this.template,
    required this.isPremiumLocked,
    required this.reduceMotion,
    required this.direction,
  });

  final TemplateItem template;
  final bool isPremiumLocked;
  final bool reduceMotion;
  final int direction;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final title = template.title.trim().isEmpty
        ? text.templateDetailFallbackTitle
        : template.title.trim();

    return Semantics(
      container: true,
      liveRegion: true,
      child: AnimatedSwitcher(
        key: const ValueKey('template-preview-summary-switcher'),
        duration: reduceMotion
            ? Duration.zero
            : _TemplatePreviewPageState._contentAnimationDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0.04 * direction, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Column(
          key: ValueKey('template-preview-summary:${template.templateId}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (template.isPremium) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PremiumCrownIcon(size: 15),
                  const SizedBox(width: 5),
                  Text(
                    text.premiumLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (isPremiumLocked) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.lock_rounded, size: 13, color: colors.gold),
                  ],
                ],
              ),
              const SizedBox(height: 5),
            ],
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontSize: 22,
                height: 1.08,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.35,
              ),
            ),
            const SizedBox(height: 11),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 8,
              children: [
                _TemplatePreviewMetaItem(
                  icon: template.isVideo
                      ? Icons.videocam_rounded
                      : Icons.image_rounded,
                  label: template.isVideo ? text.videoLabel : text.imageLabel,
                ),
                _TemplatePreviewMetaItem(
                  icon: Icons.schedule_rounded,
                  label: template.isVideo
                      ? text.templateDetailVideoEta
                      : text.templateDetailImageEta,
                ),
                if (template.tokenCost > 0)
                  _TemplatePreviewMetaItem(
                    iconWidget: const PawSparkIcon(size: 15),
                    label: '${template.tokenCost} ${text.walletBalanceUnit}',
                  )
                else if (!template.isPremium)
                  _TemplatePreviewMetaItem(
                    icon: Icons.auto_awesome_rounded,
                    label: text.freeLabel,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplatePreviewMetaItem extends StatelessWidget {
  const _TemplatePreviewMetaItem({
    required this.label,
    this.icon,
    this.iconWidget,
  }) : assert(icon != null || iconWidget != null);

  final String label;
  final IconData? icon;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget ?? Icon(icon, size: 15, color: Colors.white70),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TemplatePreviewThumbnail extends StatelessWidget {
  const _TemplatePreviewThumbnail({required this.template});

  final TemplateItem template;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveTemplatePreviewThumbnail(template);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl == null)
          _placeholder(context)
        else
          TemplatePreviewImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            cacheWidth: 192,
            mediaVersion: template.mediaVersion,
            placeholder: _placeholder(context),
            errorBuilder: (_) => _placeholder(context),
          ),
        if (template.isVideo)
          const Positioned(
            right: 4,
            bottom: 4,
            child: _TemplatePreviewVideoBadge(),
          ),
      ],
    );
  }

  Widget _placeholder(BuildContext context) {
    final colors = context.petMagicColors;
    return ColoredBox(
      color: colors.surfaceStrong,
      child: Center(
        child: Icon(
          template.isVideo ? Icons.videocam_rounded : Icons.image_rounded,
          size: 21,
          color: colors.textSoft,
        ),
      ),
    );
  }
}

class _TemplatePreviewVideoBadge extends StatelessWidget {
  const _TemplatePreviewVideoBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('template-preview-video-badge'),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.64),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: const SizedBox.square(
        dimension: 20,
        child: Icon(Icons.play_arrow_rounded, size: 13, color: Colors.white),
      ),
    );
  }
}

class _TemplatePreviewPaginationStatus extends StatelessWidget {
  const _TemplatePreviewPaginationStatus({
    required this.isLoading,
    required this.onRetry,
  });

  final bool isLoading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: SizedBox.square(
          key: ValueKey('template-preview-pagination-loading'),
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Center(
      child: IconButton.filledTonal(
        key: const ValueKey('template-preview-pagination-retry'),
        tooltip: AppLocalizations.of(context).retryAction,
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
      ),
    );
  }
}

String? _resolveTemplatePreviewThumbnail(TemplateItem template) {
  final candidates = <String?>[
    template.thumbnailUrl,
    if (!template.detailPreviewIsVideo) template.detailPreviewUrl,
    if (!isVideoPreview(template.previewAsset)) template.previewAsset?.url,
  ];
  for (final candidate in candidates) {
    final safe = parseSafeGenerationMediaUri(candidate)?.toString();
    if (safe != null && !isVideoUrl(safe)) {
      return safe;
    }
  }
  return null;
}
