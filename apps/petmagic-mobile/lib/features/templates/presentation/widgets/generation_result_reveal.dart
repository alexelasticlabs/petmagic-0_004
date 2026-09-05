import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';
import 'discovery_motion.dart';

/// Reveals decoded media once. Rebuilds, URL refreshes and local caching do not
/// replay the effect; the owning card is keyed by generation identity.
class GenerationResultReveal extends StatefulWidget {
  const GenerationResultReveal({
    required this.ready,
    required this.child,
    super.key,
  });

  final bool ready;
  final Widget child;

  @override
  State<GenerationResultReveal> createState() => _GenerationResultRevealState();
}

class _GenerationResultRevealState extends State<GenerationResultReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
    value: 1,
  );
  bool _revealed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _revealIfReady();
    if (discoveryMotionDuration(context, _controller.duration!) ==
        Duration.zero) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant GenerationResultReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _revealIfReady();
  }

  void _revealIfReady() {
    if (!widget.ready || _revealed) return;
    _revealed = true;
    _controller.duration = discoveryMotionDuration(
      context,
      const Duration(milliseconds: 560),
    );
    if (_controller.duration != Duration.zero &&
        TickerMode.valuesOf(context).enabled) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final compact = PetMotion.reduceMotion(context);
    return AnimatedBuilder(
      animation: _controller,
      child: RepaintBoundary(child: widget.child),
      builder: (context, child) {
        final progress = _controller.value;
        final arrival = Curves.easeOutCubic.transform(progress);
        return Transform.translate(
          offset: Offset(0, compact ? 0 : (1 - arrival) * 8),
          child: Transform.scale(
            scale: compact ? 1 : 0.985 + arrival * 0.015,
            child: Stack(
              children: [
                child!,
                if (_controller.isAnimating)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: colors.gold.withValues(
                                alpha: math.sin(progress * math.pi) * 0.7,
                              ),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
