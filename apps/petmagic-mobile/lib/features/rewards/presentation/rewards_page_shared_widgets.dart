part of 'rewards_page.dart';

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconGradient,
    required this.title,
    this.subtitle,
    this.iconBoxSize = 50,
    this.iconSize = 26,
    this.titleSize = 19,
    this.subtitleSize = 13.5,
  });

  final IconData icon;
  final Gradient iconGradient;
  final String title;
  final String? subtitle;
  final double iconBoxSize;
  final double iconSize;
  final double titleSize;
  final double subtitleSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: iconBoxSize,
          height: iconBoxSize,
          decoration: BoxDecoration(
            gradient: iconGradient,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2BE66C).withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF042013), size: iconSize),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: titleSize,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: subtitleSize,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReferralStats extends StatelessWidget {
  const _ReferralStats({required this.rewards});

  final _RewardsSummaryView? rewards;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF071915).withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF174439).withValues(alpha: 0.62),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MetricStat(
              leading: const PawSparkIcon(size: 18),
              label: text.rewardsReferralEarnedLabel,
              value: '${rewards?.totalReferralBonusEarned ?? 0}',
              unit: text.walletBalanceUnit,
            ),
          ),
          const _MetricDivider(),
          Expanded(
            child: _MetricStat(
              icon: Icons.group_rounded,
              iconColor: const Color(0xFF48E581),
              label: text.rewardsReferralFriendsLabel,
              value: '${rewards?.referredUsersCount ?? 0}',
            ),
          ),
          const _MetricDivider(),
          Expanded(
            child: _MetricStat(
              icon: Icons.shopping_bag_rounded,
              iconColor: const Color(0xFFFFD35B),
              label: text.rewardsReferralBonusLabel,
              value: '${rewards?.rewardedReferredUsersCount ?? 0}',
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricStat extends StatelessWidget {
  const _MetricStat({
    this.icon,
    this.iconColor,
    this.leading,
    required this.label,
    required this.value,
    this.unit,
  });

  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (leading != null)
              leading!
            else
              Icon(icon ?? Icons.circle, color: iconColor, size: 18),
            const SizedBox(width: 4),
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value),
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFF7FE6B6).withValues(alpha: 0.22),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.gradient = const LinearGradient(
      colors: [Color(0xFF49DA87), Color(0xFF3ECE76)],
    ),
    this.width,
    this.height = 50,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Gradient gradient;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
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
                  ? gradient
                  : LinearGradient(
                      colors: [
                        const Color(0xFF314036).withValues(alpha: 0.8),
                        const Color(0xFF243328).withValues(alpha: 0.8),
                      ],
                    ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: const Color(0xFF37DF78).withValues(alpha: 0.24),
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
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null) ...[
                            Icon(
                              icon,
                              color: const Color(0xFF06140C),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF06140C),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
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
    fillColor: const Color(0xFF0A1522).withValues(alpha: 0.82),
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
      borderSide: BorderSide(
        color: const Color(0xFF253549).withValues(alpha: 0.95),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xFF47DF82), width: 1.4),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(
        color: const Color(0xFF253549).withValues(alpha: 0.95),
      ),
    ),
  );
}

Color _feedbackToneColor(_FeedbackTone tone, PetMagicColors colors) {
  return switch (tone) {
    _FeedbackTone.success => colors.accent,
    _FeedbackTone.warning => const Color(0xFFD7A44A),
    _FeedbackTone.info => colors.blue,
  };
}

String _referralStatusText(AppLocalizations text, _RewardsSummaryView rewards) {
  if (rewards.isReferralRewarded) {
    return text.rewardsReferralStatusRewarded;
  }

  if (rewards.hasActivatedReferral) {
    return text.rewardsReferralStatusPending;
  }

  return text.rewardsReferralStatusNone;
}
