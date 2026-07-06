import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';

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
  static bool _isThumbnailBudgetCleanupRunning = false;
  static bool _isPreviewBudgetCleanupRunning = false;
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
      fileService: _BoundedHttpFileService(
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
      fileService: _BoundedHttpFileService(
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

  static Future<File?> getCachedPreviewFile(
    String url, {
    int? mediaVersion,
  }) async {
    final cacheKey = cacheKeyForMedia(url, mediaVersion: mediaVersion);
    if (_blockedPreviewCacheUrls.contains(cacheKey)) {
      return null;
    }

    final rememberedFile = await _getRememberedFile(
      _previewFilesByUrl,
      cacheKey,
      maxEntries: _maxPreviewFileReferences,
    );
    if (rememberedFile != null) {
      return rememberedFile;
    }

    final cachedFile = await previewVideoCache.getFileFromCache(cacheKey);
    final file = cachedFile?.file;
    if (cachedFile == null ||
        !cachedFile.validTill.isAfter(DateTime.now()) ||
        file == null ||
        !await file.exists()) {
      return null;
    }

    _rememberFile(
      _previewFilesByUrl,
      cacheKey,
      file,
      validTill: cachedFile.validTill,
      maxEntries: _maxPreviewFileReferences,
    );
    return file;
  }

  static Future<File?> getCachedThumbnailFile(
    String url, {
    int? mediaVersion,
  }) async {
    final cacheKey = cacheKeyForMedia(url, mediaVersion: mediaVersion);
    if (_blockedThumbnailCacheUrls.contains(cacheKey)) {
      return null;
    }

    final rememberedFile = await _getRememberedFile(
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

    _rememberFile(
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
    _rememberLatestFetchGeneration(
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
    _rememberInFlightFetch(
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
      await _removeCacheManagerFile(
        thumbnailCache,
        cacheKey,
        stage: 'thumbnail_blocked_cache_remove',
      );
    }

    final file = await thumbnailCache.getSingleFile(url, key: cacheKey);
    if (!_isCurrentFetch(
      cacheKey,
      generation: generation,
      urlInvalidation: urlInvalidation,
      invalidationsByUrl: _thumbnailInvalidationByUrl,
    )) {
      if (_canInvalidateCompletedFetch(
        cacheKey,
        generation: generation,
        latestFetchGenerationsByUrl: _latestThumbnailFetchGenerationByUrl,
      )) {
        _blockThumbnailCacheUrl(cacheKey);
        await _removeCacheManagerFile(
          thumbnailCache,
          cacheKey,
          stage: 'thumbnail_invalidated_fetch_remove',
        );
      }
      throw StateError('template_thumbnail_cache_invalidated');
    }

    _rememberFile(
      _thumbnailFilesByUrl,
      cacheKey,
      file,
      validTill: await _cacheValidTill(
        thumbnailCache,
        cacheKey,
        fallbackValidTill: DateTime.now().add(AppConfig.mediaCacheStalePeriod),
      ),
      maxEntries: _maxThumbnailFileReferences,
    );
    _blockedThumbnailCacheUrls.remove(cacheKey);
    _scheduleThumbnailBudgetCleanup(file.parent);
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
    _rememberLatestFetchGeneration(
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
              _schedulePreviewBudgetCleanup(file.parent);
              return file;
            })
            .whenComplete(() {
              if (identical(_previewFetchesByUrl[cacheKey], fetch)) {
                _previewFetchesByUrl.remove(cacheKey);
              }
            });
    _rememberInFlightFetch(
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
      await _removeCacheManagerFile(
        previewVideoCache,
        cacheKey,
        stage: 'preview_blocked_cache_remove',
      );
    }

    final file = await previewVideoCache.getSingleFile(url, key: cacheKey);
    if (!_isCurrentFetch(
      cacheKey,
      generation: generation,
      urlInvalidation: urlInvalidation,
      invalidationsByUrl: _previewInvalidationByUrl,
    )) {
      if (_canInvalidateCompletedFetch(
        cacheKey,
        generation: generation,
        latestFetchGenerationsByUrl: _latestPreviewFetchGenerationByUrl,
      )) {
        _blockPreviewCacheUrl(cacheKey);
        await _removeCacheManagerFile(
          previewVideoCache,
          cacheKey,
          stage: 'preview_invalidated_fetch_remove',
        );
      }
      throw StateError('template_preview_cache_invalidated');
    }

    _rememberFile(
      _previewFilesByUrl,
      cacheKey,
      file,
      validTill: await _cacheValidTill(
        previewVideoCache,
        cacheKey,
        fallbackValidTill: DateTime.now().add(AppConfig.mediaCacheStalePeriod),
      ),
      maxEntries: _maxPreviewFileReferences,
    );
    _blockedPreviewCacheUrls.remove(cacheKey);
    return file;
  }

  static Future<void> removeThumbnailFile(
    String url, {
    int? mediaVersion,
  }) async {
    final cacheKey = cacheKeyForMedia(url, mediaVersion: mediaVersion);
    _invalidateThumbnailCacheUrl(cacheKey);
    _thumbnailFetchesByUrl.remove(cacheKey);
    await thumbnailCache.removeFile(cacheKey);
  }

  static Future<void> removePreviewFile(String url, {int? mediaVersion}) {
    final cacheKey = cacheKeyForMedia(url, mediaVersion: mediaVersion);
    _invalidatePreviewCacheUrl(cacheKey);
    _previewFetchesByUrl.remove(cacheKey);
    return previewVideoCache.removeFile(cacheKey);
  }

  @visibleForTesting
  static Future<int> trimThumbnailCacheDirectoryForTesting(
    Directory thumbnailCacheDirectory, {
    required int maxBytes,
  }) {
    return _trimCacheDirectory(
      thumbnailCacheDirectory,
      maxBytes: maxBytes,
      statStage: 'thumbnail_budget_stat_file',
      deleteStage: 'thumbnail_budget_delete_file',
    );
  }

  @visibleForTesting
  static Future<int> trimPreviewCacheDirectoryForTesting(
    Directory previewCacheDirectory, {
    required int maxBytes,
  }) {
    return _trimCacheDirectory(
      previewCacheDirectory,
      maxBytes: maxBytes,
      statStage: 'preview_budget_stat_file',
      deleteStage: 'preview_budget_delete_file',
    );
  }

  static Future<void> clearAll() async {
    _cacheGeneration++;
    _thumbnailFilesByUrl.clear();
    _previewFilesByUrl.clear();
    _thumbnailFetchesByUrl.clear();
    _previewFetchesByUrl.clear();
    _thumbnailInvalidationByUrl.clear();
    _previewInvalidationByUrl.clear();
    _latestThumbnailFetchGenerationByUrl.clear();
    _latestPreviewFetchGenerationByUrl.clear();
    _blockedThumbnailCacheUrls.clear();
    _blockedPreviewCacheUrls.clear();

    try {
      await thumbnailCache.emptyCache();
    } catch (error, stackTrace) {
      _logCacheFailure('clear_thumbnail_cache', error, stackTrace);
      // Keep best-effort semantics for logout cleanup.
    }

    try {
      await previewVideoCache.emptyCache();
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
    final currentInvalidation = _thumbnailInvalidationByUrl.remove(url) ?? 0;
    _thumbnailInvalidationByUrl[url] = currentInvalidation + 1;
    _blockThumbnailCacheUrl(url);
    _trimInvalidationMap(
      _thumbnailInvalidationByUrl,
      _blockedThumbnailCacheUrls,
      maxEntries: _maxBlockedThumbnailCacheUrls,
    );
  }

  static void _invalidatePreviewCacheUrl(String url) {
    final currentInvalidation = _previewInvalidationByUrl.remove(url) ?? 0;
    _previewInvalidationByUrl[url] = currentInvalidation + 1;
    _blockPreviewCacheUrl(url);
    _trimInvalidationMap(
      _previewInvalidationByUrl,
      _blockedPreviewCacheUrls,
      maxEntries: _maxBlockedPreviewCacheUrls,
    );
  }

  static void _blockThumbnailCacheUrl(String url) {
    _thumbnailFilesByUrl.remove(url);
    _blockedThumbnailCacheUrls.remove(url);
    _blockedThumbnailCacheUrls.add(url);
    _trimBlockedCacheUrls(
      _blockedThumbnailCacheUrls,
      maxEntries: _maxBlockedThumbnailCacheUrls,
    );
  }

  static void _blockPreviewCacheUrl(String url) {
    _previewFilesByUrl.remove(url);
    _blockedPreviewCacheUrls.remove(url);
    _blockedPreviewCacheUrls.add(url);
    _trimBlockedCacheUrls(
      _blockedPreviewCacheUrls,
      maxEntries: _maxBlockedPreviewCacheUrls,
    );
  }

  static bool _isCurrentFetch(
    String url, {
    required int generation,
    required int urlInvalidation,
    required _InvalidationCountsByUrl invalidationsByUrl,
  }) {
    return generation == _cacheGeneration &&
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

  static void _trimInvalidationMap(
    _InvalidationCountsByUrl invalidationsByUrl,
    _BlockedCacheUrls blockedCacheUrls, {
    required int maxEntries,
  }) {
    while (invalidationsByUrl.length > maxEntries) {
      final oldestUrl = invalidationsByUrl.keys.first;
      invalidationsByUrl.remove(oldestUrl);
      blockedCacheUrls.remove(oldestUrl);
    }
  }

  static void _trimBlockedCacheUrls(
    _BlockedCacheUrls blockedCacheUrls, {
    required int maxEntries,
  }) {
    while (blockedCacheUrls.length > maxEntries) {
      blockedCacheUrls.remove(blockedCacheUrls.first);
    }
  }

  static void _rememberLatestFetchGeneration(
    _FetchGenerationsByUrl latestFetchGenerationsByUrl,
    String url,
    int generation, {
    required int maxEntries,
  }) {
    latestFetchGenerationsByUrl.remove(url);
    latestFetchGenerationsByUrl[url] = generation;
    while (latestFetchGenerationsByUrl.length > maxEntries) {
      latestFetchGenerationsByUrl.remove(
        latestFetchGenerationsByUrl.keys.first,
      );
    }
  }

  static void _rememberInFlightFetch(
    Map<String, Future<File>> fetchesByUrl,
    String url,
    Future<File> fetch, {
    required int maxEntries,
  }) {
    fetchesByUrl.remove(url);
    fetchesByUrl[url] = fetch;
    while (fetchesByUrl.length > maxEntries) {
      fetchesByUrl.remove(fetchesByUrl.keys.first);
    }
  }

  static Future<DateTime> _cacheValidTill(
    CacheManager cacheManager,
    String url, {
    required DateTime fallbackValidTill,
  }) async {
    try {
      return (await cacheManager.getFileFromCache(url))?.validTill ??
          fallbackValidTill;
    } catch (error, stackTrace) {
      _logCacheFailure('cache_valid_till_lookup', error, stackTrace);
      return fallbackValidTill;
    }
  }

  static void _schedulePreviewBudgetCleanup(Directory previewCacheDirectory) {
    if (_isPreviewBudgetCleanupRunning) {
      return;
    }

    _isPreviewBudgetCleanupRunning = true;
    Future<void>(() async {
      try {
        await _trimCacheDirectory(
          previewCacheDirectory,
          maxBytes: AppConfig.previewVideoCacheMaxBytesSafe,
          statStage: 'preview_budget_stat_file',
          deleteStage: 'preview_budget_delete_file',
        );
      } catch (error, stackTrace) {
        _logCacheFailure('preview_budget_cleanup', error, stackTrace);
      } finally {
        _isPreviewBudgetCleanupRunning = false;
      }
    });
  }

  static void _scheduleThumbnailBudgetCleanup(
    Directory thumbnailCacheDirectory,
  ) {
    if (_isThumbnailBudgetCleanupRunning) {
      return;
    }

    _isThumbnailBudgetCleanupRunning = true;
    Future<void>(() async {
      try {
        await _trimCacheDirectory(
          thumbnailCacheDirectory,
          maxBytes: AppConfig.mediaCacheMaxBytesSafe,
          statStage: 'thumbnail_budget_stat_file',
          deleteStage: 'thumbnail_budget_delete_file',
        );
      } catch (error, stackTrace) {
        _logCacheFailure('thumbnail_budget_cleanup', error, stackTrace);
      } finally {
        _isThumbnailBudgetCleanupRunning = false;
      }
    });
  }

  static Future<int> _trimCacheDirectory(
    Directory cacheDirectory, {
    required int maxBytes,
    required String statStage,
    required String deleteStage,
  }) async {
    if (!await cacheDirectory.exists()) {
      return 0;
    }

    final safeMaxBytes = maxBytes < 0 ? 0 : maxBytes;
    final entities = await cacheDirectory.list().toList();
    final files = <File>[];
    for (final entity in entities) {
      if (entity is File) {
        files.add(entity);
      }
    }

    if (files.isEmpty) {
      return 0;
    }

    final stats = <_CacheFileStat>[];
    var totalBytes = 0;

    for (final file in files) {
      try {
        final stat = await file.stat();
        if (stat.type != FileSystemEntityType.file) {
          continue;
        }

        final fileSize = stat.size;
        totalBytes += fileSize;
        stats.add(_CacheFileStat(file, fileSize, stat.modified));
      } catch (error, stackTrace) {
        _logCacheFailure(statStage, error, stackTrace);
        // Skip files that cannot be stat'ed.
      }
    }

    if (totalBytes <= safeMaxBytes) {
      return totalBytes;
    }

    stats.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
    for (final item in stats) {
      if (totalBytes <= safeMaxBytes) {
        break;
      }

      try {
        await item.file.delete();
        totalBytes -= item.sizeBytes;
      } catch (error, stackTrace) {
        _logCacheFailure(deleteStage, error, stackTrace);
        // Keep best-effort semantics.
      }
    }

    return totalBytes;
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
}

class _CacheFileStat {
  const _CacheFileStat(this.file, this.sizeBytes, this.modifiedAt);

  final File file;
  final int sizeBytes;
  final DateTime modifiedAt;
}

class _RememberedCacheFile {
  const _RememberedCacheFile(this.file, this.validTill);

  final File file;
  final DateTime validTill;
}

class _BoundedHttpFileService extends FileService {
  _BoundedHttpFileService({required this.maxBytes, required this.mediaKind}) {
    concurrentFetches = _delegate.concurrentFetches;
  }

  final int maxBytes;
  final String mediaKind;
  final HttpFileService _delegate = HttpFileService();

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await _delegate.get(url, headers: headers);
    final contentLength = response.contentLength;
    if (contentLength != null && contentLength > maxBytes) {
      throw StateError('template_${mediaKind}_download_too_large');
    }

    return _BoundedFileServiceResponse(
      response,
      maxBytes: maxBytes,
      mediaKind: mediaKind,
    );
  }
}

class _BoundedFileServiceResponse implements FileServiceResponse {
  const _BoundedFileServiceResponse(
    this._inner, {
    required this.maxBytes,
    required this.mediaKind,
  });

  final FileServiceResponse _inner;
  final int maxBytes;
  final String mediaKind;

  @override
  Stream<List<int>> get content async* {
    var receivedBytes = 0;
    await for (final chunk in _inner.content) {
      receivedBytes += chunk.length;
      if (receivedBytes > maxBytes) {
        throw StateError('template_${mediaKind}_download_too_large');
      }

      yield chunk;
    }
  }

  @override
  int? get contentLength => _inner.contentLength;

  @override
  String? get eTag => _inner.eTag;

  @override
  String get fileExtension => _inner.fileExtension;

  @override
  int get statusCode => _inner.statusCode;

  @override
  DateTime get validTill => _inner.validTill;
}
