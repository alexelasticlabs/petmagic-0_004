part of 'auth_flow_widgets.dart';

class DarkTrustPanel extends StatelessWidget {
  const DarkTrustPanel({
    super.key,
    required this.secureTitle,
    required this.secureSubtitle,
    required this.fastTitle,
    required this.fastSubtitle,
    required this.lovedTitle,
    required this.lovedSubtitle,
  });

  final String secureTitle;
  final String secureSubtitle;
  final String fastTitle;
  final String fastSubtitle;
  final String lovedTitle;
  final String lovedSubtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceGlass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: FeatureColumn(
              icon: Icons.verified_user_outlined,
              iconColor: colors.accent,
              title: secureTitle,
              subtitle: secureSubtitle,
            ),
          ),
          FeatureDivider(color: colors.border),
          Expanded(
            child: FeatureColumn(
              icon: Icons.bolt_rounded,
              iconColor: colors.accent,
              title: fastTitle,
              subtitle: fastSubtitle,
            ),
          ),
          FeatureDivider(color: colors.border),
          Expanded(
            child: FeatureColumn(
              icon: Icons.favorite_border_rounded,
              iconColor: colors.accent,
              title: lovedTitle,
              subtitle: lovedSubtitle,
            ),
          ),
        ],
      ),
    );
  }
}

class LightPrivacyPanel extends StatelessWidget {
  const LightPrivacyPanel({
    super.key,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 2 : 4),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 11 : 13,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? colors.accent.withValues(alpha: 0.08)
            : colors.accentSoft.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(compact ? 18 : 20),
        border: Border.all(
          color: isDark
              ? colors.accent.withValues(alpha: 0.16)
              : colors.accent.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isDark ? 0.16 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 30 : 34,
            height: compact ? 30 : 34,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: isDark ? 0.12 : 0.16),
              borderRadius: BorderRadius.circular(compact ? 10 : 11),
            ),
            child: Icon(
              Icons.shield_outlined,
              color: colors.accent,
              size: compact ? 16 : 18,
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: compact ? 12.6 : 13.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: compact ? 3 : 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: compact ? 10.9 : 11.8,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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

class FeatureColumn extends StatelessWidget {
  const FeatureColumn({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 26),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textMuted, fontSize: 11, height: 1.35),
        ),
      ],
    );
  }
}

class FeatureDivider extends StatelessWidget {
  const FeatureDivider({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 82,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: color,
    );
  }
}
