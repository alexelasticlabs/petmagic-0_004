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

    void retryGeneration() {
      _notifySoon(context, text.generationStatusRetrySoonMessage);
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
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.border.withValues(alpha: 0.45)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.surfaceStrong,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: localPreviewFile != null
                                    ? Image.file(
                                        localPreviewFile,
                                        fit: BoxFit.contain,
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
                                        fit: BoxFit.contain,
                                        memCacheWidth:
                                            _generationGalleryThumbnailCacheWidth,
                                        maxWidthDiskCache:
                                            _generationGalleryThumbnailCacheWidth,
                                        filterQuality: FilterQuality.medium,
                                        fadeInDuration: Duration.zero,
                                        placeholderFadeInDuration:
                                            Duration.zero,
                                        placeholder: (context, url) =>
                                            _ThumbnailPlaceholder(
                                              generation: generation,
                                            ),
                                        errorWidget: (context, url, error) =>
                                            _ThumbnailPlaceholder(
                                              generation: generation,
                                            ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 120,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    generation.templateTitle ??
                                        text.generationStatusResultTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: colors.textStrong,
                                          fontWeight: FontWeight.w900,
                                          height: 1.12,
                                        ),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
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
                            const SizedBox(height: 4),
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
                            const Spacer(),
                            _FailedGenerationStatusLine(
                              icon: Icons.error_outline_rounded,
                              label: text.generationStatusTechnicalError,
                              color: colors.danger,
                            ),
                            if (_shouldShowRefundStatus(generation)) ...[
                              const SizedBox(height: 7),
                              _FailedGenerationStatusLine(
                                icon: _refundStatusIcon(generation),
                                label: _refundStatusLabel(text, generation),
                                color: _refundStatusColor(colors, generation),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  color: colors.border.withValues(alpha: 0.45),
                  height: 1,
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: retryGeneration,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: colors.accent,
                    foregroundColor: colors.backgroundBottom,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.refresh_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(text.generationStatusRetryAction),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: pickAnotherPhoto,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textSoft,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(text.generationStatusPickAnotherPhotoAction),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Divider(
                  color: colors.border.withValues(alpha: 0.45),
                  height: 1,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: openGeneration,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.textSoft,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text(
                            text.generationStatusDetailsTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: openSupport,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.textSoft,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(text.generationStatusSupportShortAction),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _shouldShowRefundStatus(TemplateGenerationResult generation) =>
    generation.tokenCost > 0 &&
    (generation.refundedAtUtc != null ||
        generation.refundState == 'refunded' ||
        generation.refundState == 'pending' ||
        generation.refundState == 'failed');

String _refundStatusLabel(
  AppLocalizations text,
  TemplateGenerationResult generation,
) {
  return switch (generation.refundState) {
    'pending' => text.generationStatusRefundPending,
    'failed' => text.generationStatusRefundFailed,
    _ => text.generationStatusRefundedBalance(generation.tokenCost),
  };
}

IconData _refundStatusIcon(TemplateGenerationResult generation) {
  return switch (generation.refundState) {
    'pending' => Icons.schedule_rounded,
    'failed' => Icons.error_outline_rounded,
    _ => Icons.check_rounded,
  };
}

Color _refundStatusColor(
  PetMagicColors colors,
  TemplateGenerationResult generation,
) {
  return switch (generation.refundState) {
    'failed' => colors.danger,
    'pending' => colors.textMuted,
    _ => colors.accent,
  };
}

class _FailedGenerationStatusLine extends StatelessWidget {
  const _FailedGenerationStatusLine({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
