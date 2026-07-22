import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/performance/bounded_http_file_service.dart';
import 'package:petmagic_mobile/core/performance/media_cache_tracking.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache_budget.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';

part 'template_media_cache_maintenance.part.dart';

typedef _RememberedFilesByUrl = LinkedHashMap<String, _RememberedCacheFile>;
typedef _InvalidationCountsByUrl = LinkedHashMap<String, int>;
typedef _FetchGenerationsByUrl = LinkedHashMap<String, int>;
typedef _BlockedCacheUrls = LinkedHashSet<String>;

class TemplateMediaCache {
  TemplateMediaCache._();

  static const int _maxThumbnailFileReferences = 300;
  // Sized so a long feed session does not evict-and-redownload the same preview
  // videos: ~250 clips at 1-2 MB each stays inside the dedicated byte budget
  // (AppConfig.previewVideoCacheMaxBytes) which remains the hard disk cap.
  static const int _maxPreviewFileReferences = 250;
  static const int _maxBlockedThumbnailCacheUrls = _maxThumbnailFileReferences;
  static const int _maxBlockedPreviewCacheUrls = _maxPreviewFileReferences;
  static const int _maxThumbnailInFlightFetches = 64;
  static const int _maxPreviewInFlightFetches = 32;
  static const int _maxThumbnailDownloadBytes = 8 * 1024 * 1024;
  static const int _maxPreviewDownloadBytes = 24 * 1024 * 1024;
  static int _cacheGeneration = 0;
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
      ),
    ),
  );

  @visibleForTesting
  static int get maxThumbnailDownloadBytesForTesting =>
      _maxThumbnailDownloadBytes;

  @visibleForTesting
  static int get maxPreviewDownloadBytesForTesting => _maxPreviewDownloadBytes;

  static String cacheKeyForMedia(String url, {int? mediaVersion}) {
    final normalized = persistentSafeMediaCacheKeyUrl(url);
    if (mediaVersion == null || mediaVersion <= 0) {
      return normalized;
    }

    return 'v$mediaVersion|$normalized';
  }

  static Future<File?> getCachedPreviewFile(String url, {int? mediaVersion}) =>
      _TemplateMediaCacheMaintenance.getCachedPreviewFile(
        url,
        mediaVersion: mediaVersion,
      );

  static Future<File?> getCachedThumbnailFile(
    String url, {
    int? mediaVersion,
  }) async {
    final cacheKey = cacheKeyForMedia(url, mediaVersion: mediaVersion);
    if (_blockedThumbnailCacheUrls.contains(cacheKey)) {
      return null;
    }

    final rememberedFile =
        await _TemplateMediaCacheMaintenance._getRememberedFile(
          _thumbnailFilesByUrl,
          cacheKey,
          maxEntries: _maxThumbnailFileReferences,
        );
    if (rememberedFile != null) {
      return rememberedFile;
    }

    final cachedFile = await thumbnailCache.getFileFromCache(cacheKey);
    final file = cachedFile?.file;
    if (cachedFile == null ||
        !cachedFile.validTill.isAfter(DateTime.now()) ||
        file == null ||
        !await file.exists()) {
      return null;
    }

    _TemplateMediaCacheMaintenance._rememberFile(
      _thumbnailFilesByUrl,
      cacheKey,
      file,
      validTill: cachedFile.validTill,
      maxEntries: _maxThumbnailFileReferences,
    );
    return file;
  }

  static Future<File> fetchThumbnailFile(String url, {int? mediaVersion}) {
    final cacheKey = cacheKeyForMedia(url, mediaVersion: mediaVersion);
    final inFlightFetch = _thumbnailFetchesByUrl[cacheKey];
    if (inFlightFetch != null) {
      return inFlightFetch;
    }

    late final Future<File> fetch;
    final generation = _cacheGeneration;
    final urlInvalidation = _thumbnailInvalidationByUrl[cacheKey] ?? 0;
    MediaCacheTracking.rememberLatestGeneration(
      _latestThumbnailFetchGenerationByUrl,
      cacheKey,
      generation,
      maxEntries: _maxBlockedThumbnailCacheUrls,
    );
    fetch =
        _fetchThumbnailFile(
          url,
          cacheKey: cacheKey,
          mediaVersion: mediaVersion,
          generation: generation,
          urlInvalidation: urlInvalidation,
        ).whenComplete(() {
          if (identical(_thumbnailFetchesByUrl[cacheKey], fetch)) {
            _thumbnailFetchesByUrl.remove(cacheKey);
          }
        });
    MediaCacheTracking.rememberInFlightFetch(
      _thumbnailFetchesByUrl,
      cacheKey,
      fetch,
      maxEntries: _maxThumbnailInFlightFetches,
    );
    return fetch;
  }

  static Future<File> _fetchThumbnailFile(
    String url, {
    required String cacheKey,
    required int? mediaVersion,
    required int generation,
    required int urlInvalidation,
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

    final file = await thumbnailCache.getSingleFile(url, key: cacheKey);
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

  static Future<File> fetchPreviewFile(String url, {int? mediaVersion}) {
    final cacheKey = cacheKeyForMedia(url, mediaVersion: mediaVersion);
    final inFlightFetch = _previewFetchesByUrl[cacheKey];
    if (inFlightFetch != null) {
      return inFlightFetch;
    }

    late final Future<File> fetch;
    final generation = _cacheGeneration;
    final urlInvalidation = _previewInvalidationByUrl[cacheKey] ?? 0;
    MediaCacheTracking.rememberLatestGeneration(
      _latestPreviewFetchGenerationByUrl,
      cacheKey,
      generation,
      maxEntries: _maxBlockedPreviewCacheUrls,
    );
    fetch =
        _fetchPreviewFile(
              url,
              cacheKey: cacheKey,
              mediaVersion: mediaVersion,
              generation: generation,
              urlInvalidation: urlInvalidation,
            )
            .then((file) {
              TemplateMediaCacheBudget.schedulePreview(
                file.parent,
                onFailure: _TemplateMediaCacheMaintenance._logCacheFailure,
              );
              return file;
            })
            .whenComplete(() {
              if (identical(_previewFetchesByUrl[cacheKey], fetch)) {
                _previewFetchesByUrl.remove(cacheKey);
              }
            });
    MediaCacheTracking.rememberInFlightFetch(
      _previewFetchesByUrl,
      cacheKey,
      fetch,
      maxEntries: _maxPreviewInFlightFetches,
    );
    return fetch;
  }

  static Future<File> _fetchPreviewFile(
    String url, {
    required String cacheKey,
    required int? mediaVersion,
    required int generation,
    required int urlInvalidation,
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

    final file = await previewVideoCache.getSingleFile(url, key: cacheKey);
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
