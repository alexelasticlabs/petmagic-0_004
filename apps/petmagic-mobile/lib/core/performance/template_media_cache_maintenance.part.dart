part of 'template_media_cache.dart';

final class _TemplateMediaCacheMaintenance {
  const _TemplateMediaCacheMaintenance._();

  static String cacheKeyForMedia(String url, {int? mediaVersion}) {
    final normalized = persistentSafeMediaCacheKeyUrl(url);
    if (mediaVersion == null || mediaVersion <= 0) return normalized;
    return 'v$mediaVersion|$normalized';
  }

  static Future<void> removeThumbnailFile(
    String url, {
    int? mediaVersion,
  }) async {
    final cacheKey = TemplateMediaCache.cacheKeyForMedia(
      url,
      mediaVersion: mediaVersion,
    );
    _invalidateThumbnailCacheUrl(cacheKey);
    await _removeCacheManagerFile(
      TemplateMediaCache.thumbnailCache,
      cacheKey,
      stage: 'thumbnail_explicit_remove',
    );
  }

  static Future<void> removePreviewFile(String url, {int? mediaVersion}) {
    final cacheKey = TemplateMediaCache.cacheKeyForMedia(
      url,
      mediaVersion: mediaVersion,
    );
    _invalidatePreviewCacheUrl(cacheKey);
    return _removeCacheManagerFile(
      TemplateMediaCache.previewVideoCache,
      cacheKey,
      stage: 'preview_explicit_remove',
    );
  }

  static void releaseMemoryReferences() {
    TemplateMediaCache._thumbnailFilesByUrl.clear();
    TemplateMediaCache._previewFilesByUrl.clear();
    TemplateMediaCache.thumbnailCache.store.emptyMemoryCache();
    TemplateMediaCache.previewVideoCache.store.emptyMemoryCache();
    TemplateMediaCacheBudget.releaseMemoryReferences();
  }

  @visibleForTesting
  static Future<int> trimThumbnailCacheDirectoryForTesting(
    Directory thumbnailCacheDirectory, {
    required int maxBytes,
  }) {
    return TemplateMediaCacheBudget.trimDirectory(
      thumbnailCacheDirectory,
      maxBytes: maxBytes,
      statStage: 'thumbnail_budget_stat_file',
      deleteStage: 'thumbnail_budget_delete_file',
      onFailure: _logCacheFailure,
    );
  }

  @visibleForTesting
  static Future<int> trimPreviewCacheDirectoryForTesting(
    Directory previewCacheDirectory, {
    required int maxBytes,
  }) {
    return TemplateMediaCacheBudget.trimDirectory(
      previewCacheDirectory,
      maxBytes: maxBytes,
      statStage: 'preview_budget_stat_file',
      deleteStage: 'preview_budget_delete_file',
      onFailure: _logCacheFailure,
    );
  }

  static Future<void> clearAll() {
    final clearing = TemplateMediaCache._cacheClearInProgress;
    if (clearing != null) return clearing;
    late final Future<void> clear;
    clear = _clearAll().whenComplete(() {
      if (identical(TemplateMediaCache._cacheClearInProgress, clear)) {
        TemplateMediaCache._cacheClearInProgress = null;
      }
    });
    TemplateMediaCache._cacheClearInProgress = clear;
    return clear;
  }

  static Future<void> _clearAll() async {
    TemplateMediaCache._cacheGeneration++;
    TemplateMediaCacheBudget.releaseMemoryReferences();
    TemplateMediaCache._thumbnailFilesByUrl.clear();
    TemplateMediaCache._previewFilesByUrl.clear();
    TemplateMediaCache._thumbnailInvalidationByUrl.clear();
    TemplateMediaCache._previewInvalidationByUrl.clear();
    TemplateMediaCache._latestThumbnailFetchGenerationByUrl.clear();
    TemplateMediaCache._latestPreviewFetchGenerationByUrl.clear();
    TemplateMediaCache._blockedThumbnailCacheUrls.clear();
    TemplateMediaCache._blockedPreviewCacheUrls.clear();

    try {
      await _emptyCacheManager(TemplateMediaCache.thumbnailCache);
    } catch (error, stackTrace) {
      _logCacheFailure('clear_thumbnail_cache', error, stackTrace);
      // Keep best-effort semantics for logout cleanup.
    }

    try {
      await _emptyCacheManager(TemplateMediaCache.previewVideoCache);
    } catch (error, stackTrace) {
      _logCacheFailure('clear_preview_cache', error, stackTrace);
      // Keep best-effort semantics for logout cleanup.
    }
  }

