import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';

class AppPerformanceTrace {
  AppPerformanceTrace._();

  static String _routeLabel = 'app_startup';

  static String get currentRouteLabel => _routeLabel;

  static void setRouteLabel(String routeLabel) {
    final normalized = routeLabel.trim();
    if (normalized.isEmpty || normalized == _routeLabel) {
      return;
    }

    _routeLabel = normalized;
  }
}

class AppPerformanceRouteObserver extends NavigatorObserver {
  AppPerformanceRouteObserver._();

  static final AppPerformanceRouteObserver instance =
      AppPerformanceRouteObserver._();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _trackRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _trackRoute(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _trackRoute(previousRoute);
  }

  void _trackRoute(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null && name.trim().isNotEmpty) {
      AppPerformanceTrace.setRouteLabel(name);
    }
  }
}

class AppPerformanceMonitor extends StatefulWidget {
  const AppPerformanceMonitor({required this.child, super.key});

  final Widget child;

  @override
  State<AppPerformanceMonitor> createState() => _AppPerformanceMonitorState();
}

class _AppPerformanceMonitorState extends State<AppPerformanceMonitor> {
  static const int _minFramesBeforeReport = 90;
  static const Duration _maxReportInterval = Duration(seconds: 8);

  _FrameTelemetryBucket _bucket = _FrameTelemetryBucket(
    routeLabel: AppPerformanceTrace.currentRouteLabel,
  );
  DateTime _bucketStartedAt = DateTime.now();

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
      _flushFrameSummary(force: true);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    _rollBucketIfRouteChanged();
    for (final timing in timings) {
      final buildMs = timing.buildDuration.inMicroseconds / 1000;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000;
      final totalMs = timing.totalSpan.inMicroseconds / 1000;
      _bucket.add(
        buildMs: buildMs,
        rasterMs: rasterMs,
        totalMs: totalMs,
        frameBudgetMs: AppConfig.targetFrameBudgetMs.toDouble(),
      );
    }

    _flushFrameSummary();
  }

  void _rollBucketIfRouteChanged() {
    final routeLabel = AppPerformanceTrace.currentRouteLabel;
    if (routeLabel == _bucket.routeLabel) {
      return;
    }

    _flushFrameSummary(force: true);
    _bucket = _FrameTelemetryBucket(routeLabel: routeLabel);
    _bucketStartedAt = DateTime.now();
  }

  void _flushFrameSummary({bool force = false}) {
    if (_bucket.frameCount == 0) {
      return;
    }

    final now = DateTime.now();
    final elapsed = now.difference(_bucketStartedAt);
    final shouldReport =
        force ||
        _bucket.frameCount >= _minFramesBeforeReport ||
        elapsed >= _maxReportInterval;
    if (!shouldReport) {
      return;
    }

    if (_bucket.slowFrameCount > 0) {
      AppLogger.warn(
        feature: 'Performance.Frame',
        operation: 'frame_summary',
        message: 'Slow frame summary',
        context: _bucket.toLogPayload(
          budgetMs: AppConfig.targetFrameBudgetMs,
          elapsed: elapsed,
        ),
      );
    }

    _bucket = _FrameTelemetryBucket(
      routeLabel: AppPerformanceTrace.currentRouteLabel,
    );
    _bucketStartedAt = now;
  }
}

class _FrameTelemetryBucket {
  _FrameTelemetryBucket({required this.routeLabel});

  final String routeLabel;
  final List<double> _buildSamples = <double>[];
  final List<double> _rasterSamples = <double>[];
  final List<double> _totalSamples = <double>[];
  int slowFrameCount = 0;
  double worstBuildMs = 0;
  double worstRasterMs = 0;
  double worstTotalMs = 0;

  int get frameCount => _buildSamples.length;

  void add({
    required double buildMs,
    required double rasterMs,
    required double totalMs,
    required double frameBudgetMs,
  }) {
    _buildSamples.add(buildMs);
    _rasterSamples.add(rasterMs);
    _totalSamples.add(totalMs);
    if (buildMs > frameBudgetMs || rasterMs > frameBudgetMs) {
      slowFrameCount++;
    }
    if (buildMs > worstBuildMs) {
      worstBuildMs = buildMs;
    }
    if (rasterMs > worstRasterMs) {
      worstRasterMs = rasterMs;
    }
    if (totalMs > worstTotalMs) {
      worstTotalMs = totalMs;
    }
  }

  Map<String, Object> toLogPayload({
    required int budgetMs,
    required Duration elapsed,
  }) {
    return <String, Object>{
      'route': routeLabel,
      'frames': frameCount,
      'slow_frames': slowFrameCount,
      'slow_frame_ratio': _formatRatio(slowFrameCount, frameCount),
      'p95_build_ms': _formatMs(_percentile(_buildSamples, 0.95)),
      'p95_raster_ms': _formatMs(_percentile(_rasterSamples, 0.95)),
      'p95_total_ms': _formatMs(_percentile(_totalSamples, 0.95)),
      'worst_build_ms': _formatMs(worstBuildMs),
      'worst_raster_ms': _formatMs(worstRasterMs),
      'worst_total_ms': _formatMs(worstTotalMs),
      'budget_ms': budgetMs,
      'elapsed_ms': elapsed.inMilliseconds,
    };
  }

  static double _percentile(List<double> samples, double percentile) {
    if (samples.isEmpty) {
      return 0;
    }

    final sorted = [...samples]..sort();
    final rawIndex = ((sorted.length - 1) * percentile).round();
    final index = rawIndex.clamp(0, sorted.length - 1);
    return sorted[index];
  }

  static String _formatMs(double value) {
    return value.toStringAsFixed(2);
  }

  static String _formatRatio(int numerator, int denominator) {
    if (denominator <= 0) {
      return '0.000';
    }

    return (numerator / denominator).toStringAsFixed(3);
  }
}
