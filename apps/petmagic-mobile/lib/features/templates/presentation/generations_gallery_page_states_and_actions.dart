part of 'generations_gallery_page.dart';

class _UnreadPill extends StatelessWidget {
  const _UnreadPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.accent.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text.generationStatusUnreadCount(count),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.accent,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return ColoredBox(
      color: colors.surfaceStrong,
      child: Icon(
        statusIcon(generation),
        color: statusColor(colors, generation),
      ),
    );
  }
}

class _GalleryMediaStateBanner extends StatelessWidget {
  const _GalleryMediaStateBanner({
    required this.generation,
    required this.message,
  });

  final TemplateGenerationResult generation;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isBlocking =
        generation.galleryMedia.state == GalleryMediaState.expired ||
        generation.galleryMedia.state == GalleryMediaState.storageUnavailable ||
        generation.galleryMedia.state == GalleryMediaState.failed;
    final accent = isBlocking ? colors.danger : colors.gold;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(galleryMediaStateIcon(generation), size: 14, color: accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textSoft,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final GenerationHistoryFilter filter;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final icon = switch (filter) {
      GenerationHistoryFilter.active => Icons.hourglass_empty_rounded,
      GenerationHistoryFilter.ready => Icons.collections_rounded,
      GenerationHistoryFilter.failed => Icons.error_outline_rounded,
      GenerationHistoryFilter.all => Icons.photo_library_outlined,
    };
    final message = filter == GenerationHistoryFilter.all
        ? text.generationStatusEmptyMessage
        : subtitleForFilter(text, filter);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceGlass,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border.withValues(alpha: 0.7)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Icon(icon, size: 34, color: colors.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            text.generationStatusEmptyTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final displayMessage = _galleryHistoryErrorText(text, message);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 42, color: colors.danger),
          const SizedBox(height: 12),
          Text(
            displayMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => ref
                .read(generationHistoryControllerProvider.notifier)
                .load(refresh: true),
            child: Text(text.retryAction),
          ),
        ],
      ),
    );
  }
}

String _galleryHistoryErrorText(AppLocalizations text, String raw) {
  final authMessage = mapCommonAuthFeedbackMessage(text, raw);
  if (authMessage != null) {
    return authMessage;
  }

  return switch (normalizeTemplateErrorKey(raw)) {
    'templates.connection_timeout' => text.templatesConnectionTimeoutError,
    'templates.server_timeout' => text.templatesServerTimeoutError,
    'templates.request_failed' => text.templatesRequestFailedError,
    _ => text.templatesRequestFailedError,
  };
}

class _OfflineCacheBanner extends ConsumerWidget {
  const _OfflineCacheBanner({
    required this.lastSyncedAtUtc,
    required this.isRecovered,
  });

  final DateTime? lastSyncedAtUtc;
  final bool isRecovered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    final syncedAtLabel = lastSyncedAtUtc == null
        ? null
        : (isRecovered
              ? text.generationStatusOnlineBannerSyncedAt(
                  formattedDate(
                    text,
                    lastSyncedAtUtc!,
                    Localizations.localeOf(context),
                  ),
                )
              : text.generationStatusOfflineBannerSyncedAt(
                  formattedDate(
                    text,
                    lastSyncedAtUtc!,
                    Localizations.localeOf(context),
                  ),
                ));

