part of 'magic_loading_screen.dart';

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
