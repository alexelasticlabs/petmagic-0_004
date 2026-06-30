part of 'petmagic_shell.dart';

class _ActiveGenerationBannerSlot extends ConsumerWidget {
  const _ActiveGenerationBannerSlot({
    required this.location,
    required this.dismissedGenerationId,
    required this.onDismiss,
  });

  final String location;
  final String? dismissedGenerationId;
  final ValueChanged<String> onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGeneration = ref.watch(
      generationHistoryControllerProvider.select(
        (state) => state.activeGeneration,
      ),
    );

    if (activeGeneration == null ||
        activeGeneration.isTerminal ||
        dismissedGenerationId == activeGeneration.generationId ||
        location == GenerationsGalleryPage.routePath ||
        location.startsWith(GenerationStatusPage.routePrefix)) {
      return const SizedBox.shrink();
    }

    return _ActiveGenerationBanner(
      generation: activeGeneration,
      onDismiss: () => onDismiss(activeGeneration.generationId),
    );
  }
}

class _ActiveGenerationBanner extends StatelessWidget {
  const _ActiveGenerationBanner({
    required this.generation,
    required this.onDismiss,
  });

  final TemplateGenerationResult generation;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final previewUrl = parseSafeGenerationMediaUri(
      generation.sourceImageAsset?.url,
    )?.toString();
    final progress = generation.effectiveProgressPercent;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          bottomPadding + _bottomNavOuterGap + _bottomNavHeight + 10,
        ),
        child: PressableScale(
          borderRadius: BorderRadius.circular(16),
          haptic: PressableScaleHaptic.selection,
          onTap: () => context.push(
            GenerationStatusPage.routeFor(generation.generationId),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceGlass.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.accent.withValues(alpha: isLight ? 0.36 : 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: previewUrl == null || previewUrl.isEmpty
                              ? ColoredBox(
                                  color: colors.surfaceStrong,
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 18,
                                    color: colors.accent,
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: previewUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth:
                                      _activeGenerationThumbnailCacheWidth,
                                  maxWidthDiskCache:
                                      _activeGenerationThumbnailCacheWidth,
                                  filterQuality: FilterQuality.medium,
                                  errorWidget: (context, url, error) =>
                                      ColoredBox(
                                        color: colors.surfaceStrong,
                                        child: Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 18,
                                          color: colors.accent,
                                        ),
                                      ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              generation.templateTitle ??
                                  text.shellActiveGenerationFallback,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: colors.textStrong,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              text.templateFlowStepCreateMagic,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colors.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 42,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            value: progress / 100,
                            color: colors.accent,
                            backgroundColor: colors.border.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$progress%',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: onDismiss,
                        icon: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
