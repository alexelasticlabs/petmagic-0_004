import 'dart:async';

typedef RequestCancellationListener = void Function(Object? reason);

/// Framework-independent cancellation signal shared by application ports.
final class RequestCancellation {
  bool _isCancelled = false;
  Object? _reason;
  final Set<RequestCancellationListener> _listeners = {};
  final Completer<Object?> _completion = Completer<Object?>();

  bool get isCancelled => _isCancelled;

  Object? get reason => _reason;

  Future<Object?> get whenCancelled => _completion.future;

  /// Compatibility alias for callers migrating from Dio's `whenCancel`.
  Future<Object?> get whenCancel => whenCancelled;

  void cancel([Object? reason]) {
    if (_isCancelled) return;

    _isCancelled = true;
    _reason = reason;
    _completion.complete(reason);
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
