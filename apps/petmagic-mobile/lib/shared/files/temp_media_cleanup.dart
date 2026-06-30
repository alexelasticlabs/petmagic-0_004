import 'dart:io';

import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';

class TempMediaCleanup {
  TempMediaCleanup._();

  static const String filePrefix = 'petmagic_';
  static bool _isSweepScheduled = false;

  static void scheduleTtlSweep() {
    if (_isSweepScheduled) {
      return;
    }

    _isSweepScheduled = true;
    Future<void>(() async {
      try {
        try {
          await sweepExpiredFiles();
        } catch (error, stackTrace) {
          AppLogger.warn(
            feature: 'Shared.TempMediaCleanup',
            operation: 'schedule_ttl_sweep',
            message: 'Scheduled temp media cleanup failed',
            error: error,
            stackTrace: stackTrace,
          );
        }
      } finally {
        _isSweepScheduled = false;
      }
    });
  }

  static Future<void> sweepExpiredFiles({
    Directory? tempDirectory,
    Duration? ttl,
    DateTime? now,
  }) async {
    final directory = tempDirectory ?? Directory.systemTemp;
    final threshold = (now ?? DateTime.now()).subtract(
      ttl ?? AppConfig.mediaTempFileTtl,
    );

    final entities = await directory.list().toList();
    for (final entity in entities) {
      if (entity is! File) {
        continue;
      }

      final name = entity.uri.pathSegments.isEmpty
          ? entity.path
          : entity.uri.pathSegments.last;
      if (!name.startsWith(filePrefix)) {
        continue;
      }

      try {
        final stat = await entity.stat();
        if (stat.type != FileSystemEntityType.file) {
          continue;
        }

        if (stat.modified.isAfter(threshold)) {
          continue;
        }

        await entity.delete();
      } catch (error, stackTrace) {
        AppLogger.warn(
          feature: 'Shared.TempMediaCleanup',
          operation: 'delete_expired_file',
          message: 'Temp media cleanup skipped inaccessible file',
          context: {'name': name},
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  static Future<void> deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Shared.TempMediaCleanup',
        operation: 'delete_if_exists',
        message: 'Temp media file deletion failed',
        context: {'name': _safeFileName(file)},
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static String _safeFileName(File file) {
    final segments = file.uri.pathSegments;
    return segments.isEmpty ? file.path : segments.last;
  }
}
