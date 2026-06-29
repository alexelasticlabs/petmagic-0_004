part of 'profile_notifications_settings_section.dart';

class _NotificationsDetailHeader extends StatelessWidget {
  const _NotificationsDetailHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final router = GoRouter.of(context);

    return Row(
      children: [
        IconButton(
          onPressed: () {
            if (router.canPop()) {
              router.pop();
              return;
            }

            router.go('/profile/settings');
          },
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textStrong,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationToggleRow extends StatelessWidget {
  const _NotificationToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.icon,
    this.subtitle,
    this.enabled = true,
    this.showDivider = true,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final activeColor = value ? colors.accent : colors.textMuted;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: colors.border.withValues(alpha: 0.75),
                ),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: activeColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 14.5,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Switch.adaptive(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: colors.accent,
              activeTrackColor: colors.accent.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _PushPermissionStatusCard extends StatelessWidget {
  const _PushPermissionStatusCard({
    required this.label,
    required this.value,
    required this.status,
  });

  final String label;
  final String value;
  final AuthorizationStatus? status;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isAllowed =
        status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    final isDenied = status == AuthorizationStatus.denied;
    final chipColor = isAllowed
        ? colors.accent
        : isDenied
        ? colors.danger
        : colors.textMuted;
    final chipIcon = isAllowed
        ? Icons.notifications_active_rounded
        : isDenied
        ? Icons.notifications_off_outlined
        : Icons.notifications_none_rounded;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: chipColor.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(chipIcon, size: 20, color: chipColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  color: chipColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: chipColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: chipColor.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              isAllowed
                  ? '✓'
                  : isDenied
                  ? '✗'
                  : '?',
              style: TextStyle(
                color: chipColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DevicePermissionRow extends StatelessWidget {
  const _DevicePermissionRow({
    required this.name,
    required this.stateLabel,
    required this.state,
  });

  final String name;
  final String stateLabel;
  final AppPermissionState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isOk =
        state == AppPermissionState.granted ||
        state == AppPermissionState.limited;
    final chipColor = isOk ? colors.accent : colors.textMuted;

    return Row(
      children: [
        Icon(
          isOk
              ? Icons.check_circle_outline_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: chipColor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          stateLabel,
          style: TextStyle(
            color: chipColor,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
