import 'package:flutter/material.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/discovery_motion.dart';

/// A finite entrance, keeping the media subtree outside animation rebuilds.
class DiscoverySectionReveal extends StatelessWidget {
  const DiscoverySectionReveal({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = discoveryMotionDuration(context, PetMotion.slow);
    final reduced = duration == Duration.zero;
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: PetMotion.emphasized,
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      child: RepaintBoundary(child: child),
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(
            0,
            (PetMotion.reduceMotion(context) ? 0 : 12) * (1 - progress),
          ),
          child: child,
        ),
      ),
    );
  }
}
