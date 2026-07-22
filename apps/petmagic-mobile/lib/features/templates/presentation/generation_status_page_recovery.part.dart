part of 'generation_status_page.dart';

extension _GenerationStatusPageRecovery on _GenerationStatusPageState {
  Future<void> _showCachedOrMappedLoadError(
    GenerationRepository repository,
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
    } on RequestCancelledException {
      return;
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
    TemplateGenerationStatus.cancellationRequested ||
    TemplateGenerationStatus.finalizing => const Duration(seconds: 3),
    _ => const Duration(seconds: 5),
  };
}
