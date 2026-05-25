part of 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.premiumPageTitle,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: text.retryAction,
        ),
      ],
    );
  }
}

class _PremiumHero extends StatelessWidget {
  const _PremiumHero({
    required this.status,
    required this.selectedPlan,
    required this.isRecentlyActivated,
  });

  final PremiumStatusModel? status;
  final PremiumPlanModel? selectedPlan;
  final bool isRecentlyActivated;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final selectedPlanLabel = selectedPlan == null
        ? null
        : '${_planTitle(text, selectedPlan!)} · ${_tokensLabel(text, selectedPlan!)}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceStrong,
            colors.surfaceStrong.withValues(alpha: 0.94),
            colors.gold.withValues(alpha: 0.12),
            colors.accent.withValues(alpha: 0.12),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.gold.withValues(alpha: 0.06),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: colors.gold.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Elegant premium ambient decoration
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.gold.withValues(alpha: 0.22),
                    colors.gold.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.accent.withValues(alpha: 0.18),
                    colors.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: colors.gold.withValues(alpha: 0.2),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ProfileStatusPill(
                        label: isRecentlyActivated
                            ? text.premiumRecentlyActivatedBadge
                            : status?.isPremium == true
                            ? text.premiumAlreadyActive
                            : text.premiumHeroEyebrow,
                        leading: Icons.workspace_premium_rounded,
                        backgroundColor: isRecentlyActivated
                            ? colors.accent.withValues(alpha: 0.2)
                            : colors.gold.withValues(alpha: 0.22),
                        foregroundColor: isRecentlyActivated
                            ? colors.accent
                            : colors.gold,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: isRecentlyActivated ? colors.accent : colors.gold,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 360;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                text.premiumHeroTitle,
                                style: TextStyle(
                                  color: colors.textStrong,
                                  fontSize: compact ? 26 : 30,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                text.premiumHeroSubtitle,
                                style: TextStyle(
                                  color: colors.textSoft,
                                  fontSize: 14,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const _HeroPreviewStack(),
                      ],
                    );
                  },
                ),
                if (selectedPlanLabel != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceStrong.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: colors.gold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          selectedPlanLabel,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isRecentlyActivated) ...[
                  const SizedBox(height: 12),
                  ProfileProgressCard(
                    title: text.premiumRecentlyActivatedTitle,
                    message: text.premiumRecentlyActivatedMessage,
                    tone: colors.accent,
                    icon: Icons.check_circle_rounded,
                  ),
                ],
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroMetric(
                      icon: Icons.flash_on_rounded,
                      label: text.premiumComparisonFast,
                    ),
                    _HeroMetric(
                      icon: Icons.hd_rounded,
                      label: text.premiumComparisonHighQuality,
                    ),
                    _HeroMetric(
                      icon: Icons.workspace_premium_rounded,
                      label: text.premiumComparisonPremiumTemplates,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPreviewStack extends StatelessWidget {
  const _HeroPreviewStack();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return SizedBox(
      width: 140,
      height: 200,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 2,
            top: 26,
            child: _PreviewCard(
              angle: -0.12,
              label: 'AI DANCE',
              tag: 'MAGIC',
              accent: colors.gold,
              gradient: const [Color(0xFF3B1E08), Color(0xFF141324)],
            ),
          ),
          Positioned(
            right: -4,
            top: 32,
            child: _PreviewCard(
              angle: 0.12,
              label: 'CINEMATIC',
              tag: 'PRO',
              accent: colors.gold,
              gradient: const [Color(0xFF221133), Color(0xFF131A2D)],
            ),
          ),
          Positioned(
            left: 18,
            child: _PreviewCard(
              width: 102,
              height: 172,
              angle: 0.02,
              label: 'VIRAL VIDEO',
              tag: '4K HD',
              accent: colors.accent,
              showPlay: true,
              isCenter: true,
              gradient: const [Color(0xFF501908), Color(0xFF111E39)],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.angle,
    required this.label,
    required this.accent,
    required this.gradient,
    required this.tag,
    this.width = 86,
    this.height = 144,
    this.showPlay = false,
    this.isCenter = false,
  });

  final double angle;
  final String label;
  final String tag;
  final Color accent;
  final List<Color> gradient;
  final double width;
  final double height;
  final bool showPlay;
  final bool isCenter;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isCenter
                ? colors.gold
                : colors.border.withValues(alpha: 0.6),
            width: isCenter ? 1.8 : 1.0,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: isCenter ? 18 : 12,
              offset: Offset(0, isCenter ? 8 : 6),
            ),
            if (isCenter)
              BoxShadow(
                color: colors.gold.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 1,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            children: [
              // Gloss reflection flare
              Positioned(
                top: -30,
                left: -30,
                child: Transform.rotate(
                  angle: 0.5,
                  child: Container(
                    width: 120,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.gold.withValues(
                              alpha: isCenter ? 0.35 : 0.18,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: colors.gold,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Icon(Icons.auto_awesome, size: 12, color: accent),
                      ],
                    ),
                    const Spacer(),
                    if (showPlay)
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 40,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.95),
                            boxShadow: [
                              BoxShadow(
                                color: colors.gold.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 26,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.gold.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colors.gold.withValues(alpha: 0.45),
          width: 1.1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colors.gold),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
