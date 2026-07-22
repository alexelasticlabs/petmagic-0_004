part of 'generations_gallery_page.dart';

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
