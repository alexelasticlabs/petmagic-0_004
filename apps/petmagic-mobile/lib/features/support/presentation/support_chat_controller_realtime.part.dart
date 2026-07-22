part of 'support_chat_controller.dart';

mixin _SupportChatControllerRealtimeMixin
    on Notifier<SupportChatState>, _SupportChatControllerScope {
  StreamSubscription<SupportChatRealtimeUpdate>? _realtimeSubscription;
  Timer? _realtimeRefreshTimer;
  Future<void>? _realtimeConnectInFlight;
  bool _hasPendingRealtimeRefresh = false;
  bool _isRealtimeConnected = false;
  bool _canUsePrivateSupportApi = true;

  bool get _hasInternet;
  bool get _isScreenVisible;
  bool get _started;
  bool get _isConversationBusy;

  Future<void> initialize();
  Future<void> _loadConversation({required bool refresh});
  RequestCancellation _newActiveMarkReadCancelToken();
  void _clearActiveMarkRead(RequestCancellation cancelToken);
  void stop();

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
}
