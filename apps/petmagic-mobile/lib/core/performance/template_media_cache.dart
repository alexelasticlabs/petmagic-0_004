import 'dart:collection';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/performance/bounded_http_file_service.dart';
import 'package:petmagic_mobile/core/performance/media_cache_tracking.dart';
import 'package:petmagic_mobile/core/performance/media_prefetch_budget.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache_budget.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';

part 'template_media_cache_maintenance.part.dart';
part 'template_media_cache_storage.part.dart';
part 'template_media_cache_downloads.part.dart';

typedef _RememberedFilesByUrl = LinkedHashMap<String, _RememberedCacheFile>;
typedef _InvalidationCountsByUrl = LinkedHashMap<String, int>;
typedef _FetchGenerationsByUrl = LinkedHashMap<String, int>;
typedef _BlockedCacheUrls = LinkedHashSet<String>;

class TemplateMediaCache {
  TemplateMediaCache._();

  static const int _maxThumbnailFileReferences = 300;
  // File references contain paths and expiry only. The separate byte budget
  // evicts least recently used disk files after downloads complete.
  static const int _maxPreviewFileReferences = 250;
  static const int _maxBlockedThumbnailCacheUrls = _maxThumbnailFileReferences;
  static const int _maxBlockedPreviewCacheUrls = _maxPreviewFileReferences;
  static const int _maxThumbnailInFlightFetches = 64;
  static const int _maxPreviewInFlightFetches = 32;
  static const int _maxThumbnailDownloadBytes = 8 * 1024 * 1024;
  static const int _maxPreviewDownloadBytes = 24 * 1024 * 1024;
  static int _cacheGeneration = 0;
  static Future<void>? _cacheClearInProgress;
  static final _RememberedFilesByUrl _thumbnailFilesByUrl =
      _RememberedFilesByUrl();
  static final _RememberedFilesByUrl _previewFilesByUrl =
      _RememberedFilesByUrl();
  static final Map<String, Future<File>> _thumbnailFetchesByUrl =
      <String, Future<File>>{};
  static final Map<String, Future<File>> _previewFetchesByUrl =
      <String, Future<File>>{};
  static final _InvalidationCountsByUrl _thumbnailInvalidationByUrl =
      _InvalidationCountsByUrl();
  static final _InvalidationCountsByUrl _previewInvalidationByUrl =
      _InvalidationCountsByUrl();
  static final _FetchGenerationsByUrl _latestThumbnailFetchGenerationByUrl =
      _FetchGenerationsByUrl();
  static final _FetchGenerationsByUrl _latestPreviewFetchGenerationByUrl =
      _FetchGenerationsByUrl();
  static final _BlockedCacheUrls _blockedThumbnailCacheUrls =
      _BlockedCacheUrls();
  static final _BlockedCacheUrls _blockedPreviewCacheUrls = _BlockedCacheUrls();

  static final CacheManager thumbnailCache = CacheManager(
    Config(
      'templateThumbnailCache',
      stalePeriod: AppConfig.mediaCacheStalePeriod,
      maxNrOfCacheObjects: _maxThumbnailFileReferences,
      repo: JsonCacheInfoRepository(databaseName: 'templateThumbnailCache'),
      fileService: BoundedHttpFileService(
        maxBytes: _maxThumbnailDownloadBytes,
        mediaKind: 'thumbnail',
      ),
    ),
  );

  static final CacheManager previewVideoCache = CacheManager(
    Config(
      'templatePreviewVideoCache',
      stalePeriod: AppConfig.mediaCacheStalePeriod,
      maxNrOfCacheObjects: _maxPreviewFileReferences,
      repo: JsonCacheInfoRepository(databaseName: 'templatePreviewVideoCache'),
      fileService: BoundedHttpFileService(
        maxBytes: _maxPreviewDownloadBytes,
        mediaKind: 'preview',
        maxConcurrentFetches: 3,
      ),
    ),
  );

  @visibleForTesting
  static int get maxThumbnailDownloadBytesForTesting =>
      _maxThumbnailDownloadBytes;

