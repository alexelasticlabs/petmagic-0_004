part of 'generation_result_input_page.dart';

class _ParentPreviewCard extends StatelessWidget {
  const _ParentPreviewCard({required this.generation, required this.copy});

  final TemplateGenerationResult generation;
  final _GenerationResultInputCopy copy;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final mediaUrl = parseSafeGenerationMediaUri(generation.outputUrl ?? '');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.75)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: mediaUrl == null
                    ? ColoredBox(
                        color: colors.surfaceStrong,
                        child: Center(child: Text(copy.mediaUnavailable)),
                      )
                    : CachedNetworkImage(
                        imageUrl: mediaUrl.toString(),
                        cacheKey: persistentSafeGenerationMediaUrl(
                          mediaUrl.toString(),
                        ),
                        fit: BoxFit.cover,
                        memCacheWidth: _parentPreviewCacheWidth,
                        maxWidthDiskCache: _parentPreviewCacheWidth,
                        filterQuality: FilterQuality.medium,
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              generation.templateTitle ?? copy.parentTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              copy.parentHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSoft,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompatibleTemplateTile extends StatelessWidget {
  const _CompatibleTemplateTile({
    required this.template,
    required this.isBusy,
    required this.copy,
    required this.onTap,
  });

  final CompatibleGenerationTemplate template;
  final bool isBusy;
  final _GenerationResultInputCopy copy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final safeThumb = parseSafeGenerationMediaUri(template.thumbnailUrl ?? '');
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 74,
                  height: 111,
                  child: safeThumb == null
                      ? ColoredBox(
                          color: colors.surfaceStrong,
                          child: Icon(
                            template.isVideo
                                ? Icons.movie_creation_rounded
                                : Icons.image_rounded,
                            color: colors.textMuted,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: safeThumb.toString(),
                          cacheKey: persistentSafeGenerationMediaUrl(
                            safeThumb.toString(),
                          ),
                          fit: BoxFit.cover,
                          memCacheWidth: _compatibleTemplateThumbnailCacheWidth,
                          maxWidthDiskCache:
                              _compatibleTemplateThumbnailCacheWidth,
                          filterQuality: FilterQuality.medium,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          template.isVideo
                              ? Icons.play_circle_rounded
                              : Icons.auto_awesome_rounded,
                          size: 16,
                          color: colors.accent,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            template.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: colors.textStrong,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniBadge(
                          label: template.isVideo ? copy.video : copy.image,
                        ),
                        if (template.isRecommended)
                          _MiniBadge(label: copy.recommended),
                        if (template.isPremium)
                          _MiniBadge(label: text.premiumLabel),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${template.tokenCost} ${text.walletBalanceUnit}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultInputErrorCard extends StatelessWidget {
  const _ResultInputErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.75)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: TextStyle(color: colors.textSoft)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => unawaited(onRetry()),
              child: Text(text.retryAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerationResultInputCopy {
  const _GenerationResultInputCopy({
    required this.title,
    required this.parentTitle,
    required this.parentHint,
    required this.mediaUnavailable,
    required this.all,
    required this.image,
    required this.video,
    required this.recommended,
    required this.empty,
    required this.error,
    required this.noCredits,
    required this.start,
    required this.costBuilder,
  });

  final String title;
  final String parentTitle;
  final String parentHint;
  final String mediaUnavailable;
  final String all;
  final String image;
  final String video;
  final String recommended;
  final String empty;
  final String error;
  final String noCredits;
  final String start;
  final String Function(int credits) costBuilder;

  String cost(int credits) => costBuilder(credits);

  static _GenerationResultInputCopy forLocale(AppLocalizations text) {
    return _GenerationResultInputCopy(
      title: text.generationResultInputTitle,
      parentTitle: text.generationResultInputParentTitle,
      parentHint: text.generationResultInputParentHint,
      mediaUnavailable: text.generationResultInputMediaUnavailable,
      all: text.allFilter,
      image: text.imageLabel,
      video: text.videoLabel,
      recommended: text.generationResultInputRecommendedBadge,
      empty: text.generationResultInputEmpty,
      error: text.generationResultInputError,
      noCredits: text.generationResultInputNoCredits,
      start: text.generationResultInputStartAction,
      costBuilder: text.generationResultInputCostEstimate,
    );
  }
}
