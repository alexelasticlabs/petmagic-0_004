part of 'generation_gallery_store.dart';

Future<void> _galleryMarkDeletedLocally(
  GenerationGalleryStore store,
  String generationId, {
  String? userId,
}) {
  return GenerationGalleryDeletionCoordinator(
    fileStorage: store._fileStorage,
    readEntries: () => _galleryReadEntries(store),
    writeEntries: (entries) => _galleryWriteEntries(store, entries),
    cancelDownload: (key) => _galleryCancelDownload(store, key),
    clock: store._clock,
  ).markDeleted(
    generationId,
    userId: userId,
    resolveAccountScope: () async =>
        _galleryResolveAccountScope(userId) ??
        await store.readCurrentAccountScope(),
  );
}

Future<GenerationGalleryMediaRecord?> _galleryMaterializeGenerationMedia(
  GenerationGalleryStore store,
  TemplateGenerationResult generation, {
  required bool background,
}) async {
  if (!generation.isCompleted) {
    return null;
  }

  final accountScope =
      _galleryResolveAccountScope(generation.userId) ??
      await store.readCurrentAccountScope();
  if (accountScope == null) {
    return null;
  }

  final downloadKey = galleryDownloadKey(accountScope, generation.generationId);
  final existing = store._inFlightDownloads[downloadKey];
  if (existing != null) {
    return existing;
  }

  final future = _galleryMaterializeGenerationMediaInternal(
    store,
    generation,
    accountScopeOverride: accountScope,
    downloadKey: downloadKey,
    background: background,
  );
  store._inFlightDownloads[downloadKey] = future;
  try {
    return await future;
  } finally {
    store._inFlightDownloads.remove(downloadKey);
    store._downloadCancelTokens.remove(downloadKey);
  }
}

