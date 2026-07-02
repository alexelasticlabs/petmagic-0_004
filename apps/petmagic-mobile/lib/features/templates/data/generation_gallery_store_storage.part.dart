part of 'generation_gallery_store.dart';

Future<void> _galleryMarkDeletedLocally(
  GenerationGalleryStore store,
  String generationId, {
  String? userId,
}) async {
  final entries = await _galleryReadEntries(store);
  var changed = false;
  final updated = <GenerationGalleryMediaRecord>[];
  for (final entry in entries) {
    if (entry.generationId != generationId) {
      updated.add(entry);
      continue;
    }

    changed = true;
    _galleryCancelDownload(
      store,
      _downloadKey(entry.accountScope, generationId),
    );
    await _galleryDeleteGenerationDirectory(
      store,
      entry.accountScope,
      generationId,
    );
    updated.add(
      entry.copyWith(
        isDeletedLocally: true,
        previewLocalPath: null,
        outputLocalPath: null,
        isDownloadComplete: false,
        lastSyncedAtUtc: DateTime.now().toUtc(),
        version: entry.version + 1,
        pendingServerDelete: true,
      ),
    );
  }

  if (!changed) {
    final accountScope =
        _galleryResolveAccountScope(userId) ??
        await store.readCurrentAccountScope();
    if (accountScope == null) {
      return;
    }

    final nowUtc = DateTime.now().toUtc();
    updated.add(
      GenerationGalleryMediaRecord(
        generationId: generationId,
        accountScope: accountScope,
        userId: userId ?? accountScope,
        status: 'deleted',
        updatedAtUtc: nowUtc,
        lastSyncedAtUtc: nowUtc,
        version: 1,
        isDeletedLocally: true,
        isDownloadComplete: false,
        pendingServerDelete: true,
      ),
    );
    changed = true;
  }

  if (changed) {
    await _galleryWriteEntries(store, updated);
  }
}

class _GalleryMaterializeFileResult {
  const _GalleryMaterializeFileResult({
    this.file,
    this.downloadedBytes = 0,
    this.failureCode,
    this.shouldBackoff = false,
  });

  final File? file;
  final int downloadedBytes;
  final String? failureCode;
  final bool shouldBackoff;
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

  final downloadKey = _downloadKey(accountScope, generation.generationId);
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

