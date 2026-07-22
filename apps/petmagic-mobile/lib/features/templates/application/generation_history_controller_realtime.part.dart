part of 'generation_history_controller.dart';

mixin _GenerationHistoryControllerRealtime on _GenerationHistoryControllerBase {
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (!ref.mounted || !_isAuthenticated || !_isScreenVisible) {
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
    final eventType = _readRealtimeString(payload['eventType'], maxLength: 64);
    if (eventType != null &&
        eventType.isNotEmpty &&
        eventType != 'generation.status_changed') {
      return null;
    }

    return _readRealtimeString(payload['generationId']);
  }

  String? _readRealtimeString(Object? value, {int maxLength = 128}) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > maxLength) {
      return null;
    }

    return normalized;
  }

  Future<void> _refetchRealtimeGeneration(String generationId) async {
    if (!ref.mounted ||
        !_isAuthenticated ||
        !_isScreenVisible ||
        !_hasInternet) {
      return;
    }

    if (_activeRealtimeRefetchRequestCancellations.containsKey(generationId)) {
      return;
    }

    final cancelToken = RequestCancellation();
    _activeRealtimeRefetchRequestCancellations[generationId] = cancelToken;
    try {
      final generation = await _repository.fetchGeneration(
        generationId,
        cancelToken: cancelToken,
      );
      if (!ref.mounted ||
          !_isAuthenticated ||
          !_isScreenVisible ||
          !_hasInternet ||
          cancelToken.isCancelled) {
        return;
      }

      await _mergeExternalGeneration(
        generation,
        refreshUnreadBadge: true,
        requireScreenVisible: true,
      );
    } on RequestCancelledException {
      return;
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.GenerationHistory',
        operation: 'realtime_refetch',
        message: 'Generation history realtime refetch failed',
        context: {'generation_id': generationId},
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (identical(
        _activeRealtimeRefetchRequestCancellations[generationId],
        cancelToken,
      )) {
        _activeRealtimeRefetchRequestCancellations.remove(generationId);
      }
    }
  }

  @override
  Future<void> _resumeRealtimeIfNeeded() async {
    if (!ref.mounted ||
        !_isAuthenticated ||
        !_isScreenVisible ||
        !_hasInternet) {
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
          !_isAuthenticated ||
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

  @override
  void _pauseRealtime() {
    _cancelActiveRealtimeRefetches('generation_history_realtime_paused');
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

  @override
  void _cancelActiveRealtimeRefetches(String reason) {
    final cancelTokens = _activeRealtimeRefetchRequestCancellations.values
        .toList(growable: false);
    _activeRealtimeRefetchRequestCancellations.clear();
    for (final cancelToken in cancelTokens) {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel(reason);
      }
    }
  }
}
