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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final iconBackground = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colors.surfaceStrong.withValues(alpha: isLight ? 0.62 : 0.58),
        colors.surface.withValues(alpha: isLight ? 0.94 : 0.86),
      ],
    );
    final iconBorder = colors.border.withValues(alpha: isLight ? 0.92 : 0.8);
    final iconColor = Color.alphaBlend(
      colors.textStrong.withValues(alpha: isLight ? 0.28 : 0.18),
      colors.accent,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: iconBoxSize,
          height: iconBoxSize,
          decoration: BoxDecoration(
            gradient: iconBackground,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: iconBorder),
          ),
          child: Icon(icon, color: iconColor, size: iconSize),
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
    final colors = context.petMagicColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
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
              iconColor: colors.accent,
              label: text.rewardsReferralFriendsLabel,
              value: '${rewards?.referredUsersCount ?? 0}',
            ),
          ),
          const _MetricDivider(),
          Expanded(
            child: _MetricStat(
              icon: Icons.shopping_bag_rounded,
              iconColor: colors.gold,
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
    final colors = context.petMagicColors;

    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: colors.border,
    );
  }
}
