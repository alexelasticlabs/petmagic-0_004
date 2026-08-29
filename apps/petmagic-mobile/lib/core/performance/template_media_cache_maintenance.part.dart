part of 'template_media_cache.dart';

final class _TemplateMediaCacheMaintenance {
  const _TemplateMediaCacheMaintenance._();

  static Future<void> removeThumbnailFile(
    String url, {
    int? mediaVersion,
  }) async {
    final cacheKey = TemplateMediaCache.cacheKeyForMedia(
      url,
      mediaVersion: mediaVersion,
    );
    _invalidateThumbnailCacheUrl(cacheKey);
    TemplateMediaCache._thumbnailFetchesByUrl.remove(cacheKey);
    await TemplateMediaCache.thumbnailCache.removeFile(cacheKey);
  }

  static Future<void> removePreviewFile(String url, {int? mediaVersion}) {
    final cacheKey = TemplateMediaCache.cacheKeyForMedia(
      url,
      mediaVersion: mediaVersion,
    );
    _invalidatePreviewCacheUrl(cacheKey);
    TemplateMediaCache._previewFetchesByUrl.remove(cacheKey);
    return TemplateMediaCache.previewVideoCache.removeFile(cacheKey);
  }

  static void releaseMemoryReferences() {
    TemplateMediaCache._thumbnailFilesByUrl.clear();
    TemplateMediaCache._previewFilesByUrl.clear();
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

  static Future<void> clearAll() async {
    TemplateMediaCache._cacheGeneration++;
    TemplateMediaCache._thumbnailFilesByUrl.clear();
    TemplateMediaCache._previewFilesByUrl.clear();
    TemplateMediaCache._thumbnailFetchesByUrl.clear();
    TemplateMediaCache._previewFetchesByUrl.clear();
    TemplateMediaCache._thumbnailInvalidationByUrl.clear();
    TemplateMediaCache._previewInvalidationByUrl.clear();
    TemplateMediaCache._latestThumbnailFetchGenerationByUrl.clear();
    TemplateMediaCache._latestPreviewFetchGenerationByUrl.clear();
    TemplateMediaCache._blockedThumbnailCacheUrls.clear();
    TemplateMediaCache._blockedPreviewCacheUrls.clear();

    try {
      await TemplateMediaCache.thumbnailCache.emptyCache();
    } catch (error, stackTrace) {
      _logCacheFailure('clear_thumbnail_cache', error, stackTrace);
      // Keep best-effort semantics for logout cleanup.
    }

    try {
      await TemplateMediaCache.previewVideoCache.emptyCache();
    } catch (error, stackTrace) {
      _logCacheFailure('clear_preview_cache', error, stackTrace);
      // Keep best-effort semantics for logout cleanup.
    }
  }

  static Future<File?> _getRememberedFile(
    _RememberedFilesByUrl filesByUrl,
    String url, {
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
    return rememberedFile.file;
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
  }) async {
    try {
      await cacheManager.removeFile(url);
    } catch (error, stackTrace) {
      _logCacheFailure(stage, error, stackTrace);
    }
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
    return file;
  }
}

class _RememberedCacheFile {
  const _RememberedCacheFile(this.file, this.validTill);

  final File file;
  final DateTime validTill;
}
