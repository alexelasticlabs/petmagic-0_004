import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class PerformanceGuard {
  PerformanceGuard._();

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  static bool isDegradedMode(BuildContext context) {
    final metrics = _resolveMetrics(context);
    if (metrics == null) {
      return false;
    }

    final shortestLogicalSide = metrics.shortestLogicalSide;
    final devicePixelRatio = metrics.devicePixelRatio;
    final isPhone = shortestLogicalSide < 600;
    final isCompactPhone = shortestLogicalSide <= 390;
    final isDensePhone = shortestLogicalSide <= 430 && devicePixelRatio >= 2.75;
    final isDenseAndroidPhone =
        defaultTargetPlatform == TargetPlatform.android &&
        shortestLogicalSide <= 460 &&
        devicePixelRatio >= 2.5;

    return isPhone && (isCompactPhone || isDensePhone || isDenseAndroidPhone);
  }

  static bool shouldReduceMotion(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery != null && mediaQuery.disableAnimations) {
      return true;
    }

    final features =
        SchedulerBinding.instance.platformDispatcher.accessibilityFeatures;
    return features.disableAnimations ||
        features.accessibleNavigation ||
        isDegradedMode(context);
  }

  static bool shouldAvoidBlur(BuildContext context) {
    final metrics = _resolveMetrics(context);
    if (metrics == null) {
      return shouldReduceMotion(context);
    }

    final shortestLogicalSide = metrics.shortestLogicalSide;
    final isPhone = shortestLogicalSide < 600;
    return isPhone || shouldReduceMotion(context);
  }

  static bool shouldDisableGlassEffects(BuildContext context) {
    return shouldReduceMotion(context) ||
        (_isAndroid && (shouldAvoidBlur(context) || isDegradedMode(context)));
  }

  static bool shouldDisableDecorativeAnimations(BuildContext context) {
    return shouldReduceMotion(context) ||
        (_isAndroid && (shouldAvoidBlur(context) || isDegradedMode(context)));
  }

  static bool shouldUseStaticPlaceholders(BuildContext context) {
    return shouldDisableDecorativeAnimations(context);
  }

  static bool shouldDisableSharedRouteAnimations(BuildContext context) {
    return shouldDisableDecorativeAnimations(context);
  }

  static bool shouldAnimateRepeatingEffects(BuildContext context) {
    return !shouldDisableDecorativeAnimations(context) &&
        TickerMode.valuesOf(context).enabled;
  }

  static FlutterView? _primaryView() {
    final dispatcher = SchedulerBinding.instance.platformDispatcher;
    final implicitView = dispatcher.implicitView;
    if (implicitView != null) {
      return implicitView;
    }

    final views = dispatcher.views;
    if (views.isEmpty) {
      return null;
    }

    return views.first;
  }

  static _PerformanceMetrics? _resolveMetrics(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery != null && mediaQuery.size != Size.zero) {
      return _PerformanceMetrics(
        shortestLogicalSide: mediaQuery.size.shortestSide,
        devicePixelRatio: mediaQuery.devicePixelRatio,
      );
    }

    final view = _primaryView();
    if (view == null) {
      return null;
    }

    return _PerformanceMetrics(
      shortestLogicalSide:
          view.physicalSize.shortestSide / view.devicePixelRatio,
      devicePixelRatio: view.devicePixelRatio,
    );
  }
}

class _PerformanceMetrics {
  const _PerformanceMetrics({
    required this.shortestLogicalSide,
    required this.devicePixelRatio,
  });

  final double shortestLogicalSide;
  final double devicePixelRatio;
}
