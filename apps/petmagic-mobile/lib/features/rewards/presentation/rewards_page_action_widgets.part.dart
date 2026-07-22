part of 'rewards_page.dart';

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.gradient,
    this.width,
    this.height = 50,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Gradient? gradient;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final foreground = Theme.of(context).colorScheme.onPrimary;
    final actionTextStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: foreground,
      fontSize: 14,
      fontWeight: FontWeight.w900,
    );
    final enabledGradient =
        gradient ??
        LinearGradient(
          colors: [
            colors.accent.withValues(alpha: 0.95),
            colors.accent.withValues(alpha: 0.78),
          ],
        );
    final enabled = onPressed != null;

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(15),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: enabled
                  ? enabledGradient
                  : LinearGradient(
                      colors: [
                        colors.surfaceStrong.withValues(alpha: 0.9),
                        colors.surface.withValues(alpha: 0.9),
                      ],
                    ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: colors.accent.withValues(alpha: 0.24),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(foreground),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, color: foreground, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: actionTextStyle,
                            ),
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

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({required this.message, required this.tone});

  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          message,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message, required this.tone});

  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          message,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 12.5,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(
  BuildContext context, {
  required String hintText,
  String? labelText,
  IconData? icon,
}) {
  final colors = context.petMagicColors;

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    filled: true,
    fillColor: colors.surfaceGlass,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 20, color: colors.textSoft),
    hintStyle: TextStyle(
      color: colors.textMuted.withValues(alpha: 0.72),
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
    ),
    labelStyle: TextStyle(
      color: colors.textSoft,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: colors.accent, width: 1.4),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: colors.border),
    ),
  );
}

Color _feedbackToneColor(_FeedbackTone tone, PetMagicColors colors) {
  return switch (tone) {
    _FeedbackTone.success => colors.accent,
    _FeedbackTone.warning => colors.gold,
    _FeedbackTone.info => colors.blue,
  };
}

String _referralStatusText(AppLocalizations text, _RewardsSummaryView rewards) {
  if (rewards.isReferralRewarded || rewards.rewardedReferredUsersCount > 0) {
    return text.rewardsReferralStatusRewarded;
  }

  if (rewards.hasActivatedReferral ||
      rewards.pendingReferredUsersCount > 0 ||
      rewards.referredUsersCount > 0) {
    return text.rewardsReferralStatusPending;
  }

  return text.rewardsReferralStatusNone;
}
