typedef AuthenticatedNotificationInitializationAction =
    Future<void> Function(int sessionEpoch);

/// Serializes notification initialization while preserving a request made for
/// a new authenticated session during an older in-flight initialization.
final class AuthenticatedNotificationInitializationRunner {
  bool _active = false;
  bool _disposed = false;
  bool _pending = false;
  int _sessionEpoch = 0;
  Future<void>? _drainFuture;

  bool canContinue(int sessionEpoch) {
    return !_disposed && _active && sessionEpoch == _sessionEpoch;
  }

  Future<void> activateAndRun(
    AuthenticatedNotificationInitializationAction action,
  ) {
    if (_disposed) {
      return Future<void>.value();
    }

    final isNewSession = !_active;
    if (isNewSession) {
      _active = true;
      _pending = true;
    }

    final inFlight = _drainFuture;
    if (inFlight != null) {
      return inFlight;
    }

    _pending = true;
    final task = _drain(action);
    _drainFuture = task;
    return task;
  }

  void deactivate() {
    _active = false;
    _pending = false;
    _sessionEpoch++;
  }

  void dispose() {
    _disposed = true;
    deactivate();
  }

  Future<void> _drain(
    AuthenticatedNotificationInitializationAction action,
  ) async {
    try {
      while (_pending && !_disposed && _active) {
        _pending = false;
        await action(_sessionEpoch);
      }
    } finally {
      _drainFuture = null;
    }
  }
}
