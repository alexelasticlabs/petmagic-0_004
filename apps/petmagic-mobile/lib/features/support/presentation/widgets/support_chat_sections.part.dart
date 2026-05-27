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
    required this.onOpenVideo,
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
  final Future<void> Function({required String videoUrl, String? fileName})
  onOpenVideo;
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
        label: text.supportHomeTopicGenerationIssue,
        prompt: text.supportHomeTopicGenerationIssue,
      ),
      _SupportQuickActionData(
        icon: Icons.token_outlined,
        label: text.supportHomeTopicTokensNotArrived,
        prompt: text.supportHomeTopicTokensNotArrived,
      ),
      _SupportQuickActionData(
        icon: Icons.workspace_premium_rounded,
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
                      quickActions: quickActions,
                      onQuickActionSelected: onQuickActionSelected,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }

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
                    quickActions: quickActions,
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
                    message: message.body.trim().isEmpty
                        ? text.supportChatSystemNoticeBody
                        : message.body,
                    createdAtUtc: message.createdAtUtc,
                  )
                else
                  _MessageBubble(
                    message: message,
                    onOpenImage: onOpenImage,
                    onOpenVideo: onOpenVideo,
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
    required this.pendingAttachments,
    required this.composerHasFocus,
    required this.composerCanSend,
    required this.keyboardInset,
    required this.onRemovePendingAttachment,
    required this.onShowAttachmentOptions,
    required this.onSendMessage,
    required this.onResolveConversation,
  });

  final SupportChatState state;
  final TextEditingController messageController;
  final FocusNode messageFocusNode;
  final List<_PendingSupportAttachment> pendingAttachments;
  final bool composerHasFocus;
  final bool composerCanSend;
  final double keyboardInset;
  final ValueChanged<int> onRemovePendingAttachment;
  final VoidCallback onShowAttachmentOptions;
  final Future<void> Function() onSendMessage;
  final Future<void> Function() onResolveConversation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    final isKeyboardVisible = keyboardInset > 0;
    final sendProgress = state.sendProgress;
    final sendingIndex = state.sendingAttachmentIndex;
    final sendingTotal = state.sendingAttachmentTotal;
    final conversation = state.conversation;
    final normalizedStatus = conversation?.status.trim().toLowerCase();
    final isReadOnly =
        (conversation?.isReadOnly ?? false) && normalizedStatus != 'closed';
    final effectiveCanSend = composerCanSend && !isReadOnly;
    final showResolvePrompt =
        conversation != null &&
        normalizedStatus == 'waitingforuser' &&
        conversation.messages.any(
          (message) => message.isFromAdmin && !_isSupportSystemMessage(message),
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, isKeyboardVisible ? 4 : 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: colors.surfaceStrong.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colors.accent.withValues(
              alpha: composerHasFocus ? 0.2 : 0.08,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showResolvePrompt)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
                child: _SupportResolutionPrompt(
                  title: text.supportChatSupportRepliedStatusHint,
                  resolveLabel: text.supportChatMarkResolvedAction,
                  keepOpenLabel: text.supportChatKeepOpenAction,
                  isBusy: state.isSending,
                  onResolve: onResolveConversation,
                  onKeepOpen: messageFocusNode.requestFocus,
                ),
              ),
            if (pendingAttachments.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
                child: _PendingAttachmentPreviewList(
                  attachments: pendingAttachments,
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
                    width: 34,
                    height: 34,
                  ),
                  onPressed: state.isSending || isReadOnly
                      ? null
                      : onShowAttachmentOptions,
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
                    enabled: !isReadOnly,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 14,
                      height: 1.28,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      hintText: isReadOnly
                          ? text.supportChatReadOnlyHint
                          : text.supportChatInputHint,
                      hintStyle: const TextStyle(
                        color: _supportComposerHintColor,
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                      filled: false,
                    ),
                    textAlignVertical: TextAlignVertical.center,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedScale(
                  scale: effectiveCanSend ? 1 : 0.9,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: IgnorePointer(
                    ignoring: !effectiveCanSend || state.isSending,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: effectiveCanSend || state.isSending ? 1 : 0.72,
                      child: Material(
                        color: state.isSending
                            ? _supportComposerSendGreen.withValues(alpha: 0.85)
                            : effectiveCanSend
                            ? _supportComposerSendGreen
                            : _supportComposerSendGreen.withValues(alpha: 0.3),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: state.isSending || !effectiveCanSend
                              ? null
                              : onSendMessage,
                          child: SizedBox(
                            width: 38,
                            height: 38,
                            child: Center(
                              child: state.isSending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
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
                                      size: 17,
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
            if (state.isSending && sendProgress != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: sendProgress,
                    minHeight: 4,
                    backgroundColor: colors.surface.withValues(alpha: 0.7),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _supportComposerSendGreen,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    sendingIndex != null && sendingTotal != null
                        ? text.supportChatAttachmentUploadingWithCount(
                            sendingIndex,
                            sendingTotal,
                          )
                        : text.supportChatAttachmentStatusUploading,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SupportResolutionPrompt extends StatelessWidget {
  const _SupportResolutionPrompt({
    required this.title,
    required this.resolveLabel,
    required this.keepOpenLabel,
    required this.isBusy,
    required this.onResolve,
    required this.onKeepOpen,
  });

  final String title;
  final String resolveLabel;
  final String keepOpenLabel;
  final bool isBusy;
  final Future<void> Function() onResolve;
  final VoidCallback onKeepOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _SupportPromptButton(
                  icon: Icons.check_rounded,
                  label: resolveLabel,
                  isBusy: isBusy,
                  onPressed: onResolve,
                ),
                _SupportPromptButton(
                  icon: Icons.edit_outlined,
                  label: keepOpenLabel,
                  isBusy: isBusy,
                  onPressed: () async {
                    onKeepOpen();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportPromptButton extends StatelessWidget {
  const _SupportPromptButton({
    required this.icon,
    required this.label,
    required this.isBusy,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isBusy;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return TextButton.icon(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        foregroundColor: _supportSecondaryGreen,
        textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: colors.surfaceStrong.withValues(alpha: 0.72),
      ),
      onPressed: isBusy ? null : onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}
