import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';

class AppPerformanceMonitor extends StatefulWidget {
  const AppPerformanceMonitor({required this.child, super.key});

  final Widget child;

  @override
  State<AppPerformanceMonitor> createState() => _AppPerformanceMonitorState();
}

class _AppPerformanceMonitorState extends State<AppPerformanceMonitor> {
  Timer? _imageCacheTimer;

  @override
  void initState() {
    super.initState();

    if (AppConfig.enableFrameTelemetry) {
      SchedulerBinding.instance.addTimingsCallback(_handleFrameTimings);
    }

    if (AppConfig.enableImageCacheTelemetry) {
      _logImageCacheStats();
      _imageCacheTimer = Timer.periodic(
        Duration(seconds: AppConfig.imageCacheTelemetryIntervalSeconds),
        (_) => _logImageCacheStats(),
      );
    }
  }

  @override
  void dispose() {
    if (AppConfig.enableFrameTelemetry) {
      SchedulerBinding.instance.removeTimingsCallback(_handleFrameTimings);
    }

    _imageCacheTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    final frameBudgetMs = AppConfig.targetFrameBudgetMs.toDouble();

    for (final timing in timings) {
      final buildMs = timing.buildDuration.inMicroseconds / 1000;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000;
      final totalMs = timing.totalSpan.inMicroseconds / 1000;
      final slowFrame = buildMs > frameBudgetMs || rasterMs > frameBudgetMs;

      if (!slowFrame) {
        continue;
      }

      final payload = <String, Object>{
        'build_ms': buildMs.toStringAsFixed(2),
        'raster_ms': rasterMs.toStringAsFixed(2),
        'total_ms': totalMs.toStringAsFixed(2),
        'budget_ms': AppConfig.targetFrameBudgetMs,
      };

      AppLogger.warn(
        feature: 'Performance.Frame',
        operation: 'slow_frame_detected',
        message: 'Slow frame detected',
        context: payload,
      );
    }
  }

  void _logImageCacheStats() {
    final cache = PaintingBinding.instance.imageCache;
    final currentSizeMb = (cache.currentSizeBytes / (1024 * 1024))
        .toStringAsFixed(2);
    final maxSizeMb = (cache.maximumSizeBytes / (1024 * 1024)).toStringAsFixed(
      2,
    );
    final payload = <String, Object>{
      'entries': cache.currentSize,
      'live': cache.liveImageCount,
      'pending': cache.pendingImageCount,
      'current_mb': currentSizeMb,
      'max_mb': maxSizeMb,
    };

    AppLogger.debug(
      feature: 'Performance.ImageCache',
      operation: 'snapshot',
      message: 'Image cache stats',
      context: payload,
    );
  }
}