  static Future<File?> _getRememberedFile(
    _RememberedFilesByUrl filesByUrl,
    String url, {
    required CacheManager cacheManager,
    required int maxEntries,
  }) async {
    final rememberedFile = filesByUrl.remove(url);
    if (rememberedFile == null) {
      return null;
    }

    if (!rememberedFile.validTill.isAfter(DateTime.now())) {
      return null;
    }

    try {
      if (!await rememberedFile.file.exists()) {
        return null;
      }
    } on FileSystemException {
      return null;
    }

    _rememberFile(
      filesByUrl,
      url,
      rememberedFile.file,
      validTill: rememberedFile.validTill,
      maxEntries: maxEntries,
    );
    await _recordAccess(
      rememberedFile.file,
      cacheManager: cacheManager,
      cacheKey: url,
    );
    return rememberedFile.file;
  }

  static Future<void> _emptyCacheManager(CacheManager cacheManager) =>
      _TemplateMediaCacheStorage.empty(cacheManager);

  static Future<File> waitForInvalidatedFetch(
    Future<File> previous,
    Future<File> Function() retry,
  ) async {
    try {
      await previous;
    } catch (error) {
      // Let the old cache-manager stream and its invalidation cleanup finish.
      AppLogger.debug(
        feature: 'Performance.MediaCache',
        operation: 'invalidated_fetch_settled',
        context: {'errorType': error.runtimeType.toString()},
      );
    }
    return retry();
  }

  static Future<void> _recordAccess(
    File file, {
    required CacheManager cacheManager,
    required String cacheKey,
  }) async {
    final touched = await TemplateMediaCacheBudget.recordAccess(
      file,
      onFailure: _logCacheFailure,
    );
    if (!touched) return;
    try {
      // Refresh persisted recency for the cache manager's count/age eviction.
      // Its normal memory lookup does not update the repository's touched time.
      await cacheManager.getFileFromCache(cacheKey, ignoreMemCache: true);
    } catch (error, stackTrace) {
      _logCacheFailure('cache_access_metadata', error, stackTrace);
    }
  }

  static void _rememberFile(
    _RememberedFilesByUrl filesByUrl,
    String url,
    File file, {
    required DateTime validTill,
    required int maxEntries,
  }) {
    filesByUrl.remove(url);
    filesByUrl[url] = _RememberedCacheFile(file, validTill);
    while (filesByUrl.length > maxEntries) {
      filesByUrl.remove(filesByUrl.keys.first);
    }
  }

  static void _invalidateThumbnailCacheUrl(String url) {
    final currentInvalidation =
        TemplateMediaCache._thumbnailInvalidationByUrl.remove(url) ?? 0;
    TemplateMediaCache._thumbnailInvalidationByUrl[url] =
        currentInvalidation + 1;
    _blockThumbnailCacheUrl(url);
    MediaCacheTracking.trimInvalidations(
      TemplateMediaCache._thumbnailInvalidationByUrl,
      TemplateMediaCache._blockedThumbnailCacheUrls,
      maxEntries: TemplateMediaCache._maxBlockedThumbnailCacheUrls,
    );
  }

  static void _invalidatePreviewCacheUrl(String url) {
    final currentInvalidation =
        TemplateMediaCache._previewInvalidationByUrl.remove(url) ?? 0;
    TemplateMediaCache._previewInvalidationByUrl[url] = currentInvalidation + 1;
    _blockPreviewCacheUrl(url);
    MediaCacheTracking.trimInvalidations(
      TemplateMediaCache._previewInvalidationByUrl,
      TemplateMediaCache._blockedPreviewCacheUrls,
      maxEntries: TemplateMediaCache._maxBlockedPreviewCacheUrls,
    );
  }

  static void _blockThumbnailCacheUrl(String url) {
    TemplateMediaCache._thumbnailFilesByUrl.remove(url);
    TemplateMediaCache._blockedThumbnailCacheUrls.remove(url);
    TemplateMediaCache._blockedThumbnailCacheUrls.add(url);
    MediaCacheTracking.trimBlockedUrls(
      TemplateMediaCache._blockedThumbnailCacheUrls,
      maxEntries: TemplateMediaCache._maxBlockedThumbnailCacheUrls,
    );
  }

  static void _blockPreviewCacheUrl(String url) {
    TemplateMediaCache._previewFilesByUrl.remove(url);
    TemplateMediaCache._blockedPreviewCacheUrls.remove(url);
    TemplateMediaCache._blockedPreviewCacheUrls.add(url);
    MediaCacheTracking.trimBlockedUrls(
      TemplateMediaCache._blockedPreviewCacheUrls,
      maxEntries: TemplateMediaCache._maxBlockedPreviewCacheUrls,
    );
  }

