part of 'support_chat_page.dart';

extension on _SupportChatPageState {
  void _showSupportToast(
    String message, {
    PetMagicToastTone tone = PetMagicToastTone.info,
  }) {
    PetMagicToast.show(context, message: message, tone: tone);
  }

  bool get _hasPendingAttachment => _pendingAttachments.isNotEmpty;

  bool get _composerCanSend => _composerHasText || _hasPendingAttachment;

  bool get _isExternalMediaPickerOpen => _externalMediaPickerDepth > 0;

  void _prefillComposer(String value) {
    _messageController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _messageFocusNode.requestFocus();
  }

  void _applyInitialMessage(String? value, {bool notify = false}) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    if (_messageController.text.trim() == normalized) {
      return;
    }

    _messageController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    if (notify && mounted) {
      _applyState(() {
        _composerHasText = true;
      });
      return;
    }
    _composerHasText = true;
  }

  void _handleComposerChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText == _composerHasText || !mounted) {
      return;
    }

    _applyState(() {
      _composerHasText = hasText;
    });
  }

  void _handleComposerFocusChanged() {
    final hasFocus = _messageFocusNode.hasFocus;
    if (hasFocus == _composerHasFocus || !mounted) {
      return;
    }

    _applyState(() {
      _composerHasFocus = hasFocus;
    });
  }

  Future<void> _showAttachmentOptions() {
    return _showAttachmentOptionsImpl();
  }

  Future<void> _sendCurrentMessage(String localeTag) {
    return _sendCurrentMessageImpl(localeTag);
  }

  void _removePendingAttachment(int index) {
    _removePendingAttachmentImpl(index);
  }

  Future<void> _retryAttachmentForMessage(SupportChatMessage message) {
    return _retryAttachmentForMessageImpl(message);
  }

  Future<void> _openImageFullscreen({
    required String imageUrl,
    String? fileName,
  }) {
    return _openImageFullscreenImpl(imageUrl: imageUrl, fileName: fileName);
  }

  Future<void> _openVideoFullscreen({
    required String videoUrl,
    String? fileName,
  }) {
    return _openVideoFullscreenImpl(videoUrl: videoUrl, fileName: fileName);
  }

  void _setReplyToMessage(SupportChatMessage message) {
    if (_isSupportSystemMessage(message) || !mounted) {
      return;
    }

    _applyState(() {
      _replyToMessage = message;
    });
    _messageFocusNode.requestFocus();
  }

  void _clearReplyToMessage() {
    if (!mounted || _replyToMessage == null) {
      return;
    }

    _applyState(() {
      _replyToMessage = null;
    });
  }

  GlobalKey _messageItemKeyForId(String messageId) {
    final normalizedMessageId = messageId.trim();
    return _messageKeys.putIfAbsent(
      normalizedMessageId,
      () => GlobalKey(debugLabel: 'support-message-$normalizedMessageId'),
    );
  }

  void _retainMessageKeys(Iterable<SupportChatMessage> messages) {
    final activeIds = <String>{
      for (final message in messages)
        if (message.messageId.trim().isNotEmpty) message.messageId.trim(),
    };
    _messageKeys.removeWhere((messageId, _) => !activeIds.contains(messageId));
  }

  Future<void> _jumpToMessage(String messageId) async {
    final normalizedMessageId = messageId.trim();
    if (!mounted || normalizedMessageId.isEmpty) {
      return;
    }

    final targetKey = _messageKeys[normalizedMessageId];
    final targetContext = targetKey?.currentContext;
    if (targetContext == null) {
      final text = AppLocalizations.of(context);
      _showSupportToast(text.supportChatReplyOriginalUnavailable);
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.25,
    );
    if (!mounted) {
      return;
    }

    _messageHighlightTimer?.cancel();
    _applyState(() {
      _highlightedMessageId = normalizedMessageId;
    });
    _messageHighlightTimer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted || _highlightedMessageId != normalizedMessageId) {
        return;
      }

      _applyState(() {
        _highlightedMessageId = null;
      });
    });
  }

  String _formatDayLabel(DateTime value) {
    return _formatDayLabelImpl(value);
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return _isSameDayImpl(left, right);
  }

  bool _isPinnedToBottom({double threshold = 72}) {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    return (position.maxScrollExtent - position.pixels) <= threshold;
  }
}
