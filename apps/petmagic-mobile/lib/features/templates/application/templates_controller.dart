import 'dart:async';

// Public template catalog application state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/features/templates/application/template_scoped_invalidation_handler.dart';
import 'package:petmagic_mobile/features/templates/application/templates_filter_reducer.dart';
import 'package:petmagic_mobile/features/templates/application/templates_feed_policy.dart';
import 'package:petmagic_mobile/features/templates/application/templates_metadata_coordinator.dart';
import 'package:petmagic_mobile/features/templates/application/templates_preview_warmup_coordinator.dart';
import 'package:petmagic_mobile/features/templates/application/templates_realtime_coordinator.dart';
import 'package:petmagic_mobile/features/templates/application/templates_state.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';
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
  int _requestVersion = 0;
  int _staleResponsesDiscarded = 0;
  Future<void>? _inFlightInitialLoad;
  String? _inFlightInitialQueryKey;
  bool? _inFlightInitialForceRefresh;
  int? _inFlightInitialKnownCatalogVersion;
  bool _hasInternet = true;
  bool _isScreenVisible = true;

  int get staleResponsesDiscarded => _staleResponsesDiscarded;
  int get preloadCancellations => _previewWarmupCoordinator.cancellations;

  @override
  TemplatesState build() {
    _activeRepository = ref.read(templatesRepositoryProvider);
    _activeRealtimeClient = ref.read(realtimeClientProvider);
    _metadataCoordinator = TemplatesMetadataCoordinator(
      repository: () => _repository,
      readState: () => state,
      writeState: (next) => state = next,
      isMounted: () => ref.mounted,
      isScreenVisible: () => _isScreenVisible,
      currentRequestVersion: () => _requestVersion,
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
      requestVersion: () => _requestVersion,
      fetchCatalogVersion: () => _repository.fetchCatalogVersion(),
      loadInitial: loadInitial,
      loadTemplateOfTheDay: _metadataCoordinator.loadTemplateOfTheDay,
    );
    _previewWarmupCoordinator = TemplatesPreviewWarmupCoordinator(
      repository: () => _repository,
      readState: () => state,
      isMounted: () => ref.mounted,
      isScreenVisible: () => _isScreenVisible,
      requestVersion: () => _requestVersion,
      warmupThumbnail: (url, {mediaVersion}) => ref.read(
        templateThumbnailWarmupProvider,
      )(url, mediaVersion: mediaVersion),
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
    _requestVersion++;
    _inFlightInitialLoad = null;
    _inFlightInitialQueryKey = null;
    _inFlightInitialForceRefresh = null;
    _inFlightInitialKnownCatalogVersion = null;
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
  }) {
    final query = state.query.copyWith(clearCursor: true, resetPage: true);
    final queryKey = query.cacheKey;
    final inFlightInitialLoad = _inFlightInitialLoad;
    if (inFlightInitialLoad != null &&
        _inFlightInitialQueryKey == queryKey &&
        _inFlightInitialForceRefresh == forceRefresh &&
        _inFlightInitialKnownCatalogVersion == knownCatalogVersion) {
      return inFlightInitialLoad;
    }

    late final Future<void> initialLoad;
    initialLoad =
        _loadInitial(
          query,
          queryKey,
          forceRefresh: forceRefresh,
          knownCatalogVersion: knownCatalogVersion,
        ).whenComplete(() {
          if (identical(_inFlightInitialLoad, initialLoad)) {
            _inFlightInitialLoad = null;
            _inFlightInitialQueryKey = null;
            _inFlightInitialForceRefresh = null;
            _inFlightInitialKnownCatalogVersion = null;
          }
        });

    _inFlightInitialLoad = initialLoad;
    _inFlightInitialQueryKey = queryKey;
    _inFlightInitialForceRefresh = forceRefresh;
    _inFlightInitialKnownCatalogVersion = knownCatalogVersion;

    return initialLoad;
  }

  Future<void> _loadInitial(
    TemplatesQuery query,
    String queryKey, {
    required bool forceRefresh,
    int? knownCatalogVersion,
  }) async {
    final requestVersion = ++_requestVersion;
    _previewWarmupCoordinator.invalidate('initial_request_started');
    if (_metadataCoordinator.shouldLoadTemplateOfTheDay(
      forceRefresh: forceRefresh,
    )) {
      unawaited(_metadataCoordinator.loadTemplateOfTheDay(requestVersion));
    }

    if (!forceRefresh) {
      final inMemoryCached = state.cachedPagesByQueryKey[queryKey];
      if (inMemoryCached != null) {
        state = state.copyWith(
          query: query,
          items: inMemoryCached.items,
          currentPage: inMemoryCached.page,
          nextCursor: inMemoryCached.nextCursor,
          clearNextCursor: inMemoryCached.nextCursor == null,
          itemsQueryKey: queryKey,
          hasMore: inMemoryCached.hasMore,
          loadedFromCache: true,
          isLoading: false,
          isRefreshing: false,
          isLoadingMore: false,
          clearError: true,
        );
        if (state.categories.isEmpty) {
          unawaited(_metadataCoordinator.refreshCategories(requestVersion));
        }
        _realtimeCoordinator.resumePendingRefreshIfNeeded();
        return;
      }

      final hasStaleVisibleItemsBeforeCache = state.itemsQueryKey != null
          ? state.itemsQueryKey != queryKey
          : state.items.isNotEmpty;
      if (hasStaleVisibleItemsBeforeCache) {
        state = state.copyWith(
          query: query,
          items: const [],
          clearItemsQueryKey: true,
          isLoading: true,
          isRefreshing: false,
          isLoadingMore: false,
          loadedFromCache: false,
          clearError: true,
          currentPage: 1,
          clearNextCursor: true,
          hasMore: true,
        );
      }

      final cached = await _repository.readCachedFirstPage(query);
      if (!_isCurrentFeedRequest(requestVersion)) {
        _recordStaleResponseDiscarded(
          requestVersion: requestVersion,
          operation: 'read_cached_first_page',
        );
        return;
      }

      if (cached != null) {
        final updatedCache = TemplatesFeedPolicy.rememberPage(
          state.cachedPagesByQueryKey,
          queryKey,
          cached,
        );
        state = state.copyWith(
          query: query,
          items: cached.items,
          currentPage: cached.page,
          nextCursor: cached.nextCursor,
          clearNextCursor: cached.nextCursor == null,
          itemsQueryKey: queryKey,
          cachedPagesByQueryKey: updatedCache,
          hasMore: cached.hasMore,
          loadedFromCache: true,
          isLoading: false,
          isRefreshing: true,
          isLoadingMore: false,
          clearError: true,
        );
        if (state.categories.isEmpty) {
          unawaited(_metadataCoordinator.refreshCategories(requestVersion));
        }
      }
    }

    final isStaleVisibleItems = state.itemsQueryKey != null
        ? state.itemsQueryKey != queryKey
        : state.items.isNotEmpty;

    if (state.itemsQueryKey != queryKey || forceRefresh) {
      state = state.copyWith(
        query: query,
        items: isStaleVisibleItems ? const [] : state.items,
        clearItemsQueryKey: isStaleVisibleItems,
        isLoading:
            !forceRefresh && (isStaleVisibleItems || state.items.isEmpty),
        isRefreshing: forceRefresh || state.items.isNotEmpty,
        isLoadingMore: false,
        loadedFromCache: false,
        clearError: true,
        currentPage: 1,
        clearNextCursor: true,
        hasMore: true,
      );
    }

    try {
      final page = await _repository.fetchFeed(query);
      if (!_isCurrentFeedRequest(requestVersion)) {
        _recordStaleResponseDiscarded(
          requestVersion: requestVersion,
          operation: 'fetch_feed_initial',
        );
        return;
      }

      final updatedCache = TemplatesFeedPolicy.rememberPage(
        state.cachedPagesByQueryKey,
        queryKey,
        page,
      );
      state = state.copyWith(
        items: page.items,
        catalogVersion: knownCatalogVersion ?? state.catalogVersion,
        currentPage: page.page,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        itemsQueryKey: queryKey,
        cachedPagesByQueryKey: updatedCache,
        hasMore: page.hasMore,
        loadedFromCache: false,
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        clearError: true,
      );
      unawaited(
        _previewWarmupCoordinator.warmup(
          page.items,
          feedRequestVersion: requestVersion,
          preloadVersion: _previewWarmupCoordinator.preloadVersion,
          queryKey: queryKey,
        ),
      );
      if (state.categories.isEmpty || forceRefresh) {
        unawaited(_metadataCoordinator.refreshCategories(requestVersion));
      }
    } on RequestCancelledException {
      if (!_isCurrentFeedRequest(requestVersion)) {
        _recordStaleResponseDiscarded(
          requestVersion: requestVersion,
          operation: 'fetch_feed_initial_cancelled',
        );
        return;
      }
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
      );
    } on AppException catch (error) {
      if (!_isCurrentFeedRequest(requestVersion)) {
        _recordStaleResponseDiscarded(
          requestVersion: requestVersion,
          operation: 'fetch_feed_initial_app_error',
        );
        return;
      }
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        errorMessage: error.message,
      );
    } catch (error) {
      if (!_isCurrentFeedRequest(requestVersion)) {
        _recordStaleResponseDiscarded(
          requestVersion: requestVersion,
          operation: 'fetch_feed_initial_error',
        );
        return;
      }
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        errorMessage: 'templates.request_failed',
      );
    } finally {
      _realtimeCoordinator.resumePendingRefreshIfNeeded();
    }
  }

  Future<void> loadMore() async {
    final currentNextCursor = state.nextCursor;
    if (state.isLoadingMore ||
        state.isLoading ||
        !state.hasMore ||
        currentNextCursor == null ||
        currentNextCursor.trim().isEmpty) {
      return;
    }

    final requestVersion = _requestVersion;
    final queryKey = state.query.copyWith(resetPage: true).cacheKey;
    final query = state.query.copyWith(
      page: state.currentPage + 1,
      cursor: currentNextCursor,
    );
    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final page = await _repository.fetchFeed(query);
      final isCurrentQuery =
          state.query.copyWith(resetPage: true).cacheKey == queryKey &&
          state.itemsQueryKey == queryKey &&
          state.nextCursor == currentNextCursor;
      if (!_isCurrentFeedRequest(requestVersion) || !isCurrentQuery) {
        _recordStaleResponseDiscarded(
          requestVersion: requestVersion,
          operation: 'fetch_feed_pagination',
        );
        return;
      }

      final existingIds = state.items.map((item) => item.templateId).toSet();
      final appended = page.items.where(
        (item) => !existingIds.contains(item.templateId),
      );
      final mergedItems = [...state.items, ...appended];
      final hasAdvancedCursor =
          page.nextCursor != null && page.nextCursor != currentNextCursor;
      final hasMore = page.hasMore && hasAdvancedCursor;
      final cachedPage = TemplatesFeedPage(
        items: mergedItems,
        nextCursor: page.nextCursor,
        hasMore: hasMore,
        page: page.page,
      );
      final updatedCache = TemplatesFeedPolicy.rememberPage(
        state.cachedPagesByQueryKey,
        queryKey,
        cachedPage,
      );

      state = state.copyWith(
        items: mergedItems,
        currentPage: page.page,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        itemsQueryKey: queryKey,
        cachedPagesByQueryKey: updatedCache,
        hasMore: hasMore,
        isLoadingMore: false,
        clearError: true,
      );
    } on RequestCancelledException {
      if (!_isCurrentFeedRequest(requestVersion)) {
        _recordStaleResponseDiscarded(
          requestVersion: requestVersion,
          operation: 'fetch_feed_pagination_cancelled',
        );
        return;
      }

      state = state.copyWith(isLoadingMore: false);
    } on AppException catch (error) {
      if (!_isCurrentFeedRequest(requestVersion)) {
        _recordStaleResponseDiscarded(
          requestVersion: requestVersion,
          operation: 'fetch_feed_pagination_app_error',
        );
        return;
      }

      state = state.copyWith(isLoadingMore: false, errorMessage: error.message);
    } catch (error) {
      if (!_isCurrentFeedRequest(requestVersion)) {
        _recordStaleResponseDiscarded(
          requestVersion: requestVersion,
          operation: 'fetch_feed_pagination_error',
        );
        return;
      }

      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: 'templates.request_failed',
      );
    } finally {
      _realtimeCoordinator.resumePendingRefreshIfNeeded();
    }
  }

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

  bool _isCurrentFeedRequest(int requestVersion) {
    return ref.mounted && _isScreenVisible && requestVersion == _requestVersion;
  }

  void _recordStaleResponseDiscarded({
    required int requestVersion,
    required String operation,
  }) {
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

// Public templates application controller.
