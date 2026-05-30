import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class TemplateMediaCache {
  TemplateMediaCache._();

  static const int _previewMaxTotalBytes = 280 * 1024 * 1024;
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
      stalePeriod: const Duration(days: 3),
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
          } catch (_) {
            // Skip files that cannot be stat'ed.
          }
        }

        if (totalBytes <= _previewMaxTotalBytes) {
          return;
        }

        stats.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
        for (final item in stats) {
          if (totalBytes <= _previewMaxTotalBytes) {
            break;
          }

          try {
            await item.file.delete();
            totalBytes -= item.sizeBytes;
          } catch (_) {
            // Keep best-effort semantics.
          }
        }
      } finally {
        _isPreviewBudgetCleanupRunning = false;
      }
    });
  }
}

class _PreviewCacheFileStat {
  const _PreviewCacheFileStat(this.file, this.sizeBytes, this.modifiedAt);

  final File file;
  final int sizeBytes;
  final DateTime modifiedAt;
}
