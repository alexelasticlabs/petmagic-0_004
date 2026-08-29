part of 'generation_status_page.dart';

const double _templateRecommendationCardWidth = 136;
const int _templateRecommendationThumbnailCacheWidth = 320;

class _ContinueWithResultSection extends StatelessWidget {
  const _ContinueWithResultSection({
    required this.templates,
    required this.onTemplateSelected,
    required this.onShowAll,
  });

  final List<CompatibleGenerationTemplate> templates;
  final ValueChanged<CompatibleGenerationTemplate> onTemplateSelected;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    if (templates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                text.generationStatusContinueWithResultTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onShowAll,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(text.generationStatusAllTemplatesAction),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 278,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(right: 32),
            itemCount: templates.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _TemplateRecommendationCard(
              template: templates[index],
              onTap: () => onTemplateSelected(templates[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _TemplateRecommendationCard extends StatelessWidget {
  const _TemplateRecommendationCard({
    required this.template,
    required this.onTap,
  });

  final CompatibleGenerationTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final previewUri = parseSafeGenerationMediaUri(template.thumbnailUrl ?? '');
    final previewRadius = BorderRadius.circular(15);
    final typeLabel = template.isVideo ? text.videoLabel : text.imageLabel;

    return SizedBox(
      width: _templateRecommendationCardWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: previewRadius,
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        previewUri == null
                            ? ColoredBox(
                                color: colors.surfaceStrong,
                                child: Center(
                                  child: Icon(
                                    template.isVideo
                                        ? Icons.play_circle_fill_rounded
                                        : Icons.image_rounded,
                                    color: colors.textMuted,
                                  ),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: previewUri.toString(),
                                cacheKey: persistentSafeGenerationMediaUrl(
                                  previewUri.toString(),
                                ),
                                fit: BoxFit.cover,
                                memCacheWidth:
                                    _templateRecommendationThumbnailCacheWidth,
                                maxWidthDiskCache:
                                    _templateRecommendationThumbnailCacheWidth,
                                filterQuality: FilterQuality.medium,
                                errorWidget: (context, url, error) =>
                                    ColoredBox(
                                      color: colors.surfaceStrong,
                                      child: Icon(
                                        template.isVideo
                                            ? Icons.play_circle_fill_rounded
                                            : Icons.image_rounded,
                                        color: colors.textMuted,
                                      ),
                                    ),
                              ),
                        Positioned(
                          top: 7,
                          left: 7,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.62),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    template.isVideo
                                        ? Icons.play_arrow_rounded
                                        : Icons.image_outlined,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    typeLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (template.isPremium)
                          Positioned(
                            top: 7,
                            right: 7,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.accent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 4,
                                ),
                                child: Text(
                                  text.premiumLabel,
                                  style: TextStyle(
                                    color: colors.backgroundBottom,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  template.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  template.isPremium
                      ? text.premiumLabel
                      : '${template.tokenCost} ${text.walletBalanceUnit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${text.generationStatusTryTemplateAction} →',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w800,
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