    final surfaceColor = isRecovered
        ? colors.accentSoft.withValues(alpha: 0.16)
        : colors.gold.withValues(alpha: 0.16);
    final borderColor = isRecovered
        ? colors.accent.withValues(alpha: 0.38)
        : colors.gold.withValues(alpha: 0.38);
    final iconColor = isRecovered ? colors.accent : colors.gold;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isRecovered ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: iconColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRecovered
                        ? text.generationStatusOnlineBannerTitle
                        : text.generationStatusOfflineBannerTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isRecovered
                        ? text.generationStatusOnlineBannerMessage
                        : text.generationStatusOfflineBannerMessage,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSoft,
                      height: 1.35,
                    ),
                  ),
                  if (syncedAtLabel != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      syncedAtLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isRecovered) ...[
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => ref
                    .read(generationHistoryControllerProvider.notifier)
                    .load(refresh: true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(text.retryAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isVideo = isVideoGeneration(generation);
    final background = isVideo
        ? colors.purple.withValues(alpha: 0.78)
        : colors.blue.withValues(alpha: 0.78);
    final foreground = colors.on(background);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          isVideo ? text.videoLabel : text.imageLabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.seconds});

  final double seconds;

  @override
  Widget build(BuildContext context) {
    final totalSeconds = seconds.round();
    final minutes = totalSeconds ~/ 60;
    final restSeconds = totalSeconds % 60;
    final label =
        '${minutes.toString().padLeft(2, '0')}:${restSeconds.toString().padLeft(2, '0')}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

Future<void> _showReadyCardActions(
  BuildContext context,
  AppLocalizations text,
  WidgetRef ref,
  TemplateGenerationResult generation,
  _GenerationsGalleryPageState galleryState,
) async {
  final colors = context.petMagicColors;
  final isMediaActionInFlight = galleryState._isMediaActionInFlight;
  final mediaMessage = galleryMediaStateMessage(text, generation);
  final canDownload =
      generation.galleryMedia.canDownload && !isMediaActionInFlight;
  final canShare = generation.galleryMedia.canShare && !isMediaActionInFlight;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final bottomInset = petMagicScrollableBottomInset(sheetContext);
      final maxSheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.8;
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset),
          child: Material(
            color: colors.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: colors.border.withValues(alpha: 0.85)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (generation.galleryMedia.needsExplanation &&
                        mediaMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: _GalleryMediaStateBanner(
                          generation: generation,
                          message: mediaMessage,
                        ),
                      ),
                    ListTile(
                      leading: const Icon(Icons.open_in_new_rounded),
                      title: Text(text.generationStatusOpenStatusAction),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        if (generation.isUnread) {
                          ref
                              .read(
                                generationHistoryControllerProvider.notifier,
                              )
                              .markRead(generation.generationId);
                        }
                        context.appNavigator.push(
                          GenerationDestination(generation.generationId),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.download_rounded),
                      title: Text(text.generationStatusSaveAction),
                      subtitle:
                          !generation.galleryMedia.canDownload &&
                              mediaMessage.isNotEmpty
                          ? Text(mediaMessage)
                          : null,
                      enabled: canDownload,
                      onTap: !canDownload
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              unawaited(
                                _saveGenerationToGallery(
                                  galleryState,
                                  text,
                                  ref,
                                  generation,
                                ),
                              );
                            },
                    ),
                    ListTile(
                      leading: const Icon(Icons.share_rounded),
                      title: Text(text.supportChatShareAction),
                      subtitle:
                          !generation.galleryMedia.canShare &&
                              mediaMessage.isNotEmpty
                          ? Text(mediaMessage)
                          : null,
                      enabled: canShare,
                      onTap: !canShare
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              unawaited(
                                _shareGenerationFile(
                                  galleryState,
                                  text,
                                  ref,
                                  generation,
                                ),
                              );
                            },
                    ),
                    ListTile(
                      leading: const Icon(Icons.link_rounded),
                      title: Text(text.generationStatusCopyLinkAction),
                      subtitle:
                          !generation.galleryMedia.canShare &&
                              mediaMessage.isNotEmpty
                          ? Text(mediaMessage)
                          : null,
                      enabled: canShare,
                      onTap: !canShare
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              unawaited(
                                _copyGenerationLink(
                                  galleryState,
                                  text,
                                  ref,
                                  generation,
                                ),
                              );
                            },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline_rounded),
                      title: Text(text.generationStatusDeleteAction),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(
                          _deleteGeneration(context, text, ref, generation),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(text.generationStatusReportProblemAction),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context.appNavigator.push(
                          SupportChatDestination(
                            initialMessage:
                                _buildGenerationProblemReportMessage(
                                  text,
                                  generation,
                                ),
                            relatedGenerationId: generation.generationId,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _showFailedCardActions(
  BuildContext context,
  AppLocalizations text,
  WidgetRef ref,
  TemplateGenerationResult generation,
) async {
  final colors = context.petMagicColors;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final bottomInset = petMagicScrollableBottomInset(sheetContext);
      final maxSheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.8;
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset),
          child: Material(
            color: colors.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: colors.border.withValues(alpha: 0.85)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.open_in_new_rounded),
                      title: Text(text.generationStatusOpenStatusAction),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        if (generation.isUnread) {
                          ref
                              .read(
                                generationHistoryControllerProvider.notifier,
                              )
                              .markRead(generation.generationId);
                        }
                        context.appNavigator.push(
                          GenerationDestination(generation.generationId),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.image_search_rounded),
                      title: Text(text.generationStatusPickAnotherPhotoAction),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context.appNavigator.go(
                          _templatesDestinationForGeneration(generation),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.support_agent_rounded),
                      title: Text(text.generationStatusContactSupportAction),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context.appNavigator.push(
                          SupportChatDestination(
                            initialMessage:
                                _buildGenerationProblemReportMessage(
                                  text,
                                  generation,
                                ),
                            relatedGenerationId: generation.generationId,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _saveGenerationToGallery(
  _GenerationsGalleryPageState galleryState,
  AppLocalizations text,
  WidgetRef ref,
  TemplateGenerationResult generation,
) async {
  final mediaActionCancelToken = galleryState._startMediaAction();
  if (mediaActionCancelToken == null) {
    return;
  }
  final context = galleryState.context;

  final localOutputPath = await usableLocalMediaPath(
    generation.localOutputPath,
  );
  if (!context.mounted) {
    galleryState._completeMediaAction(mediaActionCancelToken);
    return;
  }
  final access = await _fetchGenerationMediaAccess(
    context: context,
    text: text,
    ref: ref,
    generationId: generation.generationId,
    cancelToken: mediaActionCancelToken,
    forShare: false,
  );
  if (access == null) {
    galleryState._completeMediaAction(mediaActionCancelToken);
    return;
  }
  if (!context.mounted) {
    galleryState._completeMediaAction(mediaActionCancelToken);
    return;
  }

  final safeOutputUri = parseSafeGenerationMediaUri(access.mediaUrl);
  if (safeOutputUri == null && localOutputPath == null) {
    _notifySoon(context, text.generationStatusResultUnavailableForSave);
    galleryState._completeMediaAction(mediaActionCancelToken);
    return;
  }
  final safeOutputUrl = safeOutputUri?.toString() ?? '';

  final fileName = access.fileName.isEmpty
      ? _buildGenerationFileName(
          generation,
          safeOutputUrl.isEmpty ? localOutputPath ?? '' : safeOutputUrl,
        )
      : access.fileName;
  try {
    final wasSaved = await ref
        .read(generationStatusMediaActionsProvider)
        .saveToGallery(
          mediaUrl: safeOutputUrl,
          fileName: fileName,
          isVideo: isVideoGeneration(generation),
          albumName: 'PetMagic',
          cancelToken: mediaActionCancelToken,
          localPath: localOutputPath,
        );

    if (!context.mounted) {
      return;
    }

    if (!wasSaved) {
      _notifySoon(context, text.generationStatusFileSaveFailedMessage);
      return;
    }

    _notifySoon(context, text.generationStatusSavedToGalleryMessage);
  } on RequestCancelledException {
    return;
  } on Object {
    if (!context.mounted) {
      return;
    }

    _notifySoon(context, text.generationStatusFileSaveFailedMessage);
  } finally {
    galleryState._completeMediaAction(mediaActionCancelToken);
  }
}

Future<void> _shareGenerationFile(
  _GenerationsGalleryPageState galleryState,
  AppLocalizations text,
  WidgetRef ref,
  TemplateGenerationResult generation,
) async {
  final mediaActionCancelToken = galleryState._startMediaAction();
  if (mediaActionCancelToken == null) {
    return;
  }
  final context = galleryState.context;

  final localOutputPath = await usableLocalMediaPath(
    generation.localOutputPath,
  );
  if (!context.mounted) {
    galleryState._completeMediaAction(mediaActionCancelToken);
    return;
  }
  final access = await _fetchGenerationMediaAccess(
    context: context,
    text: text,
    ref: ref,
    generationId: generation.generationId,
    cancelToken: mediaActionCancelToken,
    forShare: true,
  );
  if (access == null) {
    galleryState._completeMediaAction(mediaActionCancelToken);
    return;
  }
  if (!context.mounted) {
    galleryState._completeMediaAction(mediaActionCancelToken);
    return;
  }

  final safeShareUri = parseSafeGenerationShareUri(access.shareUrl);
  if (safeShareUri == null) {
    _notifySoon(context, text.generationStatusResultUnavailableForShare);
    galleryState._completeMediaAction(mediaActionCancelToken);
    return;
  }
  final safeOutputUri = parseSafeGenerationMediaUri(access.mediaUrl);
  if (safeOutputUri == null && localOutputPath == null) {
    _notifySoon(context, text.generationStatusResultUnavailableForShare);
    galleryState._completeMediaAction(mediaActionCancelToken);
    return;
  }
  final safeOutputUrl = safeOutputUri?.toString() ?? '';
  final fileName = access.fileName.isEmpty
      ? _buildGenerationFileName(
          generation,
          safeOutputUrl.isEmpty ? localOutputPath ?? '' : safeOutputUrl,
        )
      : access.fileName;

  try {
    await ref
        .read(generationStatusMediaActionsProvider)
        .share(
          mediaUrl: safeOutputUrl,
          fileName: fileName,
          title: generation.templateTitle ?? text.generationStatusResultTitle,
          cancelToken: mediaActionCancelToken,
          shareText: safeShareUri.toString(),
          localPath: localOutputPath,
        );
  } on RequestCancelledException {
    return;
  } on Object {
    if (!context.mounted) {
      return;
    }

    _notifySoon(context, text.generationStatusShareFailedMessage);
  } finally {
    galleryState._completeMediaAction(mediaActionCancelToken);
  }
}

Future<void> _copyGenerationLink(
  _GenerationsGalleryPageState galleryState,
  AppLocalizations text,
  WidgetRef ref,
  TemplateGenerationResult generation,
) async {
  final mediaActionCancelToken = galleryState._startMediaAction();
  if (mediaActionCancelToken == null) {
    return;
  }
  final context = galleryState.context;

  final access = await _fetchGenerationMediaAccess(
    context: context,
    text: text,
    ref: ref,
    generationId: generation.generationId,
    cancelToken: mediaActionCancelToken,
    forShare: true,
  );
  if (access == null) {
    galleryState._completeMediaAction(mediaActionCancelToken);
    return;
  }
  if (!context.mounted) {
    galleryState._completeMediaAction(mediaActionCancelToken);
    return;
  }

  final safeUri = parseSafeGenerationShareUri(access.shareUrl);
  if (safeUri == null) {
    _notifySoon(context, text.generationStatusResultUnavailableForShare);
    galleryState._completeMediaAction(mediaActionCancelToken);
    return;
  }

  try {
    await Clipboard.setData(ClipboardData(text: safeUri.toString()));
  } on Object {
    galleryState._completeMediaAction(mediaActionCancelToken);
    if (!context.mounted) {
      return;
    }
    _notifySoon(context, text.generationStatusShareFailedMessage);
    return;
  }

  if (!context.mounted) {
    galleryState._completeMediaAction(mediaActionCancelToken);
    return;
  }
  galleryState._completeMediaAction(mediaActionCancelToken);
  _notifySoon(context, text.generationStatusLinkCopiedMessage);
}

Future<GenerationMediaAccessResult?> _fetchGenerationMediaAccess({
  required BuildContext context,
  required AppLocalizations text,
  required WidgetRef ref,
  required String generationId,
  required RequestCancellation cancelToken,
  required bool forShare,
}) async {
  try {
    final repository = ref.read(templateGenerationRepositoryProvider);
    return forShare
        ? await repository.fetchShareUrl(generationId, cancelToken: cancelToken)
        : await repository.fetchDownloadUrl(
            generationId,
            cancelToken: cancelToken,
          );
  } on RequestCancelledException {
    return null;
  } on Object {
    if (!context.mounted) {
      return null;
    }

    _notifySoon(
      context,
      forShare
          ? text.generationStatusShareFailedMessage
          : text.generationStatusFileSaveFailedMessage,
    );
    return null;
  }
}

Future<void> _deleteGeneration(
  BuildContext context,
  AppLocalizations text,
  WidgetRef ref,
  TemplateGenerationResult generation,
) async {
  try {
    await ref
        .read(generationHistoryControllerProvider.notifier)
        .deleteGeneration(generation.generationId);

    if (!context.mounted) {
      return;
    }

    _notifySoon(context, text.generationStatusDeletedMessage);
  } on Object {
    if (!context.mounted) {
      return;
    }

    _notifySoon(context, text.generationStatusDeleteFailedMessage);
  }
}

String _buildGenerationFileName(
  TemplateGenerationResult generation,
  String outputUrl,
) {
  final normalizedTitle = sanitizeFileName(
    generation.templateTitle,
    fallback: 'petmagic_result',
  );
  final normalizedGenerationId = sanitizeFileName(
    generation.generationId,
    fallback: 'generation',
  );
  final extensionFromRemote = extensionFromUrl(outputUrl);
  final extension = extensionFromRemote.isEmpty
      ? (isVideoGeneration(generation) ? 'mp4' : 'jpg')
      : extensionFromRemote;
  return '${normalizedTitle}_$normalizedGenerationId.$extension';
}

String _buildGenerationProblemReportMessage(
  AppLocalizations text,
  TemplateGenerationResult generation,
) {
  final title = generation.templateTitle?.trim().isNotEmpty == true
      ? generation.templateTitle!.trim()
      : text.generationStatusUntitledFallback;
  final type = isVideoGeneration(generation)
      ? text.videoLabel
      : text.imageLabel;
  final lines = <String>[
    text.generationStatusReportProblemAction,
    '${text.supportTicketFormRelatedGenerationLabel}: ${generation.generationId}',
    '${text.generationStatusDetailsTitle}: $title',
    '${text.generationStatusTypeLabel}: $type',
    '${text.generationStatusTitle}: ${statusTitle(text, generation)}',
  ];
  return lines.join('\n');
}

void _notifySoon(BuildContext context, String message) {
  PetMagicToast.show(context, message: message, tone: PetMagicToastTone.info);
}
