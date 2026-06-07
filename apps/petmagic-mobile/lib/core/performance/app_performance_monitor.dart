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
  @override
  void initState() {
    super.initState();

    if (AppConfig.enableFrameTelemetry) {
      SchedulerBinding.instance.addTimingsCallback(_handleFrameTimings);
    }
  }

  @override
  void dispose() {
    if (AppConfig.enableFrameTelemetry) {
      SchedulerBinding.instance.removeTimingsCallback(_handleFrameTimings);
    }

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
}
