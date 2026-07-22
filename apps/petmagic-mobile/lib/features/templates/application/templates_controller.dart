import 'dart:async';

// Public template catalog application state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/features/templates/application/template_scoped_invalidation_handler.dart';
import 'package:petmagic_mobile/features/templates/application/templates_filter_reducer.dart';
import 'package:petmagic_mobile/features/templates/application/templates_feed_request_tracker.dart';
import 'package:petmagic_mobile/features/templates/application/templates_initial_feed_loader.dart';
import 'package:petmagic_mobile/features/templates/application/templates_metadata_coordinator.dart';
import 'package:petmagic_mobile/features/templates/application/templates_pagination_loader.dart';
import 'package:petmagic_mobile/features/templates/application/templates_preview_warmup_coordinator.dart';
import 'package:petmagic_mobile/features/templates/application/templates_realtime_coordinator.dart';
import 'package:petmagic_mobile/features/templates/application/templates_state.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

export 'templates_state.dart';

final templatesControllerProvider =
    NotifierProvider<TemplatesController, TemplatesState>(
      TemplatesController.new,
    );

final templateThumbnailWarmupProvider =
    Provider<Future<void> Function(String, {int? mediaVersion})>((ref) {
      return (url, {mediaVersion}) async {
        await TemplateMediaCache.fetchThumbnailFile(
          url,
          mediaVersion: mediaVersion,
        );
      };
    });

class TemplatesController extends Notifier<TemplatesState> {
  TemplatesRepository get _repository =>
      _activeRepository ?? ref.read(templatesRepositoryProvider);
  TemplatesRepository? _activeRepository;
  RealtimeClient? _activeRealtimeClient;
  late final TemplatesRealtimeCoordinator _realtimeCoordinator;
  late final TemplatesPreviewWarmupCoordinator _previewWarmupCoordinator;
  late final TemplatesMetadataCoordinator _metadataCoordinator;
  late final TemplatesFeedRequestTracker _requestTracker;
  late final TemplatesInitialFeedLoader _initialFeedLoader;
  late final TemplatesPaginationLoader _paginationLoader;
  bool _hasInternet = true;
  bool _isScreenVisible = true;

  int get staleResponsesDiscarded => _requestTracker.staleResponsesDiscarded;
  int get preloadCancellations => _previewWarmupCoordinator.cancellations;

  @override
  TemplatesState build() {
    _activeRepository = ref.read(templatesRepositoryProvider);
    _activeRealtimeClient = ref.read(realtimeClientProvider);
    _requestTracker = TemplatesFeedRequestTracker();
    _metadataCoordinator = TemplatesMetadataCoordinator(
      repository: () => _repository,
      readState: () => state,
      writeState: (next) => state = next,
      isMounted: () => ref.mounted,
      isScreenVisible: () => _isScreenVisible,
      currentRequestVersion: () => _requestTracker.requestVersion,
      warmupThumbnail: (url) => ref.read(templateThumbnailWarmupProvider)(url),
    );
    final scopedInvalidationHandler = TemplateScopedInvalidationHandler(
      repository: () => _repository,
      readState: () => state,
      writeState: (next) => state = next,
      isMounted: () => ref.mounted,
      isScreenVisible: () => _isScreenVisible,
    );
    _realtimeCoordinator = TemplatesRealtimeCoordinator(
      realtimeClient: _activeRealtimeClient!,
      scopedInvalidationHandler: scopedInvalidationHandler,
      readState: () => state,
      isMounted: () => ref.mounted,
      isScreenVisible: () => _isScreenVisible,
      hasInternet: () => _hasInternet,
      requestVersion: () => _requestTracker.requestVersion,
      fetchCatalogVersion: () => _repository.fetchCatalogVersion(),
      loadInitial: loadInitial,
      loadTemplateOfTheDay: _metadataCoordinator.loadTemplateOfTheDay,
    );
    _previewWarmupCoordinator = TemplatesPreviewWarmupCoordinator(
      repository: () => _repository,
      readState: () => state,
      isMounted: () => ref.mounted,
      isScreenVisible: () => _isScreenVisible,
      requestVersion: () => _requestTracker.requestVersion,
      warmupThumbnail: (url, {mediaVersion}) => ref.read(
        templateThumbnailWarmupProvider,
      )(url, mediaVersion: mediaVersion),
    );
    _initialFeedLoader = TemplatesInitialFeedLoader(
      repository: () => _repository,
      readState: () => state,
      writeState: (next) => state = next,
      isMounted: () => ref.mounted,
      isScreenVisible: () => _isScreenVisible,
      requestTracker: _requestTracker,
      metadataCoordinator: _metadataCoordinator,
      previewWarmupCoordinator: _previewWarmupCoordinator,
      realtimeCoordinator: _realtimeCoordinator,
    );
    _paginationLoader = TemplatesPaginationLoader(
      repository: () => _repository,
      readState: () => state,
      writeState: (next) => state = next,
      isMounted: () => ref.mounted,
      isScreenVisible: () => _isScreenVisible,
      requestTracker: _requestTracker,
      realtimeCoordinator: _realtimeCoordinator,
    );
    _hasInternet = ref.read(networkStatusControllerProvider).hasInternet;
    ref.listen<bool>(
      networkStatusControllerProvider.select((state) => state.hasInternet),
      (_, hasInternet) => _handleNetworkStatusChanged(hasInternet),
    );
    unawaited(_realtimeCoordinator.resume());
    ref.onDispose(() {
      _invalidateActiveFeedWork(
        clearLoadingState: false,
        reason: 'dispose',
        repository: _activeRepository,
      );
      _realtimeCoordinator.pause();
    });
    return const TemplatesState();
  }

