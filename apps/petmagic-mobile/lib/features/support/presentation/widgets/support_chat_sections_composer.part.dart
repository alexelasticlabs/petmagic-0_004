part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

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
    required this.onCloseConversation,
    required this.onReopenConversation,
    required this.onSubmitFeedback,
    required this.replyToMessage,
    required this.onClearReplyToMessage,
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
  final Future<void> Function() onCloseConversation;
  final Future<void> Function() onReopenConversation;
  final Future<void> Function(int rating, String? comment) onSubmitFeedback;
  final SupportChatMessage? replyToMessage;
  final VoidCallback onClearReplyToMessage;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final composerSendColor = _supportComposerSendGreen(context);
    final composerIconColor = _supportComposerIconColor(context);
    final composerHintColor = _supportComposerHintColor(context);

    final isKeyboardVisible = keyboardInset > 0;
    final sendProgress = state.sendProgress;
    final sendingIndex = state.sendingAttachmentIndex;
    final sendingTotal = state.sendingAttachmentTotal;
    final conversation = state.conversation;
    final normalizedStatus = conversation?.status.trim().toLowerCase();
    final isConversationClosed = normalizedStatus == 'closed';
    final isReadOnly =
        isConversationClosed || (conversation?.isReadOnly ?? false);
    final effectiveCanSend = composerCanSend && !isReadOnly;
    final showResolvePrompt =
        conversation != null &&
        normalizedStatus == 'waitingforuser' &&
        conversation.messages.any(
          (message) => message.isFromAdmin && !_isSupportSystemMessage(message),
        );

    if (isConversationClosed) {
      return Padding(
        padding: EdgeInsets.fromLTRB(10, 2, 10, isKeyboardVisible ? 3 : 7),
        child: _SupportClosedConversationBanner(
          feedbackRating: conversation?.feedbackRating,
          isBusy: state.isSending,
          onReopen: onReopenConversation,
          onSubmitFeedback: onSubmitFeedback,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 2, 10, isKeyboardVisible ? 3 : 7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(0),
          boxShadow: [
            if (composerHasFocus)
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
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
                  onResolve: onCloseConversation,
                  onKeepOpen: () {
                    onReopenConversation().whenComplete(() {
                      if (messageFocusNode.canRequestFocus) {
                        messageFocusNode.requestFocus();
                      }
                    });
                  },
                ),
              ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: replyToMessage == null
                  ? const SizedBox.shrink(
                      key: ValueKey<String>('reply-preview-empty'),
                    )
                  : Padding(
                      key: const ValueKey<String>('reply-preview-active'),
                      padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
                      child: _SupportReplyComposerPreview(
                        message: replyToMessage!,
                        onClear: state.isSending ? null : onClearReplyToMessage,
                      ),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    constraints: const BoxConstraints(minHeight: 42),
                    padding: const EdgeInsets.only(left: 2, right: 4),
                    decoration: BoxDecoration(
                      color: colors.surfaceStrong.withValues(
                        alpha: isLight ? 0.99 : 0.9,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: colors.border.withValues(
                          alpha: composerHasFocus
                              ? (isLight ? 0.98 : 0.55)
                              : (isLight ? 0.78 : 0.28),
                        ),
                        width: isLight ? 1.1 : 0.8,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          splashRadius: 18,
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 40,
                          ),
                          onPressed: state.isSending || isReadOnly
                              ? null
                              : onShowAttachmentOptions,
                          icon: Icon(
                            Icons.attach_file_rounded,
                            size: 21,
                            color: state.isSending || isReadOnly
                                ? colors.textMuted.withValues(alpha: 0.46)
                                : composerIconColor,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: messageController,
                            focusNode: messageFocusNode,
                            enabled: !isReadOnly,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.newline,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 15,
                              height: 1.28,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: isReadOnly
                                  ? text.supportChatReadOnlyHint
                                  : text.supportChatInputHint,
                              hintStyle: TextStyle(
                                color: composerHintColor.withValues(
                                  alpha: 0.98,
                                ),
                                fontSize: 14.5,
                                height: 1.26,
                                fontWeight: FontWeight.w600,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.fromLTRB(
                                0,
                                10,
                                0,
                                9,
                              ),
                              filled: false,
                            ),
                            textAlignVertical: TextAlignVertical.center,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: AnimatedScale(
                            scale: effectiveCanSend ? 1 : 0.88,
                            duration: const Duration(milliseconds: 140),
                            curve: Curves.easeOut,
                            child: IgnorePointer(
                              ignoring: !effectiveCanSend && !state.isSending,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 140),
                                opacity: effectiveCanSend || state.isSending
                                    ? 1
                                    : 0.38,
                                child: IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 34,
                                    height: 40,
                                  ),
                                  splashRadius: 18,
                                  onPressed:
                                      state.isSending || !effectiveCanSend
                                      ? null
                                      : onSendMessage,
                                  icon: state.isSending
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  composerSendColor,
                                                ),
                                          ),
                                        )
                                      : Icon(
                                          Icons.arrow_upward_rounded,
                                          size: 22,
                                          color: effectiveCanSend
                                              ? composerSendColor
                                              : colors.textMuted.withValues(
                                                  alpha: 0.5,
                                                ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
                    valueColor: AlwaysStoppedAnimation<Color>(
                      composerSendColor,
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
