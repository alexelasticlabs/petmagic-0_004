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
  final VoidCallback onRetryInitialize;
  final ValueChanged<String> onQuickActionSelected;
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

class _MessageEntranceAnimation extends StatelessWidget {
  const _MessageEntranceAnimation({
    required this.messageId,
    required this.child,
  });

  final String messageId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('support-message-entrance-$messageId'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, nestedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: nestedChild,
          ),
        );
      },
    );
  }
}

class _SwipeToReplyBubble extends StatefulWidget {
  const _SwipeToReplyBubble({
    required this.enabled,
    required this.onReply,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onReply;
  final Widget child;

  @override
  State<_SwipeToReplyBubble> createState() => _SwipeToReplyBubbleState();
}

class _SwipeToReplyBubbleState extends State<_SwipeToReplyBubble>
    with SingleTickerProviderStateMixin {
  static const _triggerOffset = 52.0;
  static const _maxOffset = 72.0;

  late final AnimationController _animationController;
  Animation<double>? _returnAnimation;
  double _offset = 0;
  bool _replyTriggered = false;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          final animation = _returnAnimation;
          if (animation == null || !mounted) {
            return;
          }
          setState(() {
            _offset = animation.value;
          });
        });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) {
      return;
    }

    _animationController.stop();
    _returnAnimation = null;
    final delta = details.primaryDelta ?? 0;
    final nextOffset = (_offset - delta).clamp(0.0, _maxOffset * 1.2);
    if (nextOffset == _offset) {
      return;
    }

    final shouldTrigger = nextOffset >= _triggerOffset;
    if (shouldTrigger && !_replyTriggered) {
      HapticFeedback.selectionClick();
    }

    setState(() {
      _offset = nextOffset;
      _replyTriggered = shouldTrigger;
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enabled) {
      return;
    }

    final shouldReply = _offset >= _triggerOffset;
    _animateBack();
    if (shouldReply) {
      widget.onReply();
    }
  }

  void _handleHorizontalDragCancel() {
    _animateBack();
  }

  void _animateBack() {
    final begin = _offset;
    _replyTriggered = false;
    if (begin <= 0) {
      if (mounted) {
        setState(() {
          _offset = 0;
        });
      }
      return;
    }

    _returnAnimation = Tween<double>(begin: begin, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final revealProgress = (_offset / _triggerOffset).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _handleHorizontalDragUpdate,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      onHorizontalDragCancel: _handleHorizontalDragCancel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 90),
                  opacity: revealProgress,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    curve: Curves.easeOut,
                    width: 24 + (revealProgress * 10),
                    height: 24 + (revealProgress * 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accent.withValues(
                        alpha: 0.08 + (revealProgress * 0.2),
                      ),
                    ),
                    child: Icon(
                      Icons.reply_rounded,
                      size: 16 + (revealProgress * 4),
                      color: colors.accent.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(offset: Offset(-_offset, 0), child: widget.child),
        ],
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
  final Future<void> Function() onResolveConversation;
  final SupportChatMessage? replyToMessage;
  final VoidCallback onClearReplyToMessage;

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
                  onResolve: onResolveConversation,
                  onKeepOpen: messageFocusNode.requestFocus,
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
                    padding: const EdgeInsets.only(left: 2, right: 6),
                    decoration: BoxDecoration(
                      color: colors.surfaceStrong.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: colors.border.withValues(
                          alpha: composerHasFocus ? 0.74 : 0.42,
                        ),
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
                                : _supportComposerIconColor,
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
                                color: _supportComposerHintColor.withValues(
                                  alpha: 0.98,
                                ),
                                fontSize: 14.5,
                                height: 1.26,
                                fontWeight: FontWeight.w500,
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                AnimatedScale(
                  scale: effectiveCanSend ? 1 : 0.92,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  child: IgnorePointer(
                    ignoring: !effectiveCanSend || state.isSending,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 140),
                      opacity: effectiveCanSend || state.isSending ? 1 : 0.66,
                      child: Material(
                        color: state.isSending
                            ? _supportComposerSendGreen.withValues(alpha: 0.85)
                            : effectiveCanSend
                            ? _supportComposerSendGreen
                            : colors.surface.withValues(alpha: 0.88),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: state.isSending || !effectiveCanSend
                              ? null
                              : onSendMessage,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: state.isSending
                                  ? const SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.arrow_upward_rounded,
                                      size: 22,
                                      color: effectiveCanSend
                                          ? Colors.white
                                          : colors.textMuted,
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
