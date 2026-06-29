part of 'magic_loading_screen.dart';

class _MagicBackgroundPainter extends CustomPainter {
  _MagicBackgroundPainter({required this.colors, required this.progress});

  final PetMagicColors colors;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGlow(canvas, size);
    _paintParticles(canvas, size);
    _paintTemplateCards(canvas, size);
    _paintAiWaves(canvas, size);
  }

  void _paintGlow(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36);
    paint.color = colors.accent.withValues(alpha: 0.16);
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.22),
      math.min(size.width, size.height) * 0.22,
      paint,
    );
    paint.color = colors.purple.withValues(alpha: 0.14);
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.68),
      math.min(size.width, size.height) * 0.24,
      paint,
    );
    paint.color = colors.gold.withValues(alpha: 0.08);
    canvas.drawCircle(
      Offset(size.width * 0.58, size.height * 0.14),
      math.min(size.width, size.height) * 0.16,
      paint,
    );
  }

  void _paintParticles(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;

    for (var index = 0; index < _particleSeeds.length; index++) {
      final seed = _particleSeeds[index];
      final drift = math.sin((progress + seed.phase) * math.pi * 2) * 12;
      final x = (seed.dx * size.width + drift) % size.width;
      final y =
          (seed.dy * size.height + progress * seed.speed * size.height) %
          size.height;
      final opacity =
          0.18 + 0.22 * math.sin((progress + seed.phase) * math.pi * 2).abs();
      paint.color = seed.color(colors).withValues(alpha: opacity);

      switch (seed.kind) {
        case _ParticleKind.sparkle:
          _drawSparkle(canvas, Offset(x, y), seed.size, paint);
        case _ParticleKind.paw:
          _drawPaw(canvas, Offset(x, y), seed.size, paint);
        case _ParticleKind.heart:
          _drawHeart(canvas, Offset(x, y), seed.size, paint);
      }
    }
  }

  void _paintTemplateCards(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = colors.blue.withValues(alpha: 0.15);

    for (var index = 0; index < 4; index++) {
      final travel = (progress + index * 0.22) % 1;
      final center = Offset(
        size.width * (0.16 + 0.72 * travel),
        size.height * (0.16 + 0.16 * math.sin((travel + index) * math.pi * 2)),
      );
      final rect = Rect.fromCenter(center: center, width: 24, height: 42);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-0.18 + index * 0.08);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        paint,
      );
      canvas.drawLine(
        Offset(rect.left + 5, rect.top + 10),
        Offset(rect.right - 5, rect.top + 10),
        paint,
      );
      canvas.restore();
    }
  }

  void _paintAiWaves(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3
      ..color = colors.accent.withValues(alpha: 0.14);
    final baseY = size.height * 0.82;

    for (var wave = 0; wave < 3; wave++) {
      final path = Path();
      final offset = progress * math.pi * 2 + wave * 0.8;
      for (var point = 0; point <= 48; point++) {
        final t = point / 48;
        final x = t * size.width;
        final y = baseY + wave * 12 + math.sin(t * math.pi * 4 + offset) * 5;
        if (point == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Paint paint) {
    canvas.drawLine(
      Offset(center.dx - size, center.dy),
      Offset(center.dx + size, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - size),
      Offset(center.dx, center.dy + size),
      paint,
    );
  }

  void _drawPaw(Canvas canvas, Offset center, double size, Paint paint) {
    final fill = Paint()..color = paint.color;
    canvas.drawCircle(center + Offset(0, size * 0.2), size * 0.42, fill);
    canvas.drawCircle(
      center + Offset(-size * 0.38, -size * 0.28),
      size * 0.18,
      fill,
    );
    canvas.drawCircle(center + Offset(0, -size * 0.42), size * 0.2, fill);
    canvas.drawCircle(
      center + Offset(size * 0.38, -size * 0.28),
      size * 0.18,
      fill,
    );
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size * 0.55)
      ..cubicTo(
        center.dx - size,
        center.dy,
        center.dx - size * 0.58,
        center.dy - size * 0.75,
        center.dx,
        center.dy - size * 0.22,
      )
      ..cubicTo(
        center.dx + size * 0.58,
        center.dy - size * 0.75,
        center.dx + size,
        center.dy,
        center.dx,
        center.dy + size * 0.55,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MagicBackgroundPainter oldDelegate) {
    return oldDelegate.colors != colors || oldDelegate.progress != progress;
  }

  static final _particleSeeds = [
    _ParticleSeed(
      0.12,
      0.18,
      0.12,
      0.6,
      7,
      _ParticleKind.sparkle,
      (colors) => colors.gold,
    ),
    _ParticleSeed(
      0.78,
      0.16,
      0.35,
      0.45,
      6,
      _ParticleKind.paw,
      (colors) => colors.accent,
    ),
    _ParticleSeed(
      0.24,
      0.64,
      0.52,
      0.38,
      8,
      _ParticleKind.heart,
      (colors) => colors.purple,
    ),
    _ParticleSeed(
      0.88,
      0.42,
      0.72,
      0.52,
      6,
      _ParticleKind.sparkle,
      (colors) => colors.blue,
    ),
    _ParticleSeed(
      0.46,
      0.26,
      0.24,
      0.42,
      7,
      _ParticleKind.paw,
      (colors) => colors.gold,
    ),
    _ParticleSeed(
      0.66,
      0.72,
      0.82,
      0.34,
      6,
      _ParticleKind.heart,
      (colors) => colors.accent,
    ),
    _ParticleSeed(
      0.08,
      0.48,
      0.44,
      0.5,
      8,
      _ParticleKind.sparkle,
      (colors) => colors.purple,
    ),
    _ParticleSeed(
      0.92,
      0.76,
      0.16,
      0.4,
      7,
      _ParticleKind.paw,
      (colors) => colors.blue,
    ),
  ];
}

enum _ParticleKind { sparkle, paw, heart }

class _ParticleSeed {
  const _ParticleSeed(
    this.dx,
    this.dy,
    this.phase,
    this.speed,
    this.size,
    this.kind,
    this.color,
  );

  final double dx;
  final double dy;
  final double phase;
  final double speed;
  final double size;
  final _ParticleKind kind;
  final Color Function(PetMagicColors colors) color;
}
