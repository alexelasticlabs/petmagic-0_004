part of 'generation_history_controller.dart';

mixin _GenerationHistoryControllerLifecycle
    on _GenerationHistoryControllerBase {
  @override
  void _setScreenVisible(bool visible, {bool clearLoadingState = true}) {
    if (_isScreenVisible == visible) {
      return;
    }

    _isScreenVisible = visible;
    if (!_isAuthenticated) {
      _stopPrivateGenerationActivity(clearPrivateState: false);
      return;
    }

    if (visible) {
      _scheduleLocalArtifactCleanup();
      unawaited(_hydrateCachedUnreadCount());
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

  void _handleAuthStatusChanged(bool isAuthenticated) {
    if (_isAuthenticated == isAuthenticated) {
      return;
    }

    _isAuthenticated = isAuthenticated;
    if (!isAuthenticated) {
      _hasHydratedCachedUnreadCount = false;
      _stopPrivateGenerationActivity();
      return;
    }

    if (_isScreenVisible && _hasInternet) {
      unawaited(_hydrateCachedUnreadCount());
      _startAutoRefresh();
      unawaited(_resumeRealtimeIfNeeded());
    }
  }

  void _stopPrivateGenerationActivity({bool clearPrivateState = true}) {
    _stopAutoRefresh();
    _cancelActiveLoad(
      'generation_history_signed_out',
      clearPending: true,
      clearLoadingState: false,
    );
    _cancelActiveLoadMore('generation_history_signed_out');
    _cancelActiveUnreadRefresh('generation_history_signed_out');
    _cancelActiveRealtimeRefetches('generation_history_signed_out');
    unawaited(_galleryStore.cancelActiveDownloads());
    _pauseRealtime();
    _offlineBannerTimer?.cancel();
    _offlineBannerTimer = null;
    _isLoadInFlight = false;
    _isLoadMoreInFlight = false;
    _pendingLoadRequest = null;
    final pendingCompleter = _pendingLoadCompleter;
    _pendingLoadCompleter = null;
    if (pendingCompleter != null && !pendingCompleter.isCompleted) {
      pendingCompleter.complete();
    }

    if (clearPrivateState && ref.mounted) {
      state = const GenerationHistoryState();
    }
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

    if (!_isScreenVisible || !_isAuthenticated) {
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
  RequestCancellation _startLoadRequestCancellation() {
    _cancelActiveLoad('generation_history_superseded', clearPending: false);
    final cancelToken = RequestCancellation();
    _activeLoadRequestCancellation = cancelToken;
    return cancelToken;
  }

  @override
  void _clearActiveLoadRequestCancellation(RequestCancellation cancelToken) {
    if (identical(_activeLoadRequestCancellation, cancelToken)) {
      _activeLoadRequestCancellation = null;
    }
  }

  @override
  RequestCancellation _startLoadMoreRequestCancellation() {
    _cancelActiveLoadMore('generation_history_load_more_superseded');
    final cancelToken = RequestCancellation();
    _activeLoadMoreRequestCancellation = cancelToken;
    return cancelToken;
  }

  @override
  void _clearActiveLoadMoreRequestCancellation() {
    _activeLoadMoreRequestCancellation = null;
  }

  @override
  void _cancelActiveLoadMore(String reason) {
    final cancelToken = _activeLoadMoreRequestCancellation;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel(reason);
    }
    _activeLoadMoreRequestCancellation = null;
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
    final cancelToken = _activeLoadRequestCancellation;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel(reason);
    }
    _activeLoadRequestCancellation = null;
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

  RequestCancellation _startUnreadRefreshRequestCancellation() {
    _cancelActiveUnreadRefresh('generation_history_unread_superseded');
    final cancelToken = RequestCancellation();
    _activeUnreadRefreshRequestCancellation = cancelToken;
    return cancelToken;
  }

  void _cancelActiveUnreadRefresh(String reason) {
    final cancelToken = _activeUnreadRefreshRequestCancellation;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel(reason);
    }
    _activeUnreadRefreshRequestCancellation = null;
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

  @override
  void _scheduleNextAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (!ref.mounted ||
        !_isAuthenticated ||
        !_isScreenVisible ||
        !_hasInternet) {
      return;
    }

    _autoRefreshTimer = Timer(_currentAutoRefreshInterval(), () {
      if (!ref.mounted) {
        return;
      }

      if (!_isAuthenticated ||
          !_isScreenVisible ||
          !_hasInternet ||
          _isLoadInFlight) {
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
    if (!ref.mounted ||
        !_isAuthenticated ||
        !_isScreenVisible ||
        _isLoadInFlight) {
      return;
    }

    final cancelToken = _startUnreadRefreshRequestCancellation();
    try {
      final unreadCount = await _repository.fetchUnreadGenerationCount(
        cancelToken: cancelToken,
      );
      if (!ref.mounted ||
          !_isAuthenticated ||
          !_isScreenVisible ||
          cancelToken.isCancelled) {
        return;
      }

      state = state.copyWith(unreadCount: _visibleUnreadCount(unreadCount));
    } on Object {
      // Best-effort badge refresh; the next history load remains authoritative.
    } finally {
      if (identical(_activeUnreadRefreshRequestCancellation, cancelToken)) {
        _activeUnreadRefreshRequestCancellation = null;
      }
    }
  }

  @override
  Future<int?> _fetchUnreadGenerationCountBestEffort(
    RequestCancellation cancelToken,
  ) async {
    if (!_isAuthenticated) {
      return null;
    }

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
}