  void _handleNetworkStatusChanged(bool hasInternet) {
    if (_hasInternet == hasInternet) {
      return;
    }

    _hasInternet = hasInternet;
    if (!hasInternet) {
      _realtimeCoordinator.pause();
      _invalidateActiveFeedWork(
        clearLoadingState: true,
        reason: 'network_offline',
      );
      return;
    }

    if (!_isScreenVisible) {
      return;
    }

    unawaited(_realtimeCoordinator.resume());
    _realtimeCoordinator.resumePendingRefreshIfNeeded();
  }

  void setScreenVisible(bool visible) {
    if (_isScreenVisible == visible) {
      return;
    }

    _isScreenVisible = visible;
    if (visible) {
      unawaited(_realtimeCoordinator.resume());
      _realtimeCoordinator.resumePendingRefreshIfNeeded();
      return;
    }

    _cancelActiveFeedWork();
    _realtimeCoordinator.pause();
  }

  void _cancelActiveFeedWork() {
    _invalidateActiveFeedWork(clearLoadingState: true, reason: 'screen_hidden');
  }

  void _invalidateActiveFeedWork({
    required bool clearLoadingState,
    required String reason,
    TemplatesRepository? repository,
  }) {
    _requestTracker.invalidate();
    _realtimeCoordinator.cancelPendingRefresh();
    final resolvedRepository = repository ?? _repository;
    final cancelledPreviewPreloads = _previewWarmupCoordinator.invalidate(
      reason,
      activeRepository: resolvedRepository,
    );
    resolvedRepository.cancelPendingFeedRequest();
    if (!cancelledPreviewPreloads) {
      resolvedRepository.cancelPendingMetadataRequests();
    }
    if (!clearLoadingState || !ref.mounted) {
      return;
    }

    if (state.isLoading ||
        state.isRefreshing ||
        state.isLoadingMore ||
        state.isTemplateOfTheDayLoading) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        isTemplateOfTheDayLoading: false,
      );
    }
  }

  Future<void> loadInitial({
    bool forceRefresh = false,
    int? knownCatalogVersion,
  }) => _initialFeedLoader.loadInitial(
    forceRefresh: forceRefresh,
    knownCatalogVersion: knownCatalogVersion,
  );

  Future<void> loadMore() => _paginationLoader.loadMore();
  Future<void> refresh() => loadInitial(forceRefresh: true);

  void setType(TemplateType? type) {
    final next = TemplatesFilterReducer.forType(state, type);
    if (next == null) return;
    state = next;
    loadInitial();
  }

  void setCategory(String? category) {
    final next = TemplatesFilterReducer.forCategory(state, category);
    if (next == null) return;
    state = next;
    loadInitial();
  }

  void setSearch(String value) {
    final next = TemplatesFilterReducer.forSearch(state, value);
    if (next == null) return;
    state = next;
    loadInitial();
  }
}

// Public templates application controller.
