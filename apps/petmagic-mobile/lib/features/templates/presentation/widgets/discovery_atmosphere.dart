import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/discovery_motion.dart';

/// A quiet, collection-aware backdrop. Only this paint layer animates; the
/// scroll view and its video controllers stay outside the animation builder.
class DiscoveryAtmosphere extends StatelessWidget {
  const DiscoveryAtmosphere({
    required this.collectionIndex,
    required this.child,
    super.key,
  });

  final ValueListenable<int> collectionIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final palette = [colors.accent, colors.purple, colors.blue, colors.gold];
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: ValueListenableBuilder<int>(
                  valueListenable: collectionIndex,
                  builder: (context, index, _) => TweenAnimationBuilder<Color?>(
                    tween: ColorTween(
                      end: palette[index.abs() % palette.length],
                    ),
                    duration: discoveryMotionDuration(
                      context,
                      const Duration(milliseconds: 460),
                    ),
                    curve: Curves.easeOutCubic,
                    builder: (_, accent, _) => CustomPaint(
                      key: const ValueKey('discovery-atmosphere-paint'),
                      painter: _AtmospherePainter(
                        colors,
                        accent ?? colors.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class DiscoveryIntroduction extends StatelessWidget {
  const DiscoveryIntroduction({
    required this.title,
    required this.subtitle,
    super.key,
  });
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: null,
                foreground: Paint()
                  ..shader = LinearGradient(
                    colors: [
                      colors.textStrong,
                      colors.textStrong,
                      colors.accentInk,
                    ],
                    stops: const [0, 0.45, 1],
                  ).createShader(Rect.fromLTWH(0, 0, constraints.maxWidth, 60)),
                fontSize: 23,
                height: 1.18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.55,
              ),
            ),
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textSoft,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  const _AtmospherePainter(this.colors, this.accent);
  final PetMagicColors colors;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.backgroundTop, colors.backgroundBottom],
        ).createShader(bounds),
    );
    final light = colors.backgroundTop.computeLuminance() > 0.5;
    void halo(Offset center, double radius, Color color, double opacity) {
      final area = Rect.fromCircle(center: center, radius: radius);
      canvas.drawRect(
        area,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ).createShader(area),
      );
    }

    halo(
      Offset(size.width * 0.8, size.height * 0.24),
      size.width * 0.85,
      accent,
      light ? 0.12 : 0.18,
    );
    halo(
      Offset(size.width * 0.06, size.height * 0.82),
      size.width * 0.65,
      colors.accent,
      light ? 0.055 : 0.08,
    );
    final starPaint = Paint()
      ..color = accent.withValues(alpha: light ? 0.13 : 0.2);
    for (final point in const [
      Offset(0.09, 0.21),
      Offset(0.91, 0.13),
      Offset(0.84, 0.63),
    ]) {
      final center = Offset(size.width * point.dx, size.height * point.dy);
      canvas.drawCircle(center, 1.5, starPaint);
      canvas.drawLine(
        center.translate(-4, 0),
        center.translate(4, 0),
        starPaint..strokeWidth = 0.6,
      );
      canvas.drawLine(
        center.translate(0, -4),
        center.translate(0, 4),
        starPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter oldDelegate) =>
      oldDelegate.colors != colors || oldDelegate.accent != accent;
}
