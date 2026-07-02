part of 'generation_history_controller.dart';

mixin _GenerationHistoryControllerLifecycle
    on _GenerationHistoryControllerBase {
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;

  @override
  void _setScreenVisible(bool visible, {bool clearLoadingState = true}) {
    if (_isScreenVisible == visible) {
      return;
    }

    _isScreenVisible = visible;
    if (visible) {
      _scheduleLocalArtifactCleanup();
      if (!_hasInternet) {
        return;
      }
      _startAutoRefresh();
      unawaited(_resumeRealtimeIfNeeded());
      return;
    }

    _stopAutoRefresh();
    _cancelActiveLoad(
      'generation_history_hidden',
      clearPending: true,
      clearLoadingState: clearLoadingState,
    );
    _cancelActiveLoadMore('generation_history_hidden');
    _cancelActiveUnreadRefresh('generation_history_hidden');
    unawaited(_galleryStore.cancelActiveDownloads());
    _pauseRealtime();
  }

  void _handleNetworkStatusChanged(bool hasInternet) {
    if (_hasInternet == hasInternet) {
      return;
    }

    _hasInternet = hasInternet;
    if (!hasInternet) {
      _stopAutoRefresh();
      _cancelActiveLoad('generation_history_offline', clearPending: true);
      _cancelActiveLoadMore('generation_history_offline');
      _cancelActiveUnreadRefresh('generation_history_offline');
      _pauseRealtime();
      return;
    }

    if (!_isScreenVisible) {
      return;
    }

    _startAutoRefresh();
    unawaited(_resumeRealtimeIfNeeded());
  }

  @override
  void _completeCancelledLoad() {
    if (!ref.mounted || !state.isLoading) {
      return;
    }

    state = state.copyWith(isLoading: false);
  }

  @override
  CancelToken _startLoadCancelToken() {
    _cancelActiveLoad('generation_history_superseded', clearPending: false);
    final cancelToken = CancelToken();
    _activeLoadCancelToken = cancelToken;
    return cancelToken;
  }

  @override
  void _clearActiveLoadCancelToken() {
    _activeLoadCancelToken = null;
  }

  @override
  CancelToken _startLoadMoreCancelToken() {
    _cancelActiveLoadMore('generation_history_load_more_superseded');
    final cancelToken = CancelToken();
    _activeLoadMoreCancelToken = cancelToken;
    return cancelToken;
  }

  @override
  void _clearActiveLoadMoreCancelToken() {
    _activeLoadMoreCancelToken = null;
  }

  @override
  void _cancelActiveLoadMore(String reason) {
    final cancelToken = _activeLoadMoreCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel(reason);
    }
    _activeLoadMoreCancelToken = null;
    _isLoadMoreInFlight = false;
    if (ref.mounted && state.isLoadingMore) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void _cancelActiveLoad(
    String reason, {
    required bool clearPending,
    bool clearLoadingState = true,
  }) {
    final cancelToken = _activeLoadCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel(reason);
    }
    _activeLoadCancelToken = null;
    if (clearPending && clearLoadingState) {
      _completeCancelledLoad();
    }

    if (!clearPending) {
      return;
    }

    final pendingCompleter = _pendingLoadCompleter;
    _pendingLoadRequest = null;
    _pendingLoadCompleter = null;
    if (pendingCompleter != null && !pendingCompleter.isCompleted) {
      pendingCompleter.complete();
    }
  }

  CancelToken _startUnreadRefreshCancelToken() {
    _cancelActiveUnreadRefresh('generation_history_unread_superseded');
    final cancelToken = CancelToken();
    _activeUnreadRefreshCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveUnreadRefresh(String reason) {
    final cancelToken = _activeUnreadRefreshCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel(reason);
    }
    _activeUnreadRefreshCancelToken = null;
  }

  @override
  void _drainPendingLoad() {
    final pendingRequest = _pendingLoadRequest;
    final pendingCompleter = _pendingLoadCompleter;
    _pendingLoadRequest = null;
    _pendingLoadCompleter = null;
    if (pendingRequest == null) {
      return;
    }

    if (!ref.mounted) {
      if (pendingCompleter != null && !pendingCompleter.isCompleted) {
        pendingCompleter.complete();
      }
      return;
    }

    unawaited(() async {
      try {
        await _load(
          filter: pendingRequest.filter,
          refresh: pendingRequest.refresh,
        );
        if (pendingCompleter != null && !pendingCompleter.isCompleted) {
          pendingCompleter.complete();
        }
      } catch (error, stackTrace) {
        if (pendingCompleter != null && !pendingCompleter.isCompleted) {
          pendingCompleter.completeError(error, stackTrace);
        }
      }
    }());
  }

  void _scheduleLocalArtifactCleanup() {
    if (_hasScheduledLocalArtifactCleanup) {
      return;
    }

    _hasScheduledLocalArtifactCleanup = true;
    final galleryStore = _galleryStore;
    unawaited(() async {
      try {
        await galleryStore.cleanupCurrentAccountArtifacts();
      } on Object {
        // Cache cleanup is opportunistic; history loading remains authoritative.
      }
    }());
  }

  void _startAutoRefresh() {
    _scheduleNextAutoRefresh();
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  void _scheduleNextAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (!ref.mounted || !_isScreenVisible || !_hasInternet) {
      return;
    }

    _autoRefreshTimer = Timer(_currentAutoRefreshInterval(), () {
      if (!ref.mounted) {
        return;
      }

      if (!_isScreenVisible || !_hasInternet || _isLoadInFlight) {
        _scheduleNextAutoRefresh();
        return;
      }

      unawaited(_load(refresh: true).whenComplete(_scheduleNextAutoRefresh));
    });
  }

  Duration _currentAutoRefreshInterval() {
    if (_shouldUseIdleRefreshInterval()) {
      return _GenerationHistoryControllerBase._idleRealtimeRefreshInterval;
    }

    final multiplier = 1 << _autoRefreshFailureStreak.clamp(0, 3);
    final nextSeconds =
        _GenerationHistoryControllerBase._autoRefreshMinInterval.inSeconds *
        multiplier;
    final maxSeconds =
        _GenerationHistoryControllerBase._autoRefreshMaxInterval.inSeconds;
    final boundedSeconds = nextSeconds > maxSeconds ? maxSeconds : nextSeconds;
    return Duration(seconds: boundedSeconds);
  }

  bool _shouldUseIdleRefreshInterval() {
    return _isRealtimeConnected &&
        !state.syncFailed &&
        state.activeGeneration == null;
  }

  @override
  void _registerAutoRefreshSuccess() {
    if (!ref.mounted) {
      return;
    }

    if (_autoRefreshFailureStreak != 0) {
      _autoRefreshFailureStreak = 0;
    }

    _scheduleNextAutoRefresh();
  }

  @override
  void _registerAutoRefreshFailure() {
    if (!ref.mounted) {
      return;
    }

    final next = _autoRefreshFailureStreak + 1;
    _autoRefreshFailureStreak = next > 3 ? 3 : next;
    _scheduleNextAutoRefresh();
  }

  @override
  void _scheduleOfflineBannerHide() {
    _offlineBannerTimer?.cancel();
    _offlineBannerTimer = Timer(const Duration(seconds: 3), () {
      if (!ref.mounted) {
        return;
      }

      state = state.copyWith(
        showOfflineBanner: false,
        isConnectionRecovered: false,
      );
    });
  }

  @override
  Future<void> _refreshUnreadCount() async {
    if (!ref.mounted || !_isScreenVisible || _isLoadInFlight) {
      return;
    }

    final cancelToken = _startUnreadRefreshCancelToken();
    try {
      final unreadCount = await _repository.fetchUnreadGenerationCount(
        cancelToken: cancelToken,
      );
      if (!ref.mounted || !_isScreenVisible || cancelToken.isCancelled) {
        return;
      }

      state = state.copyWith(unreadCount: _visibleUnreadCount(unreadCount));
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || cancelToken.isCancelled) {
        return;
      }
    } on Object {
      // Best-effort badge refresh; the next history load remains authoritative.
    } finally {
      if (identical(_activeUnreadRefreshCancelToken, cancelToken)) {
        _activeUnreadRefreshCancelToken = null;
      }
    }
  }

  @override
  Future<int?> _fetchUnreadGenerationCountBestEffort(
    CancelToken cancelToken,
  ) async {
    try {
      return await _repository.fetchUnreadGenerationCount(
        cancelToken: cancelToken,
      );
    } on Object catch (error) {
      if (_isCancelledRequest(error) || cancelToken.isCancelled) {
        rethrow;
      }
      return null;
    }
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (!ref.mounted || !_isScreenVisible) {
      return;
    }

    if (event.topic != RealtimeTopics.templatesGenerationStatusChanged ||
        event.payload.isEmpty) {
      return;
    }

    final generationId = _readRealtimeGenerationId(event.payload);
    if (generationId == null) {
      AppLogger.warn(
        feature: 'Templates.GenerationHistory',
        operation: 'realtime_event_parse',
        message: 'Generation history realtime payload is missing generation id',
        context: {
          'topic': event.topic,
          'payload_keys': event.payload.keys.take(8).toList(growable: false),
        },
      );
      return;
    }

    unawaited(_refetchRealtimeGeneration(generationId));
  }

  String? _readRealtimeGenerationId(Map<String, Object?> payload) {
    final eventType = payload['eventType']?.toString().trim();
    if (eventType != null &&
        eventType.isNotEmpty &&
        eventType != 'generation.status_changed') {
      return null;
    }

    final generationId = payload['generationId']?.toString().trim();
    return generationId == null || generationId.isEmpty ? null : generationId;
  }

  Future<void> _refetchRealtimeGeneration(String generationId) async {
    if (!ref.mounted || !_isScreenVisible) {
      return;
    }

    try {
      final generation = await _repository.fetchGeneration(generationId);
      if (!ref.mounted || !_isScreenVisible) {
        return;
      }

      await _mergeExternalGeneration(
        generation,
        refreshUnreadBadge: true,
        requireScreenVisible: true,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.GenerationHistory',
        operation: 'realtime_refetch',
        message: 'Generation history realtime refetch failed',
        context: {'generation_id': generationId},
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> _resumeRealtimeIfNeeded() async {
    if (!ref.mounted || !_isScreenVisible || !_hasInternet) {
      return;
    }

    final realtimeClient = _activeRealtimeClient;
    if (realtimeClient == null) {
      return;
    }

    _realtimeSubscription ??= realtimeClient.events.listen(
      _handleRealtimeEvent,
    );
    if (_isRealtimeConnected) {
      return;
    }

    final connectFuture = _realtimeConnectFuture;
    if (connectFuture != null) {
      await connectFuture;
      return;
    }

    try {
      final nextConnectFuture = realtimeClient.connect();
      _realtimeConnectFuture = nextConnectFuture;
      await nextConnectFuture;
      if (!ref.mounted) {
        unawaited(realtimeClient.disconnect());
        return;
      }

      if (!_isScreenVisible ||
          !_hasInternet ||
          !identical(_activeRealtimeClient, realtimeClient)) {
        unawaited(realtimeClient.disconnect());
        return;
      }

      _isRealtimeConnected = true;
      _scheduleNextAutoRefresh();
    } on Object {
      // Realtime is best-effort; gallery remains available via manual refresh.
    } finally {
      _realtimeConnectFuture = null;
    }
  }

  void _pauseRealtime() {
    unawaited(_realtimeSubscription?.cancel());
    _realtimeSubscription = null;

    if (_isRealtimeConnected) {
      final realtimeClient = _activeRealtimeClient;
      if (realtimeClient != null) {
        unawaited(realtimeClient.disconnect());
      }
      _isRealtimeConnected = false;
    }
    _realtimeConnectFuture = null;
  }
}
