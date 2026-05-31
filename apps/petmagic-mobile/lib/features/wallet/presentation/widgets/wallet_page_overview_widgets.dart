part of 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';

const int _kPhotoCostSpark = 6;
const int _kVideoCostSpark = 33;
const String _kWalletHeroLogoAsset = 'assets/rewards/wallet-hero-logo.png';

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
    final colors = context.petMagicColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balance = wallet?.balance ?? 0;
    final photosApprox = (balance / _kPhotoCostSpark).floor();
    final videosApprox = (balance / _kVideoCostSpark).floor();
    final cardTextPrimary = isDark ? Colors.white : const Color(0xFF19142A);
    final cardTextSecondary = isDark
        ? Colors.white.withValues(alpha: 0.78)
        : const Color(0xFF5E5876);
    final cardGradientColors = isDark
        ? const [Color(0xFF04131E), Color(0xFF071E2D), Color(0xFF0A1628)]
        : const [Color(0xFFF6F1FF), Color(0xFFEDE5FF), Color(0xFFF9F6FF)];
    final cardBorderColor = isDark
        ? colors.border.withValues(alpha: 0.84)
        : const Color(0xFFD6CFFF);
    final refreshBackground = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.92);
    final refreshForeground = isDark
        ? cardTextSecondary
        : const Color(0xFF635A8A);
    final chipBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.24)
        : const Color(0xFFCFC4FF);
    final chipBackground = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.86);

    return ProfileGlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cardBorderColor),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color(0xCC00B6A8).withValues(alpha: 0.12)
                  : const Color(0xFFA88FFF).withValues(alpha: 0.2),
              blurRadius: isDark ? 34 : 26,
              spreadRadius: isDark ? 3 : 1,
              offset: const Offset(0, 10),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.55, 1.0],
            colors: cardGradientColors,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -44,
              left: -24,
              child: _WalletGlowOrb(
                size: isDark ? 150 : 120,
                color: isDark
                    ? const Color(0xFF16D3B3).withValues(alpha: 0.22)
                    : const Color(0xFFB89BFF).withValues(alpha: 0.26),
              ),
            ),
            Positioned(
              right: -50,
              top: -12,
              child: _WalletGlowOrb(
                size: isDark ? 180 : 160,
                color: isDark
                    ? const Color(0xFF2B66FF).withValues(alpha: 0.18)
                    : const Color(0xFFE9DAFF).withValues(alpha: 0.35),
              ),
            ),
            Positioned(
              right: 108,
              bottom: 38,
              child: _WalletGlowOrb(
                size: 82,
                color: isDark
                    ? const Color(0xFF13E5BD).withValues(alpha: 0.16)
                    : const Color(0xFFD7CBFF).withValues(alpha: 0.22),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;

                  final overview = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              text.walletBalanceEyebrow,
                              style: TextStyle(
                                color: cardTextSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: onRefresh,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            tooltip: text.walletRefreshTooltip,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 34,
                              height: 34,
                            ),
                            style: IconButton.styleFrom(
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: refreshForeground,
                              backgroundColor: refreshBackground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              NumberFormat.decimalPattern().format(balance),
                              style: TextStyle(
                                color: cardTextPrimary,
                                fontSize: 50,
                                fontWeight: FontWeight.w900,
                                height: 0.96,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const PawSparkIcon(size: 22),
                            const SizedBox(width: 6),
                            Text(
                              text.walletBalanceUnit,
                              style: TextStyle(
                                color: colors.accent,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (balance > 0) ...[
                        const SizedBox(height: 10),
                        Text(
                          text.walletWhatYouCanCreateTitle,
                          style: TextStyle(
                            color: cardTextSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _BalanceUsageChip(
                              icon: Icons.photo_camera_outlined,
                              label: text.walletApproxPhotos(photosApprox),
                              iconColor: colors.accent,
                              textColor: cardTextPrimary,
                              borderColor: chipBorderColor,
                              backgroundColor: chipBackground,
                            ),
                            _BalanceUsageChip(
                              icon: Icons.play_arrow_rounded,
                              label: text.walletApproxVideos(videosApprox),
                              iconColor: colors.accent,
                              textColor: cardTextPrimary,
                              borderColor: chipBorderColor,
                              backgroundColor: chipBackground,
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(
                          text.walletInsufficientBalanceError,
                          style: TextStyle(
                            color: cardTextSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  );
                  final heroArtwork = _BalanceHeroArtwork(isDark: isDark);

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        overview,
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: heroArtwork,
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: overview),
                      const SizedBox(width: 12),
                      heroArtwork,
                    ],
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

class _BalanceUsageChip extends StatelessWidget {
  const _BalanceUsageChip({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textColor,
    required this.borderColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;
  final Color borderColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        color: backgroundColor,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceHeroArtwork extends StatelessWidget {
  const _BalanceHeroArtwork({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 152,
      height: 152,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomRight,
        children: [
          Positioned(
            right: 6,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.18)
                    : const Color(0xFFBAA6FF).withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0x33000000)
                        : const Color(0x80C7B8FF),
                    blurRadius: isDark ? 18 : 14,
                    spreadRadius: 1,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const SizedBox(width: 78, height: 26),
            ),
          ),
          Positioned(
            right: -18,
            bottom: -30,
            child: Image.asset(
              _kWalletHeroLogoAsset,
              width: 170,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            right: 24,
            bottom: 70,
            child: _WalletGlowOrb(
              size: 36,
              color: isDark
                  ? const Color(0xFFB793FF).withValues(alpha: 0.24)
                  : const Color(0xFFDBC7FF).withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletGlowOrb extends StatelessWidget {
  const _WalletGlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
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
