part of 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';

const int _kPhotoCostSpark = 6;
const int _kVideoCostSpark = 33;
const String _kWalletHeroLogoAsset = 'assets/rewards/wallet-hero-logo.png';
const String _kWalletPremiumUpsellMascotAsset =
    'assets/rewards/premium-upsell-dog.png';
bool _isRuLocale(BuildContext context) =>
    Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';

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
  const _BalanceCard({required this.wallet, required this.onRefresh});

  final WalletStateModel? wallet;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balance = wallet?.balance ?? 0;
    final cardTextPrimary = isDark ? Colors.white : const Color(0xFF1E1631);
    final cardTextSecondary = isDark
        ? Colors.white.withValues(alpha: 0.80)
        : const Color(0xFF61537F);
    final cardAccent = isDark
        ? const Color(0xFFC4A7FF)
        : const Color(0xFF8C67FF);
    final cardGradientColors = isDark
        ? const [Color(0xFF130E22), Color(0xFF2A1F45), Color(0xFF171028)]
        : const [Color(0xFFF7F0FF), Color(0xFFF0E5FF), Color(0xFFFBF8FF)];
    final cardBorderColor = isDark
        ? const Color(0xFF514173)
        : const Color(0xFFD6C8FA);
    final refreshBackground = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.88);
    final refreshForeground = isDark
        ? Colors.white.withValues(alpha: 0.90)
        : const Color(0xFF685695);

    return ProfileGlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: cardBorderColor),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color(0xFF7E5BEE).withValues(alpha: 0.24)
                  : const Color(0xFFA77CFF).withValues(alpha: 0.28),
              blurRadius: isDark ? 34 : 28,
              spreadRadius: isDark ? 2 : 1.2,
              offset: const Offset(0, 12),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.52, 1.0],
            colors: cardGradientColors,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -24,
              left: -34,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFB794FF).withValues(alpha: 0.30),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const SizedBox(width: 180, height: 180),
              ),
            ),
            Positioned(
              right: -28,
              bottom: -34,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF9765FF).withValues(alpha: 0.24),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const SizedBox(width: 190, height: 190),
              ),
            ),
            Positioned(
              right: 86,
              top: 70,
              child: IgnorePointer(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _SparkleDot(
                      size: 4,
                      color: cardAccent.withValues(alpha: 0.65),
                    ),
                    _SparkleDot(
                      size: 3,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    _SparkleDot(
                      size: 5,
                      color: const Color(0xFFD5BEFF).withValues(alpha: 0.70),
                    ),
                    _SparkleDot(
                      size: 2.8,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 380;
                  final contentRightInset = compact ? 132.0 : 172.0;
                  final heroHeight = compact ? 156.0 : 184.0;

                  return SizedBox(
                    height: compact ? 152 : 164,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.only(right: contentRightInset),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              text.walletBalanceEyebrow,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: cardTextSecondary,
                                                fontSize: compact ? 15 : 16,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.help_outline_rounded,
                                            size: 15,
                                            color: cardTextSecondary,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton.filledTonal(
                                      onPressed: onRefresh,
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 20,
                                      ),
                                      tooltip: text.walletRefreshTooltip,
                                      visualDensity: const VisualDensity(
                                        horizontal: -2,
                                        vertical: -2,
                                      ),
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 38,
                                            height: 38,
                                          ),
                                      style: IconButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        foregroundColor: refreshForeground,
                                        backgroundColor: refreshBackground,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 9),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: compact ? 38 : 42,
                                        height: compact ? 38 : 42,
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFB7A0FF,
                                          ).withValues(alpha: 0.35),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(
                                              0xFFD9C8FF,
                                            ).withValues(alpha: 0.8),
                                          ),
                                        ),
                                        child: const Center(
                                          child: PawSparkIcon(size: 22),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        NumberFormat.decimalPattern().format(
                                          balance,
                                        ),
                                        style: TextStyle(
                                          color: cardTextPrimary,
                                          fontSize: compact ? 60 : 68,
                                          fontWeight: FontWeight.w900,
                                          height: 0.88,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  text.walletBalanceUnit,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: cardTextSecondary,
                                    fontSize: compact ? 24 : 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: compact ? 4 : 2,
                          bottom: compact ? -7 : -8,
                          child: IgnorePointer(
                            child: SizedBox(
                              height: heroHeight,
                              child: Image.asset(
                                _kWalletHeroLogoAsset,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparkleDot extends StatelessWidget {
  const _SparkleDot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
        ],
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
    final isRu = _isRuLocale(context);
    final gradientColors = PremiumBannerStyle.gradient(!isDark);
    final borderColor = const Color(
      0xFFE1AF54,
    ).withValues(alpha: isDark ? 0.82 : 0.90);
    final textPrimary = isDark
        ? const Color(0xFFF7C96A)
        : const Color(0xFF735018);
    final textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.90)
        : const Color(0xFF2D3B54);
    final chipBg = isDark
        ? const Color(0xFF1A2F61).withValues(alpha: 0.72)
        : const Color(0xFFF4E7CB).withValues(alpha: 0.95);
    final chipBorder = const Color(0xFFE1AF54).withValues(alpha: 0.72);
    return ProfileGlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: 1.25),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF081538).withValues(alpha: 0.36),
              blurRadius: 18,
              spreadRadius: 0.7,
              offset: const Offset(0, 8),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.55, 1.0],
            colors: gradientColors,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -18,
              left: -22,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF3C464).withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const SizedBox(width: 120, height: 120),
              ),
            ),
            Positioned(
              right: 62,
              top: 24,
              child: _SparkleDot(
                size: 3,
                color: const Color(0xFFF3C464).withValues(alpha: 0.6),
              ),
            ),
            Positioned(
              right: 36,
              top: 54,
              child: _SparkleDot(
                size: 2.4,
                color: Colors.white.withValues(alpha: 0.56),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 390;
                final mascotWidth = compact ? 136.0 : 162.0;
                final contentRightInset = compact
                    ? mascotWidth * 0.72
                    : mascotWidth * 0.78;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                              isRu ? 'Premium-кошелек' : 'Premium wallet',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 11.6,
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
                          isRu ? 'Premium выгоднее' : 'Premium is better',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: compact ? 24 : 26,
                            fontWeight: FontWeight.w900,
                            height: 1.02,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Padding(
                        padding: EdgeInsets.only(right: contentRightInset),
                        child: Text(
                          isRu
                              ? '40 PowSpark каждую неделю\nбез водяного знака, экспорт высокого качества'
                              : '40 PowSpark every week\nno watermark, high-quality export',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: compact ? 12.4 : 13.0,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _PremiumFeaturePill(
                            icon: Icons.card_giftcard_rounded,
                            label: isRu
                                ? '40 PowSpark каждую неделю'
                                : '40 PowSpark every week',
                            foregroundColor: textPrimary,
                            backgroundColor: chipBg,
                            borderColor: chipBorder,
                          ),
                          _PremiumFeaturePill(
                            icon: Icons.auto_awesome_rounded,
                            label: isRu ? 'Без водяного знака' : 'No watermark',
                            foregroundColor: textPrimary,
                            backgroundColor: chipBg,
                            borderColor: chipBorder,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: compact ? 196 : 214,
                        child: PremiumShimmerButton(
                          label: text.profilePremiumOpenAction,
                          onTap: onOpenPremium,
                          height: 46,
                          borderRadius: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              right: -6,
              bottom: 0,
              child: IgnorePointer(
                child: Image.asset(
                  _kWalletPremiumUpsellMascotAsset,
                  width: 162,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
        color: backgroundColor,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: foregroundColor),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldShimmerButton extends StatefulWidget {
  const _GoldShimmerButton({
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  State<_GoldShimmerButton> createState() => _GoldShimmerButtonState();
}

class _GoldShimmerButtonState extends State<_GoldShimmerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final shimmerStart = -1.6 + (t * 2.8);

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              FilledButton(
                onPressed: widget.onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  backgroundColor: widget.backgroundColor,
                  foregroundColor: widget.foregroundColor,
                  textStyle: const TextStyle(
                    fontSize: 13.8,
                    fontWeight: FontWeight.w900,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.label),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(shimmerStart, -1),
                          end: Alignment(shimmerStart + 0.9, 1),
                          colors: [
                            Colors.transparent,
                            const Color(0xFFFFF3C9).withValues(alpha: 0.0),
                            const Color(0xFFFFF3C9).withValues(alpha: 0.42),
                            const Color(0xFFFFF3C9).withValues(alpha: 0.0),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.30, 0.5, 0.70, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RewardsOverviewCard extends StatelessWidget {
  const _RewardsOverviewCard({
    required this.wallet,
    required this.isClaimingAd,
    required this.onClaimAd,
  });

  final WalletStateModel? wallet;
  final bool isClaimingAd;
  final VoidCallback onClaimAd;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final remaining = wallet?.adRewardsRemainingToday ?? 0;
    final isLimitReached = remaining <= 0;

    return _RewardStatusCard(
      icon: Icons.play_circle_outline_rounded,
      title: text.walletAdRewardCompactTitle,
      subtitle: isLimitReached
          ? text.walletAdDailyLimitReached
          : text.walletAdRewardCompactDescription,
      rewardAmount: 15,
      remainingLabel: text.walletAdRewardRemaining(remaining),
      actionLabel: text.walletWatchAdAction,
      onTap: isLimitReached || isClaimingAd ? null : onClaimAd,
      isLoading: isClaimingAd,
    );
  }
}

class _RewardStatusCard extends StatelessWidget {
  const _RewardStatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.rewardAmount,
    required this.remainingLabel,
    required this.actionLabel,
    required this.onTap,
    required this.isLoading,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int rewardAmount;
  final String remainingLabel;
  final String actionLabel;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final accent = colors.accent;

    return ProfileGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;

          final badgeIcon = Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: accent.withValues(alpha: 0.26)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.surfaceStrong,
                      colors.surfaceStrong.withValues(alpha: 0.92),
                    ],
                  ),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              Positioned(
                right: -10,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: colors.surfaceStrong,
                    border: Border.all(color: accent.withValues(alpha: 0.24)),
                  ),
                  child: Text(
                    '+$rewardAmount',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          );

          final actionButton = OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 34),
              backgroundColor: colors.surfaceStrong.withValues(alpha: 0.35),
              disabledBackgroundColor: colors.surfaceStrong,
              foregroundColor: colors.textStrong,
              disabledForegroundColor: colors.textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: BorderSide(color: colors.border.withValues(alpha: 0.84)),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onTap,
            icon: Icon(
              isLoading
                  ? Icons.hourglass_top_rounded
                  : Icons.play_arrow_rounded,
              size: 16,
            ),
            label: Text(isLoading ? '...' : actionLabel),
          );

          if (compact) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                badgeIcon,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 11.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      actionButton,
                      const SizedBox(height: 4),
                      Text(
                        remainingLabel,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              badgeIcon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 11.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      remainingLabel,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 146, child: actionButton),
            ],
          );
        },
      ),
    );
  }
}

