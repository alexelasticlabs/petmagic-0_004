part of 'generation_status_page.dart';

extension _GenerationStatusPageLifecycle on _GenerationStatusPageState {
  void _startPolling() {
    if (!_canUsePrivateStatusApi || _pollTimer != null) {
      return;
    }

    _scheduleNextPoll();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _scheduleNextPoll() {
    if (!mounted ||
        !_canUsePrivateStatusApi ||
        _generation?.isTerminal == true) {
      _stopPolling();
      return;
    }

    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      _stopPolling();
      return;
    }

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      _stopPolling();
      return;
    }

    _stopPolling();
    _pollTimer = Timer(_nextPollDelay(), () {
      unawaited(_handlePollTick());
    });
  }

  /// Base poll interval with exponential error backoff (up to [_maxPollBackoff])
  /// and random jitter, so degraded backends see decaying, desynchronized load
  /// instead of a fixed-rate hammering from every client in the generation flow.
  Duration _nextPollDelay() {
    final base = _generationPollInterval(_generation);
    var delaySeconds = base.inSeconds;
    if (_consecutivePollFailures > 0) {
      final exponent = math.min(_consecutivePollFailures, 5);
      delaySeconds = math.min(
        base.inSeconds * (1 << exponent),
        _maxPollBackoff.inSeconds,
      );
    }

    return Duration(
      seconds: delaySeconds,
      milliseconds: _pollJitterRandom.nextInt(1000),
    );
  }

  Future<void> _handlePollTick() async {
    _pollTimer = null;

    if (!mounted ||
        !_canUsePrivateStatusApi ||
        _generation?.isTerminal == true) {
      return;
    }

    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      _stopPolling();
      return;
    }

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      _stopPolling();
      return;
    }

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _scheduleNextPoll();
      return;
    }

    if (_isPollInFlight) {
      _scheduleNextPoll();
      return;
    }

    _isPollInFlight = true;
    try {
      await _load(silent: true);
    } finally {
      _isPollInFlight = false;
      _scheduleNextPoll();
    }
  }

  RequestCancellation _startLoadRequest() {
    _cancelActiveLoad();
    final cancelToken = RequestCancellation();
    _activeLoadCancelToken = cancelToken;
    return cancelToken;
  }

  void _completeLoadRequest(RequestCancellation cancelToken) {
    if (identical(_activeLoadCancelToken, cancelToken)) {
      _activeLoadCancelToken = null;
    }
  }

  void _cancelActiveLoad() {
    final cancelToken = _activeLoadCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('generation_status_load_cancelled');
    }
    _activeLoadCancelToken = null;
  }

  RequestCancellation? _startGenerationCancelRequest() {
    if (_activeGenerationCancelToken != null) {
      return null;
    }

    final cancelToken = RequestCancellation();
    _activeGenerationCancelToken = cancelToken;
    return cancelToken;
  }

  void _completeGenerationCancelRequest(RequestCancellation cancelToken) {
    if (identical(_activeGenerationCancelToken, cancelToken)) {
      _activeGenerationCancelToken = null;
    }
  }

  void _cancelActiveGenerationCancel() {
    final cancelToken = _activeGenerationCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('generation_status_cancel_generation_cancelled');
    }
    _activeGenerationCancelToken = null;
  }

  void _cancelActiveLocalMediaDownloads() {
    final store = _activeGalleryStore;
    if (store != null) {
      unawaited(store.cancelActiveDownloads());
    }
  }

  bool _canApplyLocalMediaSync() {
    if (!mounted || !_canUsePrivateStatusApi || !_isPageActive) {
      return false;
    }

    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    return lifecycleState == null ||
        lifecycleState == AppLifecycleState.resumed;
  }

  Future<void> _load({bool silent = false}) async {
    if (!_canUsePrivateStatusApi) {
      _cancelActiveLoad();
      if (!silent) {
        _setPageState(() {
          _isLoading = false;
          _errorMessage = 'auth.sign_in_required';
        });
      }
      return;
    }

    if (!silent) {
      _setPageState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final repository = ref.read(templateGenerationRepositoryProvider);
    final loadCancelToken = _startLoadRequest();

    try {
      final fetchedGeneration = await repository.fetchGeneration(
        widget.generationId,
        cancelToken: loadCancelToken,
      );
      if (!mounted ||
          !_canUsePrivateStatusApi ||
          loadCancelToken.isCancelled ||
          _isMediaActionInFlight) {
        return;
      }

      final generation = _reuseCurrentLocalMedia(fetchedGeneration);
      _consecutivePollFailures = 0;
      _applyGenerationSnapshot(generation);
    } on RequestCancelledException {
      return;
    } catch (error) {
      _consecutivePollFailures++;
      await _showCachedOrMappedLoadError(repository, error);
    } finally {
      _completeLoadRequest(loadCancelToken);
    }
  }

  void _applyGenerationSnapshot(TemplateGenerationResult generation) {
    if (!mounted || !_canUsePrivateStatusApi) {
      return;
    }

    final previousGeneration = _generation;
    unawaited(
      ref
          .read(generationHistoryControllerProvider.notifier)
          .mergeFetchedGeneration(generation),
    );

    _setPageState(() {
      _generation = generation;
      _isLoading = false;
      _errorMessage = null;
    });

    if (generation.isUnread) {
      unawaited(
        ref
            .read(generationHistoryControllerProvider.notifier)
            .markRead(generation.generationId),
      );
    }

    if (generation.isCompleted) {
      unawaited(_materializeLocalMediaAndRefresh(generation));
      unawaited(_recordFeedbackPromptViewed(generation));
    }

    if (generation.isTerminal) {
      _stopPolling();
      unawaited(_recordTemplateOfTheDayTerminalAnalytics(generation));

      final reachedTerminalNow = previousGeneration != null
          ? !previousGeneration.isTerminal
          : true;
      if (reachedTerminalNow) {
        unawaited(PetMagicHaptics.heavy());
      }
    }
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (!mounted ||
        !_canUsePrivateStatusApi ||
        !_isPageActive ||
        _isMediaActionInFlight) {
      return;
    }

    if (event.topic != RealtimeTopics.templatesGenerationStatusChanged ||
        event.payload.isEmpty) {
      return;
    }

    try {
      final generationId = event.payload['generationId'] as String?;
      if (generationId != widget.generationId) {
        return;
      }

      // The server deliberately publishes compact status events to avoid
      // leaking media URLs through the broadcast channel. A terminal event
      // therefore must be refreshed from the authenticated endpoint before
      // it is rendered; otherwise polling stops with an incomplete result.
      if (event.payload['requiresRefetch'] == true) {
        unawaited(_load(silent: true));
        return;
      }

      final generation = ref
          .read(templateGenerationRepositoryProvider)
          .parseRealtimePayload(Map<String, dynamic>.from(event.payload));

      _applyGenerationSnapshot(_reuseCurrentLocalMedia(generation));
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.GenerationStatus',
        operation: 'realtime_event_parse',
        message: 'Generation status realtime payload parsing failed',
        context: {
          'topic': event.topic,
          'payload_keys': event.payload.keys.take(8).toList(growable: false),
        },
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _resumeRealtimeIfNeeded() async {
    if (!mounted || !_canUsePrivateStatusApi || !_isPageActive) {
      return;
    }

    if (!ref.read(networkStatusControllerProvider).hasInternet) {
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

    Future<void>? nextConnectFuture;
    try {
      nextConnectFuture = realtimeClient.connect();
      _realtimeConnectFuture = nextConnectFuture;
      await nextConnectFuture;
      if (!mounted ||
          !_canUsePrivateStatusApi ||
          !_isPageActive ||
          !ref.read(networkStatusControllerProvider).hasInternet ||
          !identical(_activeRealtimeClient, realtimeClient)) {
        unawaited(realtimeClient.disconnect());
        return;
      }

      _isRealtimeConnected = true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.GenerationStatus',
        operation: 'realtime_connect',
        message:
            'Generation status realtime unavailable; polling remains active',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (identical(_realtimeConnectFuture, nextConnectFuture)) {
        _realtimeConnectFuture = null;
      }
    }
  }

  void _pauseRealtime() {
    unawaited(_realtimeSubscription?.cancel());
    _realtimeSubscription = null;

    final realtimeClient = _activeRealtimeClient;
    if (_isRealtimeConnected && realtimeClient != null) {
      unawaited(realtimeClient.disconnect());
    }
    _isRealtimeConnected = false;
  }
}
