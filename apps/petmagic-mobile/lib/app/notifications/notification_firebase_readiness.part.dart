part of 'notification_coordinator.dart';

extension _NotificationFirebaseReadiness on NotificationCoordinator {
  Future<bool> _waitForFirebaseReady() async {
    if (_firebaseReady) {
      return true;
    }

    final deadline = DateTime.now().add(
      _NotificationCoordinatorBase._firebaseReadinessTimeout,
    );
    while (!_firebaseReady && _canContinueInitialization()) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        return false;
      }
      final delay =
          remaining <
              _NotificationCoordinatorBase._firebaseReadinessPollInterval
          ? remaining
          : _NotificationCoordinatorBase._firebaseReadinessPollInterval;
      final waiter = Completer<void>();
      _firebaseReadinessWaiter = waiter;
      _firebaseReadinessTimer = Timer(delay, waiter.complete);
      await waiter.future;
      if (identical(_firebaseReadinessWaiter, waiter)) {
        _firebaseReadinessWaiter = null;
        _firebaseReadinessTimer = null;
      }
    }

    return _firebaseReady && _canContinueInitialization();
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

  bool _canContinueInitialization() => !_isDisposed && _authSessionActive;
}
