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

Future<GenerationGalleryMediaRecord?> _galleryMaterializeGenerationMedia(
  GenerationGalleryStore store,
  TemplateGenerationResult generation,
) async {
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
}) async {
  final baseEntry = await _galleryUpsertReadyItem(
    store,
    generation,
    accountScopeOverride: accountScopeOverride,
  );
  if (baseEntry.isDeletedLocally) {
    return baseEntry;
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

  try {
    final previewUrl = baseEntry.previewRemoteUrl;
    final outputUrl = baseEntry.outputRemoteUrl;
    final canReuseOutputAsPreview =
        previewUrl != null &&
        outputUrl != null &&
        !isVideoGenerationResult(generation) &&
        _gallerySafeMediaUriEquals(previewUrl, outputUrl);

    if (canReuseOutputAsPreview) {
      final outputFile = await _galleryMaterializeRemoteFile(
        store,
        remoteUrl: outputUrl,
        targetDirectory: generationDirectory,
        prefix: 'result',
        fallbackExtension: 'jpg',
        cancelToken: cancelToken,
      );
      outputLocalPath = outputFile?.path;
      previewLocalPath = outputFile?.path;
      if (outputFile == null) {
        isDownloadComplete = false;
      } else {
        await _galleryDeleteStaleFilesForPrefix(
          generationDirectory,
          'preview',
          outputFile,
        );
      }
    } else {
      if (previewUrl != null) {
        final previewFile = await _galleryMaterializeRemoteFile(
          store,
          remoteUrl: previewUrl,
          targetDirectory: generationDirectory,
          prefix: 'preview',
          fallbackExtension: 'jpg',
          cancelToken: cancelToken,
        );
        previewLocalPath = previewFile?.path;
        if (previewFile == null) {
          isDownloadComplete = false;
        }
      }

      if (outputUrl != null) {
        final outputFile = await _galleryMaterializeRemoteFile(
          store,
          remoteUrl: outputUrl,
          targetDirectory: generationDirectory,
          prefix: 'result',
          fallbackExtension:
              isVideoGenerationResult(generation) ||
                  isLikelyGenerationVideoUrl(outputUrl)
              ? 'mp4'
              : 'jpg',
          cancelToken: cancelToken,
        );
        outputLocalPath = outputFile?.path;
        if (outputFile == null) {
          isDownloadComplete = false;
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
    }
    isDownloadComplete = false;
  } on Object catch (error, stackTrace) {
    _galleryLogStoreFailure(
      store,
      'materialize_generation_media',
      error,
      stackTrace,
    );
    isDownloadComplete = false;
  }

  final refreshed = await _galleryUpdateEntry(
    store,
    baseEntry.accountScope,
    generation.generationId,
    (entry) => entry.copyWith(
      previewLocalPath: previewLocalPath,
      outputLocalPath: outputLocalPath,
      isDownloadComplete:
          isDownloadComplete &&
          _galleryIsValidLocalFile(previewLocalPath, allowMissing: true) &&
          _galleryIsValidLocalFile(outputLocalPath),
      lastSyncedAtUtc: DateTime.now().toUtc(),
      version: entry.version + 1,
    ),
  );
  return refreshed;
}

Future<File?> _galleryMaterializeRemoteFile(
  GenerationGalleryStore store, {
  required String remoteUrl,
  required Directory targetDirectory,
  required String prefix,
  required String fallbackExtension,
  required CancelToken cancelToken,
}) async {
  final safeUri = parseSafeGenerationMediaUri(remoteUrl);
  if (safeUri == null) {
    return null;
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
    return targetFile;
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

  if (!await _galleryHasUsableFile(tempFile)) {
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    return null;
  }

  if (await targetFile.exists()) {
    await targetFile.delete();
  }
  await tempFile.rename(targetFile.path);
  await _galleryDeleteStaleFilesForPrefix(targetDirectory, prefix, targetFile);
  return targetFile;
}

Future<void> _galleryDeleteStaleFilesForPrefix(
  Directory targetDirectory,
  String prefix,
  File retainedFile,
) async {
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
}

Future<void> _galleryDeleteFilesForPrefix(
  Directory targetDirectory,
  String prefix,
) async {
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
    return _galleryHasSupportedMediaSignature([
      for (final chunk in header) ...chunk,
    ]);
  } on Object {
    return false;
  }
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
      return _galleryHasSupportedMediaSignature(header);
    } finally {
      handle.closeSync();
    }
  } on Object {
    return false;
  }
}

bool _gallerySafeMediaUriEquals(String left, String right) {
  final leftUri = parseSafeGenerationMediaUri(left);
  final rightUri = parseSafeGenerationMediaUri(right);
  return leftUri != null &&
      rightUri != null &&
      leftUri.toString() == rightUri.toString();
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

bool _galleryHasSupportedMediaSignature(List<int> header) {
  if (_galleryStartsWith(header, const [0xFF, 0xD8, 0xFF])) {
    return true;
  }
  if (_galleryStartsWith(header, const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ])) {
    return true;
  }
  if (header.length >= 12 &&
      _galleryAsciiEquals(header, 0, 'RIFF') &&
      _galleryAsciiEquals(header, 8, 'WEBP')) {
    return true;
  }
  if (_galleryAsciiEquals(header, 0, 'GIF8')) {
    return true;
  }
  if (header.length >= 12 && _galleryAsciiEquals(header, 4, 'ftyp')) {
    return true;
  }
  return false;
}

bool _galleryStartsWith(List<int> bytes, List<int> prefix) {
  if (bytes.length < prefix.length) {
    return false;
  }
  for (var index = 0; index < prefix.length; index++) {
    if (bytes[index] != prefix[index]) {
      return false;
    }
  }
  return true;
}

bool _galleryAsciiEquals(List<int> bytes, int offset, String value) {
  if (bytes.length < offset + value.length) {
    return false;
  }
  for (var index = 0; index < value.length; index++) {
    if (bytes[offset + index] != value.codeUnitAt(index)) {
      return false;
    }
  }
  return true;
}

Future<Directory> _galleryEnsureGenerationDirectory(
  GenerationGalleryStore store,
  String accountScope,
  String generationId,
) async {
  final root = await store._rootDirectoryResolver();
  final scopeSegment = _safePathSegment(accountScope, fallback: 'account');
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
  final scopeSegment = _safePathSegment(accountScope, fallback: 'account');
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
  final scopeSegment = _safePathSegment(accountScope, fallback: 'account');
  final directory = Directory(
    '${root.path}${Platform.pathSeparator}'
    '${GenerationGalleryStore._generationScopeRoot}${Platform.pathSeparator}$scopeSegment',
  );
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
}

Future<void> _galleryCleanupScopeArtifacts(
  GenerationGalleryStore store,
  String accountScope,
) async {
  final root = await store._rootDirectoryResolver();
  final scopeDirectory = Directory(
    '${root.path}${Platform.pathSeparator}'
    '${GenerationGalleryStore._generationScopeRoot}${Platform.pathSeparator}'
    '${_safePathSegment(accountScope, fallback: 'account')}',
  );
  if (!await scopeDirectory.exists()) {
    return;
  }

  final entries = await _galleryReadEntriesForScope(store, accountScope);
  final knownIds = entries
      .map(
        (entry) => _safePathSegment(entry.generationId, fallback: 'generation'),
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

    if (!knownIds.contains(generationId)) {
      await entity.delete(recursive: true);
      continue;
    }

    await _galleryCleanupGenerationArtifacts(entity);
  }
}

Future<void> _galleryCleanupGenerationArtifacts(
  Directory generationDirectory,
) async {
  if (!await generationDirectory.exists()) {
    return;
  }

  await for (final entity in generationDirectory.list()) {
    if (entity is File && entity.path.endsWith('.part')) {
      await entity.delete();
    }
  }
}

Future<void> _galleryCancelActiveDownloads(GenerationGalleryStore store) async {
  final downloadKeys = store._downloadCancelTokens.keys.toList(growable: false);
  for (final downloadKey in downloadKeys) {
    _galleryCancelDownload(store, downloadKey);
  }
}

void _galleryCancelDownload(GenerationGalleryStore store, String generationId) {
  final token = store._downloadCancelTokens.remove(generationId);
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
