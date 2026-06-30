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
    _cancelActiveUnreadRefresh('generation_history_hidden');
    unawaited(_galleryStore.cancelActiveDownloads());
    _pauseRealtime();
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
    if (!ref.mounted || !_isScreenVisible) {
      return;
    }

    _autoRefreshTimer = Timer(_currentAutoRefreshInterval(), () {
      if (!ref.mounted) {
        return;
      }

      if (!_isScreenVisible || _isLoadInFlight) {
        _scheduleNextAutoRefresh();
        return;
      }

      unawaited(_load(refresh: true).whenComplete(_scheduleNextAutoRefresh));
    });
  }

  Duration _currentAutoRefreshInterval() {
    final multiplier = 1 << _autoRefreshFailureStreak.clamp(0, 3);
    final nextSeconds =
        _GenerationHistoryControllerBase._autoRefreshMinInterval.inSeconds *
        multiplier;
    final maxSeconds =
        _GenerationHistoryControllerBase._autoRefreshMaxInterval.inSeconds;
    final boundedSeconds = nextSeconds > maxSeconds ? maxSeconds : nextSeconds;
    return Duration(seconds: boundedSeconds);
  }

  @override
  void _registerAutoRefreshSuccess() {
    if (!ref.mounted) {
      return;
    }

    if (_autoRefreshFailureStreak == 0) {
      return;
    }

    _autoRefreshFailureStreak = 0;
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

    try {
      final generation = TemplateGenerationDto.fromJson(
        Map<String, dynamic>.from(event.payload),
      ).toDomain();
      unawaited(
        _mergeExternalGeneration(
          generation,
          refreshUnreadBadge: true,
          requireScreenVisible: true,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.GenerationHistory',
        operation: 'realtime_event_parse',
        message: 'Generation history realtime payload parsing failed',
        context: {
          'topic': event.topic,
          'payload_keys': event.payload.keys.take(8).toList(growable: false),
        },
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> _resumeRealtimeIfNeeded() async {
    if (!ref.mounted || !_isScreenVisible) {
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
        return;
      }

      if (!_isScreenVisible ||
          !identical(_activeRealtimeClient, realtimeClient)) {
        unawaited(realtimeClient.disconnect());
        return;
      }

      _isRealtimeConnected = true;
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
