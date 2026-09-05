part of 'template_media_cache.dart';

final class _TemplateMediaCacheStorage {
  const _TemplateMediaCacheStorage._();

  static Future<void> empty(CacheManager cacheManager) async {
    // Wait for the asynchronously opened repository before capturing its files.
    await cacheManager.store.getCacheSize();
    final directory = await _directory(cacheManager);
    final files = await directory
        .list(followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    await cacheManager.emptyCache();
    // flutter_cache_manager 3.4.1 removes relative paths from the working
    // directory and leaves failed partial downloads without metadata. New
    // fetches wait for clearAll, so this snapshot cannot include their files.
    for (final file in files) {
      try {
        if (await file.exists()) await file.delete();
      } catch (error, stackTrace) {
        _TemplateMediaCacheMaintenance._logCacheFailure(
          'clear_cached_file',
          error,
          stackTrace,
        );
      }
    }
  }

  static Future<void> remove(
    CacheManager cacheManager,
    String key, {
    required String stage,
  }) async {
    try {
      final cached = await cacheManager.getFileFromCache(key);
      await cacheManager.removeFile(key);
      if (cached != null && await cached.file.exists()) {
        await cached.file.delete();
      }
    } catch (error, stackTrace) {
      _TemplateMediaCacheMaintenance._logCacheFailure(stage, error, stackTrace);
    }
  }

  static Future<File> download(
    CacheManager cacheManager,
    String url, {
    required String cacheKey,
    required bool preview,
    MediaDownloadConstraint? constraint,
  }) async {
    final service = cacheManager.config.fileService as BoundedHttpFileService;
    final headers = constraint == null
        ? null
        : service.registerConstraint(constraint);
    try {
      return await cacheManager.getSingleFile(
        url,
        key: cacheKey,
        headers: headers,
      );
    } catch (downloadError, downloadStackTrace) {
      // Failed streams can leave partial files outside the metadata index.
      try {
        final directory = await _directory(cacheManager);
        if (preview) {
          TemplateMediaCacheBudget.schedulePreview(
            directory,
            onFailure: _TemplateMediaCacheMaintenance._logCacheFailure,
          );
        } else {
          TemplateMediaCacheBudget.scheduleThumbnail(
            directory,
            onFailure: _TemplateMediaCacheMaintenance._logCacheFailure,
          );
        }
      } catch (error, stackTrace) {
        _TemplateMediaCacheMaintenance._logCacheFailure(
          'failed_download_budget',
          error,
          stackTrace,
        );
      }
      Error.throwWithStackTrace(downloadError, downloadStackTrace);
    } finally {
      if (headers != null) service.unregisterConstraint(headers);
    }
  }

  static Future<Directory> _directory(CacheManager cacheManager) async =>
      (await cacheManager.config.fileSystem.createFile(
        '.cache-directory',
      )).parent;
}
