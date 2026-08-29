part of 'generation_status_page.dart';

class _ActiveGenerationCard extends StatelessWidget {
  const _ActiveGenerationCard({
    required this.generation,
    required this.isConnectionLost,
  });

  final TemplateGenerationResult generation;
  final bool isConnectionLost;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final serverProgress = generation.progressPercent?.clamp(0, 100).toInt();
    final progressValue = serverProgress == null
        ? _stageProgressValue(generation)
        : serverProgress / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _ActivePreviewFrame(generation: generation)),
        const SizedBox(height: 2),
        Text(
          generation.templateTitle ?? text.generationStatusResultTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: colors.textStrong,
            fontWeight: FontWeight.w900,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _MetaPill(
                icon: isVideoGeneration(generation)
                    ? Icons.movie_creation_rounded
                    : Icons.image_rounded,
                label: typeLabel(text, generation),
              ),
              _MetaPill(
                icon: Icons.bolt_rounded,
                label: '${generation.tokenCost} ${text.walletBalanceUnit}',
                color: colors.accent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceStrong.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        text.generationStatusActiveProgressTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.textStrong,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    if (serverProgress != null) ...[
                      const SizedBox(width: 12),
                      ExcludeSemantics(
                        child: Text(
                          '$serverProgress%',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.accent,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _GenerationProgressBar(value: progressValue),
                const SizedBox(height: 10),
                Text(
                  etaLabel(text, generation),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSoft,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isVideoGeneration(generation)) ...[
                  const SizedBox(height: 6),
                  Text(
                    text.generationStatusQueuedVideoHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _StageTimeline(generation: generation),
                if (isConnectionLost) ...[
                  const SizedBox(height: 16),
                  _ConnectionLostHint(),
                ],
                const SizedBox(height: 16),
                _BackgroundGenerationHint(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivePreviewFrame extends StatelessWidget {
  const _ActivePreviewFrame({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final previewUrl = _activePreviewUrl(generation);
    final localPreviewFile = _localMediaFile(generation.localPreviewPath);
    const size = 176.0;

    return SizedBox(
      width: 212,
      height: 198,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const _MagicSparkle(top: 12, left: 23, size: 14, opacity: 0.64),
          const _MagicSparkle(top: 35, right: 8, size: 9, opacity: 0.42),
          const _MagicSparkle(bottom: 24, left: 7, size: 10, opacity: 0.46),
          const _MagicSparkle(bottom: 5, right: 25, size: 15, opacity: 0.56),
          Center(
            child: SizedBox(
              width: size,
              height: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.74),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.20),
                      blurRadius: 24,
                      spreadRadius: 3,
                    ),
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.34),
                      blurRadius: 18,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (localPreviewFile != null)
                        Image.file(
                          localPreviewFile,
                          fit: BoxFit.cover,
                          cacheWidth: 512,
                          filterQuality: FilterQuality.medium,
                        )
                      else if (previewUrl != null)
                        CachedNetworkImage(
                          imageUrl: previewUrl,
                          cacheKey: persistentSafeGenerationMediaUrl(
                            previewUrl,
                          ),
                          fit: BoxFit.cover,
                          memCacheWidth: 512,
                          maxWidthDiskCache: 512,
                          filterQuality: FilterQuality.medium,
                          errorWidget: (context, url, error) =>
                              _ActivePreviewPlaceholder(label: text.imageLabel),
                        )
                      else
                        _ActivePreviewPlaceholder(
                          label: typeLabel(text, generation),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivePreviewPlaceholder extends StatelessWidget {
  const _ActivePreviewPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceStrong,
            colors.surfaceStrong.withValues(alpha: 0.68),
            colors.accent.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets_rounded, color: colors.accent, size: 32),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textSoft,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MagicSparkle extends StatelessWidget {
  const _MagicSparkle({
    required this.size,
    required this.opacity,
    this.top,
    this.right,
    this.bottom,
    this.left,
  });

  final double size;
  final double opacity;
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: Icon(
        Icons.auto_awesome_rounded,
        color: context.petMagicColors.accent.withValues(alpha: opacity),
        size: size,
      ),
    );
  }
}

class _ConnectionLostHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.cloud_off_outlined, color: colors.textMuted, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text.globalOfflineBannerMessage,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _BackgroundGenerationHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.58)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_done_outlined, color: colors.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.generationStatusBackgroundTitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text.generationStatusActiveInfoHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSoft,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueuedCancelAction extends StatelessWidget {
  const _QueuedCancelAction({
    required this.isCancelling,
    required this.onCancel,
  });

  final bool isCancelling;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.58)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cancelButton = OutlinedButton.icon(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
            icon: isCancelling
                ? SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.textSoft,
                    ),
                  )
                : const Icon(Icons.cancel_outlined),
            label: Text(text.generationStatusCancelQueuedAction),
          );

          final hint = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule_rounded, color: colors.textSoft, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text.generationStatusCancelQueuedHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSoft,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );

          return Padding(
            padding: const EdgeInsets.all(12),
            child: constraints.maxWidth < 420
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [hint, const SizedBox(height: 12), cancelButton],
                  )
                : Row(
                    children: [
                      Expanded(child: hint),
                      const SizedBox(width: 10),
                      Flexible(
                        flex: 0,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: cancelButton,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

String? _activePreviewUrl(TemplateGenerationResult generation) {
  for (final candidate in [
    generation.inputPreviewUrl,
    generation.sourceImageAsset?.url,
    generation.normalizedImageUrl,
    generation.resultPreviewUrl,
    generation.outputUrl,
  ]) {
    final value = candidate?.trim();
    if (value == null || value.isEmpty) {
      continue;
    }

    final safeUri = parseSafeGenerationMediaUri(value);
    if (safeUri != null) {
      return safeUri.toString();
    }
  }

  return null;
}