Future<GenerationGalleryMediaRecord?>
_galleryMaterializeGenerationMediaInternal(
  GenerationGalleryStore store,
  TemplateGenerationResult generation, {
  required String? accountScopeOverride,
  required String downloadKey,
  required bool background,
}) async {
  final baseEntry = await _galleryUpsertReadyItem(
    store,
    generation,
    accountScopeOverride: accountScopeOverride,
  );
  if (baseEntry.isDeletedLocally) {
    return baseEntry;
  }

  if (background &&
      GenerationGalleryMaterializationPolicy.isBackoffActive(
        baseEntry.materializationBackoffUntilUtc,
        _galleryNowUtc(store),
      )) {
    return baseEntry;
  }

  if (background &&
      !_galleryCanStartBackgroundMaterialization(store, baseEntry)) {
    return _galleryMarkMaterializationSkipped(
      store,
      baseEntry,
      'background_session_cap_exceeded',
    );
  }

  final generationDirectory = await store._fileStorage
      .ensureGenerationDirectory(
        baseEntry.accountScope,
        generation.generationId,
      );
  await GenerationGalleryFileStorage.cleanupGenerationArtifacts(
    generationDirectory,
  );
  if (baseEntry.previewLocalPath == null) {
    await GenerationGalleryFileStorage.deleteFilesForPrefix(
      generationDirectory,
      'preview',
    );
  }
  if (baseEntry.outputLocalPath == null) {
    await GenerationGalleryFileStorage.deleteFilesForPrefix(
      generationDirectory,
      'result',
    );
  }

  final cancelToken = CancelToken();
  store._downloadCancelTokens[downloadKey] = cancelToken;

  var previewLocalPath = baseEntry.previewLocalPath;
  var outputLocalPath = baseEntry.outputLocalPath;
  var isDownloadComplete = true;
  var downloadedBytes = 0;
  final failureCode = <String>{};
  var shouldBackoff = false;
  final isVideo = isVideoGenerationResult(generation);

  try {
    final previewUrl = baseEntry.previewRemoteUrl;
    final outputUrl = baseEntry.outputRemoteUrl;
    final canReuseOutputAsPreview =
        previewUrl != null &&
        outputUrl != null &&
        !isVideoGenerationResult(generation) &&
        GenerationGalleryStorageCodec.safeMediaUriEquals(previewUrl, outputUrl);

    if (canReuseOutputAsPreview) {
      final outputResult = await store._materializeRemoteFile(
        remoteUrl: outputUrl,
        targetDirectory: generationDirectory,
        prefix: 'result',
        fallbackExtension: 'jpg',
        cancelToken: cancelToken,
        background: background,
      );
      GenerationGalleryMaterializationPolicy.collectFailure(
        outputResult,
        failureCode,
      );
      downloadedBytes += outputResult.downloadedBytes;
      outputLocalPath = outputResult.file?.path;
      previewLocalPath = outputResult.file?.path;
      if (outputResult.file == null) {
        isDownloadComplete = false;
        shouldBackoff = shouldBackoff || outputResult.shouldBackoff;
      } else {
        await GenerationGalleryFileStorage.deleteStaleFilesForPrefix(
          generationDirectory,
          'preview',
          outputResult.file!,
        );
      }
    } else {
      if (previewUrl != null) {
        final previewResult = await store._materializeRemoteFile(
          remoteUrl: previewUrl,
          targetDirectory: generationDirectory,
          prefix: 'preview',
          fallbackExtension: 'jpg',
          cancelToken: cancelToken,
          background: background,
        );
        GenerationGalleryMaterializationPolicy.collectFailure(
          previewResult,
          failureCode,
        );
        downloadedBytes += previewResult.downloadedBytes;
        previewLocalPath = previewResult.file?.path;
        if (previewResult.file == null) {
          isDownloadComplete = false;
          shouldBackoff = shouldBackoff || previewResult.shouldBackoff;
        }
      }

      if (outputUrl != null) {
        final shouldSkipBackgroundVideoOutput =
            background &&
            (isVideo || isLikelyGenerationVideoUrl(outputUrl)) &&
            store._backgroundVideoOutputsThisSession >=
                store._maxBackgroundVideoOutputsPerSession;
        if (shouldSkipBackgroundVideoOutput) {
          isDownloadComplete = false;
          failureCode.add('background_video_output_skipped');
        } else {
          if (background &&
              (isVideo || isLikelyGenerationVideoUrl(outputUrl))) {
            store._backgroundVideoOutputsThisSession++;
          }
          final outputResult = await store._materializeRemoteFile(
            remoteUrl: outputUrl,
            targetDirectory: generationDirectory,
            prefix: 'result',
            fallbackExtension: isVideo || isLikelyGenerationVideoUrl(outputUrl)
                ? 'mp4'
                : 'jpg',
            cancelToken: cancelToken,
            background: background,
          );
          GenerationGalleryMaterializationPolicy.collectFailure(
            outputResult,
            failureCode,
          );
          downloadedBytes += outputResult.downloadedBytes;
          outputLocalPath = outputResult.file?.path;
          if (outputResult.file == null) {
            isDownloadComplete = false;
            shouldBackoff = shouldBackoff || outputResult.shouldBackoff;
          }
        }
      } else {
        isDownloadComplete = false;
      }
    }
  } on DioException catch (error) {
    if (!CancelToken.isCancel(error)) {
      _galleryLogStoreFailure(
        store,
        'materialize_generation_media',
        error,
        StackTrace.current,
      );
      failureCode.add(
        GenerationGalleryMaterializationPolicy.dioFailureCode(error),
      );
      shouldBackoff = true;
    }
    isDownloadComplete = false;
  } on Object catch (error, stackTrace) {
    _galleryLogStoreFailure(
      store,
      'materialize_generation_media',
      error,
      stackTrace,
    );
    failureCode.add('materialization_failed');
    shouldBackoff = true;
    isDownloadComplete = false;
  }

  if (background) {
    store._backgroundBytesThisSession += downloadedBytes;
  }

  final localBytes = await GenerationGalleryFileStorage.calculateLocalBytes([
    previewLocalPath,
    outputLocalPath,
  ]);
  final nowUtc = _galleryNowUtc(store);
  final complete =
      isDownloadComplete &&
      GenerationGalleryFileStorage.isValidLocalFile(
        previewLocalPath,
        allowMissing: true,
      ) &&
      GenerationGalleryFileStorage.isValidLocalFile(outputLocalPath);
  final nextFailureCount = complete || !shouldBackoff
      ? (complete ? 0 : baseEntry.materializationFailureCount)
      : math.min(
          baseEntry.materializationFailureCount + 1,
          store._maxMaterializationRetryCount,
        );
  final backoffUntil = complete || !shouldBackoff
      ? null
      : nowUtc.add(
          GenerationGalleryMaterializationPolicy.retryBackoff(
            store._materializationRetryBaseBackoff,
            nextFailureCount,
          ),
        );
  final latestEntries = await _galleryReadEntriesForScope(
    store,
    baseEntry.accountScope,
  );
  final latestEntry = _galleryFindEntry(latestEntries, generation.generationId);
  if (latestEntry?.isDeletedLocally == true) {
    await store._fileStorage.deleteLocalPath(
      baseEntry.accountScope,
      generation.generationId,
      previewLocalPath,
    );
    await store._fileStorage.deleteLocalPath(
      baseEntry.accountScope,
      generation.generationId,
      outputLocalPath,
    );
    return latestEntry;
  }
  final refreshed = await _galleryUpdateEntry(
    store,
    baseEntry.accountScope,
    generation.generationId,
    (entry) => entry.copyWith(
      previewLocalPath: previewLocalPath,
      outputLocalPath: outputLocalPath,
      isDownloadComplete: complete,
      lastSyncedAtUtc: nowUtc,
      version: entry.version + 1,
      materializationFailureCount: nextFailureCount,
      materializationBackoffUntilUtc: backoffUntil,
      materializationFailureCode: failureCode.isEmpty
          ? null
          : failureCode.join(','),
      localBytes: localBytes,
    ),
  );
  return refreshed;
}

