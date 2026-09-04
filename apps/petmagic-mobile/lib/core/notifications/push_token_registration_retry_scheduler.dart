import 'dart:async';

typedef PushTokenRegistrationRetryAction = Future<void> Function();
typedef PushTokenRegistrationRetryGuard = bool Function();
typedef PushTokenRegistrationRetryFailure =
    void Function(Object error, StackTrace stackTrace);

/// Schedules one token-registration retry at a time and keeps retrying with a
/// capped backoff until the action resets the scheduler or the lifecycle guard
/// becomes false.
final class PushTokenRegistrationRetryScheduler {
  PushTokenRegistrationRetryScheduler({
    required PushTokenRegistrationRetryGuard canRetry,
    PushTokenRegistrationRetryFailure? onFailure,
    List<Duration> retryDelays = const [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 5),
    ],
  }) : _canRetry = canRetry,
       _onFailure = onFailure,
       _retryDelays = List<Duration>.unmodifiable(retryDelays) {
    if (_retryDelays.isEmpty || _retryDelays.any((delay) => delay.isNegative)) {
      throw ArgumentError.value(
        retryDelays,
        'retryDelays',
        'Must contain at least one non-negative delay.',
      );
    }
  }

  final PushTokenRegistrationRetryGuard _canRetry;
  final PushTokenRegistrationRetryFailure? _onFailure;
  final List<Duration> _retryDelays;
  Timer? _timer;
  int _nextDelayIndex = 0;

  bool get hasPendingRetry => _timer?.isActive ?? false;

  void schedule(PushTokenRegistrationRetryAction action) {
    if (!_canRetry() || hasPendingRetry) {
      return;
    }

    final delay = _retryDelays[_nextDelayIndex];
    if (_nextDelayIndex < _retryDelays.length - 1) {
      _nextDelayIndex++;
    }

    _timer = Timer(delay, () {
      _timer = null;
      if (!_canRetry()) {
        return;
      }
      unawaited(_run(action));
    });
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _nextDelayIndex = 0;
  }

  void cancel() => reset();

  Future<void> _run(PushTokenRegistrationRetryAction action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      _onFailure?.call(error, stackTrace);
      schedule(action);
    }
  }
}
