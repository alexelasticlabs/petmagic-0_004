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

  CancelToken _startLoadRequest() {
    _cancelActiveLoad();
    final cancelToken = CancelToken();
    _activeLoadCancelToken = cancelToken;
    return cancelToken;
  }

  void _completeLoadRequest(CancelToken cancelToken) {
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

  CancelToken? _startGenerationCancelRequest() {
    if (_activeGenerationCancelToken != null) {
      return null;
    }

    final cancelToken = CancelToken();
    _activeGenerationCancelToken = cancelToken;
    return cancelToken;
  }

  void _completeGenerationCancelRequest(CancelToken cancelToken) {
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
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return;
      }

      _consecutivePollFailures++;
      await _showCachedOrMappedLoadError(repository, error);
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
      final generation = TemplateGenerationDto.fromJson(
        Map<String, dynamic>.from(event.payload),
      ).toDomain();
      if (generation.generationId != widget.generationId) {
        return;
      }

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

  Future<void> _showCachedOrMappedLoadError(
    TemplateGenerationRepository repository,
    Object error,
  ) async {
    if (!_canUsePrivateStatusApi) {
      return;
    }

    final cachedGeneration = await repository.readCachedGeneration(
      widget.generationId,
    );
    if (!mounted || !_canUsePrivateStatusApi) {
      return;
    }

    final localizedCachedGeneration = cachedGeneration == null
        ? null
        : _reuseCurrentLocalMedia(cachedGeneration);

    if (!mounted || !_canUsePrivateStatusApi) {
      return;
    }

    if (localizedCachedGeneration != null) {
      _setPageState(() {
        _generation = localizedCachedGeneration;
        _isLoading = false;
        _errorMessage = null;
      });
      if (localizedCachedGeneration.isCompleted) {
        unawaited(_materializeLocalMediaAndRefresh(localizedCachedGeneration));
      }
      if (localizedCachedGeneration.isTerminal) {
        unawaited(
          _recordTemplateOfTheDayTerminalAnalytics(localizedCachedGeneration),
        );
      }
      return;
    }

    _setPageState(() {
      _isLoading = false;
      _errorMessage = _mapStatusLoadError(error);
    });
  }

  TemplateGenerationResult _reuseCurrentLocalMedia(
    TemplateGenerationResult generation,
  ) {
    final current = _generation;
    if (current == null || current.generationId != generation.generationId) {
      return generation;
    }

    if (current.outputUrl != generation.outputUrl) {
      return generation.copyWith(
        clearLocalPreviewPath: true,
        clearLocalOutputPath: true,
        isLocalMediaReady: false,
      );
    }

    return generation.copyWith(
      localPreviewPath: current.localPreviewPath,
      localOutputPath: current.localOutputPath,
      isLocalMediaReady: current.isLocalMediaReady,
    );
  }

  Future<void> _materializeLocalMediaAndRefresh(
    TemplateGenerationResult generation,
  ) async {
    final localRecord = await _galleryStore.materializeGenerationMedia(
      generation,
    );
    if (!_canApplyLocalMediaSync() ||
        localRecord == null ||
        localRecord.isDeletedLocally) {
      return;
    }

    final current = _generation;
    if (current == null || current.generationId != generation.generationId) {
      return;
    }

    final localizedGeneration = current.copyWith(
      localPreviewPath: localRecord.previewLocalPath,
      localOutputPath: localRecord.outputLocalPath,
      isLocalMediaReady: localRecord.isDownloadComplete,
    );
    _setPageState(() {
      _generation = localizedGeneration;
    });
    unawaited(
      ref
          .read(generationHistoryControllerProvider.notifier)
          .mergeFetchedGeneration(localizedGeneration),
    );
  }

  Future<void> _confirmAndCancelQueuedGeneration(
    TemplateGenerationResult generation,
  ) async {
    if (!_canUsePrivateStatusApi) {
      return;
    }

    if (!generation.canCancelQueued) {
      _showGenerationAlreadyStartedMessage();
      return;
    }

    final text = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(text.generationStatusCancelQueuedTitle),
          content: Text(text.generationStatusCancelQueuedMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(text.generationStatusCancelQueuedKeepAction),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(text.generationStatusCancelQueuedConfirmAction),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _cancelQueuedGeneration(generation);
  }

  Future<void> _cancelQueuedGeneration(
    TemplateGenerationResult generation,
  ) async {
    if (!_canUsePrivateStatusApi) {
      return;
    }

    final text = AppLocalizations.of(context);
    final current = _generation;
    if (current == null ||
        current.generationId != generation.generationId ||
        !current.canCancelQueued) {
      _showGenerationAlreadyStartedMessage();
      return;
    }
    final cancelToken = _startGenerationCancelRequest();
    if (cancelToken == null) {
      return;
    }

    _setPageState(() {
      _isCancellingGeneration = true;
      _errorMessage = null;
    });

    final repository = ref.read(templateGenerationRepositoryProvider);
    try {
      final result = await repository.cancelGeneration(
        generation.generationId,
        cancelToken: cancelToken,
      );
      if (!mounted || cancelToken.isCancelled) {
        return;
      }

      _stopPolling();
      _setPageState(() {
        _generation = _reuseCurrentLocalMedia(result.generation);
        _isCancellingGeneration = false;
        _isLoading = false;
        _errorMessage = null;
      });

      unawaited(
        ref
            .read(generationHistoryControllerProvider.notifier)
            .mergeFetchedGeneration(result.generation),
      );

      if (result.refunded || result.generation.refundedAtUtc != null) {
        unawaited(
          ref.read(walletControllerProvider.notifier).load(refresh: true),
        );
      }

      PetMagicToast.show(
        context,
        message: text.generationStatusCancelQueuedSuccess,
        tone: PetMagicToastTone.success,
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || cancelToken.isCancelled) {
        return;
      }

      if (!mounted) {
        return;
      }

      _setPageState(() {
        _isCancellingGeneration = false;
      });

      if (_isGenerationAlreadyStartedCancelError(error)) {
        _showGenerationAlreadyStartedMessage();
        unawaited(_load(silent: true));
        return;
      }

      PetMagicToast.show(
        context,
        message: text.generationStatusCancelQueuedFailed,
        tone: PetMagicToastTone.warning,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _setPageState(() {
        _isCancellingGeneration = false;
      });

      if (_isGenerationAlreadyStartedCancelError(error)) {
        _showGenerationAlreadyStartedMessage();
        unawaited(_load(silent: true));
        return;
      }

      PetMagicToast.show(
        context,
        message: text.generationStatusCancelQueuedFailed,
        tone: PetMagicToastTone.warning,
      );
    } finally {
      _completeGenerationCancelRequest(cancelToken);
    }
  }

  bool _isGenerationAlreadyStartedCancelError(Object error) {
    if (error is AppException) {
      if (error.statusCode == 409 || error.statusCode == 422) {
        return true;
      }

      final normalized = normalizeTemplateErrorKey(error.message);
      return normalized == 'templates.generation_already_started' ||
          normalized == 'templates.generation_cancel_not_allowed';
    }

    return false;
  }

  void _showGenerationAlreadyStartedMessage() {
    final text = AppLocalizations.of(context);
    PetMagicToast.show(
      context,
      message: text.generationStatusCancelQueuedAlreadyStarted,
      tone: PetMagicToastTone.info,
    );
  }
}

String _mapStatusLoadError(Object error) {
  if (error is AppException) {
    if (error.statusCode == 401) {
      return 'auth.sign_in_required';
    }
    if (error.statusCode == 402) {
      return 'templates.insufficient_balance';
    }

    final message = normalizeTemplateErrorKey(error.message);
    if (message != null) {
      return message;
    }
  }

  return 'templates.generation_failed';
}

const Duration _maxPollBackoff = Duration(seconds: 30);
final math.Random _pollJitterRandom = math.Random();

String _statusLoadErrorText(AppLocalizations text, String raw) {
  final authMessage = mapCommonAuthFeedbackMessage(text, raw);
  if (authMessage != null) {
    return authMessage;
  }

  return switch (normalizeTemplateErrorKey(raw) ?? raw.trim().toLowerCase()) {
    'auth.sign_in_required' => text.authSignInRequired,
    'templates.insufficient_balance' =>
      text.templateFlowInsufficientBalanceTitle,
    'templates.premium_required' => text.templateFlowPremiumRequiredError,
    'templates.generation_already_started' =>
      text.templateFlowActiveGenerationLimitError,
    'templates.generation_wait_too_long' => text.templateFlowServerError,
    'templates.network_unavailable' => text.templateFlowNetworkError,
    'templates.connection_timeout' => text.templateFlowNetworkError,
    'templates.server_unavailable' => text.templateFlowServerError,
    'templates.server_timeout' => text.templateFlowServerError,
    'templates.request_failed' => text.templatesRequestFailedError,
    _ => text.templateFlowStartFailedError,
  };
}

Duration _generationPollInterval(TemplateGenerationResult? generation) {
  return switch (generation?.status) {
    TemplateGenerationStatus.queued => const Duration(seconds: 8),
    TemplateGenerationStatus.submittingToProvider ||
    TemplateGenerationStatus.providerQueued => const Duration(seconds: 5),
    TemplateGenerationStatus.processing ||
    TemplateGenerationStatus.preprocessing ||
    TemplateGenerationStatus.generating ||
    TemplateGenerationStatus.providerProcessing ||
    TemplateGenerationStatus.importingMedia ||
    TemplateGenerationStatus.finalizing => const Duration(seconds: 3),
    _ => const Duration(seconds: 5),
  };
}