bool _galleryCanStartBackgroundMaterialization(
  GenerationGalleryStore store,
  GenerationGalleryMediaRecord entry,
) {
  if (entry.isDownloadComplete &&
      GenerationGalleryFileStorage.isValidLocalFile(
        entry.previewLocalPath,
        allowMissing: true,
      ) &&
      GenerationGalleryFileStorage.isValidLocalFile(entry.outputLocalPath)) {
    return true;
  }
  if (store._backgroundMaterializationsThisSession >=
      store._maxBackgroundMaterializationsPerSession) {
    return false;
  }
  store._backgroundMaterializationsThisSession++;
  return true;
}

Future<GenerationGalleryMediaRecord?> _galleryMarkMaterializationSkipped(
  GenerationGalleryStore store,
  GenerationGalleryMediaRecord entry,
  String reasonCode,
) {
  return _galleryUpdateEntry(
    store,
    entry.accountScope,
    entry.generationId,
    (current) => current.copyWith(
      isDownloadComplete: false,
      lastSyncedAtUtc: _galleryNowUtc(store),
      version: current.version + 1,
      materializationFailureCode: reasonCode,
    ),
  );
}

DateTime _galleryNowUtc(GenerationGalleryStore store) {
  return store._clock().toUtc();
}

Future<void> _galleryCancelActiveDownloads(GenerationGalleryStore store) async {
  final downloadKeys = store._downloadCancelTokens.keys.toList(growable: false);
  for (final downloadKey in downloadKeys) {
    _galleryCancelDownload(store, downloadKey);
  }
}

void _galleryCancelDownload(GenerationGalleryStore store, String downloadKey) {
  final token = store._downloadCancelTokens.remove(downloadKey);
  if (token != null && !token.isCancelled) {
    token.cancel('gallery_cleanup');
  }
}

void _galleryLogStoreFailure(
  GenerationGalleryStore store,
  String stage,
  Object error,
  StackTrace stackTrace,
) {
  AppLogger.warn(
    feature: 'Templates.GenerationGalleryStore',
    operation: stage,
    message: 'Generation gallery store operation failed',
    context: {'stage': stage},
    error: error,
    stackTrace: stackTrace,
  );
}
