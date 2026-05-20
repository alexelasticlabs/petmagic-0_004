import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_controller.dart';

class SupportChatPage extends ConsumerStatefulWidget {
  const SupportChatPage({super.key});

  static const routePath = '/profile/support';

  @override
  ConsumerState<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends ConsumerState<SupportChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ref.read(supportChatControllerProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    ref.read(supportChatControllerProvider.notifier).stop();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final state = ref.watch(supportChatControllerProvider);
    final controller = ref.read(supportChatControllerProvider.notifier);
    final conversation = state.conversation;
    final messages = conversation?.messages ?? const <SupportChatMessage>[];

    if (messages.length != _lastMessageCount) {
      _lastMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) {
          return;
        }

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      });
    }

    return ProfileScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SizedBox.expand(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
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
                              text.supportChatTitle,
                              style: TextStyle(
                                color: colors.textStrong,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              text.supportChatSubtitle,
                              style: TextStyle(
                                color: colors.textSoft,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (conversation != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ProfileStatusPill(
                            label: _statusLabel(text, conversation.status),
                          ),
                          if (conversation
                                  .assignedAdminDisplayName
                                  ?.isNotEmpty ==
                              true)
                            ProfileStatusPill(
                              label: conversation.assignedAdminDisplayName!,
                            ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: () {
                      if (state.isLoading && conversation == null) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (conversation == null) {
                        return Center(
                          child: _SupportEmptyState(
                            icon: Icons.support_agent_rounded,
                            title: text.supportChatEmptyTitle,
                            description:
                                state.errorMessage ??
                                text.supportChatEmptyMessage,
                            actionLabel: text.retryAction,
                            onAction: controller.initialize,
                          ),
                        );
                      }

                      if (messages.isEmpty) {
                        return RefreshIndicator(
                          onRefresh: controller.refresh,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Center(
                                    child: _SupportEmptyState(
                                      icon: Icons.mark_chat_unread_outlined,
                                      title: text.supportChatEmptyTitle,
                                      description: text.supportChatEmptyMessage,
                                      actionLabel: text.supportChatSendAction,
                                      onAction: () {
                                        _messageFocusNode.requestFocus();
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: controller.refresh,
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
                          itemCount:
                              messages.length +
                              (state.errorMessage == null ? 0 : 1),
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (state.errorMessage != null && index == 0) {
                              return ProfileMessageCard(
                                message: state.errorMessage!,
                                tone: colors.danger,
                              );
                            }

                            final messageIndex = state.errorMessage == null
                                ? index
                                : index - 1;
                            final message = messages[messageIndex];
                            return _MessageBubble(message: message);
                          },
                        ),
                      );
                    }(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: ProfileGlassCard(
                    child: Material(
                      color: Colors.transparent,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              focusNode: _messageFocusNode,
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.newline,
                              style: TextStyle(
                                color: colors.textStrong,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: text.supportChatInputHint,
                                hintStyle: TextStyle(
                                  color: colors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: state.isSending
                                ? null
                                : () async {
                                    final body = _messageController.text;
                                    await controller.sendMessage(body);
                                    if (!mounted) {
                                      return;
                                    }

                                    if (body.trim().isNotEmpty) {
                                      _messageController.clear();
                                    }
                                  },
                            icon: state.isSending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(text.supportChatSendAction),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations text, String status) {
    return switch (status.toLowerCase()) {
      'open' => text.supportChatStatusOpen,
      'inprogress' => text.supportChatStatusInProgress,
      'resolved' => text.supportChatStatusResolved,
      'closed' => text.supportChatStatusClosed,
      _ => status,
    };
  }
}

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
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent.withValues(alpha: 0.14),
              ),
              child: Icon(icon, color: colors.accent, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.edit_outlined),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SupportChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final bubbleColor = message.isFromAdmin
        ? colors.surfaceStrong
        : colors.accent.withValues(alpha: 0.16);
    final borderColor = message.isFromAdmin
        ? colors.border
        : colors.accent.withValues(alpha: 0.4);
    final alignment = message.isFromAdmin
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final timeLabel = DateFormat(
      'HH:mm',
    ).format(message.createdAtUtc.toLocal());

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderDisplayName,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message.body,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      timeLabel,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!message.isFromAdmin) ...[
                      const SizedBox(width: 6),
                      Icon(
                        message.isRead
                            ? Icons.done_all_rounded
                            : Icons.check_rounded,
                        size: 14,
                        color: message.isRead
                            ? colors.accent
                            : colors.textMuted,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
