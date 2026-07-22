import 'dart:async';

import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/features/templates/application/templates_feed_policy.dart';
import 'package:petmagic_mobile/features/templates/application/templates_feed_request_tracker.dart';
import 'package:petmagic_mobile/features/templates/application/templates_metadata_coordinator.dart';
import 'package:petmagic_mobile/features/templates/application/templates_preview_warmup_coordinator.dart';
import 'package:petmagic_mobile/features/templates/application/templates_realtime_coordinator.dart';
import 'package:petmagic_mobile/features/templates/application/templates_state.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';

/// Loads the first catalog page with memory/disk cache and stale guards.
final class TemplatesInitialFeedLoader {
  const TemplatesInitialFeedLoader({
    required this.repository,
    required this.readState,
    required this.writeState,
    required this.isMounted,
    required this.isScreenVisible,
    required this.requestTracker,
    required this.metadataCoordinator,
    required this.previewWarmupCoordinator,
    required this.realtimeCoordinator,
  });

  final TemplatesRepository Function() repository;
  final TemplatesState Function() readState;
  final void Function(TemplatesState state) writeState;
  final bool Function() isMounted;
  final bool Function() isScreenVisible;
  final TemplatesFeedRequestTracker requestTracker;
  final TemplatesMetadataCoordinator metadataCoordinator;
  final TemplatesPreviewWarmupCoordinator previewWarmupCoordinator;
  final TemplatesRealtimeCoordinator realtimeCoordinator;

  Future<void> loadInitial({
    bool forceRefresh = false,
    int? knownCatalogVersion,
  }) {
    final query = readState().query.copyWith(
      clearCursor: true,
      resetPage: true,
    );
    final queryKey = query.cacheKey;
    return requestTracker.runInitial(
      queryKey: queryKey,
      forceRefresh: forceRefresh,
      knownCatalogVersion: knownCatalogVersion,
      load: () => _load(
        query,
        queryKey,
        forceRefresh: forceRefresh,
        knownCatalogVersion: knownCatalogVersion,
      ),
    );
  }

  Future<void> _load(
    TemplatesQuery query,
    String queryKey, {
    required bool forceRefresh,
    int? knownCatalogVersion,
  }) async {
    final requestVersion = requestTracker.startRequest();
    previewWarmupCoordinator.invalidate('initial_request_started');
    if (metadataCoordinator.shouldLoadTemplateOfTheDay(
      forceRefresh: forceRefresh,
    )) {
      unawaited(metadataCoordinator.loadTemplateOfTheDay(requestVersion));
    }

    if (!forceRefresh &&
        await _restoreCachedPage(query, queryKey, requestVersion)) {
      return;
    }
    _showNetworkLoading(query, queryKey, forceRefresh: forceRefresh);

    try {
      final page = await repository().fetchFeed(query);
      if (!_isCurrent(requestVersion)) {
        _recordStale(requestVersion, 'fetch_feed_initial');
        return;
      }

      final current = readState();
      final updatedCache = TemplatesFeedPolicy.rememberPage(
        current.cachedPagesByQueryKey,
        queryKey,
        page,
      );
      writeState(
        current.copyWith(
          items: page.items,
          catalogVersion: knownCatalogVersion ?? current.catalogVersion,
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
        ),
      );
      unawaited(
        previewWarmupCoordinator.warmup(
          page.items,
          feedRequestVersion: requestVersion,
          preloadVersion: previewWarmupCoordinator.preloadVersion,
          queryKey: queryKey,
        ),
      );
      if (readState().categories.isEmpty || forceRefresh) {
        unawaited(metadataCoordinator.refreshCategories(requestVersion));
      }
    } on RequestCancelledException {
      _finishCancelled(requestVersion, 'fetch_feed_initial_cancelled');
    } on AppException catch (error) {
      _finishError(
        requestVersion,
        'fetch_feed_initial_app_error',
        error.message,
      );
    } catch (error) {
      _finishError(
        requestVersion,
        'fetch_feed_initial_error',
        'templates.request_failed',
      );
    } finally {
      realtimeCoordinator.resumePendingRefreshIfNeeded();
    }
  }

