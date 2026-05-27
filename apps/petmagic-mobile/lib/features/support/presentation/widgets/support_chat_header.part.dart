part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _SupportHeader extends StatelessWidget {
  const _SupportHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: colors.textStrong,
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.surfaceStrong,
                  colors.accent.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(color: colors.border.withValues(alpha: 0.75)),
            ),
            child: Icon(Icons.pets_rounded, size: 20, color: colors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _supportSecondaryGreen,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
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
    );
  }
}

class _SupportSecurityCard extends StatelessWidget {
  const _SupportSecurityCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_rounded, color: colors.textMuted, size: 13),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportConversationStatusStrip extends StatelessWidget {
  const _SupportConversationStatusStrip({required this.conversation});

  final SupportChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final descriptor = _resolveConversationStatusDescriptor(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: descriptor.color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(descriptor.icon, color: descriptor.color, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                descriptor.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({IconData icon, Color color, String title, String subtitle})
  _resolveConversationStatusDescriptor(BuildContext context) {
    final text = AppLocalizations.of(context);
    final normalizedStatus = conversation.status.trim().toLowerCase();
    const mutedColor = Color(0xFF8A94A6);
    const activeColor = _supportSecondaryGreen;

    if (normalizedStatus == 'resolved') {
      return (
        icon: Icons.check_circle_rounded,
        color: activeColor,
        title: text.supportChatStatusResolved,
        subtitle: text.supportChatResolvedStatusHint,
      );
    }

    if (normalizedStatus == 'closed') {
      return (
        icon: Icons.archive_rounded,
        color: mutedColor,
        title: text.supportChatStatusClosed,
        subtitle: text.supportChatClosedStatusHint,
      );
    }

    if (normalizedStatus == 'waitingforuser') {
      return (
        icon: Icons.mark_chat_unread_rounded,
        color: activeColor,
        title: text.supportChatAwaitingYourReplyStatus,
        subtitle: text.supportChatSupportRepliedStatusHint,
      );
    }

    if (normalizedStatus == 'inprogress') {
      return (
        icon: Icons.hourglass_top_rounded,
        color: activeColor,
        title: text.supportChatStatusInProgress,
        subtitle: text.supportChatInProgressStatusHint,
      );
    }

    if (normalizedStatus == 'new' ||
        normalizedStatus == 'open' ||
        normalizedStatus == 'waitingforsupport') {
      return (
        icon: Icons.mark_email_unread_rounded,
        color: activeColor,
        title: text.supportChatSystemNoticeTitle,
        subtitle: text.supportChatSystemNoticeBody,
      );
    }

    return (
      icon: Icons.support_agent_rounded,
      color: activeColor,
      title: text.supportChatSystemNoticeTitle,
      subtitle: text.supportChatWaitingForSupportStatusHint,
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: colors.border.withValues(alpha: 0.9),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: colors.border.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}
