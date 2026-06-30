part of 'auth_flow_widgets.dart';

class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -56,
            top: 76,
            child: BlurOrb(
              size: 150,
              color: colors.accent.withValues(alpha: isDark ? 0.06 : 0.07),
            ),
          ),
          Positioned(
            right: -64,
            top: 126,
            child: BlurOrb(
              size: 170,
              color: colors.gold.withValues(alpha: isDark ? 0.05 : 0.06),
            ),
          ),
          Positioned(
            right: 24,
            top: 98,
            child: Icon(
              Icons.pets_rounded,
              size: 22,
              color: colors.accent.withValues(alpha: isDark ? 0.18 : 0.22),
            ),
          ),
          Positioned(
            left: 38,
            top: 124,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: colors.gold.withValues(alpha: isDark ? 0.22 : 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthHero extends StatelessWidget {
  const AuthHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isDark,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final titleStyle = Theme.of(context).textTheme.headlineMedium;
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 360;
        final stackedCompact = compact && constraints.maxWidth < 340;
        final imageHeight = compact
            ? (stackedCompact ? 116.0 : (narrow ? 126.0 : 140.0))
            : (narrow ? 172.0 : 196.0);
        final textBlock = Padding(
          padding: EdgeInsets.only(bottom: compact ? 6 : (narrow ? 12 : 20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthWordmark(isDark: isDark, compact: compact),
              SizedBox(height: compact ? 6 : 10),
              Text(
                title,
                maxLines: stackedCompact ? 3 : 2,
                softWrap: true,
                overflow: TextOverflow.visible,
                style: titleStyle?.copyWith(
                  fontSize: compact ? 18.5 : (narrow ? 20 : 22),
                  height: compact ? 1.04 : 1.08,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  color: colors.textStrong,
                ),
              ),
              SizedBox(height: compact ? 5 : 8),
              Text(
                subtitle,
                maxLines: stackedCompact ? 3 : (compact ? 2 : 3),
                overflow: TextOverflow.visible,
                style: subtitleStyle?.copyWith(
                  fontSize: compact ? 11.1 : (narrow ? 11.8 : 12.6),
                  height: compact ? 1.28 : 1.36,
                  fontWeight: FontWeight.w600,
                  color: colors.textSoft,
                ),
              ),
            ],
          ),
        );
        final artwork = SizedBox(
          height: imageHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.gold.withValues(alpha: isDark ? 0.1 : 0.13),
                        colors.accent.withValues(alpha: isDark ? 0.18 : 0.22),
                        colors.accent.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                      stops: const [0.08, 0.42, 0.76, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: compact ? 8 : (narrow ? 12 : 18),
                right: compact ? 8 : (narrow ? 12 : 18),
                top: compact ? 34 : (narrow ? 48 : 52),
                bottom: compact ? 4 : 8,
                child: Transform.rotate(
                  angle: -0.1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: colors.surfaceGlass.withValues(
                        alpha: isDark ? 0.24 : 0.68,
                      ),
                      border: Border.all(
                        color: colors.border.withValues(
                          alpha: isDark ? 0.45 : 0.55,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: compact ? -8 : (narrow ? -12 : -16),
                right: compact ? -8 : (narrow ? -12 : -16),
                top: compact ? 26 : (narrow ? 38 : 42),
                bottom: compact ? -36 : (narrow ? -46 : -68),
                child: Transform.scale(
                  scale: compact ? 1.0 : (narrow ? 1.06 : 1.12),
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(
                    'assets/auth/petmagic-auth-hero.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        );

        return ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: stackedCompact
                ? 206
                : (compact ? 152 : (narrow ? 190 : 214)),
          ),
          child: stackedCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textBlock,
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(width: 148, child: artwork),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: compact ? 13 : (narrow ? 12 : 11),
                      child: textBlock,
                    ),
                    SizedBox(width: compact ? 2 : (narrow ? 0 : 6)),
                    Expanded(
                      flex: compact ? 7 : (narrow ? 8 : 9),
                      child: artwork,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class AuthWordmark extends StatelessWidget {
  const AuthWordmark({super.key, required this.isDark, this.compact = false});

  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: compact ? 42 : 58,
          height: compact ? 42 : 58,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.22),
                      width: 1.1,
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent.withValues(alpha: 0.08),
                ),
                child: Padding(
                  padding: EdgeInsets.all(compact ? 8 : 11),
                  child: Icon(
                    Icons.pets_rounded,
                    color: colors.accent,
                    size: compact ? 20 : 26,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 5 : 8),
        Text(
          'PetMagic',
          style: GoogleFonts.comfortaa(
            fontSize: compact ? 20 : 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            color: isDark ? colors.textStrong : const Color(0xFF10234A),
          ),
        ),
      ],
    );
  }
}

class BlurOrb extends StatelessWidget {
  const BlurOrb({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}
