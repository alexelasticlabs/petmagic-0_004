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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 42, color: colors.textMuted),
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
            text.generationStatusEmptyMessage,
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 42, color: colors.danger),
          const SizedBox(height: 12),
          Text(
            message,
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
            color: Colors.white,
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
) async {
  final colors = context.petMagicColors;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: colors.surface,
    builder: (sheetContext) {
      return SafeArea(
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
                      .read(generationHistoryControllerProvider.notifier)
                      .markRead(generation.generationId);
                }
                context.go(
                  '${GenerationStatusPage.routePrefix}/${generation.generationId}',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: Text(text.generationStatusSaveAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_saveGenerationToGallery(context, text, generation));
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: Text(text.supportChatShareAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_shareGenerationFile(context, text, generation));
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Copy link'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_copyGenerationLink(context, text, generation));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(text.generationStatusDeleteAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_deleteGeneration(context, text, ref, generation));
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(text.generationStatusReportProblemAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(SupportChatPage.routePath);
              },
            ),
          ],
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
    showDragHandle: true,
    backgroundColor: colors.surface,
    builder: (sheetContext) {
      return SafeArea(
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
                      .read(generationHistoryControllerProvider.notifier)
                      .markRead(generation.generationId);
                }
                context.go(
                  '${GenerationStatusPage.routePrefix}/${generation.generationId}',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_search_rounded),
              title: Text(text.generationStatusPickAnotherPhotoAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(TemplatesPage.routePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_rounded),
              title: Text(text.generationStatusContactSupportAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(SupportChatPage.routePath);
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _saveGenerationToGallery(
  BuildContext context,
  AppLocalizations text,
  TemplateGenerationResult generation,
) async {
  final outputUrl = generation.outputUrl;
  if (outputUrl == null || outputUrl.isEmpty) {
    _notifySoon(context, text.generationStatusResultUnavailableForSave);
    return;
  }

  final fileName = _buildGenerationFileName(generation, outputUrl);
  try {
    final wasSaved = await saveRemoteMediaToGallery(
      mediaUrl: outputUrl,
      fileName: fileName,
      isVideo: isVideoGeneration(generation),
      albumName: 'PetMagic',
    );

    if (!context.mounted) {
      return;
    }

    if (!wasSaved) {
      _notifySoon(context, text.generationStatusFileSaveFailedMessage);
      return;
    }

    _notifySoon(context, text.generationStatusSavedToGalleryMessage);
  } on Object {
    if (!context.mounted) {
      return;
    }

    _notifySoon(context, text.generationStatusFileSaveFailedMessage);
  }
}

Future<void> _shareGenerationFile(
  BuildContext context,
  AppLocalizations text,
  TemplateGenerationResult generation,
) async {
  final outputUrl = generation.outputUrl;
  if (outputUrl == null || outputUrl.isEmpty) {
    _notifySoon(context, text.generationStatusResultUnavailableForShare);
    return;
  }

  try {
    await shareRemoteMediaFile(
      mediaUrl: outputUrl,
      fileName: _buildGenerationFileName(generation, outputUrl),
      title: generation.templateTitle ?? text.generationStatusResultTitle,
    );
  } on Object {
    if (!context.mounted) {
      return;
    }

    _notifySoon(context, 'Failed to share result. Please try again.');
  }
}

Future<void> _copyGenerationLink(
  BuildContext context,
  AppLocalizations text,
  TemplateGenerationResult generation,
) async {
  final outputUrl = generation.outputUrl;
  if (outputUrl == null || outputUrl.isEmpty) {
    _notifySoon(context, text.generationStatusResultUnavailableForShare);
    return;
  }

  await Clipboard.setData(ClipboardData(text: outputUrl));
  if (!context.mounted) {
    return;
  }

  _notifySoon(context, text.generationStatusLinkCopiedMessage);
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

    _notifySoon(context, 'Failed to delete result. Please try again.');
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
  final extensionFromRemote = extensionFromUrl(outputUrl);
  final extension = extensionFromRemote.isEmpty
      ? (isVideoGeneration(generation) ? 'mp4' : 'jpg')
      : extensionFromRemote;
  return '${normalizedTitle}_${generation.generationId}.$extension';
}

void _notifySoon(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
