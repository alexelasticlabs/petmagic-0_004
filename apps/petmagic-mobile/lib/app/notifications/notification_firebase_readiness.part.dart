part of 'notification_coordinator.dart';

extension _NotificationFirebaseReadiness on NotificationCoordinator {
  Future<bool> _waitForFirebaseReady(int sessionEpoch) async {
    if (!_appInitializer.enabled) {
      return false;
    }

    var attempt = 0;
    while (!_firebaseReady && _canContinueInitialization(sessionEpoch)) {
      try {
        if (await _appInitializer.ensureInitialized()) {
          return _canContinueInitialization(sessionEpoch);
        }
      } catch (error, stackTrace) {
        if (attempt == 0 || (attempt + 1) % 10 == 0) {
          _logNotificationFailure(
            'firebase_initialize_retry',
            error,
            stackTrace,
            context: {'attempt': attempt + 1},
          );
        }
      }

      if (!_canContinueInitialization(sessionEpoch)) {
        return false;
      }

      final delay = _firebaseRetryDelayForAttempt(attempt);
      attempt++;
      if (!await _waitForInitializationDelay(sessionEpoch, delay)) {
        return false;
      }
    }

    return _firebaseReady && _canContinueInitialization(sessionEpoch);
  }

  Future<bool> _waitForNotificationInitializationRetry(
    int sessionEpoch,
    int attempt,
  ) {
    return _waitForInitializationDelay(
      sessionEpoch,
      _firebaseRetryDelayForAttempt(attempt),
    );
  }

  Duration _firebaseRetryDelayForAttempt(int attempt) {
    final retryDelays =
        _NotificationCoordinatorBase._firebaseInitializationRetryDelays;
    final retryIndex = attempt < retryDelays.length
        ? attempt
        : retryDelays.length - 1;
    return retryDelays[retryIndex];
  }

  Future<bool> _waitForInitializationDelay(
    int sessionEpoch,
    Duration delay,
  ) async {
    if (!_canContinueInitialization(sessionEpoch)) {
      return false;
    }

    final waiter = Completer<void>();
    _firebaseReadinessWaiter = waiter;
    _firebaseReadinessTimer = Timer(delay, waiter.complete);
    await waiter.future;
    if (identical(_firebaseReadinessWaiter, waiter)) {
      _firebaseReadinessWaiter = null;
      _firebaseReadinessTimer = null;
    }
    return _canContinueInitialization(sessionEpoch);
  }

  void _cancelFirebaseReadinessWait() {
    _firebaseReadinessTimer?.cancel();
    _firebaseReadinessTimer = null;
    final waiter = _firebaseReadinessWaiter;
    _firebaseReadinessWaiter = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  bool _canContinueInitialization(int sessionEpoch) {
    return !_isDisposed &&
        _authSessionActive &&
        _initializationRunner.canContinue(sessionEpoch);
  }
}
