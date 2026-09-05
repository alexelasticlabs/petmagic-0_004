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
          stops: const [0, 0.18, 0.48, 0.76, 1],
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
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

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
        icon: Icon(icon),
      ),
    );
  }
}

class _TemplatePreviewSummary extends StatelessWidget {
  const _TemplatePreviewSummary({
    required this.template,
    required this.reduceMotion,
    required this.direction,
  });

  final TemplateItem template;
  final bool reduceMotion;
  final int direction;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
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
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [
            for (final child in previous)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(child: ExcludeSemantics(child: child)),
              ),
            ?current,
          ],
        ),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0.12 * direction, 0.06),
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
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(44),
              child: Center(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _TemplatePreviewDescription(
              key: ValueKey(
                'template-preview-description:${template.templateId}',
              ),
              description: template.shortDescription,
              isVideo: template.isVideo,
              reduceMotion: reduceMotion,
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(
                MediaQuery.sizeOf(context).width /
                            MediaQuery.textScalerOf(context).scale(1) <
                        360
                    ? 48
                    : 28,
              ),
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _TemplatePreviewMetaItem(
                      icon: template.isVideo
                          ? Icons.videocam_rounded
                          : Icons.image_rounded,
                      label: _resultLabel(text),
                    ),
                    if (template.tokenCost > 0)
                      _TemplatePreviewMetaItem(
                        iconWidget: const PawSparkIcon(size: 15),
                        label:
                            '${template.tokenCost} ${text.walletBalanceUnit}',
                      )
                    else if (!template.isPremium)
                      _TemplatePreviewMetaItem(
                        icon: Icons.auto_awesome_rounded,
                        label: text.freeLabel,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text.templatePreviewCreationTime(
                template.isVideo
                    ? text.templateDetailVideoEta
                    : text.templateDetailImageEta,
              ),
              key: const ValueKey('template-preview-creation-time'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white60,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resultLabel(AppLocalizations text) {
    if (!template.isVideo) return text.templatePreviewImageResult;
    // Preview/loop duration can differ from the motion reference used by generation.
    final seconds = template.referenceVideoDurationSeconds;
    if (seconds == null || !seconds.isFinite || seconds <= 0) {
      return text.templatePreviewVideoDurationUnknown;
    }
    final format = NumberFormat.decimalPattern(text.localeName)
      ..maximumFractionDigits = 1;
    final duration = format.format(seconds);
    return text.templatePreviewVideoResult(duration);
  }
}

class _TemplatePreviewPremiumBadge extends StatelessWidget {
  const _TemplatePreviewPremiumBadge({required this.isLocked});

  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final gold = context.petMagicColors.gold;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFFFFE5A3), gold]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFE5A3)),
        boxShadow: [
          BoxShadow(color: gold.withValues(alpha: 0.24), blurRadius: 18),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              size: 18,
              color: Color(0xFF30200A),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                AppLocalizations.of(context).premiumLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF30200A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (isLocked) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.lock_rounded,
                size: 13,
                color: Color(0xFF30200A),
              ),
            ],
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
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TemplatePreviewThumbnail extends StatelessWidget {
  const _TemplatePreviewThumbnail({
    required this.template,
    required this.isActive,
    required this.autoplay,
    required this.playbackRegistry,
  });

  final TemplateItem template;
  final bool isActive;
  final bool autoplay;
  final TemplatePreviewPlaybackRegistry playbackRegistry;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveTemplatePreviewThumbnail(template);
    final poster = imageUrl == null
        ? _placeholder(context)
        : TemplatePreviewImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            cacheWidth: 192,
            mediaVersion: template.mediaVersion,
            placeholder: _placeholder(context),
            errorBuilder: (_) => _placeholder(context),
          );
    final fallback = TemplateVideoThumbnail(
      template: template,
      isActive: isActive,
      autoplay: autoplay,
      placeholder: poster,
      playbackRegistry: playbackRegistry,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (template.isVideo ||
            template.detailPreviewIsVideo ||
            imageUrl == null)
          fallback
        else
          TemplatePreviewImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            cacheWidth: 192,
            mediaVersion: template.mediaVersion,
            placeholder: _placeholder(context),
            errorBuilder: (_) => fallback,
          ),
        if (template.isVideo)
          const Positioned(
            right: 4,
            bottom: 4,
            child: _TemplatePreviewVideoBadge(),
          ),
        if (template.isPremium)
          Positioned(
            top: 3,
            right: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.petMagicColors.gold,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  size: 12,
                  color: Color(0xFF30200A),
                ),
              ),
            ),
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
        child: Icon(Icons.graphic_eq_rounded, size: 13, color: Colors.white),
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
