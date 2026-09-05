import 'dart:io';

import 'package:petmagic_mobile/core/config/app_config.dart';

typedef MediaCacheFailureLogger =
    void Function(String stage, Object error, StackTrace stackTrace);

/// Owns disk byte-budget enforcement independently from fetch coordination.
final class TemplateMediaCacheBudget {
  TemplateMediaCacheBudget._();

  static bool _thumbnailCleanupRunning = false;
  static bool _previewCleanupRunning = false;
  static bool _thumbnailCleanupRequested = false;
  static bool _previewCleanupRequested = false;
  static bool _thumbnailBudgetChecked = false;
  static bool _previewBudgetChecked = false;
  static const _accessWriteInterval = Duration(minutes: 1);
  static const _maxAccessReferences = 550;
  static final _lastAccessByPath = <String, DateTime>{};

  /// Persist recency without reading media bytes or writing on every rebuild.
  /// The byte budget uses this timestamp across page changes and app restarts.
  static Future<bool> recordAccess(
    File file, {
    required MediaCacheFailureLogger onFailure,
  }) async {
    final now = DateTime.now();
    final previous = _lastAccessByPath[file.path];
    if (previous != null && now.difference(previous) < _accessWriteInterval) {
      return false;
    }
    _lastAccessByPath.remove(file.path);
    _lastAccessByPath[file.path] = now;
    while (_lastAccessByPath.length > _maxAccessReferences) {
      _lastAccessByPath.remove(_lastAccessByPath.keys.first);
    }
    try {
      await file.setLastModified(now);
      return true;
    } catch (error, stackTrace) {
      _lastAccessByPath.remove(file.path);
      onFailure('cache_access_timestamp', error, stackTrace);
      return false;
    }
  }

  static void releaseMemoryReferences() => _lastAccessByPath.clear();

  static void ensurePreviewBudget(
    Directory directory, {
    required MediaCacheFailureLogger onFailure,
  }) {
    if (!_previewBudgetChecked) {
      schedulePreview(directory, onFailure: onFailure);
    }
  }

  static void ensureThumbnailBudget(
    Directory directory, {
    required MediaCacheFailureLogger onFailure,
  }) {
    if (!_thumbnailBudgetChecked) {
      scheduleThumbnail(directory, onFailure: onFailure);
    }
  }

  static void schedulePreview(
    Directory directory, {
    required MediaCacheFailureLogger onFailure,
  }) {
    _previewBudgetChecked = true;
    _previewCleanupRequested = true;
    if (_previewCleanupRunning) {
      return;
    }
    _previewCleanupRunning = true;
    Future<void>(() async {
      try {
        do {
          _previewCleanupRequested = false;
          await trimDirectory(
            directory,
            maxBytes: AppConfig.previewVideoCacheMaxBytesSafe,
            statStage: 'preview_budget_stat_file',
            deleteStage: 'preview_budget_delete_file',
            onFailure: onFailure,
          );
        } while (_previewCleanupRequested);
      } catch (error, stackTrace) {
        onFailure('preview_budget_cleanup', error, stackTrace);
      } finally {
        _previewCleanupRunning = false;
      }
    });
  }

  static void scheduleThumbnail(
    Directory directory, {
    required MediaCacheFailureLogger onFailure,
  }) {
    _thumbnailBudgetChecked = true;
    _thumbnailCleanupRequested = true;
    if (_thumbnailCleanupRunning) {
      return;
    }
    _thumbnailCleanupRunning = true;
    Future<void>(() async {
      try {
        do {
          _thumbnailCleanupRequested = false;
          await trimDirectory(
            directory,
            maxBytes: AppConfig.mediaCacheMaxBytesSafe,
            statStage: 'thumbnail_budget_stat_file',
            deleteStage: 'thumbnail_budget_delete_file',
            onFailure: onFailure,
          );
        } while (_thumbnailCleanupRequested);
      } catch (error, stackTrace) {
        onFailure('thumbnail_budget_cleanup', error, stackTrace);
      } finally {
        _thumbnailCleanupRunning = false;
      }
    });
  }

  static Future<int> trimDirectory(
    Directory cacheDirectory, {
    required int maxBytes,
    required String statStage,
    required String deleteStage,
    required MediaCacheFailureLogger onFailure,
  }) async {
    if (!await cacheDirectory.exists()) {
      return 0;
    }

    final files = await cacheDirectory
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
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
        totalBytes += stat.size;
        stats.add(_CacheFileStat(file, stat.size, stat.modified));
      } catch (error, stackTrace) {
        onFailure(statStage, error, stackTrace);
      }
    }

    final safeMaxBytes = maxBytes < 0 ? 0 : maxBytes;
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
        _lastAccessByPath.remove(item.file.path);
        totalBytes -= item.sizeBytes;
      } catch (error, stackTrace) {
        onFailure(deleteStage, error, stackTrace);
      }
    }
    return totalBytes;
  }
}

final class _CacheFileStat {
  const _CacheFileStat(this.file, this.sizeBytes, this.modifiedAt);

  final File file;
  final int sizeBytes;
  final DateTime modifiedAt;
}