class _PromoCodeForm extends StatefulWidget {
  const _PromoCodeForm({required this.isSubmitting, required this.onSubmit});

  final bool isSubmitting;
  final Future<String?> Function(String code) onSubmit;

  @override
  State<_PromoCodeForm> createState() => _PromoCodeFormState();
}

class _PromoCodeFormState extends State<_PromoCodeForm> {
  late final TextEditingController _controller;
  String? _message;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    final text = AppLocalizations.of(context);
    if (code.isEmpty) {
      setState(() {
        _isSuccess = false;
        _message = text.walletPromoInputPlaceholder;
      });
      return;
    }

    if (widget.isSubmitting) {
      return;
    }

    setState(() {
      _message = null;
    });

    final error = await widget.onSubmit(code);
    if (!mounted) {
      return;
    }

    setState(() {
      if (error == null) {
        _isSuccess = true;
        _message = text.walletPromoSuccessMessage;
        _controller.clear();
      } else {
        _isSuccess = false;
        _message = _friendlyError(text, error);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.confirmation_number_rounded,
                color: colors.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text.walletPromoTitle,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text.walletPromoSubtitle,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 12.2,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.surfaceStrong.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.9),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => unawaited(_submit()),
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      hintText: text.walletPromoInputPlaceholder,
                      hintStyle: TextStyle(
                        color: colors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: widget.isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: colors.surfaceStrong.withValues(
                      alpha: 0.95,
                    ),
                    disabledForegroundColor: colors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: widget.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded, size: 20),
                ),
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  _isSuccess
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: _isSuccess ? colors.accent : colors.gold,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _isSuccess ? colors.textStrong : colors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
