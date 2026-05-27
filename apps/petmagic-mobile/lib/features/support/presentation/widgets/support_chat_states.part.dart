part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _SupportEmptyState extends StatelessWidget {
  const _SupportEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: ProfileGlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent.withValues(alpha: 0.14),
              ),
              child: Icon(icon, color: colors.accent, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Align(
              child: FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.edit_outlined),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportStarterState extends StatelessWidget {
  const _SupportStarterState({
    required this.title,
    required this.description,
    required this.quickActions,
    required this.onQuickActionSelected,
  });

  final String title;
  final String description;
  final List<_SupportQuickActionData> quickActions;
  final ValueChanged<String> onQuickActionSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return ProfileGlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent.withValues(alpha: 0.14),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: colors.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).supportChatTeamTitle,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 12.5,
                        height: 1.33,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final action in quickActions)
                ActionChip(
                  onPressed: () => onQuickActionSelected(action.prompt),
                  avatar: Icon(action.icon, size: 14, color: colors.accent),
                  label: Text(action.label),
                  side: BorderSide(color: colors.border.withValues(alpha: 0.7)),
                  backgroundColor: colors.surfaceStrong.withValues(alpha: 0.72),
                  labelStyle: TextStyle(
                    color: colors.textStrong,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
