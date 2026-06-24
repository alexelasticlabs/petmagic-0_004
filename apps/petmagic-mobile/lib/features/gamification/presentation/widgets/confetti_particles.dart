import 'dart:math' as math;

import 'package:flutter/material.dart';

class ConfettiParticles extends StatefulWidget {
  const ConfettiParticles({
    super.key,
    this.particleCount = 40,
    this.duration = const Duration(milliseconds: 2000),
    this.onComplete,
  });

  final int particleCount;
  final Duration duration;
  final VoidCallback? onComplete;

  @override
  State<ConfettiParticles> createState() => _ConfettiParticlesState();
}

class _ConfettiParticlesState extends State<ConfettiParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ConfettiParticle> _particles;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _particles = List.generate(widget.particleCount, (_) => _createParticle());
    _controller.forward().then((_) => widget.onComplete?.call());
  }

  _ConfettiParticle _createParticle() {
    return _ConfettiParticle(
      x: 0.5 + (_random.nextDouble() - 0.5) * 0.3,
      y: -0.1,
      vx: (_random.nextDouble() - 0.5) * 2,
      vy: _random.nextDouble() * 2 + 1,
      rotation: _random.nextDouble() * math.pi * 2,
      rotationSpeed: (_random.nextDouble() - 0.5) * 10,
      size: _random.nextDouble() * 6 + 4,
      color: _confettiColors[_random.nextInt(_confettiColors.length)],
    );
  }

  static const _confettiColors = [
    Color(0xFFFF6D00),
    Color(0xFFFFD700),
    Color(0xFF4CAF50),
    Color(0xFF42A5F5),
    Color(0xFFAB47BC),
    Color(0xFFFF4081),
    Color(0xFF00BCD4),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
            particles: _particles,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

class _ConfettiParticle {
  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.color,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;
  double rotation;
  final double rotationSpeed;
  final double size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.progress});

  final List<_ConfettiParticle> particles;
  final double progress;

  static const double _gravity = 3;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dt = progress;
      final px = (p.x + p.vx * dt * 0.3) * size.width;
      final py = (p.y + p.vy * dt + _gravity * dt * dt) * size.height;
      final opacity = (1 - progress).clamp(0.0, 1.0);

      if (py > size.height || opacity <= 0) continue;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation + p.rotationSpeed * progress);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: p.size,
        height: p.size * 0.6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
