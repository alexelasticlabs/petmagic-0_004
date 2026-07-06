part of 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';

const String _kWalletHeroLogoAsset = 'assets/rewards/wallet-hero-logo.png';
const String _kWalletPremiumUpsellMascotAsset =
    'assets/rewards/premium-upsell-dog.png';

class _WalletHeader extends StatelessWidget {
  const _WalletHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final router = GoRouter.of(context);
    final canPop = router.canPop();

    void handleBack() {
      if (router.canPop()) {
        router.pop();
        return;
      }

      router.go('/profile');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (canPop)
                    IconButton.filledTonal(
                      onPressed: handleBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                    )
                  else
                    const SizedBox(width: 48, height: 48),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (canPop)
              IconButton.filledTonal(
                onPressed: handleBack,
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              )
            else
              const SizedBox(width: 48, height: 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
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

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet});

  final WalletStateModel? wallet;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.petMagicColors;
    final balance = wallet?.balance ?? 0;
    final cardAccent = colors.accent;
    final cardTextSecondary = colors.textSoft.withValues(
      alpha: isDark ? 0.72 : 0.86,
    );

    return PetMagicAccentCard(
      accentColor: cardAccent,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(26),
      borderOpacity: isDark ? 0.3 : 0.22,
      glowOpacity: isDark ? 0.16 : 0.1,
      glowAlignment: const Alignment(-0.96, -0.08),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final mascotWidth = compact ? 104.0 : 126.0;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 14 : 16,
              compact ? 14 : 16,
              compact ? 10 : 12,
              compact ? 14 : 16,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        text.walletBalanceEyebrow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cardTextSecondary,
                          fontSize: compact ? 13 : 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: compact ? 40 : 44,
                            height: compact ? 40 : 44,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.18 : 0.06,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: cardAccent.withValues(
                                  alpha: isDark ? 0.3 : 0.22,
                                ),
                              ),
                            ),
                            child: const Center(
                              child: PawSparkIcon(size: 22, showGlow: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                NumberFormat.decimalPattern(
                                  localeTag,
                                ).format(balance),
                                style: TextStyle(
                                  color: colors.textStrong,
                                  fontSize: compact ? 48 : 56,
                                  fontWeight: FontWeight.w900,
                                  height: 0.94,
                                  letterSpacing: -1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: cardAccent.withValues(alpha: 0.88),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              text.walletBalanceUnit,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cardTextSecondary,
                                fontSize: compact ? 15 : 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IgnorePointer(
                  child: Opacity(
                    opacity: isDark ? 0.2 : 0.13,
                    child: Image.asset(
                      _kWalletHeroLogoAsset,
                      width: mascotWidth,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PremiumUpsellCard extends StatelessWidget {
  const _PremiumUpsellCard({required this.onOpenPremium});

  final VoidCallback onOpenPremium;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.petMagicColors;
    final textPrimary = colors.textStrong;
    final textSecondary = colors.textSoft.withValues(
      alpha: isDark ? 0.84 : 0.92,
    );
    final accent = colors.gold;
    final chipBg = accent.withValues(alpha: isDark ? 0.14 : 0.1);
    final chipBorder = accent.withValues(alpha: isDark ? 0.26 : 0.22);
    final chipForeground = isDark ? colors.gold : colors.on(chipBg);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final veryCompactScreen = screenWidth < 360;
    final compactScreen = screenWidth < 410;
    final mascotWidth = veryCompactScreen
        ? 124.0
        : compactScreen
        ? 148.0
        : 170.0;
    return PetMagicAccentCard(
      accentColor: accent,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(22),
      borderOpacity: isDark ? 0.28 : 0.2,
      glowOpacity: isDark ? 0.15 : 0.1,
      glowAlignment: const Alignment(-0.94, -0.92),
      child: Stack(
        children: [
          Positioned(
            top: 10,
            left: 12,
            child: IgnorePointer(
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: isDark ? 0.18 : 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 390;
              final veryCompact = constraints.maxWidth < 360;
              final contentRightInset = veryCompact
                  ? mascotWidth * 0.92
                  : compact
                  ? mascotWidth * 0.86
                  : mascotWidth * 0.78;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 14,
                  12,
                  compact ? 12 : 14,
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: chipBg,
                        border: Border.all(color: chipBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PremiumCrownIcon(size: 14),
                          const SizedBox(width: 6),
                          Text(
                            text.walletPremiumStatus,
                            style: TextStyle(
                              color: chipForeground,
                              fontSize: compact ? 11.0 : 11.4,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.only(right: contentRightInset),
                      child: Text(
                        text.premiumUpsellHeadline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: veryCompact
                              ? 21
                              : compact
                              ? 22
                              : 24,
                          fontWeight: FontWeight.w900,
                          height: 1.02,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Padding(
                      padding: EdgeInsets.only(right: contentRightInset),
                      child: Text(
                        text.premiumUpsellSubtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: compact ? 11.7 : 12.4,
                          height: 1.22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Padding(
                      padding: EdgeInsets.only(right: contentRightInset),
                      child: Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          _PremiumFeaturePill(
                            icon: Icons.card_giftcard_rounded,
                            label: text.premiumUpsellWeeklyCredits,
                            foregroundColor: chipForeground,
                            backgroundColor: chipBg,
                            borderColor: chipBorder,
                          ),
                          _PremiumFeaturePill(
                            icon: Icons.auto_awesome_rounded,
                            label: text.profilePremiumBenefitNoWatermark,
                            foregroundColor: colors.textSoft,
                            backgroundColor: colors.surfaceStrong.withValues(
                              alpha: isDark ? 0.46 : 0.72,
                            ),
                            borderColor: colors.border.withValues(
                              alpha: isDark ? 0.68 : 0.78,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: veryCompact
                          ? 164
                          : compact
                          ? 178
                          : 196,
                      child: PremiumShimmerButton(
                        label: text.profilePremiumOpenAction,
                        onTap: onOpenPremium,
                        height: compact ? 40 : 42,
                        borderRadius: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            right: veryCompactScreen ? -24 : -26,
            bottom: veryCompactScreen ? -12 : -10,
            child: IgnorePointer(
              child: Opacity(
                opacity: isDark ? 0.92 : 0.82,
                child: Image.asset(
                  _kWalletPremiumUpsellMascotAsset,
                  width: mascotWidth,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumFeaturePill extends StatelessWidget {
  const _PremiumFeaturePill({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
        color: backgroundColor,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.8, color: foregroundColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
