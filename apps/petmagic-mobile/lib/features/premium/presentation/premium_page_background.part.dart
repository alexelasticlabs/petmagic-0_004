part of 'premium_page.dart';

class _PremiumGoldenBackground extends StatelessWidget {
  const _PremiumGoldenBackground({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final topGlow = isDark ? const Color(0xFFFFD98C) : const Color(0xFFD4BB8A);
    final bottomGlow = isDark
        ? const Color(0xFFF4C07A)
        : const Color(0xFFCCAE78);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [
                        Color(0xFF090A10),
                        Color(0xFF0B0D13),
                        Color(0xFF090A10),
                      ]
                    : const [
                        Color(0xFFF4F7FC),
                        Color(0xFFF6F6F4),
                        Color(0xFFF3F7FD),
                      ],
              ),
            ),
          ),
        ),
        Positioned(
          right: -110,
          top: -70,
          width: 250,
          height: 250,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.92,
                colors: [
                  topGlow.withValues(alpha: isDark ? 0.06 : 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -120,
          bottom: -120,
          width: 280,
          height: 280,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.95,
                colors: [
                  bottomGlow.withValues(alpha: isDark ? 0.045 : 0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: _PremiumSparkleLayer(
            count: 18,
            seed: 11,
            color: const Color(0xFFFFDC89),
            duration: const Duration(seconds: 54),
          ),
        ),
        Positioned.fill(
          child: _PremiumSparkleLayer(
            count: 12,
            seed: 29,
            color: const Color(0xFFFFF1C8),
            duration: const Duration(seconds: 70),
          ),
        ),
      ],
    );
  }
}

class _PremiumSparkleLayer extends StatefulWidget {
  const _PremiumSparkleLayer({
    required this.count,
    required this.seed,
    required this.color,
    required this.duration,
  });

  final int count;
  final int seed;
  final Color color;
  final Duration duration;

  @override
  State<_PremiumSparkleLayer> createState() => _PremiumSparkleLayerState();
}

class _PremiumSparkleLayerState extends State<_PremiumSparkleLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final List<_PremiumSparkleParticle> _particles = _generateParticles();

  List<_PremiumSparkleParticle> _generateParticles() {
    final random = math.Random(widget.seed);
    return List<_PremiumSparkleParticle>.generate(widget.count, (_) {
      return _PremiumSparkleParticle(
        x: random.nextDouble(),
        drift: (random.nextDouble() - 0.5) * 0.06,
        speed: 0.22 + (random.nextDouble() * 0.34),
        size: 1.15 + (random.nextDouble() * 2.15),
        alpha: 0.08 + (random.nextDouble() * 0.14),
        twinkle: 0.2 + (random.nextDouble() * 0.7),
        phase: random.nextDouble(),
      );
    });
  }

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
    if (!PerformanceGuard.shouldAnimateRepeatingEffects(context)) {
      return const SizedBox.expand();
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _PremiumSparklePainter(
              time: _controller.value,
              particles: _particles,
              color: widget.color,
            ),
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
      _controller.repeat();
    }
  }
}

class _PremiumSparkleParticle {
  const _PremiumSparkleParticle({
    required this.x,
    required this.drift,
    required this.speed,
    required this.size,
    required this.alpha,
    required this.twinkle,
    required this.phase,
  });

  final double x;
  final double drift;
  final double speed;
  final double size;
  final double alpha;
  final double twinkle;
  final double phase;
}

class _PremiumSparklePainter extends CustomPainter {
  const _PremiumSparklePainter({
    required this.time,
    required this.particles,
    required this.color,
  });

  final double time;
  final List<_PremiumSparkleParticle> particles;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final progress = (time * particle.speed + particle.phase) % 1;
      final wave = math.sin((progress * math.pi * 2) + (particle.phase * 5));
      final x = size.width * (particle.x + (wave * particle.drift));
      final y = size.height * (1.14 - (progress * 1.28));

      if (x < -24 || x > size.width + 24 || y < -24 || y > size.height + 24) {
        continue;
      }

      final twinkleWave =
          math.sin(
                (time * math.pi * 2 * particle.twinkle) +
                    (particle.phase * math.pi * 2),
              ) *
              0.5 +
          0.5;
      final twinkle = 0.65 + (0.35 * twinkleWave);
      final radius = particle.size * (0.9 + (0.35 * twinkle));
      final edgeFade = switch (progress) {
        < 0.16 => (progress / 0.16).clamp(0.0, 1.0),
        > 0.86 => ((1 - progress) / 0.14).clamp(0.0, 1.0),
        _ => 1.0,
      };
      final opacity = (particle.alpha * twinkle * edgeFade).clamp(0.0, 1.0);

      final corePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: opacity);

      canvas.drawCircle(Offset(x, y), radius, corePaint);

      if (radius > 2.2) {
        final glowPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: opacity * 0.08);
        canvas.drawCircle(Offset(x, y), radius * 1.45, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumSparklePainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.color != color;
  }
}
