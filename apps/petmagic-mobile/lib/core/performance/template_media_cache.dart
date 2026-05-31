import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';

class TemplateMediaCache {
  TemplateMediaCache._();

  static bool _isPreviewBudgetCleanupRunning = false;

  static final CacheManager thumbnailCache = CacheManager(
    Config(
      'templateThumbnailCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 300,
      repo: JsonCacheInfoRepository(databaseName: 'templateThumbnailCache'),
      fileService: HttpFileService(),
    ),
  );

  static final CacheManager previewVideoCache = CacheManager(
    Config(
      'templatePreviewVideoCache',
      stalePeriod: AppConfig.mediaCacheStalePeriod,
      maxNrOfCacheObjects: 80,
      repo: JsonCacheInfoRepository(databaseName: 'templatePreviewVideoCache'),
      fileService: HttpFileService(),
    ),
  );

  static Future<File?> getCachedPreviewFile(String url) async {
    final cachedFile = await previewVideoCache.getFileFromCache(url);
    return cachedFile?.file;
  }

  static Future<File> fetchPreviewFile(String url) {
    return previewVideoCache.getSingleFile(url).then((file) {
      _schedulePreviewBudgetCleanup(file.parent);
      return file;
    });
  }

  static Future<void> removePreviewFile(String url) {
    return previewVideoCache.removeFile(url);
  }

  static Future<void> clearAll() async {
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

  static void _schedulePreviewBudgetCleanup(Directory previewCacheDirectory) {
    if (_isPreviewBudgetCleanupRunning) {
      return;
    }

    _isPreviewBudgetCleanupRunning = true;
    Future<void>(() async {
      try {
        final entities = await previewCacheDirectory.list().toList();
        final files = <File>[];
        for (final entity in entities) {
          if (entity is File) {
            files.add(entity);
          }
        }

        if (files.isEmpty) {
          return;
        }

        final stats = <_PreviewCacheFileStat>[];
        var totalBytes = 0;

        for (final file in files) {
          try {
            final stat = await file.stat();
            if (stat.type != FileSystemEntityType.file) {
              continue;
            }

            final fileSize = stat.size;
            totalBytes += fileSize;
            stats.add(_PreviewCacheFileStat(file, fileSize, stat.modified));
          } catch (error, stackTrace) {
            _logCacheFailure('preview_budget_stat_file', error, stackTrace);
            // Skip files that cannot be stat'ed.
          }
        }

        if (totalBytes <= AppConfig.mediaCacheMaxBytesSafe) {
          return;
        }

        stats.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
        for (final item in stats) {
          if (totalBytes <= AppConfig.mediaCacheMaxBytesSafe) {
            break;
          }

          try {
            await item.file.delete();
            totalBytes -= item.sizeBytes;
          } catch (error, stackTrace) {
            _logCacheFailure('preview_budget_delete_file', error, stackTrace);
            // Keep best-effort semantics.
          }
        }
      } catch (error, stackTrace) {
        _logCacheFailure('preview_budget_cleanup', error, stackTrace);
      } finally {
        _isPreviewBudgetCleanupRunning = false;
      }
    });
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

class _PreviewCacheFileStat {
  const _PreviewCacheFileStat(this.file, this.sizeBytes, this.modifiedAt);

  final File file;
  final int sizeBytes;
  final DateTime modifiedAt;
}
