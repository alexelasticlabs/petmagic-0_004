import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';

class MagicLoadingScreen extends StatefulWidget {
  const MagicLoadingScreen({
    super.key,
    this.messages,
    this.title,
    this.showBackground = true,
  });

  final List<String>? messages;
  final String? title;
  final bool showBackground;

  @override
  State<MagicLoadingScreen> createState() => _MagicLoadingScreenState();
}

class _MagicLoadingScreenState extends State<MagicLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _messageTimer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    )..repeat();
    _messageTimer = Timer.periodic(const Duration(milliseconds: 1700), (_) {
      if (mounted) {
        setState(() => _messageIndex++);
      }
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final messages = _resolveMessages(text);
    final message = messages[_messageIndex % messages.length];
    final title = widget.title?.trim();

    final child = Semantics(
      container: true,
      liveRegion: true,
      label: title == null || title.isEmpty ? message : '$title. $message',
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _MagicBackgroundPainter(
                    colors: colors,
                    progress: _controller.value,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MagicPortal(controller: _controller),
                      const SizedBox(height: 30),
                      if (title != null && title.isNotEmpty) ...[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: Text(
                          message,
                          key: ValueKey(message),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textSoft,
                            fontSize: 16,
                            height: 1.28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _PawProgress(controller: _controller),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!widget.showBackground) {
      return child;
    }

    return DecoratedBox(
      key: const ValueKey('magic-loading-screen'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.backgroundTop,
            Color.alphaBlend(
              colors.accent.withValues(alpha: 0.13),
              colors.backgroundBottom,
            ),
            Color.alphaBlend(
              colors.purple.withValues(alpha: 0.12),
              colors.backgroundBottom,
            ),
            colors.backgroundBottom,
          ],
          stops: const [0, 0.38, 0.74, 1],
        ),
      ),
      child: child,
    );
  }

  List<String> _resolveMessages(AppLocalizations text) {
    final provided = widget.messages
        ?.map((message) => message.trim())
        .where((message) => message.isNotEmpty)
        .toList(growable: false);

    if (provided != null && provided.isNotEmpty) {
      return provided;
    }

    return [
      text.magicLoadingPreparing,
      text.magicLoadingCutestAngle,
      text.magicLoadingAiPaws,
      text.magicLoadingCreatingAdorable,
      text.magicLoadingAlmostReady,
    ];
  }
}

class SliverMagicLoadingScreen extends StatelessWidget {
  const SliverMagicLoadingScreen({
    super.key,
    this.messages,
    this.title,
    this.showBackground = false,
  });

  final List<String>? messages;
  final String? title;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: MagicLoadingScreen(
        messages: messages,
        title: title,
        showBackground: showBackground,
      ),
    );
  }
}

class _MagicPortal extends StatelessWidget {
  const _MagicPortal({required this.controller});

  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return SizedBox(
      width: 210,
      height: 210,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final progress = controller.value;
          final pulse = 0.5 + 0.5 * math.sin(progress * math.pi * 2);
          final scanTop = -40 + 250 * ((progress * 1.35) % 1);

          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 154 + pulse * 5,
                height: 154 + pulse * 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.28),
                      blurRadius: 34,
                      spreadRadius: 6,
                    ),
                    BoxShadow(
                      color: colors.purple.withValues(alpha: 0.18),
                      blurRadius: 52,
                      spreadRadius: 10,
                    ),
                  ],
                  gradient: RadialGradient(
                    colors: [
                      colors.surfaceGlass.withValues(alpha: 0.95),
                      colors.accentSoft.withValues(alpha: 0.62),
                      colors.purple.withValues(alpha: 0.16),
                    ],
                    stops: const [0, 0.58, 1],
                  ),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.38),
                  ),
                ),
              ),
              ClipOval(
                child: SizedBox(
                  width: 148,
                  height: 148,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.pets_rounded,
                        size: 74,
                        color: colors.textStrong.withValues(alpha: 0.9),
                      ),
                      Positioned(
                        top: scanTop,
                        left: 10,
                        right: 10,
                        child: Transform.rotate(
                          angle: -0.12,
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  colors.accent.withValues(alpha: 0),
                                  colors.accent.withValues(alpha: 0.28),
                                  colors.gold.withValues(alpha: 0.2),
                                  colors.accent.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (var index = 0; index < _orbitIcons.length; index++)
                _OrbitIcon(
                  icon: _orbitIcons[index],
                  angle: progress * math.pi * 2 + index * math.pi / 2,
                  color: _orbitColor(colors, index),
                ),
            ],
          );
        },
      ),
    );
  }

  static const _orbitIcons = [
    Icons.movie_creation_rounded,
    Icons.auto_awesome_rounded,
    Icons.pets_rounded,
    Icons.music_note_rounded,
  ];

  static Color _orbitColor(PetMagicColors colors, int index) {
    return switch (index) {
      0 => colors.blue,
      1 => colors.gold,
      2 => colors.accent,
      _ => colors.purple,
    };
  }
}

class _OrbitIcon extends StatelessWidget {
  const _OrbitIcon({
    required this.icon,
    required this.angle,
    required this.color,
  });

  final IconData icon;
  final double angle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final radius = 88.0;
    final x = math.cos(angle) * radius;
    final y = math.sin(angle) * radius;

    return Transform.translate(
      offset: Offset(x, y),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: colors.surfaceGlass.withValues(alpha: isLight ? 0.96 : 0.9),
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: isLight ? 0.42 : 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _PawProgress extends StatelessWidget {
  const _PawProgress({required this.controller});

  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final step = (controller.value * 5).floor() % 5;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 5; index++) ...[
              _PawStep(
                index: index,
                active: index == step,
                color: index.isEven ? colors.gold : colors.accent,
              ),
              if (index != 4) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}

class _PawStep extends StatelessWidget {
  const _PawStep({
    required this.index,
    required this.active,
    required this.color,
  });

  final int index;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return AnimatedContainer(
      key: ValueKey('magic-loading-paw-$index'),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? color.withValues(alpha: 0.18)
            : colors.surfaceGlass.withValues(alpha: isLight ? 0.6 : 0.34),
        border: Border.all(
          color: active
              ? color.withValues(alpha: 0.42)
              : colors.border.withValues(alpha: isLight ? 0.64 : 0.28),
        ),
      ),
      child: Icon(
        Icons.pets_rounded,
        color: active
            ? color
            : colors.textMuted.withValues(alpha: isLight ? 0.9 : 0.68),
        size: 18,
      ),
    );
  }
}

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
