part of 'generation_status_page.dart';

extension _GenerationStatusPageLifecycle on _GenerationStatusPageState {
  void _startPolling() {
    if (_pollTimer != null) {
      return;
    }

    _scheduleNextPoll();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _scheduleNextPoll() {
    if (!mounted || _generation?.isTerminal == true) {
      _stopPolling();
      return;
    }

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      _stopPolling();
      return;
    }

    _stopPolling();
    _pollTimer = Timer(const Duration(seconds: 3), () {
      unawaited(_handlePollTick());
    });
  }

  Future<void> _handlePollTick() async {
    _pollTimer = null;

    if (!mounted || _generation?.isTerminal == true) {
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

  void _cancelActiveLocalMediaDownloads() {
    unawaited(_galleryStore.cancelActiveDownloads());
  }

  bool _canApplyLocalMediaSync() {
    if (!mounted || !_isPageActive) {
      return false;
    }

    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    return lifecycleState == null ||
        lifecycleState == AppLifecycleState.resumed;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      _setPageState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final repository = ref.read(templateGenerationRepositoryProvider);
    final loadCancelToken = _startLoadRequest();

    try {
      final previousGeneration = _generation;
      final fetchedGeneration = await repository.fetchGeneration(
        widget.generationId,
        cancelToken: loadCancelToken,
      );
      if (!mounted || loadCancelToken.isCancelled || _isMediaActionInFlight) {
        return;
      }

      final generation = _reuseCurrentLocalMedia(fetchedGeneration);
      if (!mounted) {
        return;
      }

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
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return;
      }

      await _showCachedOrMappedLoadError(repository, error);
    } catch (error) {
      await _showCachedOrMappedLoadError(repository, error);
    } finally {
      _completeLoadRequest(loadCancelToken);
    }
  }

  Future<void> _showCachedOrMappedLoadError(
    TemplateGenerationRepository repository,
    Object error,
  ) async {
    final cachedGeneration = await repository.readCachedGeneration(
      widget.generationId,
    );
    if (!mounted) {
      return;
    }

    final localizedCachedGeneration = cachedGeneration == null
        ? null
        : _reuseCurrentLocalMedia(cachedGeneration);

    if (!mounted) {
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
}

String _mapStatusLoadError(Object error) {
  if (error is AppException) {
    if (error.statusCode == 401) {
      return 'auth.sign_in_required';
    }
    if (error.statusCode == 402) {
      return 'templates.insufficient_balance';
    }

    final message = error.message.trim();
    if (message == 'auth.legal_acceptance_required') {
      return message;
    }
    if (message == 'templates.connection_timeout' ||
        message == 'templates.server_timeout' ||
        message == 'templates.request_failed' ||
        message == 'templates.generation_failed') {
      return message;
    }
  }

  return 'templates.generation_failed';
}

String _statusLoadErrorText(AppLocalizations text, String raw) {
  final authMessage = mapCommonAuthFeedbackMessage(text, raw);
  if (authMessage != null) {
    return authMessage;
  }

  return switch (raw) {
    'auth.sign_in_required' => text.authSignInRequired,
    'templates.insufficient_balance' =>
      text.templateFlowInsufficientBalanceTitle,
    'templates.connection_timeout' => text.templateFlowNetworkError,
    'templates.server_timeout' => text.templateFlowServerError,
    'templates.request_failed' => text.templatesRequestFailedError,
    _ => text.templateFlowStartFailedError,
  };
}
