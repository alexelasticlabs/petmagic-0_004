import 'package:flutter/material.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';

abstract final class PetMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 380);

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve standard = Curves.easeOut;

  static const double pressScale = 0.965;

  static bool reduceMotion(BuildContext context) {
    return PerformanceGuard.shouldReduceMotion(context);
  }

  static Duration effectiveDuration(BuildContext context, Duration normal) {
    if (!reduceMotion(context)) {
      return normal;
    }

    final reducedMilliseconds = (normal.inMilliseconds * 0.35).round();
    return Duration(milliseconds: reducedMilliseconds.clamp(60, 160));
  }
}
