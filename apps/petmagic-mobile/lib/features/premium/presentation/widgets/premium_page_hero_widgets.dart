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
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.premiumPageTitle,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
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

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceStrong,
            colors.surfaceStrong.withValues(alpha: 0.96),
            colors.gold.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileStatusPill(
                  label: isRecentlyActivated
                      ? text.premiumRecentlyActivatedBadge
                      : status?.isPremium == true
                      ? text.premiumAlreadyActive
                      : text.premiumHeroEyebrow,
                  leading: Icons.workspace_premium_rounded,
                  backgroundColor: isRecentlyActivated
                      ? colors.accent.withValues(alpha: 0.16)
                      : colors.gold.withValues(alpha: 0.16),
                  foregroundColor: isRecentlyActivated
                      ? colors.accent
                      : colors.gold,
                ),
                const Spacer(),
                Icon(
                  Icons.auto_awesome_rounded,
                  color: isRecentlyActivated ? colors.accent : colors.gold,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.premiumHeroTitle,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: compact ? 25 : 28,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            text.premiumHeroSubtitle,
                            style: TextStyle(
                              color: colors.textSoft,
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    const _HeroPreviewStack(),
                  ],
                );
              },
            ),
            if (selectedPlanLabel != null) ...[
              const SizedBox(height: 14),
              Text(
                selectedPlanLabel,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _HeroMetric(
                  icon: Icons.stacked_line_chart_rounded,
                  label: selectedPlan == null
                      ? text.premiumComparisonPremiumTokensFallback
                      : _tokensLabel(text, selectedPlan!),
                ),
                _HeroMetric(
                  icon: Icons.flash_on_rounded,
                  label: text.premiumComparisonFast,
                ),
                _HeroMetric(
                  icon: Icons.hd_rounded,
                  label: text.premiumComparisonHighQuality,
                ),
              ],
            ),
          ],
        ),
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
      width: 148,
      height: 210,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 6,
            top: 30,
            child: _PreviewCard(
              angle: -0.14,
              label: 'AI DANCE',
              accent: colors.gold,
              gradient: const [Color(0xFF4C2F12), Color(0xFF191B31)],
            ),
          ),
          Positioned(
            right: -6,
            top: 38,
            child: _PreviewCard(
              angle: 0.12,
              label: 'CINEMATIC',
              accent: colors.gold,
              gradient: const [Color(0xFF5A3A12), Color(0xFF141C2D)],
            ),
          ),
          Positioned(
            left: 22,
            child: _PreviewCard(
              width: 104,
              height: 170,
              angle: 0.04,
              label: 'VIRAL VIDEO',
              accent: colors.accent,
              showPlay: true,
              gradient: const [Color(0xFF7B3A17), Color(0xFF1B2440)],
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
    this.width = 92,
    this.height = 148,
    this.showPlay = false,
  });

  final double angle;
  final String label;
  final Color accent;
  final List<Color> gradient;
  final double width;
  final double height;
  final bool showPlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border.withValues(alpha: 0.75)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Icon(Icons.auto_awesome, size: 15, color: accent),
              ),
              const Spacer(),
              if (showPlay)
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colors.accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
