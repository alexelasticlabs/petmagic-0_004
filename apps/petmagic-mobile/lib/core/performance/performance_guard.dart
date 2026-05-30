import 'package:flutter/widgets.dart';

class PerformanceGuard {
  PerformanceGuard._();

  static bool isDegradedMode(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media == null) {
      return false;
    }

    final shortestLogicalSide = media.size.shortestSide;
    final devicePixelRatio = media.devicePixelRatio;
    final isSmallDisplay = shortestLogicalSide <= 360;
    final isHighDensity = devicePixelRatio >= 3.0;
    return isSmallDisplay && isHighDensity;
  }
}
