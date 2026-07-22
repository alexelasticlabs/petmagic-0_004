part of 'support_home_page.dart';

class _SupportTabButton extends StatelessWidget {
  const _SupportTabButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  final String title;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? colors.accent.withValues(alpha: 0.75)
                  : colors.border,
            ),
            color: isActive
                ? colors.accent.withValues(alpha: 0.16)
                : colors.surface,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? colors.accent : colors.textSoft,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.tab,
    required this.onOpenChat,
    required this.subtitle,
  });

  final SupportChatConversation conversation;
  final _SupportHomeTab tab;
  final VoidCallback onOpenChat;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tab == _SupportHomeTab.archive
                ? text.supportChatArchiveAction
                : text.supportChatStatusOpen,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            conversation.userDisplayName?.trim().isNotEmpty == true
                ? conversation.userDisplayName!.trim()
                : conversation.userEmail,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                style: TextStyle(color: colors.textSoft, fontSize: 12),
              ),
            ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onOpenChat,
            child: Text(text.supportHomeOpenChatAction),
          ),
        ],
      ),
    );
  }
}

class _SupportTopic {
  const _SupportTopic({
    required this.icon,
    this.isPremium = false,
    required this.label,
    required this.scenario,
  });

  final IconData icon;
  final bool isPremium;
  final String label;
  final String scenario;
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});

  final _SupportTopic topic;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ProfileGlassCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => context.appNavigator.push(
            SupportAssistantDestination(scenario: topic.scenario),
          ),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent.withValues(alpha: 0.12),
                  ),
                  child: topic.isPremium
                      ? const PremiumCrownIcon(size: 20)
                      : Icon(topic.icon, color: colors.accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    topic.label,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textSoft,
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
