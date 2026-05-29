import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'support_assistant_scenarios.dart';
import 'support_assistant_page.dart';

enum _SupportHomeTab { active, archive }

class SupportHomePage extends ConsumerStatefulWidget {
  const SupportHomePage({super.key});

  static const routePath = '/profile/support';

  @override
  ConsumerState<SupportHomePage> createState() => _SupportHomePageState();
}

class _SupportHomePageState extends ConsumerState<SupportHomePage> {
  _SupportHomeTab _tab = _SupportHomeTab.active;
  bool _isLoadingConversation = true;
  String? _conversationError;
  SupportChatConversation? _conversation;

  @override
  void initState() {
    super.initState();
    _loadConversation();
  }

  Future<void> _loadConversation() async {
    setState(() {
      _isLoadingConversation = true;
      _conversationError = null;
    });

    try {
      final conversation = await ref.read(supportChatRepositoryProvider).getConversation();
      if (!mounted) {
        return;
      }

      setState(() {
        _conversation = conversation;
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      final isNotFound = error.message
          .toLowerCase()
          .contains('support.conversation_not_found');
      setState(() {
        _conversation = null;
        _conversationError = isNotFound ? null : error.message;
      });
    } on Object {
      if (!mounted) {
        return;
      }

      setState(() {
        _conversation = null;
        _conversationError = 'support.unavailable';
      });
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingConversation = false;
    });
  }

  bool _isArchived(SupportChatConversation conversation) {
    final status = conversation.status.trim().toLowerCase();
    return status == 'closed' || status == 'resolved';
  }

  String _formatLastActivity(BuildContext context, DateTime? lastMessageAtUtc) {
    if (lastMessageAtUtc == null) {
      return '';
    }

    final localDateTime = lastMessageAtUtc.toLocal();
    final material = MaterialLocalizations.of(context);
    return '${material.formatShortDate(localDateTime)} ${material.formatTimeOfDay(TimeOfDay.fromDateTime(localDateTime), alwaysUse24HourFormat: true)}';
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    final topics = _buildTopics(text);
    final hasConversation = _conversation != null;
    final conversationIsArchived = hasConversation && _isArchived(_conversation!);
    final shouldShowConversation = hasConversation &&
        ((_tab == _SupportHomeTab.active && !conversationIsArchived) ||
            (_tab == _SupportHomeTab.archive && conversationIsArchived));

    return ProfileScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(text.supportHomeTitle),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                text.supportHomeSubtitle,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SupportTabButton(
                      title: text.supportChatStatusOpen,
                      isActive: _tab == _SupportHomeTab.active,
                      onTap: () => setState(() => _tab = _SupportHomeTab.active),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SupportTabButton(
                      title: text.supportChatArchiveAction,
                      isActive: _tab == _SupportHomeTab.archive,
                      onTap: () => setState(() => _tab = _SupportHomeTab.archive),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoadingConversation)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(color: colors.accent),
                  ),
                )
              else if (_conversationError != null)
                ProfileGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.supportChatEmptyTitle,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        text.supportChatEmptyMessage,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loadConversation,
                        child: Text(text.retryAction),
                      ),
                    ],
                  ),
                )
              else if (shouldShowConversation)
                _ConversationCard(
                  conversation: _conversation!,
                  tab: _tab,
                  onOpenChat: () => context.push(SupportChatPage.routePath),
                  subtitle: _formatLastActivity(context, _conversation!.lastMessageAtUtc),
                )
              else
                ProfileGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tab == _SupportHomeTab.archive
                            ? text.supportChatArchiveAction
                            : text.supportChatEmptyTitle,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        text.supportChatEmptyMessage,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.push(SupportChatPage.routePath),
                        child: Text(text.supportHomeOpenChatAction),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              ...topics.map((topic) => _TopicCard(topic: topic)),
            ],
          ),
        ),
      ),
    );
  }

  List<_SupportTopic> _buildTopics(AppLocalizations text) {
    const keys = <String>[
      'GenerationIssue',
      'GenerationTooLong',
      'TokensNotArrived',
      'PremiumIssue',
      'PaymentRefund',
      'Other',
    ];
    return keys
        .map((key) => buildSupportAssistantScenario(key, text))
        .map(
          (scenario) => _SupportTopic(
            icon: scenario.icon,
            label: scenario.topicLabel,
            scenario: scenario.key,
          ),
        )
        .toList(growable: false);
  }
}

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
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 12,
                ),
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
    required this.label,
    required this.scenario,
  });

  final IconData icon;
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
          onTap: () => context.push(
            '${SupportAssistantPage.routePath}?scenario=${Uri.encodeComponent(topic.scenario)}',
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
                  child: Icon(topic.icon, color: colors.accent, size: 20),
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
