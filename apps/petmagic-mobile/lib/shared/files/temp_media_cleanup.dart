import 'dart:io';

import 'package:petmagic_mobile/core/config/app_config.dart';

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
        await sweepExpiredFiles();
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
      } catch (_) {
        // Best effort cleanup: skip inaccessible files.
      }
    }
  }

  static Future<void> deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best effort cleanup.
    }
  }
}
