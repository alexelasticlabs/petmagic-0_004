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
      context.push(GenerationStatusPage.routeFor(generation.generationId));
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
                          '${typeLabel(text, generation)} · ${generation.tokenCost} PawSpark',
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.generation});

  final String label;
  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final tint = statusColor(colors, generation);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: tint,
            fontWeight: FontWeight.w900,
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

    void openGeneration() {
      if (generation.isUnread) {
        unawaited(
          ref
              .read(generationHistoryControllerProvider.notifier)
              .markRead(generation.generationId),
        );
      }
      context.push(GenerationStatusPage.routeFor(generation.generationId));
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
                              '${typeLabel(text, generation)} · ${generation.tokenCost} PawSpark',
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
                              formattedDate(text, generation.updatedAtUtc),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
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

class _FailedCard extends ConsumerWidget {
  const _FailedCard({required this.generation});

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
    final failureReason = failureReasonMessage(text, generation);

    void openGeneration() {
      if (generation.isUnread) {
        ref
            .read(generationHistoryControllerProvider.notifier)
            .markRead(generation.generationId);
      }
      context.push(GenerationStatusPage.routeFor(generation.generationId));
    }

    void pickAnotherPhoto() {
      context.go(_templatesLocationForGeneration(generation));
    }

    void openSupport() {
      context.push(
        SupportChatPage.routeFor(
          initialMessage: _buildGenerationProblemReportMessage(
            text,
            generation,
          ),
          relatedGenerationId: generation.generationId,
        ),
      );
    }

    return _CardEntrance(
      child: RepaintBoundary(
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surfaceGlass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.14),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: localPreviewFile != null
                                  ? Image.file(
                                      localPreviewFile,
                                      fit: BoxFit.cover,
                                      cacheWidth:
                                          _generationGalleryThumbnailCacheWidth,
                                      filterQuality: FilterQuality.medium,
                                    )
                                  : !canRenderPreview
                                  ? _ThumbnailPlaceholder(
                                      generation: generation,
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: safePreviewImageUrl!,
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            generation.templateTitle ??
                                text.generationStatusResultTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: colors.textStrong,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${typeLabel(text, generation)} · ${generation.tokenCost} PawSpark',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: colors.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            text.generationStatusFailedTitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.danger,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if (generation.refundedAtUtc != null ||
                              generation.tokenCost > 0)
                            Text(
                              text.generationStatusTokensRefundedShort,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: colors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showFailedCardActions(
                        context,
                        text,
                        ref,
                        generation,
                      ),
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceStrong.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: colors.gold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            failureReason,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: colors.textSoft,
                                  height: 1.25,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: pickAnotherPhoto,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.backgroundBottom,
                  ),
                  child: Text(text.generationStatusPickAnotherPhotoAction),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: openSupport,
                  child: Text(text.generationStatusContactSupportAction),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: openGeneration,
                    child: Text(text.generationStatusOpenStatusAction),
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

class _AnimatedGenerationProgress extends StatefulWidget {
  const _AnimatedGenerationProgress({
    required this.value,
    required this.colors,
  });

  final double value;
  final PetMagicColors colors;

  @override
  State<_AnimatedGenerationProgress> createState() =>
      _AnimatedGenerationProgressState();
}

class _AnimatedGenerationProgressState
    extends State<_AnimatedGenerationProgress> {
  late double _previous;

  @override
  void initState() {
    super.initState();
    _previous = widget.value.clamp(0, 1).toDouble();
  }

  @override
  void didUpdateWidget(covariant _AnimatedGenerationProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previous = oldWidget.value.clamp(0, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final next = widget.value.clamp(0, 1).toDouble();

    LinearProgressIndicator progressBar(double value) {
      return LinearProgressIndicator(
        minHeight: 5,
        value: value,
        color: widget.colors.accent,
        backgroundColor: widget.colors.border.withValues(alpha: 0.55),
      );
    }

    if (PerformanceGuard.isDegradedMode(context) ||
        PetMotion.reduceMotion(context)) {
      return progressBar(next);
    }

    return TweenAnimationBuilder<double>(
      duration: PetMotion.effectiveDuration(context, PetMotion.medium),
      curve: PetMotion.standard,
      tween: Tween<double>(begin: _previous, end: next),
      builder: (context, value, _) => progressBar(value),
    );
  }
}

class _CardEntrance extends StatelessWidget {
  const _CardEntrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (PerformanceGuard.isDegradedMode(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.92, end: 1),
      child: child,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.96 + (0.04 * value),
            child: animatedChild,
          ),
        );
      },
    );
  }
}
