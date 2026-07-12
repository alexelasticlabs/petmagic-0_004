import 'package:flutter/animation.dart';

/// Stable semantic design tokens shared by feature UI.
///
/// Feature widgets should consume these values instead of introducing local
/// spacing, radius or motion scales. Colors and typography remain theme-driven
/// so light, dark and high-text-scale rendering stay consistent.
abstract final class PetMagicSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 40;
}

abstract final class PetMagicRadii {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 28;
  static const double pill = 999;
}

abstract final class PetMagicBreakpoints {
  static const double compact = 360;
  static const double phone = 600;
  static const double tablet = 840;

  static bool isCompact(double width) => width <= compact;
  static bool isTablet(double width) => width >= phone;
}

abstract final class PetMagicMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 380);

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve standard = Curves.easeOut;
}

abstract final class PetMagicA11y {
  static const double minimumTouchTarget = 48;
  static const double minimumTextContrast = 4.5;
  static const double minimumLargeTextContrast = 3;
}
