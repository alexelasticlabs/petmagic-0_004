part of 'subscription_management_page.dart';

class _SubscriptionSparkleBackground extends StatefulWidget {
  const _SubscriptionSparkleBackground();

  @override
  State<_SubscriptionSparkleBackground> createState() =>
      _SubscriptionSparkleBackgroundState();
}

class _SubscriptionSparkleBackgroundState
    extends State<_SubscriptionSparkleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState();
  }

  @override
  void deactivate() {
    _controller.stop();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _syncAnimationState();
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final baseGold = isLight
        ? const Color(0xFFB68830)
        : const Color(0xFFF2C86B);
    final softViolet = isLight
        ? const Color(0xFFC9B6EB)
        : const Color(0xFF6A52A6);
    final animate = PerformanceGuard.shouldAnimateRepeatingEffects(context);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = animate ? _controller.value : 0.38;
          final phaseA = 0.55 + (0.45 * (0.5 - (t - 0.5).abs()) * 2);
          final phaseB =
              0.45 + (0.55 * (0.5 - ((t + 0.25) % 1 - 0.5).abs()) * 2);

          return Stack(
            children: [
              Positioned(
                top: 70,
                left: 18,
                child: _SparkleParticle(
                  size: 4.2,
                  color: baseGold.withValues(alpha: 0.18 * phaseA),
                ),
              ),
              Positioned(
                top: 140,
                right: 34,
                child: _SparkleParticle(
                  size: 3.4,
                  color: baseGold.withValues(alpha: 0.15 * phaseB),
                ),
              ),
              Positioned(
                top: 260,
                left: 42,
                child: _SparkleParticle(
                  size: 3.2,
                  color: softViolet.withValues(alpha: 0.13 * phaseB),
                ),
              ),
              Positioned(
                top: 370,
                right: 22,
                child: _SparkleParticle(
                  size: 2.8,
                  color: baseGold.withValues(alpha: 0.14 * phaseA),
                ),
              ),
              Positioned(
                top: 520,
                left: 26,
                child: _SparkleParticle(
                  size: 3.6,
                  color: baseGold.withValues(alpha: 0.12 * phaseB),
                ),
              ),
              Positioned(
                top: 650,
                right: 30,
                child: _SparkleParticle(
                  size: 2.6,
                  color: softViolet.withValues(alpha: 0.1 * phaseA),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _syncAnimationState() {
    if (!PerformanceGuard.shouldAnimateRepeatingEffects(context)) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      return;
    }

    if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }
}

class _SparkleParticle extends StatelessWidget {
  const _SparkleParticle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color, blurRadius: size * 2, spreadRadius: 0.2),
        ],
      ),
    );
  }
}

class _SubscriptionPanel extends StatelessWidget {
  const _SubscriptionPanel({
    required this.child,
    this.padding,
    this.accentColor,
    this.borderOpacity,
    this.glowOpacity,
    this.showAccentGlow = false,
    this.glowAlignment = Alignment.centerLeft,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? accentColor;
  final double? borderOpacity;
  final double? glowOpacity;
  final bool showAccentGlow;
  final AlignmentGeometry glowAlignment;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return PetMagicAccentCard(
      accentColor: accentColor ?? colors.border,
      padding: padding ?? const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(28),
      borderOpacity: borderOpacity ?? (accentColor == null ? 0.14 : 0.26),
      glowOpacity: glowOpacity ?? 0.14,
      showAccentGlow: showAccentGlow,
      glowAlignment: glowAlignment,
      child: child,
    );
  }
}
