part of 'generations_gallery_page.dart';

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
      context.appNavigator.push(GenerationDestination(generation.generationId));
    }

    void pickAnotherPhoto() {
      context.appNavigator.go(_templatesDestinationForGeneration(generation));
    }

    void openSupport() {
      context.appNavigator.push(
        SupportChatDestination(
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
                                      cacheKey:
                                          persistentSafeGenerationMediaUrl(
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
                            '${typeLabel(text, generation)} · ${generation.tokenCost} ${text.walletBalanceUnit}',
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
