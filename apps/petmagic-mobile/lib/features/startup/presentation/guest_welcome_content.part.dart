part of 'guest_welcome_page.dart';

class _MagicSignInButton extends StatelessWidget {
  const _MagicSignInButton({
    required this.animation,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  final Animation<double> animation;
  final String label;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final disableAnimations =
        PerformanceGuard.shouldDisableDecorativeAnimations(context);

    if (disableAnimations) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: colors.blue,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          minimumSize: Size.fromHeight(compact ? 46 : 48),
        ),
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final pulse = 1 - ((t - 0.5).abs() * 2);
        final shimmerX = -1.2 + (2.4 * t);

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colors.blue.withValues(
                          alpha: 0.18 + (0.16 * pulse),
                        ),
                        blurRadius: 20 + (8 * pulse),
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  FilledButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(label),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.blue,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: Size.fromHeight(compact ? 46 : 48),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(shimmerX - 0.7, -1),
                            end: Alignment(shimmerX + 0.7, 1),
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(
                                alpha: 0.16 + (0.08 * pulse),
                              ),
                              Colors.transparent,
                            ],
                            stops: const [0.2, 0.5, 0.8],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 12,
                    child: IgnorePointer(
                      child: Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: Colors.white.withValues(
                          alpha: 0.65 + (0.2 * pulse),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WelcomeHeroCard extends StatelessWidget {
  const _WelcomeHeroCard({
    required this.templatesLabel,
    required this.imageLabel,
    required this.videoLabel,
    this.compact = false,
  });

  final String templatesLabel;
  final String imageLabel;
  final String videoLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final content = Container(
      height: compact ? 150 : 186,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 14,
        compact ? 10 : 12,
        compact ? 12 : 14,
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 24 : 30),
        border: Border.all(color: colors.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceGlass.withValues(alpha: 0.96),
            colors.surfaceGlass.withValues(alpha: 0.76),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: compact ? -38 : -44,
            right: compact ? -18 : -22,
            child: BlurOrb(
              color: colors.blue.withValues(alpha: 0.18),
              size: compact ? 116 : 140,
            ),
          ),
          Positioned(
            left: compact ? -14 : -20,
            bottom: compact ? -42 : -56,
            child: BlurOrb(
              color: colors.accent.withValues(alpha: 0.2),
              size: compact ? 132 : 170,
            ),
          ),
          Positioned(
            top: compact ? 4 : 6,
            left: compact ? 8 : 10,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: colors.gold.withValues(alpha: 0.72),
              size: compact ? 14 : 16,
            ),
          ),
          Positioned(
            top: compact ? 26 : 34,
            right: compact ? 22 : 28,
            child: Icon(
              Icons.close_rounded,
              color: colors.blue.withValues(alpha: 0.55),
              size: compact ? 12 : 14,
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: _HeroPill(
              icon: Icons.auto_awesome_rounded,
              label: 'AI',
              compact: compact,
            ),
          ),
          Align(
            child: Container(
              width: compact ? 132 : 152,
              height: compact ? 84 : 98,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(compact ? 20 : 24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.backgroundBottom.withValues(alpha: 0.96),
                    colors.surface.withValues(alpha: 0.9),
                  ],
                ),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.2),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Align(
                    child: Icon(
                      Icons.pets_rounded,
                      color: colors.accent,
                      size: compact ? 34 : 42,
                    ),
                  ),
                  Positioned(
                    right: compact ? 8 : 10,
                    bottom: compact ? 8 : 10,
                    child: Container(
                      width: compact ? 26 : 30,
                      height: compact ? 26 : 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.accent,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: compact ? 16 : 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              children: [
                Expanded(
                  child: _HeroFlowChip(
                    icon: Icons.style_rounded,
                    label: templatesLabel,
                    compact: compact,
                  ),
                ),
                SizedBox(width: compact ? 5 : 6),
                Expanded(
                  child: _HeroFlowChip(
                    icon: Icons.add_photo_alternate_outlined,
                    label: imageLabel,
                    compact: compact,
                  ),
                ),
                SizedBox(width: compact ? 5 : 6),
                Expanded(
                  child: _HeroFlowChip(
                    icon: Icons.movie_creation_outlined,
                    label: videoLabel,
                    compact: compact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 24 : 30),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.42),
            blurRadius: compact ? 22 : 28,
            offset: Offset(0, compact ? 12 : 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 24 : 30),
        child: PerformanceGuard.shouldAvoidBlur(context)
            ? content
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: content,
              ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colors.backgroundBottom.withValues(alpha: 0.78),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.gold, size: compact ? 12 : 14),
          SizedBox(width: compact ? 4 : 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11.2 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFlowChip extends StatelessWidget {
  const _HeroFlowChip({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 7,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        color: colors.backgroundBottom.withValues(alpha: 0.78),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.textSoft, size: compact ? 12 : 14),
          SizedBox(width: compact ? 3 : 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textSoft,
                fontWeight: FontWeight.w600,
                fontSize: compact ? 10.1 : 10.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