  @visibleForTesting
  static int get maxPreviewDownloadBytesForTesting => _maxPreviewDownloadBytes;

  @visibleForTesting
  static int get rememberedFileReferenceCountForTesting =>
      _thumbnailFilesByUrl.length + _previewFilesByUrl.length;

  static String cacheKeyForMedia(String url, {int? mediaVersion}) =>
      _TemplateMediaCacheMaintenance.cacheKeyForMedia(
        url,
        mediaVersion: mediaVersion,
      );

  static Future<File?> getCachedPreviewFile(String url, {int? mediaVersion}) =>
      _TemplateMediaCacheMaintenance.getCachedPreviewFile(
        url,
        mediaVersion: mediaVersion,
      );

  static Future<File?> getCachedThumbnailFile(
    String url, {
    int? mediaVersion,
  }) => _TemplateMediaCacheMaintenance.getCachedThumbnailFile(
    url,
    mediaVersion: mediaVersion,
  );

  static Future<File> fetchThumbnailFile(
    String url, {
    int? mediaVersion,
    MediaPrefetchBudget? prefetchBudget,
  }) => _TemplateMediaCacheDownloads.fetch(
    url,
    preview: false,
    mediaVersion: mediaVersion,
    prefetchBudget: prefetchBudget,
  );
  static Future<File> _fetchThumbnailFile(
    String url, {
    required String cacheKey,
    required int? mediaVersion,
    required int generation,
    required int urlInvalidation,
    MediaDownloadConstraint? constraint,
  }) async {
    final cachedFile = await getCachedThumbnailFile(
      url,
      mediaVersion: mediaVersion,
    );
    if (cachedFile != null) {
      return cachedFile;
    }

    if (_blockedThumbnailCacheUrls.contains(cacheKey)) {
      await _TemplateMediaCacheMaintenance._removeCacheManagerFile(
        thumbnailCache,
        cacheKey,
        stage: 'thumbnail_blocked_cache_remove',
      );
    }

    final file = await _TemplateMediaCacheStorage.download(
      thumbnailCache,
      url,
      cacheKey: cacheKey,
      preview: false,
      constraint: constraint,
    );
    if (!_TemplateMediaCacheMaintenance._isCurrentFetch(
      cacheKey,
      generation: generation,
      urlInvalidation: urlInvalidation,
      invalidationsByUrl: _thumbnailInvalidationByUrl,
    )) {
      if (_TemplateMediaCacheMaintenance._canInvalidateCompletedFetch(
        cacheKey,
        generation: generation,
        latestFetchGenerationsByUrl: _latestThumbnailFetchGenerationByUrl,
      )) {
        _TemplateMediaCacheMaintenance._blockThumbnailCacheUrl(cacheKey);
        await _TemplateMediaCacheMaintenance._removeCacheManagerFile(
          thumbnailCache,
          cacheKey,
          stage: 'thumbnail_invalidated_fetch_remove',
        );
      }
      throw StateError('template_thumbnail_cache_invalidated');
    }

    _TemplateMediaCacheMaintenance._rememberFile(
      _thumbnailFilesByUrl,
      cacheKey,
      file,
      validTill: await MediaCacheTracking.cacheValidTill(
        thumbnailCache,
        cacheKey,
        fallbackValidTill: DateTime.now().add(AppConfig.mediaCacheStalePeriod),
        onFailure: _TemplateMediaCacheMaintenance._logCacheFailure,
      ),
      maxEntries: _maxThumbnailFileReferences,
    );
    _blockedThumbnailCacheUrls.remove(cacheKey);
    TemplateMediaCacheBudget.scheduleThumbnail(
      file.parent,
      onFailure: _TemplateMediaCacheMaintenance._logCacheFailure,
    );
    return file;
  }

