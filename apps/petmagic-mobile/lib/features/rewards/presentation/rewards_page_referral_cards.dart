part of 'rewards_page.dart';

const _kRewardsPremiumMascotAsset = 'assets/rewards/premium-upsell-dog.png';
bool _isRuRewardsLocale(BuildContext context) =>
    Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';

class _PromoCodeCard extends StatefulWidget {
  const _PromoCodeCard({required this.isSubmitting, required this.onSubmit});

  final bool isSubmitting;
  final Future<String?> Function(String code) onSubmit;

  @override
  State<_PromoCodeCard> createState() => _PromoCodeCardState();
}

class _PromoCodeCardState extends State<_PromoCodeCard> {
  late final TextEditingController _controller;

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

  void _showInAppPush(String message, _FeedbackTone tone) {
    PetMagicToast.show(
      context,
      message: message,
      tone: switch (tone) {
        _FeedbackTone.success => PetMagicToastTone.success,
        _FeedbackTone.warning => PetMagicToastTone.warning,
        _FeedbackTone.info => PetMagicToastTone.info,
      },
    );
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    final text = AppLocalizations.of(context);
    if (code.isEmpty) {
      _showInAppPush(text.rewardsPromoEmptyError, _FeedbackTone.warning);
      return;
    }

    if (widget.isSubmitting) {
      return;
    }

    _showInAppPush(text.rewardsPromoCheckingStatus, _FeedbackTone.info);

    final error = await widget.onSubmit(code);
    if (!mounted) {
      return;
    }

    _showInAppPush(
      error == null
          ? text.walletRedeemSuccessMessage
          : friendlyRewardsError(text, error),
      error == null ? _FeedbackTone.success : _FeedbackTone.warning,
    );

    if (error == null) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final promoForeground = Theme.of(context).colorScheme.onPrimary;
    final promoHeaderGradient = LinearGradient(
      colors: [
        colors.gold.withValues(alpha: 0.7),
        colors.accent.withValues(alpha: 0.9),
      ],
    );

    return _RewardsGlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Material(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 390;
            final actionWidth = (constraints.maxWidth * 0.34).clamp(
              118.0,
              140.0,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  icon: Icons.confirmation_number_rounded,
                  iconGradient: promoHeaderGradient,
                  title: text.rewardsPromoTitle,
                  subtitle: text.rewardsPromoSubtitle,
                  iconBoxSize: 42,
                  iconSize: 22,
                  titleSize: 17,
                  subtitleSize: 12.5,
                ),
                const SizedBox(height: 12),
                if (compact) ...[
                  SizedBox(
                    height: 50,
                    child: TextField(
                      key: const Key('rewards_promo_input'),
                      controller: _controller,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => unawaited(_submit()),
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                      decoration: _fieldDecoration(
                        context,
                        hintText: text.walletRedeemHint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      key: const Key('rewards_promo_submit'),
                      onPressed: widget.isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: promoForeground,
                        disabledBackgroundColor: colors.border,
                        disabledForegroundColor: colors.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: widget.isSubmitting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  promoForeground,
                                ),
                              ),
                            )
                          : Text(
                              text.walletRedeemAction,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: TextField(
                            key: const Key('rewards_promo_input'),
                            controller: _controller,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => unawaited(_submit()),
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                            decoration: _fieldDecoration(
                              context,
                              hintText: text.walletRedeemHint,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: actionWidth,
                        height: 50,
                        child: FilledButton(
                          key: const Key('rewards_promo_submit'),
                          onPressed: widget.isSubmitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.accent,
                            foregroundColor: promoForeground,
                            disabledBackgroundColor: colors.border,
                            disabledForegroundColor: colors.textMuted,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          child: widget.isSubmitting
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      promoForeground,
                                    ),
                                  ),
                                )
                              : Text(
                                  text.walletRedeemAction,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RewardsPremiumUpsellCard extends StatelessWidget {
  const _RewardsPremiumUpsellCard({required this.onOpenPremium});

  final VoidCallback onOpenPremium;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final isRu = _isRuRewardsLocale(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpenPremium,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE0A91E).withValues(
                  alpha: isLight ? 0.78 : 0.88,
                ),
                width: 1.15,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: PremiumBannerStyle.gradient(isLight),
              ),
              boxShadow: [
                BoxShadow(
                  color: isLight
                      ? const Color(0xFFD7B35D).withValues(alpha: 0.25)
                      : const Color(0xFF02070F).withValues(alpha: 0.55),
                  blurRadius: isLight ? 12 : 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: 168,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.3, 0.35),
                          radius: 1.2,
                          colors: [
                            const Color(0xFFF4C64D).withValues(
                              alpha: isLight ? 0.2 : 0.18,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Image.asset(
                        _kRewardsPremiumMascotAsset,
                        height: 136,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 140, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFE0A91E).withValues(
                                alpha: isLight ? 0.7 : 0.8,
                              ),
                            ),
                            color: const Color(0xFF201300).withValues(
                              alpha: isLight ? 0.08 : 0.24,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const PremiumCrownIcon(size: 12),
                              const SizedBox(width: 5),
                              Text(
                                text.premiumLabel,
                                style: TextStyle(
                                  color: const Color(0xFFEABA47),
                                  fontSize: 10.4,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isRu ? 'Premium выгоднее' : 'Premium is better',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF1E1608)
                                : const Color(0xFFEABF55),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isRu
                              ? '40 PowSpark каждую неделю\nБез водяного знака, экспорт\nвысокого качества'
                              : '40 PowSpark every week\nNo watermark, high-quality\nexport',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF3B3324)
                                : const Color(0xFFE3DFD2),
                            fontSize: 11.2,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        PremiumShimmerButton(
                          label: text.profilePremiumOpenAction,
                          onTap: onOpenPremium,
                          height: 42,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardsGoldShimmerButton extends StatefulWidget {
  const _RewardsGoldShimmerButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_RewardsGoldShimmerButton> createState() =>
      _RewardsGoldShimmerButtonState();
}

class _RewardsGoldShimmerButtonState extends State<_RewardsGoldShimmerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: widget.onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE0A91E).withValues(alpha: 0.34),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                final shimmerStart = -1.6 + (t * 2.8);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF4C64D), Color(0xFFEAB13A)],
                        ),
                      ),
                      child: child,
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(shimmerStart, -1),
                              end: Alignment(shimmerStart + 0.9, 1),
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.68),
                                Colors.transparent,
                              ],
                              stops: const [0.23, 0.5, 0.77],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Color(0xFF261903),
                        fontSize: 11.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF261903),
                      size: 15,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferralCard extends StatefulWidget {
  const _ReferralCard({required this.rewards});

  final _RewardsSummaryView? rewards;

  @override
  State<_ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends State<_ReferralCard> {
  static const _inviteImage = 'assets/rewards/invite-friend.png';

  Timer? _copyHintTimer;
  bool _showCopyHint = false;

  @override
  void dispose() {
    _copyHintTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyCode() async {
    final code = widget.rewards?.referralCode;
    if (code == null || code.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) {
      return;
    }

    _copyHintTimer?.cancel();
    setState(() => _showCopyHint = true);
    _copyHintTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }

      setState(() => _showCopyHint = false);
    });
  }

  Future<void> _shareCode() async {
    final rewards = widget.rewards;
    if (rewards == null || rewards.referralCode.isEmpty) {
      return;
    }

    final text = AppLocalizations.of(context);
    final shareMessage = text.rewardsReferralShareMessage(
      rewards.referralCode,
      rewards.referralBonusSpark,
    );

    await SharePlus.instance.share(ShareParams(text: shareMessage));
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final rewards = widget.rewards;
    final hasRewards = rewards != null;
    final bonus = rewards?.referralBonusSpark ?? 15;
    final colors = context.petMagicColors;
    final cardBorder = colors.accent.withValues(alpha: 0.32);
    final cardGradient = [
      colors.accentSoft.withValues(alpha: 0.92),
      colors.surfaceStrong.withValues(alpha: 0.98),
      colors.surface.withValues(alpha: 0.98),
    ];
    final shareIconGradient = [
      colors.accent.withValues(alpha: 0.26),
      colors.accent.withValues(alpha: 0.14),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // 36 = 18px left + 18px right padding inside the glass panel
        final innerWidth = constraints.maxWidth - 36;
        final textWidth = innerWidth * 0.58;
        final imageWidth = (innerWidth * 0.44).clamp(132.0, 188.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            _RewardsGlassPanel(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              borderColor: cardBorder,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: cardGradient,
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: textWidth,
                      child: _SectionHeader(
                        icon: Icons.group_rounded,
                        iconGradient: LinearGradient(colors: shareIconGradient),
                        title: text.rewardsReferralTitle,
                        subtitle: null,
                        iconBoxSize: 48,
                        iconSize: 24,
                        titleSize: 17.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: textWidth,
                      child: _ReferralInviteText(bonus: bonus),
                    ),
                    const SizedBox(height: 12),
                    _ReferralCodeBox(
                      code: hasRewards && rewards.referralCode.isNotEmpty
                          ? rewards.referralCode
                          : '...',
                      canCopy: hasRewards,
                      onCopy: _copyCode,
                    ),
                    if (_showCopyHint) ...[
                      const SizedBox(height: 6),
                      Text(
                        text.rewardsReferralCopiedMessage,
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _GradientActionButton(
                      key: const Key('rewards_referral_share'),
                      height: 52,
                      label: text.rewardsReferralShareCodeAction,
                      icon: Icons.ios_share_rounded,
                      onPressed: hasRewards ? _shareCode : null,
                    ),
                    const SizedBox(height: 8),
                    _ReferralStats(rewards: rewards),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: -14,
              child: IgnorePointer(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: imageWidth,
                    maxHeight: 202,
                  ),
                  child: Image.asset(
                    _inviteImage,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReferralInviteText extends StatelessWidget {
  const _ReferralInviteText({required this.bonus});

  final int bonus;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${text.rewardsReferralInvitePrefix} '),
          TextSpan(
            text: '+$bonus ${text.walletBalanceUnit}',
            style: TextStyle(color: colors.accent, fontWeight: FontWeight.w900),
          ),
          TextSpan(text: ' ${text.rewardsReferralInviteSuffix}'),
        ],
      ),
      style: TextStyle(
        color: colors.textSoft,
        fontSize: 12.6,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ReferralCodeBox extends StatelessWidget {
  const _ReferralCodeBox({
    required this.code,
    required this.canCopy,
    required this.onCopy,
  });

  final String code;
  final bool canCopy;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.rewardsYourReferralCode,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 16,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.55,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            key: const Key('rewards_referral_copy'),
            onPressed: canCopy ? onCopy : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text(text.rewardsCopyReferralCodeAction),
          ),
        ],
      ),
    );
  }
}

class _ReferralInfoNote extends StatelessWidget {
  const _ReferralInfoNote({
    required this.rewards,
    required this.onHowItWorksTap,
  });

  final _RewardsSummaryView? rewards;
  final VoidCallback onHowItWorksTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final statusText = rewards == null
        ? text.rewardsReferralStatusLoading
        : rewards!.hasActivatedReferral
        ? _referralStatusText(text, rewards!)
        : text.rewardsReferralRulesNote;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: colors.textMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                TextButton(
                  onPressed: onHowItWorksTap,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(
                    text.rewardsReferralHowItWorksAction,
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendCodeCard extends StatefulWidget {
  const _FriendCodeCard({
    required this.rewards,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final _RewardsSummaryView? rewards;
  final bool isSubmitting;
  final Future<String?> Function(String code) onSubmit;

  @override
  State<_FriendCodeCard> createState() => _FriendCodeCardState();
}

class _FriendCodeCardState extends State<_FriendCodeCard> {
  late final TextEditingController _controller;
  late final FocusNode _friendCodeFocusNode;
  bool _showFriendCodeInput = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _friendCodeFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _FriendCodeCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.rewards?.hasActivatedReferral == true) {
      _showFriendCodeInput = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _friendCodeFocusNode.dispose();
    super.dispose();
  }

  void _showInAppPush(String message, _FeedbackTone tone) {
    PetMagicToast.show(
      context,
      message: message,
      tone: switch (tone) {
        _FeedbackTone.success => PetMagicToastTone.success,
        _FeedbackTone.warning => PetMagicToastTone.warning,
        _FeedbackTone.info => PetMagicToastTone.info,
      },
    );
  }

  void _openFriendCodeInput() {
    if (_showFriendCodeInput) {
      return;
    }

    setState(() => _showFriendCodeInput = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _friendCodeFocusNode.requestFocus();
    });
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    final text = AppLocalizations.of(context);
    if (code.isEmpty) {
      _showInAppPush(text.rewardsReferralEmptyError, _FeedbackTone.warning);
      return;
    }

    if (widget.isSubmitting) {
      return;
    }

    _showInAppPush(text.rewardsReferralCheckingStatus, _FeedbackTone.info);

    final error = await widget.onSubmit(code);
    if (!mounted) {
      return;
    }

    _showInAppPush(
      error == null
          ? text.rewardsReferralActivatedMessage
          : friendlyRewardsError(text, error),
      error == null ? _FeedbackTone.success : _FeedbackTone.warning,
    );

    if (error == null) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final referrerCode = widget.rewards?.referrerCode?.trim();
    final hasReferrerCode = referrerCode != null && referrerCode.isNotEmpty;
    final isReferralAlreadyActive =
        widget.rewards?.hasActivatedReferral == true;
    final cardBorder = colors.purple.withValues(alpha: 0.26);
    final cardGradient = [
      colors.surface,
      colors.surfaceStrong.withValues(alpha: 0.96),
    ];
    final iconGradient = [
      colors.purple.withValues(alpha: 0.24),
      colors.purple.withValues(alpha: 0.12),
    ];
    final iconColor = colors.purple;
    final actionGradient = [
      colors.purple.withValues(alpha: 0.8),
      colors.purple.withValues(alpha: 0.62),
    ];

    return _RewardsGlassPanel(
      padding: const EdgeInsets.all(16),
      borderColor: cardBorder,
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: cardGradient,
      ),
      child: Material(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 390;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(colors: iconGradient),
                        boxShadow: [
                          BoxShadow(
                            color: colors.purple.withValues(alpha: 0.17),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.group_add_rounded,
                        color: iconColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.rewardsReferralFriendCodePrompt,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text.rewardsReferralFriendCodeHint,
                            style: TextStyle(
                              color: colors.textSoft,
                              fontSize: 12,
                              height: 1.32,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_showFriendCodeInput && !compact) ...[
                      const SizedBox(width: 12),
                      _GradientActionButton(
                        key: const Key('rewards_referral_show_input'),
                        width: 168,
                        height: 48,
                        label: text.rewardsReferralUseFriendCodeAction,
                        gradient: LinearGradient(colors: actionGradient),
                        onPressed: _openFriendCodeInput,
                      ),
                    ],
                  ],
                ),
                if (!_showFriendCodeInput && compact) ...[
                  const SizedBox(height: 14),
                  _GradientActionButton(
                    key: const Key('rewards_referral_show_input'),
                    height: 48,
                    label: text.rewardsReferralUseFriendCodeAction,
                    gradient: LinearGradient(colors: actionGradient),
                    onPressed: _openFriendCodeInput,
                  ),
                ],
                if (isReferralAlreadyActive) ...[
                  const SizedBox(height: 14),
                  _InlineStatus(
                    message: text.rewardsReferralActivatedMessage,
                    tone: _feedbackToneColor(_FeedbackTone.success, colors),
                  ),
                  if (hasReferrerCode) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: colors.surfaceGlass,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: colors.accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  text.rewardsReferralInputLabel,
                                  style: TextStyle(
                                    color: colors.textSoft,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  referrerCode,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textStrong,
                                    fontSize: 14,
                                    letterSpacing: 0.45,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else if (_showFriendCodeInput) ...[
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('rewards_referral_input'),
                    controller: _controller,
                    focusNode: _friendCodeFocusNode,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => unawaited(_submit()),
                    style: TextStyle(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    decoration: _fieldDecoration(
                      context,
                      hintText: text.rewardsReferralInputHint,
                      labelText: text.rewardsReferralInputLabel,
                      icon: Icons.group_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GradientActionButton(
                    key: const Key('rewards_referral_submit'),
                    height: 48,
                    label: text.rewardsReferralActivateAction,
                    isLoading: widget.isSubmitting,
                    gradient: LinearGradient(colors: actionGradient),
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: widget.isSubmitting ? null : _submit,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
