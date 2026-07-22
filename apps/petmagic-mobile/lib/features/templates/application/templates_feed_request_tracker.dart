import 'package:petmagic_mobile/core/logging/app_logger.dart';

/// Owns feed request identity, initial-load deduplication and stale telemetry.
final class TemplatesFeedRequestTracker {
  int _requestVersion = 0;
  int _staleResponsesDiscarded = 0;
  Future<void>? _inFlightInitialLoad;
  String? _inFlightInitialQueryKey;
  bool? _inFlightInitialForceRefresh;
  int? _inFlightInitialKnownCatalogVersion;

  int get requestVersion => _requestVersion;
  int get staleResponsesDiscarded => _staleResponsesDiscarded;

  int startRequest() => ++_requestVersion;

  void invalidate() {
    _requestVersion++;
    _inFlightInitialLoad = null;
    _inFlightInitialQueryKey = null;
    _inFlightInitialForceRefresh = null;
    _inFlightInitialKnownCatalogVersion = null;
  }

  Future<void> runInitial({
    required String queryKey,
    required bool forceRefresh,
    required int? knownCatalogVersion,
    required Future<void> Function() load,
  }) {
    final inFlight = _inFlightInitialLoad;
    if (inFlight != null &&
        _inFlightInitialQueryKey == queryKey &&
        _inFlightInitialForceRefresh == forceRefresh &&
        _inFlightInitialKnownCatalogVersion == knownCatalogVersion) {
      return inFlight;
    }

    late final Future<void> next;
    next = load().whenComplete(() {
      if (identical(_inFlightInitialLoad, next)) {
        _inFlightInitialLoad = null;
        _inFlightInitialQueryKey = null;
        _inFlightInitialForceRefresh = null;
        _inFlightInitialKnownCatalogVersion = null;
      }
    });
    _inFlightInitialLoad = next;
    _inFlightInitialQueryKey = queryKey;
    _inFlightInitialForceRefresh = forceRefresh;
    _inFlightInitialKnownCatalogVersion = knownCatalogVersion;
    return next;
  }

  bool isCurrent({
    required int requestVersion,
    required bool isMounted,
    required bool isScreenVisible,
  }) {
    return isMounted && isScreenVisible && requestVersion == _requestVersion;
  }

  void recordStale({required int requestVersion, required String operation}) {
    _staleResponsesDiscarded++;
    AppLogger.debug(
      feature: 'Templates.Controller',
      operation: 'stale_responses_discarded',
      message: 'Discarded stale templates feed response.',
      context: {
        'sourceOperation': operation,
        'discardedRequestVersion': requestVersion,
        'currentRequestVersion': _requestVersion,
        'count': _staleResponsesDiscarded,
      },
    );
  }
}
