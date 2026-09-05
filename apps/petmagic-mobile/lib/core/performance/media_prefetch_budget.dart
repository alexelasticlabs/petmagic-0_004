import 'dart:async';

/// A shared allowance for the response bodies of one speculative queue.
/// Metadata estimates can decide admission, but cannot enlarge this allowance.
class MediaPrefetchBudget {
  MediaPrefetchBudget({required this.maxBytes, required this.maxFileBytes})
    : assert(maxBytes > 0),
      assert(maxFileBytes > 0);

  final int maxBytes;
  final int maxFileBytes;
  int _receivedBytes = 0;
  bool _cancelled = false;
  final Set<void Function()> _cancelListeners = {};

  int get receivedBytes => _receivedBytes;
  int get remainingBytes => (maxBytes - _receivedBytes).clamp(0, maxBytes);
  bool get isCancelled => _cancelled;
  bool get canDownload => !_cancelled && remainingBytes > 0;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in _cancelListeners.toList()) {
      listener();
    }
    _cancelListeners.clear();
  }

  void _consume(int bytes) => _receivedBytes += bytes;
}

/// Mutable only to promote a speculative transfer when playback joins it.
/// Promotion keeps the same HTTP request and the normal global file cap.
class MediaDownloadConstraint {
  MediaDownloadConstraint(this.budget);

  final MediaPrefetchBudget budget;
  int _receivedBytes = 0;
  bool _requiredForPlayback = false;
  Completer<void>? _abort;
  void Function()? _cancelListener;

  Future<void> get abortTrigger {
    final existing = _abort;
    if (existing != null) return existing.future;
    final abort = _abort = Completer<void>();
    if (!_requiredForPlayback) {
      if (budget.isCancelled) {
        abort.complete();
      } else {
        final listener = _cancelListener = () {
          if (!abort.isCompleted) abort.complete();
        };
        budget._cancelListeners.add(listener);
      }
    }
    return abort.future;
  }

  void promote() {
    _requiredForPlayback = true;
    dispose();
  }

  void dispose() {
    final listener = _cancelListener;
    if (listener != null) budget._cancelListeners.remove(listener);
    _cancelListener = null;
  }

  void checkContentLength(int? length) {
    if (_requiredForPlayback) return;
    if (!budget.canDownload ||
        length != null &&
            (length > budget.remainingBytes || length > budget.maxFileBytes)) {
      throw const MediaPrefetchLimitException();
    }
  }

  void consume(int bytes) {
    if (_requiredForPlayback) return;
    _receivedBytes += bytes;
    // Account even the final rejected chunk. Socket buffering can receive one
    // chunk past the allowance, but that chunk is never written to the cache.
    budget._consume(bytes);
    if (budget.isCancelled ||
        budget.receivedBytes > budget.maxBytes ||
        _receivedBytes > budget.maxFileBytes) {
      throw const MediaPrefetchLimitException();
    }
  }
}

class MediaPrefetchLimitException implements Exception {
  const MediaPrefetchLimitException();

  @override
  String toString() => 'media_prefetch_allowance_exhausted_or_cancelled';
}