  if (background && _galleryIsMaterializationBackoffActive(store, baseEntry)) {
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

  final generationDirectory = await _galleryEnsureGenerationDirectory(
    store,
    baseEntry.accountScope,
    generation.generationId,
  );
  await _galleryCleanupGenerationArtifacts(generationDirectory);
  if (baseEntry.previewLocalPath == null) {
    await _galleryDeleteFilesForPrefix(generationDirectory, 'preview');
  }
  if (baseEntry.outputLocalPath == null) {
    await _galleryDeleteFilesForPrefix(generationDirectory, 'result');
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
        _gallerySafeMediaUriEquals(previewUrl, outputUrl);

    if (canReuseOutputAsPreview) {
      final outputResult = await _galleryMaterializeRemoteFile(
        store,
        remoteUrl: outputUrl,
        targetDirectory: generationDirectory,
        prefix: 'result',
        fallbackExtension: 'jpg',
        cancelToken: cancelToken,
        background: background,
      );
      _galleryApplyMaterializeResult(outputResult, failureCode);
      downloadedBytes += outputResult.downloadedBytes;
      outputLocalPath = outputResult.file?.path;
      previewLocalPath = outputResult.file?.path;
      if (outputResult.file == null) {
        isDownloadComplete = false;
        shouldBackoff = shouldBackoff || outputResult.shouldBackoff;
      } else {
        await _galleryDeleteStaleFilesForPrefix(
          generationDirectory,
          'preview',
          outputResult.file!,
        );
      }
    } else {
      if (previewUrl != null) {
        final previewResult = await _galleryMaterializeRemoteFile(
          store,
          remoteUrl: previewUrl,
          targetDirectory: generationDirectory,
          prefix: 'preview',
          fallbackExtension: 'jpg',
          cancelToken: cancelToken,
          background: background,
        );
        _galleryApplyMaterializeResult(previewResult, failureCode);
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
          final outputResult = await _galleryMaterializeRemoteFile(
            store,
            remoteUrl: outputUrl,
            targetDirectory: generationDirectory,
            prefix: 'result',
            fallbackExtension: isVideo || isLikelyGenerationVideoUrl(outputUrl)
                ? 'mp4'
                : 'jpg',
            cancelToken: cancelToken,
            background: background,
          );
          _galleryApplyMaterializeResult(outputResult, failureCode);
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
      failureCode.add(_galleryDioFailureCode(error));
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

  final localBytes = await _galleryCalculateLocalBytes([
    previewLocalPath,
    outputLocalPath,
  ]);
  final nowUtc = _galleryNowUtc(store);
  final complete =
      isDownloadComplete &&
      _galleryIsValidLocalFile(previewLocalPath, allowMissing: true) &&
      _galleryIsValidLocalFile(outputLocalPath);
  final nextFailureCount = complete || !shouldBackoff
      ? (complete ? 0 : baseEntry.materializationFailureCount)
      : math.min(
          baseEntry.materializationFailureCount + 1,
          store._maxMaterializationRetryCount,
        );
  final backoffUntil = complete || !shouldBackoff
      ? null
      : nowUtc.add(_galleryMaterializationBackoff(store, nextFailureCount));
  final latestEntries = await _galleryReadEntriesForScope(
    store,
    baseEntry.accountScope,
  );
  final latestEntry = _galleryFindEntry(latestEntries, generation.generationId);
  if (latestEntry?.isDeletedLocally == true) {
    await _galleryDeleteLocalPath(previewLocalPath);
    await _galleryDeleteLocalPath(outputLocalPath);
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

bool _galleryIsMaterializationBackoffActive(
  GenerationGalleryStore store,
  GenerationGalleryMediaRecord entry,
) {
  final until = entry.materializationBackoffUntilUtc;
  return until != null && until.isAfter(_galleryNowUtc(store));
}

bool _galleryCanStartBackgroundMaterialization(
  GenerationGalleryStore store,
  GenerationGalleryMediaRecord entry,
) {
  if (entry.isDownloadComplete &&
      _galleryIsValidLocalFile(entry.previewLocalPath, allowMissing: true) &&
      _galleryIsValidLocalFile(entry.outputLocalPath)) {
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

void _galleryApplyMaterializeResult(
  _GalleryMaterializeFileResult result,
  Set<String> failureCode,
) {
  if (result.failureCode != null) {
    failureCode.add(result.failureCode!);
  }
}

Duration _galleryMaterializationBackoff(
  GenerationGalleryStore store,
  int failureCount,
) {
  final exponent = math.max(0, failureCount - 1);
  final multiplier = math.pow(2, exponent).toInt();
  return store._materializationRetryBaseBackoff * multiplier;
}

String _galleryDioFailureCode(DioException error) {
  final statusCode = error.response?.statusCode ?? 0;
  return switch (statusCode) {
    401 || 403 => 'signed_url_unavailable',
    404 => 'storage_unavailable',
    408 || 429 || >= 500 => 'network_retryable',
    _ => 'network_error',
  };
}

DateTime _galleryNowUtc(GenerationGalleryStore store) {
  return store._clock().toUtc();
}

Future<_GalleryMaterializeFileResult> _galleryMaterializeRemoteFile(
  GenerationGalleryStore store, {
  required String remoteUrl,
  required Directory targetDirectory,
  required String prefix,
  required String fallbackExtension,
  required CancelToken cancelToken,
  required bool background,
}) async {
  final safeUri = parseSafeGenerationMediaUri(remoteUrl);
  if (safeUri == null) {
    return const _GalleryMaterializeFileResult(
      failureCode: 'unsafe_url',
      shouldBackoff: false,
    );
  }

  final remainingBackgroundBytes =
      store._maxBackgroundBytesPerSession - store._backgroundBytesThisSession;
  if (background && remainingBackgroundBytes <= 0) {
    return const _GalleryMaterializeFileResult(
      failureCode: 'background_byte_budget_exceeded',
      shouldBackoff: false,
    );
  }

  final extension = extensionFromUrl(safeUri.toString()).trim().isEmpty
      ? fallbackExtension
      : extensionFromUrl(safeUri.toString());
  final urlStamp = _stableUrlStamp(safeUri.toString());
  final fileName = sanitizeFileName(
    '${prefix}_$urlStamp.$extension',
    fallback: '${prefix}_$urlStamp.$fallbackExtension',
  );
  final targetFile = File(
    '${targetDirectory.path}${Platform.pathSeparator}$fileName',
  );
  if (await _galleryHasUsableFile(targetFile)) {
    await _galleryDeleteStaleFilesForPrefix(
      targetDirectory,
      prefix,
      targetFile,
    );
    return _GalleryMaterializeFileResult(file: targetFile);
  }

  final tempFile = File('${targetFile.path}.part');
  if (await tempFile.exists()) {
    await tempFile.delete();
  }

  await store._dio.downloadUri(
    safeUri,
    tempFile.path,
    cancelToken: cancelToken,
    deleteOnError: true,
    options: Options(responseType: ResponseType.bytes),
  );

  final downloadedBytes = await _galleryFileSize(tempFile);
  if (background && downloadedBytes > store._maxBackgroundFileBytes) {
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    return _GalleryMaterializeFileResult(
      downloadedBytes: downloadedBytes,
      failureCode: 'background_file_too_large',
      shouldBackoff: false,
    );
  }
  if (background && downloadedBytes > remainingBackgroundBytes) {
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    return _GalleryMaterializeFileResult(
      downloadedBytes: downloadedBytes,
      failureCode: 'background_byte_budget_exceeded',
      shouldBackoff: false,
    );
  }

  if (!await _galleryHasUsableFile(tempFile)) {
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    return _GalleryMaterializeFileResult(
      downloadedBytes: downloadedBytes,
      failureCode: downloadedBytes <= 0 ? 'empty_download' : 'invalid_media',
      shouldBackoff: true,
    );
  }

  if (await targetFile.exists()) {
    await targetFile.delete();
  }
  await tempFile.rename(targetFile.path);
  await _galleryDeleteStaleFilesForPrefix(targetDirectory, prefix, targetFile);
  return _GalleryMaterializeFileResult(
    file: targetFile,
    downloadedBytes: downloadedBytes,
  );
}

Future<void> _galleryDeleteStaleFilesForPrefix(
  Directory targetDirectory,
  String prefix,
  File retainedFile,
) async {
  try {
    if (!await targetDirectory.exists()) {
      return;
    }

    final retainedPath = retainedFile.path;
    await for (final entity in targetDirectory.list()) {
      if (entity is! File || entity.path == retainedPath) {
        continue;
      }

      final fileName = _basename(entity.path);
      final isLegacyFile = fileName.startsWith('$prefix.');
      final isStampedFile = fileName.startsWith('${prefix}_');
      if (!isLegacyFile && !isStampedFile) {
        continue;
      }

      await entity.delete();
    }
  } on Object {
    // Local cache cleanup is best effort.
  }
}

Future<void> _galleryDeleteFilesForPrefix(
  Directory targetDirectory,
  String prefix,
) async {
  try {
    if (!await targetDirectory.exists()) {
      return;
    }

    await for (final entity in targetDirectory.list()) {
      if (entity is! File) {
        continue;
      }

      final fileName = _basename(entity.path);
      final isLegacyFile = fileName.startsWith('$prefix.');
      final isStampedFile = fileName.startsWith('${prefix}_');
      if (!isLegacyFile && !isStampedFile) {
        continue;
      }

      await entity.delete();
    }
  } on Object {
    // Local cache cleanup is best effort.
  }
}

Future<bool> _galleryHasUsableFile(File file) async {
  try {
    if (!await file.exists()) {
      return false;
    }
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file || stat.size <= 0) {
      return false;
    }
    final header = await file.openRead(0, 16).toList();
    return hasSupportedMediaSignature([for (final chunk in header) ...chunk]);
  } on Object {
    return false;
  }
}

Future<int> _galleryFileSize(File file) async {
  try {
    if (!await file.exists()) {
      return 0;
    }
    final stat = await file.stat();
    return stat.type == FileSystemEntityType.file ? stat.size : 0;
  } on Object {
    return 0;
  }
}

Future<int> _galleryCalculateLocalBytes(Iterable<String?> paths) async {
  var total = 0;
  final seen = <String>{};
  for (final path in paths) {
    final normalized = path?.trim();
    if (normalized == null || normalized.isEmpty || !seen.add(normalized)) {
      continue;
    }
    total += await _galleryFileSize(File(normalized));
  }
  return total;
}

bool _galleryIsValidLocalFile(String? path, {bool allowMissing = false}) {
  final normalized = path?.trim();
  if (normalized == null || normalized.isEmpty) {
    return allowMissing;
  }
  try {
    final file = File(normalized);
    if (!file.existsSync() || file.lengthSync() <= 0) {
      return false;
    }
    final handle = file.openSync();
    try {
      final header = handle.readSync(16);
      return hasSupportedMediaSignature(header);
    } finally {
      handle.closeSync();
    }
  } on Object {
    return false;
  }
}

bool _gallerySafeMediaUriEquals(String left, String right) {
  final leftSafe = persistentSafeGenerationMediaUrl(left);
  final rightSafe = persistentSafeGenerationMediaUrl(right);
  return leftSafe != null && rightSafe != null && leftSafe == rightSafe;
}

bool _gallerySafeNullableMediaUriEquals(String? left, String? right) {
  if (left == null && right == null) {
    return true;
  }
  if (left == null || right == null) {
    return false;
  }
  return _gallerySafeMediaUriEquals(left, right);
}

Future<Directory> _galleryEnsureGenerationDirectory(
  GenerationGalleryStore store,
  String accountScope,
  String generationId,
) async {
  final root = await store._rootDirectoryResolver();
  final scopeSegment = _galleryScopeStorageSegment(accountScope);
  final generationSegment = _safePathSegment(
    generationId,
    fallback: 'generation',
  );
  final directory = Directory(
    '${root.path}${Platform.pathSeparator}'
    '${GenerationGalleryStore._generationScopeRoot}${Platform.pathSeparator}'
    '$scopeSegment${Platform.pathSeparator}$generationSegment',
  );
  await directory.create(recursive: true);
  return directory;
}

Future<void> _galleryDeleteGenerationDirectory(
  GenerationGalleryStore store,
  String accountScope,
  String generationId,
) async {
  final root = await store._rootDirectoryResolver();
  final scopeSegment = _galleryScopeStorageSegment(accountScope);
  final generationSegment = _safePathSegment(
    generationId,
    fallback: 'generation',
  );
  final directory = Directory(
    '${root.path}${Platform.pathSeparator}'
    '${GenerationGalleryStore._generationScopeRoot}${Platform.pathSeparator}'
    '$scopeSegment${Platform.pathSeparator}$generationSegment',
  );
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
}

Future<void> _galleryDeleteScopeDirectory(
  GenerationGalleryStore store,
  String accountScope,
) async {
  final root = await store._rootDirectoryResolver();
  final scopeSegment = _galleryScopeStorageSegment(accountScope);
  final directory = Directory(
    '${root.path}${Platform.pathSeparator}'
    '${GenerationGalleryStore._generationScopeRoot}${Platform.pathSeparator}$scopeSegment',
  );
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
}

Future<void> _galleryDeleteRootDirectory(GenerationGalleryStore store) async {
  final root = await store._rootDirectoryResolver();
  final directory = Directory(
    '${root.path}${Platform.pathSeparator}'
    '${GenerationGalleryStore._generationScopeRoot}',
  );
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
}

Future<void> _galleryCleanupScopeArtifacts(
  GenerationGalleryStore store,
  String accountScope,
) async {
  final entries = await _galleryReadEntriesForScope(store, accountScope);
  await _galleryCleanupScopeArtifactsForKnownIds(
    store,
    accountScope,
    entries.map((entry) => entry.generationId).toSet(),
  );
}

Future<void> _galleryCleanupScopeArtifactsForKnownIds(
  GenerationGalleryStore store,
  String accountScope,
  Set<String> knownGenerationIds,
) async {
  final root = await store._rootDirectoryResolver();
  final scopeSegment = _galleryScopeStorageSegment(accountScope);
  final scopeDirectory = Directory(
    '${root.path}${Platform.pathSeparator}'
    '${GenerationGalleryStore._generationScopeRoot}${Platform.pathSeparator}'
    '$scopeSegment',
  );
  if (!await scopeDirectory.exists()) {
    return;
  }

  final knownIds = knownGenerationIds
      .map(
        (generationId) =>
            _safePathSegment(generationId, fallback: 'generation'),
      )
      .toSet();
  final activeIds = store._downloadCancelTokens.keys
      .where((downloadKey) => downloadKey.startsWith('$accountScope\u{1F}'))
      .map((downloadKey) => downloadKey.substring(accountScope.length + 1))
      .map(
        (generationId) =>
            _safePathSegment(generationId, fallback: 'generation'),
      )
      .toSet();
  await for (final entity in scopeDirectory.list()) {
    if (entity is! Directory) {
      continue;
    }

    final generationId = entity.uri.pathSegments.isEmpty
        ? ''
        : entity.uri.pathSegments.lastWhere(
            (segment) => segment.isNotEmpty,
            orElse: () => '',
          );
    if (generationId.isEmpty) {
      continue;
    }

    if (activeIds.contains(generationId)) {
      continue;
    }

    if (!knownIds.contains(generationId)) {
      await entity.delete(recursive: true);
      continue;
    }

    await _galleryCleanupGenerationArtifacts(entity);
  }
}

Future<void> _galleryDeleteLocalPath(String? path) async {
  final normalized = path?.trim();
  if (normalized == null || normalized.isEmpty) {
    return;
  }
  try {
    final file = File(normalized);
    if (await file.exists()) {
      await file.delete();
    }
    final partFile = File('$normalized.part');
    if (await partFile.exists()) {
      await partFile.delete();
    }
  } on Object {
    // Local cache cleanup is best effort; stale artifacts will be retried later.
  }
}

Future<void> _galleryCleanupGenerationArtifacts(
  Directory generationDirectory,
) async {
  try {
    if (!await generationDirectory.exists()) {
      return;
    }

    await for (final entity in generationDirectory.list()) {
      if (entity is File && entity.path.endsWith('.part')) {
        await entity.delete();
      }
    }
  } on Object {
    // Cache cleanup is best effort; materialization can recreate safe files.
  }
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
