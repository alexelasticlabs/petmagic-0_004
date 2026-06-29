import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';

class StartupBackdrop extends StatelessWidget {
  const StartupBackdrop({required this.accentRank, super.key});

  final int accentRank;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final accent = switch (accentRank % 3) {
      0 => colors.accent,
      1 => colors.blue,
      _ => colors.gold,
    };

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            child: BlurOrb(color: accent.withValues(alpha: 0.18), size: 220),
          ),
          Positioned(
            right: -70,
            top: 150,
            child: BlurOrb(
              color: colors.purple.withValues(alpha: 0.12),
              size: 240,
            ),
          ),
          Positioned(
            left: 40,
            bottom: 120,
            child: BlurOrb(
              color: colors.accent.withValues(alpha: 0.14),
              size: 260,
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: SparkPainter(
                sparkColor: accent.withValues(alpha: 0.36),
                secondaryColor: colors.gold.withValues(alpha: 0.26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({this.actionLabel, this.onAction, super.key});

  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final brandStyle = Theme.of(context).textTheme.titleLarge;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colors.surfaceGlass,
            shape: BoxShape.circle,
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.18),
                blurRadius: 28,
              ),
            ],
          ),
          child: Icon(Icons.pets_rounded, color: colors.accent, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'PetMagic',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.comfortaa(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: brandStyle?.color ?? colors.textStrong,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class BlurOrb extends StatelessWidget {
  const BlurOrb({required this.color, required this.size, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final orb = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    if (PerformanceGuard.shouldAvoidBlur(context)) {
      return RepaintBoundary(child: orb);
    }

    return RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: orb,
      ),
    );
  }
}

class SparkPainter extends CustomPainter {
  const SparkPainter({required this.sparkColor, required this.secondaryColor});

  final Color sparkColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final sparkPaint = Paint()
      ..color = sparkColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final secondaryPaint = Paint()
      ..color = secondaryColor
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final points = <Offset>[
      Offset(size.width * 0.14, size.height * 0.17),
      Offset(size.width * 0.86, size.height * 0.2),
      Offset(size.width * 0.12, size.height * 0.74),
      Offset(size.width * 0.84, size.height * 0.82),
      Offset(size.width * 0.52, size.height * 0.12),
      Offset(size.width * 0.68, size.height * 0.56),
    ];

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final paint = index.isEven ? sparkPaint : secondaryPaint;
      canvas.drawLine(point.translate(-5, 0), point.translate(5, 0), paint);
      canvas.drawLine(point.translate(0, -5), point.translate(0, 5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant SparkPainter oldDelegate) {
    return oldDelegate.sparkColor != sparkColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
