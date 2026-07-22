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
    final navigator = context.appNavigator;
    final canPop = navigator.canPop();

    void handleBack() {
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }

      navigator.go(const ProfileDestination());
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
      borderOpacity: isDark ? 0.42 : 0.28,
      glowOpacity: isDark ? 0.22 : 0.14,
      glowAlignment: const Alignment(-0.96, -0.08),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cardAccent.withValues(alpha: isDark ? 0.17 : 0.1),
                      colors.surfaceStrong.withValues(
                        alpha: isDark ? 0.18 : 0.26,
                      ),
                      colors.gold.withValues(alpha: isDark ? 0.08 : 0.12),
                    ],
                    stops: const [0, 0.58, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -42,
            top: -56,
            child: IgnorePointer(
              child: Container(
                width: 164,
                height: 164,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      cardAccent.withValues(alpha: isDark ? 0.28 : 0.2),
                      cardAccent.withValues(alpha: isDark ? 0.08 : 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -18,
            bottom: -38,
            child: IgnorePointer(
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.gold.withValues(alpha: isDark ? 0.12 : 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 380;
              final mascotWidth = compact ? 112.0 : 134.0;
              final mascotHeight = compact ? 112.0 : 132.0;

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
                                      alpha: isDark ? 0.42 : 0.28,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: cardAccent.withValues(
                                        alpha: isDark ? 0.28 : 0.16,
                                      ),
                                      blurRadius: 22,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
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
                                      letterSpacing: 0,
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
                    const SizedBox(width: 8),
                    SizedBox(
                      width: mascotWidth,
                      height: mascotHeight,
                      child: IgnorePointer(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: isDark ? 0.1 : 0.2,
                                    ),
                                    cardAccent.withValues(
                                      alpha: isDark ? 0.12 : 0.08,
                                    ),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: const SizedBox.expand(),
                            ),
                            Opacity(
                              opacity: isDark ? 0.82 : 0.72,
                              child: Image.asset(
                                _kWalletHeroLogoAsset,
                                width: mascotWidth,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
