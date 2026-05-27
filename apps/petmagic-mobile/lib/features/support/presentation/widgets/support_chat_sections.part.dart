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
                    createdAtUtc: message.createdAtUtc,
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
    required this.pendingAttachments,
    required this.composerHasFocus,
    required this.composerCanSend,
    required this.keyboardInset,
    required this.onRemovePendingAttachment,
    required this.onShowAttachmentOptions,
    required this.onSendMessage,
    required this.onResolveConversation,
    required this.onReopenConversation,
    required this.onCloseConversation,
    required this.onSubmitFeedback,
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
  final Future<void> Function() onReopenConversation;
  final Future<void> Function() onCloseConversation;
  final Future<void> Function(int rating) onSubmitFeedback;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    final isKeyboardVisible = keyboardInset > 0;
    final sendProgress = state.sendProgress;
    final sendingIndex = state.sendingAttachmentIndex;
    final sendingTotal = state.sendingAttachmentTotal;
    final conversation = state.conversation;
    final isReadOnly = conversation?.isReadOnly ?? false;
    final effectiveCanSend = composerCanSend && !isReadOnly;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, isKeyboardVisible ? 4 : 8),
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
            if (conversation != null)
              _SupportLifecycleActionBar(
                conversation: conversation,
                isBusy: state.isSending,
                onResolve: onResolveConversation,
                onReopen: onReopenConversation,
                onClose: onCloseConversation,
                onSubmitFeedback: onSubmitFeedback,
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
                    width: 36,
                    height: 36,
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
                      fontSize: 15.5,
                      height: 1.28,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      hintText: isReadOnly
                          ? text.supportChatReadOnlyHint
                          : text.supportChatInputHint,
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

class _SupportLifecycleActionBar extends StatelessWidget {
  const _SupportLifecycleActionBar({
    required this.conversation,
    required this.isBusy,
    required this.onResolve,
    required this.onReopen,
    required this.onClose,
    required this.onSubmitFeedback,
  });

  final SupportChatConversation conversation;
  final bool isBusy;
  final Future<void> Function() onResolve;
  final Future<void> Function() onReopen;
  final Future<void> Function() onClose;
  final Future<void> Function(int rating) onSubmitFeedback;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final normalizedStatus = conversation.status.trim().toLowerCase();
    final isResolved = normalizedStatus == 'resolved';
    final isClosed = normalizedStatus == 'closed';
    final canResolve =
        !conversation.isReadOnly &&
        !isResolved &&
        !isClosed &&
        conversation.messages.isNotEmpty;
    final canReopen = conversation.canReopen;
    final canClose = isResolved && conversation.closedAtUtc == null;
    final showRating = isResolved && conversation.feedbackRating == null;
    final hasActions = canResolve || canReopen || canClose || showRating;

    if (!hasActions) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showRating) ...[
                Text(
                  text.supportChatRateTitle,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 2,
                  children: List.generate(5, (index) {
                    final rating = index + 1;
                    return IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      onPressed: isBusy ? null : () => onSubmitFeedback(rating),
                      icon: const Icon(
                        Icons.star_rounded,
                        size: 22,
                        color: Color(0xFFFFB84D),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
              ] else if (conversation.feedbackRating != null) ...[
                Text(
                  text.supportChatRatedLabel(conversation.feedbackRating!),
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (canResolve)
                    _SupportLifecycleButton(
                      icon: Icons.check_rounded,
                      label: text.supportChatMarkResolvedAction,
                      isBusy: isBusy,
                      onPressed: onResolve,
                    ),
                  if (canReopen)
                    _SupportLifecycleButton(
                      icon: Icons.refresh_rounded,
                      label: text.supportChatReopenAction,
                      isBusy: isBusy,
                      onPressed: onReopen,
                    ),
                  if (canClose)
                    _SupportLifecycleButton(
                      icon: Icons.archive_outlined,
                      label: text.supportChatArchiveAction,
                      isBusy: isBusy,
                      onPressed: onClose,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportLifecycleButton extends StatelessWidget {
  const _SupportLifecycleButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        foregroundColor: _supportSecondaryGreen,
        textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: colors.surfaceStrong.withValues(alpha: 0.72),
      ),
      onPressed: isBusy ? null : onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}
