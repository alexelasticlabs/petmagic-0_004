import 'package:flutter/widgets.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';

/// Finite feedback stays brief on constrained devices and stops entirely when
/// accessibility settings request reduced motion. No repeating effects.
Duration discoveryMotionDuration(BuildContext context, Duration normal) {
  final media = MediaQuery.of(context);
  final accessibility =
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
  if (media.disableAnimations ||
      media.accessibleNavigation ||
      accessibility.disableAnimations ||
      accessibility.accessibleNavigation) {
    return Duration.zero;
  }
  return PetMotion.effectiveDuration(context, normal);
}
