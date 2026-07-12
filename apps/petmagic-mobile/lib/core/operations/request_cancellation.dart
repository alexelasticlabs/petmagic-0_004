typedef RequestCancellationListener = void Function(Object? reason);

/// Framework-independent cancellation signal shared by application ports.
final class RequestCancellation {
  bool _isCancelled = false;
  Object? _reason;
  final Set<RequestCancellationListener> _listeners = {};

  bool get isCancelled => _isCancelled;

  Object? get reason => _reason;

  void cancel([Object? reason]) {
    if (_isCancelled) return;

    _isCancelled = true;
    _reason = reason;
    final listeners = List<RequestCancellationListener>.of(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener(reason);
    }
  }

  void addListener(RequestCancellationListener listener) {
    if (_isCancelled) {
      listener(_reason);
      return;
    }
    _listeners.add(listener);
  }

  void removeListener(RequestCancellationListener listener) {
    _listeners.remove(listener);
  }
}
