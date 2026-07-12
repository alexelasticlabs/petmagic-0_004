part of 'support_chat_controller.dart';

mixin _SupportChatControllerConversationMixin
    on Notifier<SupportChatState>, _SupportChatControllerScope {
  StreamSubscription<SupportChatRealtimeUpdate>? _realtimeSubscription;
  Timer? _realtimeRefreshTimer;
  RequestCancellation? _activeUploadCancelToken;
  RequestCancellation? _activeConversationLoadCancelToken;
  RequestCancellation? _activeLoadOlderCancelToken;
  RequestCancellation? _activeMarkReadCancelToken;
  Future<void>? _conversationLoadInFlight;
  Future<void>? _realtimeConnectInFlight;
  bool _hasPendingRealtimeRefresh = false;
  bool _hasLoadedConversationSnapshot = false;
  bool _started = false;
  bool _hasInternet = true;
  bool _isScreenVisible = true;
  bool _isRealtimeConnected = false;
  bool _canUsePrivateSupportApi = true;

  bool _isLaunchAuthorized(AppLaunchState state) {
    return state.isLoading || state.isAuthenticated;
  }

  void _handleAuthStatusChanged(AppLaunchState state) {
    final canUsePrivateApi = _isLaunchAuthorized(state);
    if (_canUsePrivateSupportApi == canUsePrivateApi) {
      return;
    }

    _canUsePrivateSupportApi = canUsePrivateApi;
    if (canUsePrivateApi) {
      return;
    }

    stop();
    _settlePrivateApiDisabledState();
  }

  void _settlePrivateApiDisabledState() {
    _updateStateIfMounted(
      (state) => state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isSending: false,
        isLoadingOlder: false,
        clearSendProgress: true,
      ),
    );
  }

  void stop() {
    suspend();
    _hasLoadedConversationSnapshot = false;
    _started = false;
    _hasPendingRealtimeRefresh = false;
  }

  void suspend() {
    _cancelActiveUpload();
    _cancelActiveConversationLoad();
    _cancelActiveLoadOlder();
    _cancelActiveMarkRead();
    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = null;
    _pauseRealtime();
    _isScreenVisible = false;
  }

  RequestCancellation _newActiveUploadCancelToken() {
    _cancelActiveUpload();
    final cancelToken = RequestCancellation();
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

  void _clearActiveUpload(RequestCancellation cancelToken) {
    if (identical(_activeUploadCancelToken, cancelToken)) {
      _activeUploadCancelToken = null;
    }
  }

  RequestCancellation _newActiveConversationLoadCancelToken() {
    _cancelActiveConversationLoad();
    final cancelToken = RequestCancellation();
    _activeConversationLoadCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveConversationLoad() {
    final cancelToken = _activeConversationLoadCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('support_conversation_load_cancelled');
    }
    _activeConversationLoadCancelToken = null;
  }

  void _clearActiveConversationLoad(RequestCancellation cancelToken) {
    if (identical(_activeConversationLoadCancelToken, cancelToken)) {
      _activeConversationLoadCancelToken = null;
    }
  }

  RequestCancellation _newActiveLoadOlderCancelToken() {
    _cancelActiveLoadOlder();
    final cancelToken = RequestCancellation();
    _activeLoadOlderCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveLoadOlder() {
    final cancelToken = _activeLoadOlderCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('support_load_older_cancelled');
    }
    _activeLoadOlderCancelToken = null;
  }

  void _clearActiveLoadOlder(RequestCancellation cancelToken) {
    if (identical(_activeLoadOlderCancelToken, cancelToken)) {
      _activeLoadOlderCancelToken = null;
    }
  }

  RequestCancellation _newActiveMarkReadCancelToken() {
    _cancelActiveMarkRead();
    final cancelToken = RequestCancellation();
    _activeMarkReadCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveMarkRead() {
    final cancelToken = _activeMarkReadCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('support_mark_read_cancelled');
    }
    _activeMarkReadCancelToken = null;
  }

  void _clearActiveMarkRead(RequestCancellation cancelToken) {
    if (identical(_activeMarkReadCancelToken, cancelToken)) {
      _activeMarkReadCancelToken = null;
    }
  }

  void setScreenVisible(bool visible) {
    if (_isScreenVisible == visible) {
      return;
    }

    _isScreenVisible = visible;
    if (!_canUsePrivateSupportApi) {
      suspend();
      return;
    }

    if (_isScreenVisible) {
      if (_started) {
        unawaited(_resumeRealtimeIfNeeded());
      }
      _resumePendingRealtimeRefreshIfNeeded();
      return;
    }

    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = null;
    _pauseRealtime();
  }

  void _handleNetworkStatusChanged(bool hasInternet) {
    if (_hasInternet == hasInternet) {
      return;
    }

    _hasInternet = hasInternet;
    if (!hasInternet) {
      _realtimeRefreshTimer?.cancel();
      _realtimeRefreshTimer = null;
      _pauseRealtime();
      return;
    }

    if (!_started || !_isScreenVisible) {
      return;
    }

    if (!_hasLoadedConversationSnapshot && state.conversation == null) {
      unawaited(() async {
        await initialize();
        if (!ref.mounted) {
          return;
        }
        await _resumeRealtimeIfNeeded();
        _resumePendingRealtimeRefreshIfNeeded();
      }());
      return;
    }

    unawaited(_resumeRealtimeIfNeeded());
    _resumePendingRealtimeRefreshIfNeeded();
  }

  Future<void> start() async {
    if (!_canUsePrivateSupportApi) {
      stop();
      _settlePrivateApiDisabledState();
      return;
    }

    final shouldInitialize = !_hasLoadedConversationSnapshot;
    if (_started) {
      if (_isScreenVisible) {
        if (shouldInitialize) {
          await initialize();
          if (!ref.mounted) {
            return;
          }
        }
        await _resumeRealtimeIfNeeded();
        _resumePendingRealtimeRefreshIfNeeded();
      }
      return;
    }

    _started = true;
    if (shouldInitialize) {
      await initialize();
      if (!ref.mounted) {
        return;
      }
    }
    await _resumeRealtimeIfNeeded();
    _resumePendingRealtimeRefreshIfNeeded();
  }

  Future<void> initialize() async {
    await _loadConversation(refresh: false);
  }

  Future<void> _loadConversation({required bool refresh}) async {
    if (!_canUsePrivateSupportApi) {
      _settlePrivateApiDisabledState();
      return;
    }

    if (!_hasInternet) {
      if (state.conversation == null) {
        _updateStateIfMounted(
          (state) => state.copyWith(
            isLoading: false,
            isRefreshing: false,
            errorMessage: 'network.unavailable',
          ),
        );
      } else {
        _updateStateIfMounted(
          (state) => state.copyWith(
            isLoading: false,
            isRefreshing: false,
            clearError: true,
          ),
        );
      }
      return;
    }

    final inFlight = _conversationLoadInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final operation = _performConversationLoad(refresh: refresh);
    _conversationLoadInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_conversationLoadInFlight, operation)) {
        _conversationLoadInFlight = null;
      }
    }
  }

  Future<void> refresh() async {
    await _loadConversation(refresh: true);
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

  Future<void> submitFeedback(int rating, {String? comment}) async {
    await _runConversationLifecycleAction(
      (conversation) => _repository.submitFeedback(
        conversationId: conversation.conversationId,
        rating: rating,
        comment: comment,
      ),
    );
  }

  Future<void> _runConversationLifecycleAction(
    Future<SupportChatConversation> Function(
      SupportChatConversation conversation,
    )
    action,
  ) async {
    if (!_canUsePrivateSupportApi) {
      return;
    }

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

  Future<void> _performConversationLoad({required bool refresh}) async {
    if (!_canUsePrivateSupportApi) {
      return;
    }

    state = state.copyWith(
      isLoading: !refresh,
      isRefreshing: refresh,
      clearError: true,
    );

    final cancelToken = _newActiveConversationLoadCancelToken();
    try {
      final conversation = await _repository.getConversation(
        cancelToken: cancelToken,
      );
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
      _hasLoadedConversationSnapshot = true;

      if (conversation.userUnreadCount > 0) {
        await _markReadIfNeeded(conversation);
      }
      if (!ref.mounted) {
        return;
      }
      _resumePendingRealtimeRefreshIfNeeded();
    } on RequestCancelledException {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isLoading: false,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } on AppException catch (error) {
      if (_isConversationNotFound(error)) {
        _hasLoadedConversationSnapshot = true;
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
    } finally {
      _clearActiveConversationLoad(cancelToken);
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
    final cancelToken = _newActiveLoadOlderCancelToken();
    try {
      final chunk = await _repository.getConversation(
        beforeMessageCreatedAtUtc: before,
        beforeMessageId: beforeMessageId,
        cancelToken: cancelToken,
      );
      if (!ref.mounted) {
        return;
      }

      final existingById = {
        for (final message in conversation.messages) message.messageId: message,
      };
      final newOlderMessages = chunk.messages
          .where((message) => !existingById.containsKey(message.messageId))
          .toList(growable: false);
      final merged = <SupportChatMessage>[
        ...newOlderMessages,
        ...conversation.messages,
      ]..sort((a, b) => a.createdAtUtc.compareTo(b.createdAtUtc));

      _updateStateIfMounted(
        (state) => state.copyWith(
          isLoadingOlder: false,
          conversation: conversation.copyWith(
            hasOlderMessages:
                chunk.hasOlderMessages && newOlderMessages.isNotEmpty,
            oldestLoadedMessageCreatedAtUtc:
                chunk.oldestLoadedMessageCreatedAtUtc,
            messages: merged,
          ),
        ),
      );
    } on RequestCancelledException {
      _updateStateIfMounted(
        (state) => state.copyWith(isLoadingOlder: false, clearError: true),
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
    } finally {
      _clearActiveLoadOlder(cancelToken);
    }
  }

  void _scheduleRealtimeRefresh() {
    if (!_canUsePrivateSupportApi ||
        !_isScreenVisible ||
        !_hasInternet ||
        _isConversationBusy) {
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
    if (!_hasPendingRealtimeRefresh ||
        !_canUsePrivateSupportApi ||
        !_isScreenVisible ||
        !_hasInternet ||
        _isConversationBusy) {
      return;
    }

    _hasPendingRealtimeRefresh = false;
    unawaited(_loadConversation(refresh: true));
  }

  void _resumePendingRealtimeRefreshIfNeeded() {
    if (!ref.mounted) {
      return;
    }

    if (_canUsePrivateSupportApi &&
        _isScreenVisible &&
        _hasInternet &&
        _hasPendingRealtimeRefresh) {
      _scheduleRealtimeRefresh();
    }
  }

  Future<void> _resumeRealtimeIfNeeded() async {
    if (!_started ||
        !ref.mounted ||
        !_canUsePrivateSupportApi ||
        !_isScreenVisible ||
        !_hasInternet) {
      return;
    }

    _realtimeSubscription ??= _realtimeClient.events.listen(
      _handleRealtimeUpdate,
    );
    if (_isRealtimeConnected) {
      return;
    }

    final connectInFlight = _realtimeConnectInFlight;
    if (connectInFlight != null) {
      await connectInFlight;
      return;
    }

    try {
      final nextConnect = _realtimeClient.connect();
      _realtimeConnectInFlight = nextConnect;
      await nextConnect;
      if (!ref.mounted ||
          !_started ||
          !_canUsePrivateSupportApi ||
          !_isScreenVisible ||
          !_hasInternet) {
        unawaited(_realtimeClient.disconnect());
        _pauseRealtime();
        return;
      }

      _isRealtimeConnected = true;
    } on Object {
      // Realtime is best-effort; keep the chat usable over REST even if the hub is unavailable.
    } finally {
      _realtimeConnectInFlight = null;
    }
  }

  void _pauseRealtime() {
    unawaited(_realtimeSubscription?.cancel());
    _realtimeSubscription = null;
    if (_isRealtimeConnected) {
      unawaited(_realtimeClient.disconnect());
    }
    _isRealtimeConnected = false;
    _realtimeConnectInFlight = null;
  }

  Future<void> _markReadIfNeeded(SupportChatConversation conversation) async {
    if (!ref.mounted) {
      return;
    }

    if (!_canUsePrivateSupportApi) {
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
    final cancelToken = _newActiveMarkReadCancelToken();
    try {
      await _repository.markConversationRead(
        conversation.conversationId,
        cancelToken: cancelToken,
      );
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
    } on RequestCancelledException {
      return;
    } on AppException {
      // Keep realtime refresh resilient; the next event or manual refresh will try again.
    } finally {
      _clearActiveMarkRead(cancelToken);
    }
  }

  void _handleRealtimeUpdate(SupportChatRealtimeUpdate event) {
    if (!_canUsePrivateSupportApi) {
      return;
    }

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

  bool _isConversationNotFound(AppException error) {
    return error.isSupportConversationNotFound;
  }

  bool _isConversationReadOnlyForUser(SupportChatConversation conversation) {
    final normalizedStatus = conversation.status.trim().toLowerCase();
    if (normalizedStatus == 'closed') {
      return false;
    }

    return conversation.isReadOnly;
  }
}
