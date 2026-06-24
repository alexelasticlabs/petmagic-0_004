import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class PerformanceGuard {
  PerformanceGuard._();

  static bool isDegradedMode(BuildContext context) {
    final view = _primaryView();
    if (view == null) {
      return false;
    }

    final shortestLogicalSide =
        view.physicalSize.shortestSide / view.devicePixelRatio;
    final devicePixelRatio = view.devicePixelRatio;
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
    final view = _primaryView();
    if (view == null) {
      return shouldReduceMotion(context);
    }

    final shortestLogicalSide =
        view.physicalSize.shortestSide / view.devicePixelRatio;
    final isPhone = shortestLogicalSide < 600;
    return isPhone || shouldReduceMotion(context);
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
}
