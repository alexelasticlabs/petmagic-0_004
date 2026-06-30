part of 'generations_gallery_page.dart';

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.generation});

  final String label;
  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final tint = statusColor(colors, generation);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: tint,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _AnimatedGenerationProgress extends StatefulWidget {
  const _AnimatedGenerationProgress({
    required this.value,
    required this.colors,
  });

  final double value;
  final PetMagicColors colors;

  @override
  State<_AnimatedGenerationProgress> createState() =>
      _AnimatedGenerationProgressState();
}

class _AnimatedGenerationProgressState
    extends State<_AnimatedGenerationProgress> {
  late double _previous;

  @override
  void initState() {
    super.initState();
    _previous = widget.value.clamp(0, 1).toDouble();
  }

  @override
  void didUpdateWidget(covariant _AnimatedGenerationProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previous = oldWidget.value.clamp(0, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final next = widget.value.clamp(0, 1).toDouble();

    LinearProgressIndicator progressBar(double value) {
      return LinearProgressIndicator(
        minHeight: 5,
        value: value,
        color: widget.colors.accent,
        backgroundColor: widget.colors.border.withValues(alpha: 0.55),
      );
    }

    if (PerformanceGuard.isDegradedMode(context) ||
        PetMotion.reduceMotion(context)) {
      return progressBar(next);
    }

    return TweenAnimationBuilder<double>(
      duration: PetMotion.effectiveDuration(context, PetMotion.medium),
      curve: PetMotion.standard,
      tween: Tween<double>(begin: _previous, end: next),
      builder: (context, value, _) => progressBar(value),
    );
  }
}

class _CardEntrance extends StatelessWidget {
  const _CardEntrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (PerformanceGuard.isDegradedMode(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.92, end: 1),
      child: child,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.96 + (0.04 * value),
            child: animatedChild,
          ),
        );
      },
    );
  }
}
