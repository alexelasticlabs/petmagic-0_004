part of 'rewards_page.dart';

class _PromoCodeCard extends StatefulWidget {
  const _PromoCodeCard({required this.isSubmitting, required this.onSubmit});

  final bool isSubmitting;
  final Future<String?> Function(String code) onSubmit;

  @override
  State<_PromoCodeCard> createState() => _PromoCodeCardState();
}

class _PromoCodeCardState extends State<_PromoCodeCard> {
  late final TextEditingController _controller;
  String? _message;
  _FeedbackTone _messageTone = _FeedbackTone.info;

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
        _messageTone = _FeedbackTone.warning;
        _message = text.rewardsPromoEmptyError;
      });
      return;
    }

    if (widget.isSubmitting) {
      return;
    }

    setState(() {
      _messageTone = _FeedbackTone.info;
      _message = text.rewardsPromoCheckingStatus;
    });

    final error = await widget.onSubmit(code);
    if (!mounted) {
      return;
    }

    setState(() {
      _messageTone = error == null
          ? _FeedbackTone.success
          : _FeedbackTone.warning;
      _message = error == null
          ? text.walletRedeemSuccessMessage
          : friendlyRewardsError(text, error);
    });

    if (error == null) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return _RewardsGlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Material(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final actionWidth = (constraints.maxWidth * 0.34).clamp(
              118.0,
              140.0,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  icon: Icons.confirmation_number_rounded,
                  iconGradient: const LinearGradient(
                    colors: [Color(0xFFDDFB72), Color(0xFF49C667)],
                  ),
                  title: text.rewardsPromoTitle,
                  subtitle: text.rewardsPromoSubtitle,
                  iconBoxSize: 42,
                  iconSize: 22,
                  titleSize: 17,
                  subtitleSize: 12.5,
                ),
                const SizedBox(height: 12),
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
                          backgroundColor: const Color(0xFF49DA87),
                          foregroundColor: const Color(0xFF06140C),
                          disabledBackgroundColor: const Color(0xFF314036),
                          disabledForegroundColor: const Color(0xFF7F8EA0),
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
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF06140C),
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
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  _InlineStatus(
                    message: _message!,
                    tone: _feedbackToneColor(_messageTone, colors),
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
              borderColor: const Color(0xFF0C6E4D).withValues(alpha: 0.78),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF062D24).withValues(alpha: 0.96),
                  const Color(0xFF092B22).withValues(alpha: 0.88),
                  const Color(0xFF061018).withValues(alpha: 0.94),
                ],
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
                        iconGradient: const LinearGradient(
                          colors: [Color(0xFF46E58B), Color(0xFF11753D)],
                        ),
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
                        style: const TextStyle(
                          color: Color(0xFF44E681),
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
            style: const TextStyle(
              color: Color(0xFF48E581),
              fontWeight: FontWeight.w900,
            ),
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
        color: const Color(0xFF031116).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFF12382F).withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
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
                    style: const TextStyle(
                      color: Color(0xFF44E681),
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
  String? _message;
  _FeedbackTone _messageTone = _FeedbackTone.info;
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
      setState(() {
        _messageTone = _FeedbackTone.warning;
        _message = text.rewardsReferralEmptyError;
      });
      return;
    }

    if (widget.isSubmitting) {
      return;
    }

    setState(() {
      _messageTone = _FeedbackTone.info;
      _message = text.rewardsReferralCheckingStatus;
    });

    final error = await widget.onSubmit(code);
    if (!mounted) {
      return;
    }

    setState(() {
      _messageTone = error == null
          ? _FeedbackTone.success
          : _FeedbackTone.warning;
      _message = error == null
          ? text.rewardsReferralActivatedMessage
          : friendlyRewardsError(text, error);
    });

    if (error == null) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return _RewardsGlassPanel(
      padding: const EdgeInsets.all(16),
      borderColor: const Color(0xFF3B3264).withValues(alpha: 0.86),
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF15182B).withValues(alpha: 0.96),
          const Color(0xFF101421).withValues(alpha: 0.96),
        ],
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5B347C), Color(0xFF2B1F54)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFA855F7,
                            ).withValues(alpha: 0.17),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.group_add_rounded,
                        color: Color(0xFFEBD6FF),
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFFA867F2), Color(0xFF7440B9)],
                        ),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA867F2), Color(0xFF7440B9)],
                    ),
                    onPressed: _openFriendCodeInput,
                  ),
                ],
                if (_showFriendCodeInput) ...[
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA867F2), Color(0xFF7440B9)],
                    ),
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: widget.isSubmitting ? null : _submit,
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  _InlineStatus(
                    message: _message!,
                    tone: _feedbackToneColor(_messageTone, colors),
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
