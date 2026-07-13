import 'package:petmagic_mobile/core/operations/request_cancellation.dart';

final class TemplateGenerationRequestTracker {
  RequestCancellation? _active;

  RequestCancellation start() {
    cancel();
    final next = RequestCancellation();
    _active = next;
    return next;
  }

  void cancel() {
    final active = _active;
    if (active != null && !active.isCancelled) {
      active.cancel('generation_request_cancelled');
    }
    _active = null;
  }

  void clear(RequestCancellation request) {
    if (identical(_active, request)) _active = null;
  }
}
