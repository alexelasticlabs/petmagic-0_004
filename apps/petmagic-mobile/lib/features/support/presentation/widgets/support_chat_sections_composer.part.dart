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
    final actionTone = _supportSecondaryGreen(context);
    final textTheme = Theme.of(context).textTheme;

    return TextButton.icon(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        foregroundColor: actionTone,
        textStyle: textTheme.labelLarge?.copyWith(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: colors.surfaceStrong.withValues(alpha: 0.72),
      ),
      onPressed: isBusy ? null : onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}

class _SupportClosedConversationBanner extends StatelessWidget {
  const _SupportClosedConversationBanner({
    required this.feedbackRating,
    required this.isBusy,
    required this.onReopen,
    required this.onSubmitFeedback,
  });

  final int? feedbackRating;
  final bool isBusy;
  final Future<void> Function() onReopen;
  final Future<void> Function(int rating, String? comment) onSubmitFeedback;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final actionTone = _supportComposerSendGreen(context);
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: colors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text.supportChatConversationClosedLabel,
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    foregroundColor: actionTone,
                    textStyle: textTheme.labelLarge?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    backgroundColor: actionTone.withValues(alpha: 0.1),
                  ),
                  onPressed: isBusy ? null : onReopen,
                  child: Text(text.supportChatReopenAction),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              feedbackRating == null
                  ? text.supportChatRateTitle
                  : text.supportChatRatedLabel(feedbackRating!),
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 2,
              children: [
                for (var rating = 1; rating <= 5; rating++)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: text.supportChatRatedLabel(rating),
                    onPressed: feedbackRating == null && !isBusy
                        ? () async {
                            final comment =
                                await _showSupportFeedbackCommentDialog(
                                  context,
                                );
                            if (comment == null || !context.mounted) {
                              return;
                            }
                            await onSubmitFeedback(rating, comment);
                          }
                        : null,
                    icon: Icon(
                      rating <= (feedbackRating ?? 0)
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: rating <= (feedbackRating ?? 0)
                          ? actionTone
                          : colors.textMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _showSupportFeedbackCommentDialog(BuildContext context) async {
  final controller = TextEditingController();
  final text = AppLocalizations.of(context);
  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.supportChatRateTitle),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          maxLength: 1000,
          decoration: InputDecoration(
            labelText: text.profileSettingsFeedbackMessageLabel,
            hintText: text.profileSettingsFeedbackMessageHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(text.profileSettingsFeedbackSubmitAction),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}
