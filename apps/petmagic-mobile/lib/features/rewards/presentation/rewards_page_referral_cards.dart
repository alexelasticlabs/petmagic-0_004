part of 'rewards_page.dart';

const _kRewardsPremiumMascotAsset = 'assets/rewards/premium-upsell-dog.png';

class _PromoCodeCard extends StatefulWidget {
  const _PromoCodeCard({required this.isSubmitting, required this.onSubmit});

  final bool isSubmitting;
  final Future<String?> Function(String code) onSubmit;

  @override
  State<_PromoCodeCard> createState() => _PromoCodeCardState();
}

class _PromoCodeCardState extends State<_PromoCodeCard> {
  late final TextEditingController _controller;
  String? _feedbackMessage;
  _FeedbackTone _feedbackTone = _FeedbackTone.info;

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

  void _showFeedback(String message, _FeedbackTone tone) {
    setState(() {
      _feedbackMessage = message;
      _feedbackTone = tone;
    });
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    final text = AppLocalizations.of(context);
    if (code.isEmpty) {
      _showFeedback(text.rewardsPromoEmptyError, _FeedbackTone.warning);
      return;
    }

    if (widget.isSubmitting) {
      return;
    }

    _showFeedback(text.rewardsPromoCheckingStatus, _FeedbackTone.info);

    final error = await widget.onSubmit(code);
    if (!mounted) {
      return;
    }

    _showFeedback(
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
    final textTheme = Theme.of(context).textTheme;
    final promoForeground = Theme.of(context).colorScheme.onPrimary;
    final promoHeaderGradient = LinearGradient(
      colors: [
        colors.gold.withValues(alpha: 0.7),
        colors.accent.withValues(alpha: 0.9),
      ],
    );
    final promoButtonTextStyle = textTheme.labelLarge?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w900,
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
                        textStyle: promoButtonTextStyle,
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
                            textStyle: promoButtonTextStyle,
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
                if (_feedbackMessage != null) ...[
                  const SizedBox(height: 10),
                  _PromoFeedbackMessage(
                    message: _feedbackMessage!,
                    tone: _feedbackTone,
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

class _PromoFeedbackMessage extends StatelessWidget {
  const _PromoFeedbackMessage({required this.message, required this.tone});

  final String message;
  final _FeedbackTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final color = switch (tone) {
      _FeedbackTone.success => colors.accent,
      _FeedbackTone.warning => colors.gold,
      _FeedbackTone.info => colors.blue,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          tone == _FeedbackTone.success
              ? Icons.check_circle_rounded
              : Icons.info_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
