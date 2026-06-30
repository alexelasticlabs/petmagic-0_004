part of 'generation_status_page.dart';

class _ActiveGenerationCard extends StatelessWidget {
  const _ActiveGenerationCard({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final progress = generation.effectiveProgressPercent.clamp(0, 100);
    final progressValue = progress / 100;
    final statusColor = generationStatusColor(colors, generation);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceGlass.withValues(alpha: 0.98),
            colors.surfaceStrong.withValues(alpha: 0.86),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border.withValues(alpha: 0.76)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.34),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.gold.withValues(alpha: 0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ActivePreviewFrame(generation: generation),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _StatusBadge(
                              label: statusTitle(text, generation),
                              icon: generationStatusIcon(generation),
                              color: statusColor,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              generation.templateTitle ??
                                  text.generationStatusResultTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: colors.textStrong,
                                    fontWeight: FontWeight.w900,
                                    height: 1.12,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                _MetaPill(
                                  icon: isVideoGeneration(generation)
                                      ? Icons.movie_creation_rounded
                                      : Icons.image_rounded,
                                  label: typeLabel(text, generation),
                                ),
                                _MetaPill(
                                  icon: Icons.bolt_rounded,
                                  label:
                                      '${generation.tokenCost} ${text.walletBalanceUnit}',
                                  color: colors.gold,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$progress%',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: colors.textStrong,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            etaLabel(text, generation),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: colors.textSoft,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PremiumProgressBar(value: progressValue, color: statusColor),
                  const SizedBox(height: 18),
                  _StageTimeline(generation: generation),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceStrong.withValues(alpha: 0.56),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.gold.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.cloud_done_outlined,
                            color: colors.gold,
                            size: 19,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              text.generationStatusBackgroundHint,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colors.textSoft,
                                    height: 1.35,
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
          ],
        ),
      ),
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
    const size = 104.0;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.gold.withValues(alpha: 0.32)),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (localPreviewFile != null)
                Image.file(
                  localPreviewFile,
                  fit: BoxFit.cover,
                  cacheWidth: 320,
                  filterQuality: FilterQuality.medium,
                )
              else if (previewUrl != null)
                CachedNetworkImage(
                  imageUrl: previewUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 320,
                  maxWidthDiskCache: 320,
                  filterQuality: FilterQuality.medium,
                  errorWidget: (context, url, error) =>
                      _ActivePreviewPlaceholder(label: text.imageLabel),
                )
              else
                _ActivePreviewPlaceholder(label: typeLabel(text, generation)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.62),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 9,
                bottom: 8,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: colors.gold,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
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
            colors.gold.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets_rounded, color: colors.gold, size: 28),
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
