part of 'support_chat_controller.dart';

mixin _SupportChatControllerConversationMixin
    on Notifier<SupportChatState>, _SupportChatControllerScope {
  StreamSubscription<SupportChatRealtimeUpdate>? _realtimeSubscription;
  Timer? _realtimeRefreshTimer;
  CancelToken? _activeUploadCancelToken;
  bool _hasPendingRealtimeRefresh = false;
  bool _started = false;
  bool _isScreenVisible = true;

  void stop() {
    _cancelActiveUpload();
    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = null;
    unawaited(_realtimeSubscription?.cancel());
    _realtimeSubscription = null;
    unawaited(_realtimeClient.disconnect());
    _started = false;
    _hasPendingRealtimeRefresh = false;
    _isScreenVisible = false;
  }

  CancelToken _newActiveUploadCancelToken() {
    _cancelActiveUpload();
    final cancelToken = CancelToken();
    _activeUploadCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveUpload() {
    final cancelToken = _activeUploadCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('support_upload_cancelled');
    }
    _activeUploadCancelToken = null;
  }

  void _clearActiveUpload(CancelToken cancelToken) {
    if (identical(_activeUploadCancelToken, cancelToken)) {
      _activeUploadCancelToken = null;
    }
  }

  void setScreenVisible(bool visible) {
    if (_isScreenVisible == visible) {
      return;
    }

    _isScreenVisible = visible;
    if (_isScreenVisible) {
      _resumePendingRealtimeRefreshIfNeeded();
      return;
    }

    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = null;
  }

  Future<void> start() async {
    if (_started) {
      return;
    }

    _started = true;
    await initialize();
    if (!ref.mounted) {
      return;
    }

    _realtimeSubscription ??= _realtimeClient.events.listen(
      _handleRealtimeUpdate,
    );
    try {
      await _realtimeClient.connect();
    } on Object {
      // Realtime is best-effort; keep the chat usable over REST even if the hub is unavailable.
    }
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final conversation = await _repository.getConversation();
      if (!ref.mounted) {
        return;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isLoading: false,
          conversation: conversation,
          clearError: true,
        ),
      );
      _updateStateIfMounted((state) => state.copyWith(isLoadingOlder: false));
      await _markReadIfNeeded(conversation);
      if (!ref.mounted) {
        return;
      }
      _resumePendingRealtimeRefreshIfNeeded();
    } on AppException catch (error) {
      if (_isConversationNotFound(error.message)) {
        _updateStateIfMounted(
          (state) => state.copyWith(
            isLoading: false,
            clearConversation: true,
            clearError: true,
          ),
        );
        _resumePendingRealtimeRefreshIfNeeded();
      } else {
        _updateStateIfMounted(
          (state) =>
              state.copyWith(isLoading: false, errorMessage: error.message),
        );
      }
    } on Object {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isLoading: false,
          errorMessage: 'support.unavailable',
        ),
      );
    }
  }

  Future<void> refresh() async {
    await _refreshConversation();
  }

  Future<void> resolveConversation() async {
    await _runConversationLifecycleAction(
      (conversation) =>
          _repository.resolveConversation(conversation.conversationId),
    );
  }

  Future<void> reopenConversation() async {
    await _runConversationLifecycleAction(
      (conversation) =>
          _repository.reopenConversation(conversation.conversationId),
    );
  }

  Future<void> closeConversation() async {
    await _runConversationLifecycleAction(
      (conversation) =>
          _repository.closeConversation(conversation.conversationId),
    );
  }

  Future<void> submitFeedback(int rating) async {
    await _runConversationLifecycleAction(
      (conversation) => _repository.submitFeedback(
        conversationId: conversation.conversationId,
        rating: rating,
      ),
    );
  }

  Future<void> _runConversationLifecycleAction(
    Future<SupportChatConversation> Function(
      SupportChatConversation conversation,
    )
    action,
  ) async {
    final conversation = state.conversation;
    if (conversation == null || state.isSending) {
      return;
    }

    state = state.copyWith(isSending: true, clearError: true);
    try {
      final updatedConversation = await action(conversation);
      if (!ref.mounted) {
        return;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSending: false,
          conversation: updatedConversation,
          clearError: true,
        ),
      );
      _resumePendingRealtimeRefreshIfNeeded();
    } on AppException catch (error) {
      _updateStateIfMounted(
        (state) =>
            state.copyWith(isSending: false, errorMessage: error.message),
      );
    } on Object {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isSending: false,
          errorMessage: 'support.unavailable',
        ),
      );
    }
  }

  Future<void> _refreshConversation() async {
    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      final conversation = await _repository.getConversation();
      if (!ref.mounted) {
        return;
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isLoading: false,
          isRefreshing: false,
          conversation: conversation,
          clearError: true,
        ),
      );

      if (conversation.userUnreadCount > 0) {
        await _markReadIfNeeded(conversation);
      }
      if (!ref.mounted) {
        return;
      }
      _resumePendingRealtimeRefreshIfNeeded();
    } on AppException catch (error) {
      if (_isConversationNotFound(error.message)) {
        _updateStateIfMounted(
          (state) => state.copyWith(
            isLoading: false,
            isRefreshing: false,
            clearConversation: true,
            clearError: true,
          ),
        );
      } else {
        _updateStateIfMounted(
          (state) => state.copyWith(
            isLoading: false,
            isRefreshing: false,
            errorMessage: error.message,
          ),
        );
      }
    } on Object {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isLoading: false,
          isRefreshing: false,
          errorMessage: 'support.unavailable',
        ),
      );
    }
  }

  bool get _isConversationBusy =>
      state.isLoading ||
      state.isRefreshing ||
      state.isSending ||
      state.isLoadingOlder;

  Future<void> loadOlderMessages() async {
    final conversation = state.conversation;
    if (conversation == null ||
        state.isLoadingOlder ||
        !conversation.hasOlderMessages) {
      return;
    }

    final before = conversation.oldestLoadedMessageCreatedAtUtc;
    if (before == null) {
      return;
    }
    final beforeMessageId = conversation.messages.isEmpty
        ? null
        : conversation.messages.first.messageId;

    state = state.copyWith(isLoadingOlder: true);
    try {
      final chunk = await _repository.getConversation(
        beforeMessageCreatedAtUtc: before,
        beforeMessageId: beforeMessageId,
      );
      if (!ref.mounted) {
        return;
      }

      final existingById = {
        for (final message in conversation.messages) message.messageId: message,
      };
      final merged = <SupportChatMessage>[
        ...chunk.messages.where(
          (message) => !existingById.containsKey(message.messageId),
        ),
        ...conversation.messages,
      ]..sort((a, b) => a.createdAtUtc.compareTo(b.createdAtUtc));

      _updateStateIfMounted(
        (state) => state.copyWith(
          isLoadingOlder: false,
          conversation: conversation.copyWith(
            hasOlderMessages: chunk.hasOlderMessages,
            oldestLoadedMessageCreatedAtUtc:
                chunk.oldestLoadedMessageCreatedAtUtc,
            messages: merged,
          ),
        ),
      );
    } on AppException catch (error) {
      _updateStateIfMounted(
        (state) =>
            state.copyWith(isLoadingOlder: false, errorMessage: error.message),
      );
    } on Object {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isLoadingOlder: false,
          errorMessage: 'support.unavailable',
        ),
      );
    }
  }

  void _scheduleRealtimeRefresh() {
    if (!_isScreenVisible || _isConversationBusy) {
      return;
    }

    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = Timer(
      const Duration(milliseconds: 350),
      _flushPendingRealtimeRefresh,
    );
  }

  void _flushPendingRealtimeRefresh() {
    _realtimeRefreshTimer = null;
    if (!_hasPendingRealtimeRefresh || _isConversationBusy) {
      return;
    }

    _hasPendingRealtimeRefresh = false;
    unawaited(_refreshConversation());
  }

  void _resumePendingRealtimeRefreshIfNeeded() {
    if (!ref.mounted) {
      return;
    }

    if (_isScreenVisible && _hasPendingRealtimeRefresh) {
      _scheduleRealtimeRefresh();
    }
  }

  Future<void> _markReadIfNeeded(SupportChatConversation conversation) async {
    if (!ref.mounted) {
      return;
    }

    if (conversation.userUnreadCount <= 0) {
      return;
    }

    if (!_isScreenVisible) {
      return;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return;
    }

    final now = DateTime.now().toUtc();
    try {
      await _repository.markConversationRead(conversation.conversationId);
      if (!ref.mounted) {
        return;
      }
      final updatedMessages = conversation.messages
          .map(
            (message) => message.isFromAdmin && !message.isRead
                ? message.copyWith(isRead: true, readAtUtc: now)
                : message,
          )
          .toList(growable: false);

      _updateStateIfMounted(
        (state) => state.copyWith(
          conversation: conversation.copyWith(
            userUnreadCount: 0,
            messages: updatedMessages,
          ),
        ),
      );
    } on AppException {
      // Keep realtime refresh resilient; the next event or manual refresh will try again.
    }
  }

  void _handleRealtimeUpdate(SupportChatRealtimeUpdate event) {
    final activeConversationId = state.conversation?.conversationId;
    if (activeConversationId != null &&
        activeConversationId != event.conversationId) {
      return;
    }

    if (!_isScreenVisible) {
      _hasPendingRealtimeRefresh = true;
      return;
    }

    _hasPendingRealtimeRefresh = true;
    _scheduleRealtimeRefresh();
  }

  bool _isConversationNotFound(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('support.conversation_not_found') ||
        normalized.contains('support conversation was not found');
  }

  bool _isConversationReadOnlyForUser(SupportChatConversation conversation) {
    final normalizedStatus = conversation.status.trim().toLowerCase();
    if (normalizedStatus == 'closed') {
      return false;
    }

    return conversation.isReadOnly;
  }
}