  static Future<File> fetchPreviewFile(
    String url, {
    int? mediaVersion,
    MediaPrefetchBudget? prefetchBudget,
  }) => _TemplateMediaCacheDownloads.fetch(
    url,
    preview: true,
    mediaVersion: mediaVersion,
    prefetchBudget: prefetchBudget,
  );
  static Future<File> _fetchPreviewFile(
    String url, {
    required String cacheKey,
    required int? mediaVersion,
    required int generation,
    required int urlInvalidation,
    MediaDownloadConstraint? constraint,
  }) async {
    final cachedFile = await getCachedPreviewFile(
      url,
      mediaVersion: mediaVersion,
    );
    if (cachedFile != null) {
      return cachedFile;
    }

    if (_blockedPreviewCacheUrls.contains(cacheKey)) {
      await _TemplateMediaCacheMaintenance._removeCacheManagerFile(
        previewVideoCache,
        cacheKey,
        stage: 'preview_blocked_cache_remove',
      );
    }

    final file = await _TemplateMediaCacheStorage.download(
      previewVideoCache,
      url,
      cacheKey: cacheKey,
      preview: true,
      constraint: constraint,
    );
    if (!_TemplateMediaCacheMaintenance._isCurrentFetch(
      cacheKey,
      generation: generation,
      urlInvalidation: urlInvalidation,
      invalidationsByUrl: _previewInvalidationByUrl,
    )) {
      if (_TemplateMediaCacheMaintenance._canInvalidateCompletedFetch(
        cacheKey,
        generation: generation,
        latestFetchGenerationsByUrl: _latestPreviewFetchGenerationByUrl,
      )) {
        _TemplateMediaCacheMaintenance._blockPreviewCacheUrl(cacheKey);
        await _TemplateMediaCacheMaintenance._removeCacheManagerFile(
          previewVideoCache,
          cacheKey,
          stage: 'preview_invalidated_fetch_remove',
        );
      }
      throw StateError('template_preview_cache_invalidated');
    }

    _TemplateMediaCacheMaintenance._rememberFile(
      _previewFilesByUrl,
      cacheKey,
      file,
      validTill: await MediaCacheTracking.cacheValidTill(
        previewVideoCache,
        cacheKey,
        fallbackValidTill: DateTime.now().add(AppConfig.mediaCacheStalePeriod),
        onFailure: _TemplateMediaCacheMaintenance._logCacheFailure,
      ),
      maxEntries: _maxPreviewFileReferences,
    );
    _blockedPreviewCacheUrls.remove(cacheKey);
    TemplateMediaCacheBudget.schedulePreview(
      file.parent,
      onFailure: _TemplateMediaCacheMaintenance._logCacheFailure,
    );
    return file;
  }

  static Future<void> removeThumbnailFile(String url, {int? mediaVersion}) =>
      _TemplateMediaCacheMaintenance.removeThumbnailFile(
        url,
        mediaVersion: mediaVersion,
      );

  static Future<void> removePreviewFile(String url, {int? mediaVersion}) =>
      _TemplateMediaCacheMaintenance.removePreviewFile(
        url,
        mediaVersion: mediaVersion,
      );

  /// Releases bounded in-memory file lookups while preserving disk cache and
  /// in-flight fetch coordination. Disk metadata is resolved again on demand.
  static void releaseMemoryReferences() =>
      _TemplateMediaCacheMaintenance.releaseMemoryReferences();

  @visibleForTesting
  static Future<int> trimThumbnailCacheDirectoryForTesting(
    Directory thumbnailCacheDirectory, {
    required int maxBytes,
  }) => _TemplateMediaCacheMaintenance.trimThumbnailCacheDirectoryForTesting(
    thumbnailCacheDirectory,
    maxBytes: maxBytes,
  );

  @visibleForTesting
  static Future<int> trimPreviewCacheDirectoryForTesting(
    Directory previewCacheDirectory, {
    required int maxBytes,
  }) => _TemplateMediaCacheMaintenance.trimPreviewCacheDirectoryForTesting(
    previewCacheDirectory,
    maxBytes: maxBytes,
  );

  static Future<void> clearAll() => _TemplateMediaCacheMaintenance.clearAll();
}
