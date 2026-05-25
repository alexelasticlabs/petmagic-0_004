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
    required this.faqTitle,
    required this.quickActions,
    required this.faqItems,
    required this.onQuickActionSelected,
  });

  final String title;
  final String description;
  final String faqTitle;
  final List<_SupportQuickActionData> quickActions;
  final List<_SupportFaqItemData> faqItems;
  final ValueChanged<String> onQuickActionSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileGlassCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Stack(
            children: [
              Positioned(
                top: -4,
                right: 0,
                child: Icon(
                  Icons.pets_rounded,
                  size: 24,
                  color: colors.accent.withValues(alpha: 0.12),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 34,
                child: Icon(
                  Icons.pets_rounded,
                  size: 18,
                  color: colors.accent.withValues(alpha: 0.08),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colors.surfaceStrong,
                              colors.accent.withValues(alpha: 0.16),
                            ],
                          ),
                          border: Border.all(color: colors.border),
                        ),
                        child: Icon(
                          Icons.support_agent_rounded,
                          color: colors.accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context).supportChatTeamTitle,
                              style: TextStyle(
                                color: colors.textStrong,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 8,
                                  height: 8,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _supportSecondaryGreen,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    ).supportChatTeamStatus,
                                    style: TextStyle(
                                      color: colors.textSoft,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 20,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 13,
                      height: 1.42,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final action in quickActions)
                        ActionChip(
                          onPressed: () => onQuickActionSelected(action.prompt),
                          avatar: Icon(
                            action.icon,
                            size: 16,
                            color: colors.accent,
                          ),
                          label: Text(action.label),
                          side: BorderSide(
                            color: colors.border.withValues(alpha: 0.7),
                          ),
                          backgroundColor: colors.surfaceStrong.withValues(
                            alpha: 0.72,
                          ),
                          labelStyle: TextStyle(
                            color: colors.textStrong,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            faqTitle,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (final item in faqItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SupportFaqCard(
              item: item,
              onTap: () => onQuickActionSelected(item.title),
            ),
          ),
      ],
    );
  }
}

class _SupportFaqCard extends StatelessWidget {
  const _SupportFaqCard({required this.item, required this.onTap});

  final _SupportFaqItemData item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surfaceStrong.withValues(alpha: 0.66),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border.withValues(alpha: 0.78)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(item.icon, size: 18, color: colors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.body,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
