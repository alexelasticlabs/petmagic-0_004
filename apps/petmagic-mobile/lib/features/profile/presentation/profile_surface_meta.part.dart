part of 'profile_surface_widgets.dart';

class ProfileStatusPill extends StatelessWidget {
  const ProfileStatusPill({
    required this.label,
    this.leading,
    this.leadingWidget,
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  });

  final String label;
  final IconData? leading;
  final Widget? leadingWidget;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final baseBg = backgroundColor ?? colors.accentSoft;
    final baseFg = foregroundColor ?? colors.textStrong;
    final bg = isLight
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.22), baseBg)
        : baseBg;
    final fg = isLight
        ? Color.alphaBlend(Colors.black.withValues(alpha: 0.24), baseFg)
        : baseFg;
    final borderColor = (foregroundColor ?? colors.border).withValues(
      alpha: foregroundColor != null ? (isLight ? 0.52 : 0.38) : 0.9,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isLight ? 0.12 : 0.18),
            blurRadius: isLight ? 10 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final labelText = Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            );

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingWidget != null || leading != null) ...[
                  leadingWidget ?? Icon(leading, size: 13, color: fg),
                  const SizedBox(width: 6),
                ],
                if (constraints.hasBoundedWidth)
                  Flexible(child: labelText)
                else
                  labelText,
              ],
            );
          },
        ),
      ),
    );
  }
}

class ProfileStatTile extends StatelessWidget {
  const ProfileStatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final tone = highlight ?? colors.accent;

    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 11,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSectionLabel extends StatelessWidget {
  const ProfileSectionLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: colors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class ProfileSettingsRow extends StatelessWidget {
  const ProfileSettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.isDestructive = false,
    this.showDivider = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool isDestructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final tone = isDestructive ? colors.danger : colors.textStrong;
    final iconTone =
        iconColor ?? (isDestructive ? colors.danger : colors.accent);
    final iconBackground = isDestructive
        ? colors.danger.withValues(alpha: isLight ? 0.12 : 0.14)
        : colors.surfaceStrong.withValues(alpha: isLight ? 0.52 : 0.58);
    final iconBorder = isDestructive
        ? colors.danger.withValues(alpha: isLight ? 0.22 : 0.3)
        : colors.border.withValues(alpha: isLight ? 0.85 : 0.78);
    final resolvedIconColor = isDestructive
        ? colors.danger
        : Color.alphaBlend(
            colors.textStrong.withValues(alpha: isLight ? 0.35 : 0.18),
            iconTone,
          );

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconBorder),
            ),
            child: Icon(icon, color: resolvedIconColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tone,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDestructive
                        ? colors.danger.withValues(alpha: 0.82)
                        : colors.textSoft,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (trailing != null)
            Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: trailing!,
            )
          else if (trailingText != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                trailingText!,
                style: TextStyle(
                  color: isDestructive ? colors.danger : colors.accent,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              color: isDestructive ? colors.danger : colors.textSoft,
              size: 24,
            ),
        ],
      ),
    );

    final row = onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap, child: content),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: colors.border.withValues(alpha: 0.82),
                ),
              )
            : null,
      ),
      child: row,
    );
  }
}
