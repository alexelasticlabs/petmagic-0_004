part of 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';

const String _kPremiumHeroImageAsset =
    'assets/rewards/wallet-dog-skateboard.png';

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({
    required this.onRefresh,
    required this.onRestore,
    required this.isRestoring,
  });

  final VoidCallback onRefresh;
  final VoidCallback onRestore;
  final bool isRestoring;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
          Expanded(
            child: Text(
              text.premiumPageTitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: isRestoring ? null : onRestore,
            style: TextButton.styleFrom(
              foregroundColor: colors.gold,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.1,
              ),
            ),
            icon: isRestoring
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(text.premiumRestoreAction),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: text.retryAction,
            icon: Icon(Icons.sync_rounded, color: colors.textMuted),
          ),
        ],
      ),
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
    final heroGradient = [
      colors.surface,
      colors.surfaceStrong.withValues(alpha: 0.96),
      colors.accentSoft.withValues(alpha: 0.48),
    ];
    final heroSubtitleColor = colors.gold;
    final selectedPlanLabel = selectedPlan == null
        ? null
        : '${_planTitle(text, selectedPlan!)} • ${_formatPrice(selectedPlan!, selectedPlan!.priceAmount)} ${_periodLabel(text, selectedPlan!)}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: heroGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
        border: Border.all(
          color: colors.gold.withValues(alpha: 0.36),
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -70,
            top: -48,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.gold.withValues(alpha: 0.42),
                    colors.gold.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -80,
            bottom: -80,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.accent.withValues(alpha: 0.33),
                    colors.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
                          ? colors.accent.withValues(alpha: 0.25)
                          : colors.gold.withValues(alpha: 0.22),
                      foregroundColor: isRecentlyActivated
                          ? colors.accent
                          : colors.gold,
                    ),
                    const Spacer(),
                    Icon(Icons.star_rounded, color: colors.gold, size: 22),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 380;

                    Widget content = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${text.premiumHeroTitle}\n',
                                style: TextStyle(
                                  color: colors.textStrong,
                                  fontSize: compact ? 34 : 40,
                                  height: 1.04,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.25,
                                ),
                              ),
                              TextSpan(
                                text: text.premiumHeroSubtitle,
                                style: TextStyle(
                                  color: heroSubtitleColor,
                                  fontSize: compact ? 15.5 : 17,
                                  height: 1.32,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _HeroFeatureTile(
                              icon: Icons.auto_awesome_rounded,
                              label: text.premiumComparisonPremiumTemplates,
                            ),
                            _HeroFeatureTile(
                              icon: Icons.opacity_rounded,
                              label: text.premiumComparisonNoWatermark,
                            ),
                            _HeroFeatureTile(
                              icon: Icons.bolt_rounded,
                              label: text.premiumComparisonFast,
                            ),
                          ],
                        ),
                      ],
                    );

                    final image = Align(
                      alignment: Alignment.bottomRight,
                      child: Image.asset(
                        _kPremiumHeroImageAsset,
                        height: compact ? 190 : 230,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [content, const SizedBox(height: 10), image],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: content),
                        const SizedBox(width: 8),
                        SizedBox(width: 172, child: image),
                      ],
                    );
                  },
                ),
                if (selectedPlanLabel != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.gold.withValues(alpha: 0.34),
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
                            fontSize: 12.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isRecentlyActivated) ...[
                  const SizedBox(height: 10),
                  ProfileProgressCard(
                    title: text.premiumRecentlyActivatedTitle,
                    message: text.premiumRecentlyActivatedMessage,
                    tone: colors.accent,
                    icon: Icons.check_circle_rounded,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFeatureTile extends StatelessWidget {
  const _HeroFeatureTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colors.gold),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
