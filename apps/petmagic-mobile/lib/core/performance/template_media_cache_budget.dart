import 'dart:io';

import 'package:petmagic_mobile/core/config/app_config.dart';

typedef MediaCacheFailureLogger =
    void Function(String stage, Object error, StackTrace stackTrace);

/// Owns disk byte-budget enforcement independently from fetch coordination.
final class TemplateMediaCacheBudget {
  TemplateMediaCacheBudget._();

  static bool _thumbnailCleanupRunning = false;
  static bool _previewCleanupRunning = false;

  static void schedulePreview(
    Directory directory, {
    required MediaCacheFailureLogger onFailure,
  }) {
    if (_previewCleanupRunning) {
      return;
    }
    _previewCleanupRunning = true;
    Future<void>(() async {
      try {
        await trimDirectory(
          directory,
          maxBytes: AppConfig.previewVideoCacheMaxBytesSafe,
          statStage: 'preview_budget_stat_file',
          deleteStage: 'preview_budget_delete_file',
          onFailure: onFailure,
        );
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
    if (_thumbnailCleanupRunning) {
      return;
    }
    _thumbnailCleanupRunning = true;
    Future<void>(() async {
      try {
        await trimDirectory(
          directory,
          maxBytes: AppConfig.mediaCacheMaxBytesSafe,
          statStage: 'thumbnail_budget_stat_file',
          deleteStage: 'thumbnail_budget_delete_file',
          onFailure: onFailure,
        );
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
