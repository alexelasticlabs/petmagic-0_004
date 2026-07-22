part of 'generations_gallery_page.dart';

const int _generationGalleryThumbnailCacheWidth = 320;

File? _localMediaFile(String? path) {
  final usablePath = usableLocalMediaPathSync(path);
  if (usablePath == null) {
    return null;
  }
  return File(usablePath);
}

class _ActiveCard extends ConsumerWidget {
  const _ActiveCard({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final previewImageUrl = previewUrl(generation);
    final safePreviewImageUrl = parseSafeGenerationMediaUri(
      previewImageUrl,
    )?.toString();
    final canRenderPreview = canRenderImagePreview(safePreviewImageUrl);
    final localPreviewFile = _localMediaFile(generation.localPreviewPath);

    void openGeneration() {
      if (generation.isUnread) {
        ref
            .read(generationHistoryControllerProvider.notifier)
            .markRead(generation.generationId);
      }
      context.appNavigator.push(GenerationDestination(generation.generationId));
    }

    return _CardEntrance(
      child: RepaintBoundary(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: openGeneration,
          child: Ink(
            decoration: BoxDecoration(
              color: colors.surfaceGlass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: generation.isUnread
                    ? colors.accent.withValues(alpha: 0.7)
                    : colors.border.withValues(alpha: 0.7),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.16),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: localPreviewFile != null
                                ? Image.file(
                                    localPreviewFile,
                                    fit: BoxFit.cover,
                                    cacheWidth:
                                        _generationGalleryThumbnailCacheWidth,
                                    filterQuality: FilterQuality.medium,
                                  )
                                : !canRenderPreview
                                ? _ThumbnailPlaceholder(generation: generation)
                                : CachedNetworkImage(
                                    imageUrl: safePreviewImageUrl!,
                                    cacheKey: persistentSafeGenerationMediaUrl(
                                      safePreviewImageUrl.toString(),
                                    ),
                                    fit: BoxFit.cover,
                                    memCacheWidth:
                                        _generationGalleryThumbnailCacheWidth,
                                    maxWidthDiskCache:
                                        _generationGalleryThumbnailCacheWidth,
                                    filterQuality: FilterQuality.medium,
                                    errorWidget: (context, url, error) =>
                                        _ThumbnailPlaceholder(
                                          generation: generation,
                                        ),
                                  ),
                          ),
                        ),
                        Positioned(
                          left: 6,
                          top: 6,
                          child: _TypeBadge(generation: generation),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                generation.templateTitle ??
                                    text.generationStatusResultTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: colors.textStrong,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Tooltip(
                              message: text.generationStatusOpenStatusAction,
                              child: InkResponse(
                                radius: 18,
                                onTap: openGeneration,
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: Icon(
                                    Icons.open_in_new_rounded,
                                    size: 17,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${typeLabel(text, generation)} · ${generation.tokenCost} ${text.walletBalanceUnit}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Flexible(
                              child: _StatusPill(
                                label: stageStatusLabel(text, generation),
                                generation: generation,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                estimatedTimeLabel(text, generation),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colors.textSoft,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: _AnimatedGenerationProgress(
                                  value:
                                      generation.effectiveProgressPercent / 100,
                                  colors: colors,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${generation.effectiveProgressPercent}%',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: colors.accent,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _ReadyGridCard extends ConsumerWidget {
  const _ReadyGridCard({required this.generation, required this.galleryState});

  final TemplateGenerationResult generation;
  final _GenerationsGalleryPageState galleryState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final previewImageUrl = previewUrl(generation);
    final safePreviewImageUrl = parseSafeGenerationMediaUri(
      previewImageUrl,
    )?.toString();
    final canRenderPreview = canRenderImagePreview(safePreviewImageUrl);
    final localPreviewFile = _localMediaFile(generation.localPreviewPath);
    final mediaMessage = galleryMediaStateMessage(text, generation);

    void openGeneration() {
      if (generation.isUnread) {
        unawaited(
          ref
              .read(generationHistoryControllerProvider.notifier)
              .markRead(generation.generationId),
        );
      }
      context.appNavigator.push(GenerationDestination(generation.generationId));
    }

    return _CardEntrance(
      child: RepaintBoundary(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: openGeneration,
          child: Ink(
            decoration: BoxDecoration(
              color: colors.surfaceGlass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border.withValues(alpha: 0.7)),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.14),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: localPreviewFile != null
                              ? Image.file(
                                  localPreviewFile,
                                  fit: BoxFit.cover,
                                  cacheWidth:
                                      _generationGalleryThumbnailCacheWidth,
                                  filterQuality: FilterQuality.medium,
                                )
                              : !canRenderPreview
                              ? _ThumbnailPlaceholder(generation: generation)
                              : CachedNetworkImage(
                                  imageUrl: safePreviewImageUrl!,
                                  cacheKey: persistentSafeGenerationMediaUrl(
                                    safePreviewImageUrl.toString(),
                                  ),
                                  fit: BoxFit.cover,
                                  memCacheWidth:
                                      _generationGalleryThumbnailCacheWidth,
                                  maxWidthDiskCache:
                                      _generationGalleryThumbnailCacheWidth,
                                  filterQuality: FilterQuality.medium,
                                  errorWidget: (context, url, error) =>
                                      _ThumbnailPlaceholder(
                                        generation: generation,
                                      ),
                                ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _TypeBadge(generation: generation),
                      ),
                      if (isVideoGeneration(generation) &&
                          generation.outputVideoDurationSeconds != null)
                        Positioned(
                          left: 8,
                          top: 34,
                          child: _DurationBadge(
                            seconds: generation.outputVideoDurationSeconds!,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 8, 6, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              generation.templateTitle ??
                                  text.generationStatusResultTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: colors.textStrong,
                                    fontWeight: FontWeight.w900,
                                    height: 1.15,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${typeLabel(text, generation)} · ${generation.tokenCost} ${text.walletBalanceUnit}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: colors.textSoft,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formattedDate(
                                text,
                                generation.updatedAtUtc,
                                Localizations.localeOf(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (generation.galleryMedia.needsExplanation &&
                                mediaMessage.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _GalleryMediaStateBanner(
                                generation: generation,
                                message: mediaMessage,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showReadyCardActions(
                          context,
                          text,
                          ref,
                          generation,
                          galleryState,
                        ),
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
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
