part of 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';

const int _kPhotoCostSpark = 6;
const int _kVideoCostSpark = 33;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.petMagicColors;
    final balance = wallet?.balance ?? 0;
    const cardAccent = Color(0xFF00F2A6);
    final cardTextSecondary = isDark
        ? Colors.white.withValues(alpha: 0.52)
        : const Color(0xFF43606A);

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
                                NumberFormat.decimalPattern().format(balance),
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
    final textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.8)
        : const Color(0xFF32485A);
    const accent = Color(0xFFFFC107);
    final chipBg = accent.withValues(alpha: isDark ? 0.14 : 0.1);
    final chipBorder = accent.withValues(alpha: isDark ? 0.26 : 0.22);
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
                              color: const Color(0xFFFFD666),
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
                            foregroundColor: const Color(0xFFFFD666),
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
                      width: veryCompact ? 164 : compact ? 178 : 196,
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
                fontSize: 10.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
