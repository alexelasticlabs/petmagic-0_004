part of 'generation_history_controller.dart';

mixin _GenerationHistoryControllerSync
    on _GenerationHistoryControllerBase, _GenerationHistoryControllerMutations {
  @override
  Future<void> _load({
    GenerationHistoryFilter? filter,
    bool refresh = false,
  }) async {
    if (!_isAuthenticated) {
      return;
    }

    final requestedFilter = filter ?? state.filter;
    if (_isLoadInFlight) {
      if (!refresh && requestedFilter == state.filter && state.isLoading) {
        return;
      }

      _pendingLoadRequest = _GenerationHistoryLoadRequest(
        filter: requestedFilter,
        refresh: refresh,
      );
      final completer = _pendingLoadCompleter ??= Completer<void>();
      return completer.future;
    }

    _isLoadInFlight = true;
    final loadEpoch = ++_loadEpoch;
    _cancelActiveLoadMore('generation_history_initial_load_started');
    RequestCancellation? loadRequestCancellation;
    try {
      await _resumeRealtimeIfNeeded();
      if (!ref.mounted || !_isAuthenticated) {
        return;
      }

      final nextFilter = requestedFilter;
      final wasOfflineBeforeLoad = state.syncFailed;
      final deletedGenerationIds = await _galleryStore
          .loadDeletedGenerationIds();
      final localReadyRecords = await _galleryStore.loadLocalReadyItems();
      _locallyDeletedGenerationIds = Set<String>.from(deletedGenerationIds);
      if (state.isLoading && !refresh && nextFilter == state.filter) {
        return;
      }

      final cachedItems = state.cachedItemsByFilter[nextFilter];
      if (!refresh && cachedItems != null) {
        final localizedCachedItems = _decorateWithLocalMedia(
          cachedItems,
          deletedGenerationIds,
          localReadyRecords,
        );
        state = state.copyWith(
          filter: nextFilter,
          items: localizedCachedItems,
          isLoading: false,
          clearNextCursor: true,
          hasMore: false,
          clearLoadMoreError: true,
          clearError: true,
        );
        return;
      }

      List<TemplateGenerationResult>? persistedItems;
      if (!refresh) {
        persistedItems = await _repository.readCachedGenerations(
          status: nextFilter.apiStatus,
        );
        if (!ref.mounted || !_isAuthenticated) {
          return;
        }
      }

      final seedItems = refresh
          ? (cachedItems ?? state.items)
          : (persistedItems ?? const []);
      final localizedSeedItems = _decorateWithLocalMedia(
        seedItems,
        deletedGenerationIds,
        localReadyRecords,
      );

      state = state.copyWith(
        items: localizedSeedItems,
        filter: nextFilter,
        isLoading: true,
        isLoadingMore: false,
        syncFailed: false,
        clearNextCursor: true,
        hasMore: false,
        clearLoadMoreError: true,
        clearError: true,
      );

      if (persistedItems != null) {
        final persistedCache =
            Map<GenerationHistoryFilter, List<TemplateGenerationResult>>.from(
                state.cachedItemsByFilter,
              )
              ..[nextFilter] = _decorateWithLocalMedia(
                persistedItems,
                deletedGenerationIds,
                localReadyRecords,
              );
        state = state.copyWith(cachedItemsByFilter: persistedCache);
      }

      loadRequestCancellation = _startLoadRequestCancellation();
      try {
        if (refresh) {
          await _fetchUnreadGenerationCountBestEffort(loadRequestCancellation);
        }
        if (loadRequestCancellation.isCancelled) {
          _completeCancelledLoad();
          return;
        }

        await _flushPendingServerDeletes();
        if (!ref.mounted ||
            !_isAuthenticated ||
            loadRequestCancellation.isCancelled) {
          _completeCancelledLoad();
          return;
        }

        final page = await _repository.fetchGenerationPage(
          status: nextFilter.apiStatus,
          take: 50,
          cancelToken: loadRequestCancellation,
        );
        final remoteItems = page.items;
        final items = _decorateWithLocalMedia(
          remoteItems,
          deletedGenerationIds,
          localReadyRecords,
        );
        final unreadCount = page.serverTimeUtc == null
            ? await _fetchUnreadGenerationCountBestEffort(
                loadRequestCancellation,
              )
            : page.unreadCount;
        _reconcileLocallyReadIds(remoteItems);
        _locallyDeletedUnreadGenerationIds =
            await _loadDeletedUnreadGenerationIds(
              deletedGenerationIds: deletedGenerationIds,
              remoteItems: remoteItems,
            );
        if (!ref.mounted || !_isAuthenticated || loadEpoch != _loadEpoch) {
          return;
        }

        final visibleUnreadCount = unreadCount == null
            ? state.unreadCount
            : _visibleUnreadCount(unreadCount);
        if (!ref.mounted || !_isAuthenticated) {
          return;
        }

        if (loadRequestCancellation.isCancelled ||
            nextFilter != state.filter ||
            loadEpoch != _loadEpoch) {
          _completeCancelledLoad();
          return;
        }

        final updatedCache =
            Map<GenerationHistoryFilter, List<TemplateGenerationResult>>.from(
              state.cachedItemsByFilter,
            )..[nextFilter] = items;
        final nowUtc = DateTime.now().toUtc();
        state = state.copyWith(
          items: items,
          unreadCount: visibleUnreadCount,
          isLoading: false,
          isLoadingMore: false,
          syncFailed: false,
          showOfflineBanner: wasOfflineBeforeLoad && items.isNotEmpty,
          isConnectionRecovered: wasOfflineBeforeLoad && items.isNotEmpty,
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          hasMore: page.hasMore,
          clearLoadMoreError: true,
          lastSyncedAtUtc: nowUtc,
          cachedItemsByFilter: updatedCache,
          clearError: true,
        );
        _registerAutoRefreshSuccess();

        if (wasOfflineBeforeLoad && items.isNotEmpty) {
          _scheduleOfflineBannerHide();
        }
        unawaited(_syncCompletedMedia(items));
      } catch (error) {
        if (_isCancelledRequest(error)) {
          _completeCancelledLoad();
          return;
        }
        _registerAutoRefreshFailure();
        if (state.items.isNotEmpty) {
          _offlineBannerTimer?.cancel();
          _offlineBannerTimer = null;
          state = state.copyWith(
            isLoading: false,
            syncFailed: true,
            showOfflineBanner: true,
            isConnectionRecovered: false,
          );
          return;
        }

        _offlineBannerTimer?.cancel();
        _offlineBannerTimer = null;
        state = state.copyWith(
          isLoading: false,
          errorMessage: _historyLoadErrorMessage(error),
        );
      }
    } finally {
      final activeLoadRequestCancellation = loadRequestCancellation;
      if (activeLoadRequestCancellation != null) {
        _clearActiveLoadRequestCancellation(activeLoadRequestCancellation);
      }
      _isLoadInFlight = false;
      _drainPendingLoad();
    }
  }

  @override
  Future<void> _loadMore() async {
    if (!ref.mounted ||
        !_isAuthenticated ||
        !_isScreenVisible ||
        _isLoadInFlight ||
        _isLoadMoreInFlight ||
        state.isLoading ||
        !state.hasMore ||
        state.nextCursor == null) {
      return;
    }

    _isLoadMoreInFlight = true;
    final requestFilter = state.filter;
    final requestCursor = state.nextCursor!;
    final requestEpoch = _loadEpoch;
    final loadRequestCancellation = _startLoadMoreRequestCancellation();
    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);

    try {
      final deletedGenerationIds = await _galleryStore
          .loadDeletedGenerationIds();
      final localReadyRecords = await _galleryStore.loadLocalReadyItems();
      _locallyDeletedGenerationIds = Set<String>.from(deletedGenerationIds);

      if (!ref.mounted ||
          !_isAuthenticated ||
          loadRequestCancellation.isCancelled) {
        return;
      }

      final page = await _repository.fetchGenerationPage(
        status: requestFilter.apiStatus,
        cursor: requestCursor,
        take: 50,
        cancelToken: loadRequestCancellation,
      );
      if (!ref.mounted ||
          !_isAuthenticated ||
          loadRequestCancellation.isCancelled ||
          requestEpoch != _loadEpoch ||
          requestFilter != state.filter ||
          requestCursor != state.nextCursor) {
        return;
      }

      final decoratedItems = _decorateWithLocalMedia(
        page.items,
        deletedGenerationIds,
        localReadyRecords,
      );
      final mergedItems = _appendUniqueGenerationItems(
        state.items,
        decoratedItems,
      );
      _reconcileLocallyReadIds(page.items);
      final updatedCache =
          Map<GenerationHistoryFilter, List<TemplateGenerationResult>>.from(
            state.cachedItemsByFilter,
          )..[requestFilter] = mergedItems;
      final visibleUnreadCount = page.serverTimeUtc == null
          ? state.unreadCount
          : _visibleUnreadCount(page.unreadCount);
      final hasAdvancedCursor =
          page.nextCursor != null && page.nextCursor != requestCursor;
      final hasMore = page.hasMore && hasAdvancedCursor;

      state = state.copyWith(
        items: mergedItems,
        unreadCount: visibleUnreadCount,
        isLoadingMore: false,
        syncFailed: false,
        nextCursor: hasMore ? page.nextCursor : null,
        clearNextCursor: !hasMore,
        hasMore: hasMore,
        cachedItemsByFilter: updatedCache,
        clearLoadMoreError: true,
      );
      unawaited(_syncCompletedMedia(decoratedItems));
    } catch (error) {
      if (_isCancelledRequest(error) || loadRequestCancellation.isCancelled) {
        return;
      }
      if (!ref.mounted ||
          !_isAuthenticated ||
          requestEpoch != _loadEpoch ||
          requestFilter != state.filter ||
          requestCursor != state.nextCursor) {
        return;
      }

      state = state.copyWith(
        isLoadingMore: false,
        loadMoreError: _historyLoadErrorMessage(error),
      );
    } finally {
      if (identical(
        _activeLoadMoreRequestCancellation,
        loadRequestCancellation,
      )) {
        _clearActiveLoadMoreRequestCancellation();
      }
      _isLoadMoreInFlight = false;
      if (ref.mounted && state.isLoadingMore) {
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }
}

List<TemplateGenerationResult> _appendUniqueGenerationItems(
  List<TemplateGenerationResult> current,
  List<TemplateGenerationResult> nextPage,
) {
  if (nextPage.isEmpty) {
    return current;
  }

  final seenIds = current.map((item) => item.generationId).toSet();
  return [
    ...current,
    for (final item in nextPage)
      if (seenIds.add(item.generationId)) item,
  ];
}

// Generation history application synchronization.
