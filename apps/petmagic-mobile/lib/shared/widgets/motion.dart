import 'package:flutter/material.dart';

abstract final class PetMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 380);

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve standard = Curves.easeOut;

  static const double pressScale = 0.965;

  static bool reduceMotion(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media == null) {
      return false;
    }

    return media.disableAnimations || media.accessibleNavigation;
  }

  static Duration effectiveDuration(BuildContext context, Duration normal) {
    if (!reduceMotion(context)) {
      return normal;
    }

    final reducedMilliseconds = (normal.inMilliseconds * 0.35).round();
    return Duration(milliseconds: reducedMilliseconds.clamp(60, 160));
  }
}