  static bool _isCurrentFetch(
    String url, {
    required int generation,
    required int urlInvalidation,
    required _InvalidationCountsByUrl invalidationsByUrl,
  }) {
    return generation == TemplateMediaCache._cacheGeneration &&
        urlInvalidation == (invalidationsByUrl[url] ?? 0);
  }

  static bool _canInvalidateCompletedFetch(
    String url, {
    required int generation,
    required _FetchGenerationsByUrl latestFetchGenerationsByUrl,
  }) {
    final latestGeneration = latestFetchGenerationsByUrl[url];
    return latestGeneration == null || latestGeneration == generation;
  }

  static Future<void> _removeCacheManagerFile(
    CacheManager cacheManager,
    String url, {
    required String stage,
  }) => _TemplateMediaCacheStorage.remove(cacheManager, url, stage: stage);

  static Future<File?> getCachedThumbnailFile(
    String url, {
    int? mediaVersion,
  }) async {
    final clearing = TemplateMediaCache._cacheClearInProgress;
    if (clearing != null) await clearing;
    final cacheKey = TemplateMediaCache.cacheKeyForMedia(
      url,
      mediaVersion: mediaVersion,
    );
    if (TemplateMediaCache._blockedThumbnailCacheUrls.contains(cacheKey)) {
      return null;
    }
    final remembered = await _getRememberedFile(
      TemplateMediaCache._thumbnailFilesByUrl,
      cacheKey,
      cacheManager: TemplateMediaCache.thumbnailCache,
      maxEntries: TemplateMediaCache._maxThumbnailFileReferences,
    );
    if (remembered != null) return remembered;
    final cached = await TemplateMediaCache.thumbnailCache.getFileFromCache(
      cacheKey,
    );
    if (cached == null ||
        !cached.validTill.isAfter(DateTime.now()) ||
        !await cached.file.exists()) {
      return null;
    }
    _rememberFile(
      TemplateMediaCache._thumbnailFilesByUrl,
      cacheKey,
      cached.file,
      validTill: cached.validTill,
      maxEntries: TemplateMediaCache._maxThumbnailFileReferences,
    );
    await _recordAccess(
      cached.file,
      cacheManager: TemplateMediaCache.thumbnailCache,
      cacheKey: cacheKey,
    );
    TemplateMediaCacheBudget.ensureThumbnailBudget(
      cached.file.parent,
      onFailure: _logCacheFailure,
    );
    return cached.file;
  }

  static void _logCacheFailure(
    String stage,
    Object error,
    StackTrace stackTrace,
  ) {
    AppLogger.error(
      feature: 'Performance.MediaCache',
      operation: stage,
      message: 'Template media cache operation failed',
      error: error,
      stackTrace: stackTrace,
      context: {'stage': stage},
    );
  }

  static Future<File?> getCachedPreviewFile(
    String url, {
    int? mediaVersion,
  }) async {
    final clearing = TemplateMediaCache._cacheClearInProgress;
    if (clearing != null) await clearing;
    final cacheKey = TemplateMediaCache.cacheKeyForMedia(
      url,
      mediaVersion: mediaVersion,
    );
    if (TemplateMediaCache._blockedPreviewCacheUrls.contains(cacheKey)) {
      return null;
    }

    final rememberedFile = await _getRememberedFile(
      TemplateMediaCache._previewFilesByUrl,
      cacheKey,
      cacheManager: TemplateMediaCache.previewVideoCache,
      maxEntries: TemplateMediaCache._maxPreviewFileReferences,
    );
    if (rememberedFile != null) {
      return rememberedFile;
    }

    final cachedFile = await TemplateMediaCache.previewVideoCache
        .getFileFromCache(cacheKey);
    final file = cachedFile?.file;
    if (cachedFile == null ||
        !cachedFile.validTill.isAfter(DateTime.now()) ||
        file == null ||
        !await file.exists()) {
      return null;
    }

    _rememberFile(
      TemplateMediaCache._previewFilesByUrl,
      cacheKey,
      file,
      validTill: cachedFile.validTill,
      maxEntries: TemplateMediaCache._maxPreviewFileReferences,
    );
    await _recordAccess(
      file,
      cacheManager: TemplateMediaCache.previewVideoCache,
      cacheKey: cacheKey,
    );
    TemplateMediaCacheBudget.ensurePreviewBudget(
      file.parent,
      onFailure: _logCacheFailure,
    );
    return file;
  }
}

class _RememberedCacheFile {
  const _RememberedCacheFile(this.file, this.validTill);

  final File file;
  final DateTime validTill;
}
