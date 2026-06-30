part of 'rewards_page.dart';

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
