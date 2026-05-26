part of '../support_chat_page.dart';

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
    required this.onRetryInitialize,
    required this.onQuickActionSelected,
    required this.onOpenImage,
    required this.onRetryAttachment,
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
  final VoidCallback onRetryInitialize;
  final ValueChanged<String> onQuickActionSelected;
  final Future<void> Function({required String imageUrl, String? fileName})
  onOpenImage;
  final Future<void> Function(SupportChatMessage message) onRetryAttachment;
  final String Function(DateTime day) formatDayLabel;
  final bool Function(DateTime a, DateTime b) isSameDay;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    final quickActions = [
      _SupportQuickActionData(
        icon: Icons.auto_awesome_rounded,
        label: text.supportChatQuickActionGeneration,
        prompt: text.supportChatQuickActionGeneration,
      ),
      _SupportQuickActionData(
        icon: Icons.credit_card_rounded,
        label: text.supportChatQuickActionPayment,
        prompt: text.supportChatQuickActionPayment,
      ),
      _SupportQuickActionData(
        icon: Icons.reply_all_rounded,
        label: text.supportChatQuickActionRefund,
        prompt: text.supportChatQuickActionRefund,
      ),
      _SupportQuickActionData(
        icon: Icons.workspace_premium_rounded,
        label: text.supportChatQuickActionSubscription,
        prompt: text.supportChatQuickActionSubscription,
      ),
      _SupportQuickActionData(
        icon: Icons.videocam_rounded,
        label: text.supportChatQuickActionVideo,
        prompt: text.supportChatQuickActionVideo,
      ),
      _SupportQuickActionData(
        icon: Icons.support_agent_rounded,
        label: text.supportChatQuickActionTokens,
        prompt: text.supportChatQuickActionTokens,
      ),
    ];

    final faqItems = [
      _SupportFaqItemData(
        icon: Icons.image_search_rounded,
        title: text.supportChatFaqGenerationTitle,
        body: text.supportChatFaqGenerationBody,
      ),
      _SupportFaqItemData(
        icon: Icons.schedule_rounded,
        title: text.supportChatFaqResponseTitle,
        body: text.supportChatFaqResponseBody,
      ),
      _SupportFaqItemData(
        icon: Icons.receipt_long_rounded,
        title: text.supportChatFaqRefundTitle,
        body: text.supportChatFaqRefundBody,
      ),
    ];

    if (isWaitingForInitialConversation && !showLoadingFallback) {
      return const Center(child: CircularProgressIndicator());
    }

    if (conversation == null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: _SupportEmptyState(
                  icon: Icons.support_agent_rounded,
                  title: text.supportChatEmptyTitle,
                  description: state.errorMessage != null
                      ? _mapSupportError(text, state.errorMessage!)
                      : (showLoadingFallback
                            ? _mapSupportError(text, loadingFallbackMessageCode)
                            : text.supportChatEmptyMessage),
                  actionLabel: text.retryAction,
                  onAction: onRetryInitialize,
                ),
              ),
            ),
          );
        },
      );
    }

    if (messages.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  child: _SupportStarterState(
                    title: text.supportChatWelcomeTitle,
                    description: text.supportChatWelcomeBody,
                    faqTitle: text.supportChatFaqTitle,
                    quickActions: quickActions,
                    faqItems: faqItems,
                    onQuickActionSelected: onQuickActionSelected,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 24),
        itemCount: messages.length + (state.errorMessage == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (state.errorMessage != null && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ProfileMessageCard(
                message: _mapSupportError(text, state.errorMessage!),
                tone: colors.danger,
              ),
            );
          }

          final messageIndex = state.errorMessage == null ? index : index - 1;
          final message = messages[messageIndex];
          final previousMessage = messageIndex > 0
              ? messages[messageIndex - 1]
              : null;
          final showDayDivider =
              previousMessage == null ||
              !isSameDay(previousMessage.createdAtUtc, message.createdAtUtc);

          return Padding(
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
                if (_isSupportSystemMessage(message))
                  _SupportSystemMessageCard(
                    message: text.supportChatSystemNoticeBody,
                  )
                else
                  _MessageBubble(
                    message: message,
                    onOpenImage: onOpenImage,
                    onRetryAttachment: () => onRetryAttachment(message),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SupportComposerPanel extends StatelessWidget {
  const _SupportComposerPanel({
    required this.state,
    required this.messageController,
    required this.messageFocusNode,
    required this.pendingAttachment,
    required this.composerHasFocus,
    required this.composerCanSend,
    required this.keyboardInset,
    required this.onRemovePendingAttachment,
    required this.onShowAttachmentOptions,
    required this.onSendMessage,
  });

  final SupportChatState state;
  final TextEditingController messageController;
  final FocusNode messageFocusNode;
  final _PendingSupportAttachment? pendingAttachment;
  final bool composerHasFocus;
  final bool composerCanSend;
  final double keyboardInset;
  final VoidCallback onRemovePendingAttachment;
  final VoidCallback onShowAttachmentOptions;
  final Future<void> Function() onSendMessage;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    final isKeyboardVisible = keyboardInset > 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, isKeyboardVisible ? 12 : 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        decoration: BoxDecoration(
          color: colors.surfaceStrong.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: colors.accent.withValues(
              alpha: composerHasFocus ? 0.2 : 0.08,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingAttachment != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
                child: _PendingAttachmentPreview(
                  attachment: pendingAttachment!,
                  onRemove: state.isSending ? null : onRemovePendingAttachment,
                ),
              ),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  splashRadius: 18,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  onPressed: state.isSending ? null : onShowAttachmentOptions,
                  icon: const Icon(
                    Icons.attach_file_rounded,
                    size: 23,
                    color: _supportComposerIconColor,
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    focusNode: messageFocusNode,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 15.5,
                      height: 1.28,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      hintText: text.supportChatInputHint,
                      hintStyle: const TextStyle(
                        color: _supportComposerHintColor,
                        fontSize: 15.5,
                        height: 1.3,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
                      filled: false,
                    ),
                    textAlignVertical: TextAlignVertical.center,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedScale(
                  scale: composerCanSend ? 1 : 0.9,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: IgnorePointer(
                    ignoring: !composerCanSend || state.isSending,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: composerCanSend || state.isSending ? 1 : 0.72,
                      child: Material(
                        color: state.isSending
                            ? _supportComposerSendGreen.withValues(alpha: 0.85)
                            : composerCanSend
                            ? _supportComposerSendGreen
                            : _supportComposerSendGreen.withValues(alpha: 0.3),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: state.isSending || !composerCanSend
                              ? null
                              : onSendMessage,
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: Center(
                              child: state.isSending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send_rounded,
                                      size: 19,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 8, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _SupportComposerInfoChip(
                    icon: Icons.photo_library_outlined,
                    label: text.supportChatComposerAttachmentChip,
                  ),
                  _SupportComposerInfoChip(
                    icon: Icons.schedule_rounded,
                    label: text.supportChatComposerResponseChip,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportComposerInfoChip extends StatelessWidget {
  const _SupportComposerInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: colors.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
