part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _SupportConversationViewport extends StatelessWidget {
  const _SupportConversationViewport({
    required this.state,
    required this.conversation,
    required this.messages,
    required this.scrollController,
    required this.isWaitingForInitialConversation,
    required this.showLoadingFallback,
    required this.loadingFallbackMessageCode,
    required this.onRefresh,
    required this.onLoadOlderMessages,
    required this.onRetryInitialize,
    required this.onQuickActionSelected,
    required this.onOpenAttachment,
    required this.onOpenImage,
    required this.onOpenVideo,
    required this.onRetryAttachment,
    required this.onReplyToMessage,
    required this.onJumpToMessage,
    required this.highlightedMessageId,
    required this.messageItemKeyForId,
    required this.formatDayLabel,
    required this.isSameDay,
  });

  final SupportChatState state;
  final SupportChatConversation? conversation;
  final List<SupportChatMessage> messages;
  final ScrollController scrollController;
  final bool isWaitingForInitialConversation;
  final bool showLoadingFallback;
  final String loadingFallbackMessageCode;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadOlderMessages;
  final VoidCallback onRetryInitialize;
  final ValueChanged<String> onQuickActionSelected;
  final Future<void> Function(String value) onOpenAttachment;
  final Future<void> Function({required String imageUrl, String? fileName})
  onOpenImage;
  final Future<void> Function({required String videoUrl, String? fileName})
  onOpenVideo;
  final Future<void> Function(SupportChatMessage message) onRetryAttachment;
  final ValueChanged<SupportChatMessage> onReplyToMessage;
  final ValueChanged<String> onJumpToMessage;
  final String? highlightedMessageId;
  final GlobalKey Function(String messageId) messageItemKeyForId;
  final String Function(DateTime day) formatDayLabel;
  final bool Function(DateTime a, DateTime b) isSameDay;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final messageById = {
      for (final message in messages) message.messageId: message,
    };

    final quickActions = [
      _SupportQuickActionData(
        icon: Icons.auto_awesome_rounded,
        label: text.supportHomeTopicGenerationIssue,
        prompt: text.supportHomeTopicGenerationIssue,
      ),
      _SupportQuickActionData(
        icon: Icons.token_outlined,
        label: text.supportHomeTopicTokensNotArrived,
        prompt: text.supportHomeTopicTokensNotArrived,
      ),
      _SupportQuickActionData(
        icon: Icons.star_rounded,
        isPremium: true,
        label: text.supportHomeTopicPremiumIssue,
        prompt: text.supportHomeTopicPremiumIssue,
      ),
      _SupportQuickActionData(
        icon: Icons.credit_card_rounded,
        label: text.supportHomeTopicPaymentRefund,
        prompt: text.supportHomeTopicPaymentRefund,
      ),
      _SupportQuickActionData(
        icon: Icons.help_outline_rounded,
        label: text.supportHomeTopicOther,
        prompt: text.supportHomeTopicOther,
      ),
    ];

    if (isWaitingForInitialConversation && !showLoadingFallback) {
      return const Center(child: CircularProgressIndicator());
    }

    if (conversation == null) {
      if (state.errorMessage == null && !showLoadingFallback) {
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  child: _SupportStarterState(
                    title: text.supportChatWelcomeTitle,
                    description: text.supportChatWelcomeBody,
                    quickActions: quickActions,
                    onQuickActionSelected: onQuickActionSelected,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Builder(
                builder: (context) {
                  final legalAcceptanceRequired =
                      isLegalAcceptanceRequiredError(state.errorMessage);
                  return _SupportEmptyState(
                    icon: Icons.support_agent_rounded,
                    title: text.supportChatEmptyTitle,
                    description: state.errorMessage != null
                        ? _mapSupportError(text, state.errorMessage!)
                        : (showLoadingFallback
                              ? _mapSupportError(
                                  text,
                                  loadingFallbackMessageCode,
                                )
                              : text.supportChatEmptyMessage),
                    actionLabel: legalAcceptanceRequired
                        ? text.profileLegalAcceptAction
                        : text.retryAction,
                    onAction: legalAcceptanceRequired
                        ? () => context.go(LegalAcceptanceGatePage.routePath)
                        : onRetryInitialize,
                  );
                },
              ),
            ),
          ),
        ],
      );
    }

    if (messages.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                child: _SupportStarterState(
                  title: text.supportChatWelcomeTitle,
                  description: text.supportChatWelcomeBody,
                  quickActions: quickActions,
                  onQuickActionSelected: onQuickActionSelected,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 24),
        itemCount:
            messages.length +
            (state.errorMessage == null ? 0 : 1) +
            ((conversation?.hasOlderMessages ?? false) ? 1 : 0),
        itemBuilder: (context, index) {
          var currentIndex = index;

          if (conversation?.hasOlderMessages ?? false) {
            if (currentIndex == 0) {
              final text = AppLocalizations.of(context);
              final loadOlderLabel = text.supportChatLoadPreviousMessagesAction;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Align(
                  child: TextButton.icon(
                    onPressed: state.isLoadingOlder
                        ? null
                        : onLoadOlderMessages,
                    icon: state.isLoadingOlder
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.history_rounded, size: 16),
                    label: Text(loadOlderLabel),
                  ),
                ),
              );
            }

            currentIndex -= 1;
          }

          if (state.errorMessage != null && currentIndex == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ProfileMessageCard(
                message: _mapSupportError(text, state.errorMessage!),
                tone: colors.danger,
              ),
            );
          }

          final messageIndex = state.errorMessage == null
              ? currentIndex
              : currentIndex - 1;
          final message = messages[messageIndex];
          final previousMessage = messageIndex > 0
              ? messages[messageIndex - 1]
              : null;
          final showDayDivider =
              previousMessage == null ||
              !isSameDay(previousMessage.createdAtUtc, message.createdAtUtc);

          return Padding(
            key: messageItemKeyForId(message.messageId),
            padding: EdgeInsets.only(top: showDayDivider ? 12 : 0, bottom: 14),
            child: Column(
              children: [
                if (showDayDivider)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _DayDivider(
                      label: formatDayLabel(message.createdAtUtc),
                    ),
                  ),
                _MessageEntranceAnimation(
                  messageId: message.messageId,
                  child: _SwipeToReplyBubble(
                    enabled: true,
                    onReply: () => onReplyToMessage(message),
                    child: RepaintBoundary(
                      child: _MessageBubble(
                        message: message,
                        repliedMessage:
                            message.replyToMessageId?.trim().isNotEmpty == true
                            ? messageById[message.replyToMessageId!.trim()]
                            : null,
                        onOpenAttachment: onOpenAttachment,
                        onOpenImage: onOpenImage,
                        onOpenVideo: onOpenVideo,
                        onRetryAttachment: () => onRetryAttachment(message),
                        onReplyToMessage: () => onReplyToMessage(message),
                        onJumpToMessage: onJumpToMessage,
                        isHighlighted:
                            highlightedMessageId == message.messageId,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