  Future<bool> _restoreCachedPage(
    TemplatesQuery query,
    String queryKey,
    int requestVersion,
  ) async {
    final memoryPage = readState().cachedPagesByQueryKey[queryKey];
    if (memoryPage != null) {
      _showCachedPage(
        query,
        queryKey,
        memoryPage,
        isRefreshing: false,
        remember: false,
      );
      if (readState().categories.isEmpty) {
        unawaited(metadataCoordinator.refreshCategories(requestVersion));
      }
      realtimeCoordinator.resumePendingRefreshIfNeeded();
      return true;
    }

    final current = readState();
    final hasStaleItems = current.itemsQueryKey != null
        ? current.itemsQueryKey != queryKey
        : current.items.isNotEmpty;
    if (hasStaleItems) {
      writeState(
        current.copyWith(
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
        ),
      );
    }

    final cached = await repository().readCachedFirstPage(query);
    if (!_isCurrent(requestVersion)) {
      _recordStale(requestVersion, 'read_cached_first_page');
      return true;
    }
    if (cached == null) return false;

    _showCachedPage(
      query,
      queryKey,
      cached,
      isRefreshing: true,
      remember: true,
    );
    if (readState().categories.isEmpty) {
      unawaited(metadataCoordinator.refreshCategories(requestVersion));
    }
    return false;
  }

  void _showCachedPage(
    TemplatesQuery query,
    String queryKey,
    TemplatesFeedPage page, {
    required bool isRefreshing,
    required bool remember,
  }) {
    final current = readState();
    final updatedCache = remember
        ? TemplatesFeedPolicy.rememberPage(
            current.cachedPagesByQueryKey,
            queryKey,
            page,
          )
        : current.cachedPagesByQueryKey;
    writeState(
      current.copyWith(
        query: query,
        items: page.items,
        currentPage: page.page,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        itemsQueryKey: queryKey,
        cachedPagesByQueryKey: updatedCache,
        hasMore: page.hasMore,
        loadedFromCache: true,
        isLoading: false,
        isRefreshing: isRefreshing,
        isLoadingMore: false,
        clearError: true,
      ),
    );
  }

  void _showNetworkLoading(
    TemplatesQuery query,
    String queryKey, {
    required bool forceRefresh,
  }) {
    final current = readState();
    final hasStaleItems = current.itemsQueryKey != null
        ? current.itemsQueryKey != queryKey
        : current.items.isNotEmpty;
    if (current.itemsQueryKey == queryKey && !forceRefresh) return;
    writeState(
      current.copyWith(
        query: query,
        items: hasStaleItems ? const [] : current.items,
        clearItemsQueryKey: hasStaleItems,
        isLoading: !forceRefresh && (hasStaleItems || current.items.isEmpty),
        isRefreshing: forceRefresh || current.items.isNotEmpty,
        isLoadingMore: false,
        loadedFromCache: false,
        clearError: true,
        currentPage: 1,
        clearNextCursor: true,
        hasMore: true,
      ),
    );
  }

  void _finishCancelled(int requestVersion, String operation) {
    if (!_isCurrent(requestVersion)) {
      _recordStale(requestVersion, operation);
      return;
    }
    writeState(
      readState().copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
      ),
    );
  }

  void _finishError(int requestVersion, String operation, String message) {
    if (!_isCurrent(requestVersion)) {
      _recordStale(requestVersion, operation);
      return;
    }
    writeState(
      readState().copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        errorMessage: message,
      ),
    );
  }

  bool _isCurrent(int version) => requestTracker.isCurrent(
    requestVersion: version,
    isMounted: isMounted(),
    isScreenVisible: isScreenVisible(),
  );

  void _recordStale(int version, String operation) {
    requestTracker.recordStale(requestVersion: version, operation: operation);
  }
}
