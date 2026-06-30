part of 'rewards_page.dart';

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
        fontSize: 12.5,
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
