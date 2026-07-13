import 'dart:async';

import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/application/template_feed_invalidation.dart';
import 'package:petmagic_mobile/features/templates/application/template_scoped_invalidation_handler.dart';
import 'package:petmagic_mobile/features/templates/application/templates_state.dart';

/// Owns realtime connection state, debounce and invalidation routing.
final class TemplatesRealtimeCoordinator {
  TemplatesRealtimeCoordinator({
    required this.realtimeClient,
    required this.scopedInvalidationHandler,
    required this.readState,
    required this.isMounted,
    required this.isScreenVisible,
    required this.hasInternet,
    required this.requestVersion,
    required this.fetchCatalogVersion,
    required this.loadInitial,
    required this.loadTemplateOfTheDay,
  });

  static const _refreshDebounce = Duration(milliseconds: 350);

  final RealtimeClient realtimeClient;
  final TemplateScopedInvalidationHandler scopedInvalidationHandler;
  final TemplatesState Function() readState;
  final bool Function() isMounted;
  final bool Function() isScreenVisible;
  final bool Function() hasInternet;
  final int Function() requestVersion;
  final Future<int> Function() fetchCatalogVersion;
  final Future<void> Function({bool forceRefresh, int? knownCatalogVersion})
  loadInitial;
  final Future<void> Function(int requestVersion) loadTemplateOfTheDay;

  StreamSubscription<RealtimeEvent>? _subscription;
  Timer? _refreshTimer;
  bool _hasPendingRefresh = false;
  bool _isRefreshInFlight = false;
  bool _isConnected = false;

  void handleEvent(RealtimeEvent event) {
    if (!isScreenVisible() ||
        event.topic != RealtimeTopics.templatesFeedInvalidated) {
      return;
    }
    final invalidation = TemplateFeedInvalidation.fromPayload(event.payload);
    if (invalidation == null) return;

    if (invalidation.isFull) {
      _handleFullInvalidation();
    } else if (invalidation.isCategory) {
      _recordScopedInvalidation(invalidation);
      unawaited(scopedInvalidationHandler.refreshCategories());
    } else if (invalidation.isTemplateOfTheDay) {
      _recordScopedInvalidation(invalidation);
      unawaited(loadTemplateOfTheDay(requestVersion()));
    } else if (invalidation.isTemplate) {
      _recordScopedInvalidation(invalidation);
      unawaited(scopedInvalidationHandler.apply(invalidation));
    } else {
      _handleFullInvalidation();
    }
  }

  void _handleFullInvalidation() {
    final state = readState();
    if (state.isLoadingMore) {
      _recordBusyIntersection('pagination');
      _hasPendingRefresh = true;
      return;
    }
    if (state.isLoading || state.isRefreshing) {
      _recordBusyIntersection(
        _isRefreshInFlight ? 'realtime_refresh' : 'initial_refresh',
      );
      _hasPendingRefresh = _isRefreshInFlight;
      if (_hasPendingRefresh) _scheduleRefresh();
      return;
    }
    _hasPendingRefresh = true;
    _scheduleRefresh();
  }

  void resumePendingRefreshIfNeeded() {
    if (isScreenVisible() && _hasPendingRefresh) _scheduleRefresh();
  }

  void _scheduleRefresh() {
    if (!isScreenVisible() || _isFeedBusy) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer(_refreshDebounce, _flushPendingRefresh);
  }

  void _flushPendingRefresh() {
    _refreshTimer = null;
    if (!_hasPendingRefresh || _isFeedBusy) return;
    _hasPendingRefresh = false;
    unawaited(_refreshFromInvalidation());
  }

  Future<void> _refreshFromInvalidation() async {
    _isRefreshInFlight = true;
    try {
      final latestVersion = await fetchCatalogVersion();
      if (!isScreenVisible() || latestVersion <= readState().catalogVersion) {
        return;
      }
      await loadInitial(forceRefresh: true, knownCatalogVersion: latestVersion);
    } on Object {
      await loadInitial(forceRefresh: true);
    } finally {
      _isRefreshInFlight = false;
    }
  }

  bool get _isFeedBusy {
    final state = readState();
    return state.isLoading || state.isRefreshing || state.isLoadingMore;
  }

  Future<void> resume() async {
    if (!isScreenVisible() || !hasInternet()) return;
    _subscription ??= realtimeClient.events.listen(handleEvent);
    if (_isConnected) return;

    try {
      await realtimeClient.connect();
      if (!isMounted() || !isScreenVisible() || !hasInternet()) {
        unawaited(realtimeClient.disconnect());
        return;
      }
      _isConnected = true;
    } on Object {
      // Realtime is best-effort; templates feed still works via pull refresh.
    }
  }

  void pause() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (_isConnected) {
      unawaited(realtimeClient.disconnect());
      _isConnected = false;
    }
  }

  void cancelPendingRefresh() {
    _isRefreshInFlight = false;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _hasPendingRefresh = false;
  }

  void _recordBusyIntersection(String activeRequest) {
    AppLogger.debug(
      feature: 'Templates.Controller',
      operation: 'realtime_invalidation_during_active_request',
      message: 'Templates feed invalidation arrived during an active request.',
      context: {
        'activeRequest': activeRequest,
        'requestVersion': requestVersion(),
      },
    );
  }

  void _recordScopedInvalidation(TemplateFeedInvalidation invalidation) {
    AppLogger.debug(
      feature: 'Templates.Controller',
      operation: 'scoped_realtime_invalidation',
      message: 'Applying scoped templates feed invalidation.',
      context: {
        'scope': invalidation.scope,
        'templateId': invalidation.templateId,
        'category': invalidation.category,
        'mediaVersion': invalidation.mediaVersion,
        'templateType': invalidation.templateType,
        'isCritical': invalidation.isCritical,
        'isPubliclyVisible': invalidation.isPubliclyVisible,
        'reason': invalidation.reason,
      },
    );
  }
}
