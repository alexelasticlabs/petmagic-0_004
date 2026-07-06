part of 'generation_history_controller.dart';

mixin _GenerationHistoryControllerSync on _GenerationHistoryControllerBase {
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
    CancelToken? loadCancelToken;
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

      loadCancelToken = _startLoadCancelToken();
      try {
        if (refresh) {
          await _fetchUnreadGenerationCountBestEffort(loadCancelToken);
        }
        if (loadCancelToken.isCancelled) {
          _completeCancelledLoad();
          return;
        }

        await _flushPendingServerDeletes();
        if (!ref.mounted || !_isAuthenticated || loadCancelToken.isCancelled) {
          _completeCancelledLoad();
          return;
        }

        final page = await _repository.fetchGenerationPage(
          status: nextFilter.apiStatus,
          take: 50,
          cancelToken: loadCancelToken,
        );
        final remoteItems = page.items;
        final items = _decorateWithLocalMedia(
          remoteItems,
          deletedGenerationIds,
          localReadyRecords,
        );
        final unreadCount = page.serverTimeUtc == null
            ? await _fetchUnreadGenerationCountBestEffort(loadCancelToken)
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

        if (loadCancelToken.isCancelled ||
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
      final activeLoadCancelToken = loadCancelToken;
      if (activeLoadCancelToken != null) {
        _clearActiveLoadCancelToken(activeLoadCancelToken);
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
    final loadCancelToken = _startLoadMoreCancelToken();
    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);

    try {
      final deletedGenerationIds = await _galleryStore
          .loadDeletedGenerationIds();
      final localReadyRecords = await _galleryStore.loadLocalReadyItems();
      _locallyDeletedGenerationIds = Set<String>.from(deletedGenerationIds);

      if (!ref.mounted || !_isAuthenticated || loadCancelToken.isCancelled) {
        return;
      }

      final page = await _repository.fetchGenerationPage(
        status: requestFilter.apiStatus,
        cursor: requestCursor,
        take: 50,
        cancelToken: loadCancelToken,
      );
      if (!ref.mounted ||
          !_isAuthenticated ||
          loadCancelToken.isCancelled ||
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
      if (_isCancelledRequest(error) || loadCancelToken.isCancelled) {
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
      if (identical(_activeLoadMoreCancelToken, loadCancelToken)) {
        _clearActiveLoadMoreCancelToken();
      }
      _isLoadMoreInFlight = false;
      if (ref.mounted && state.isLoadingMore) {
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }

  @override
  Future<void> _markRead(String generationId) async {
    if (!_isAuthenticated) {
      return;
    }

    final wasUnread =
        _findGeneration(generationId)?.isUnread ??
        state.items.any(
          (item) => item.generationId == generationId && item.isUnread,
        );
    final updated = _markReadInList(state.items, generationId);
    final updatedCache = _markReadInCaches(
      state.cachedItemsByFilter,
      generationId,
    );
    state = state.copyWith(
      items: updated,
      cachedItemsByFilter: updatedCache,
      unreadCount: wasUnread && state.unreadCount > 0
          ? state.unreadCount - 1
          : state.unreadCount,
    );
    if (wasUnread) {
      _locallyReadGenerationIds = {..._locallyReadGenerationIds, generationId};
      _locallyReadUnreadGenerationIds = {
        ..._locallyReadUnreadGenerationIds,
        generationId,
      };
    }

    try {
      await _repository.markGenerationRead(generationId);
      _locallyReadUnreadGenerationIds = {
        for (final id in _locallyReadUnreadGenerationIds)
          if (id != generationId) id,
      };
    } on Object {
      // Keep the optimistic read state; the server count is reconciled on sync.
    }
  }

  @override
  Future<void> _deleteGeneration(String generationId) async {
    if (!_isAuthenticated) {
      return;
    }

    _locallyDeletedGenerationIds = {
      ..._locallyDeletedGenerationIds,
      generationId,
    };
    final targetGeneration = _findGeneration(generationId);
    final wasUnread =
        targetGeneration?.isUnread ??
        state.items.any(
          (item) => item.generationId == generationId && item.isUnread,
        );

    final updatedItems = _removeGenerationFromList(state.items, generationId);
    final updatedCache = _removeGenerationFromCaches(
      state.cachedItemsByFilter,
      generationId,
    );

    state = state.copyWith(
      items: updatedItems,
      cachedItemsByFilter: updatedCache,
      unreadCount: wasUnread && state.unreadCount > 0
          ? state.unreadCount - 1
          : state.unreadCount,
      clearError: true,
    );
    if (wasUnread) {
      _locallyDeletedUnreadGenerationIds = {
        ..._locallyDeletedUnreadGenerationIds,
        generationId,
      };
    }

    await _galleryStore.markDeletedLocally(
      generationId,
      userId: targetGeneration?.userId,
    );
    if (!ref.mounted || !_isAuthenticated) {
      return;
    }

    try {
      await _repository.deleteGeneration(generationId);
      if (!ref.mounted || !_isAuthenticated) {
        return;
      }

      await _galleryStore.clearPendingServerDelete(generationId);
    } on Object {
      // Local tombstone remains visible immediately; server delete retries on sync.
    }
  }

  @override
  Future<void> _submitFeedback({
    required String generationId,
    required int rating,
    List<String> selectedReasons = const [],
    String? comment,
  }) {
    if (!_isAuthenticated) {
      return Future<void>.value();
    }

    return _repository.submitGenerationFeedback(
      generationId: generationId,
      rating: rating,
      selectedReasons: selectedReasons,
      comment: comment,
    );
  }

  @override
  Future<void> _mergeFetchedGeneration(
    TemplateGenerationResult generation,
  ) async {
    if (!_isAuthenticated) {
      return;
    }

    await _mergeExternalGeneration(
      generation,
      refreshUnreadBadge: false,
      requireScreenVisible: false,
    );
  }

  @override
  Future<void> _mergeExternalGeneration(
    TemplateGenerationResult generation, {
    required bool refreshUnreadBadge,
    required bool requireScreenVisible,
  }) async {
    if (!_isAuthenticated) {
      return;
    }

    final deletedGenerationIds = await _galleryStore.loadDeletedGenerationIds();
    _locallyDeletedGenerationIds = Set<String>.from(deletedGenerationIds);
    if (!ref.mounted ||
        !_isAuthenticated ||
        (requireScreenVisible && !_isScreenVisible) ||
        deletedGenerationIds.contains(generation.generationId)) {
      return;
    }

    final localReadyRecords = await _galleryStore.loadLocalReadyItems();
    if (!ref.mounted ||
        !_isAuthenticated ||
        (requireScreenVisible && !_isScreenVisible)) {
      return;
    }

    final decoratedItems = _decorateWithLocalMedia(
      [generation],
      deletedGenerationIds,
      localReadyRecords,
    );
    if (decoratedItems.isEmpty) {
      return;
    }

    final decoratedGeneration = decoratedItems.single;
    final currentGeneration = _findGeneration(decoratedGeneration.generationId);
    if (currentGeneration != null &&
        decoratedGeneration.updatedAtUtc.isBefore(
          currentGeneration.updatedAtUtc,
        )) {
      return;
    }

    _upsertGeneration(decoratedGeneration);
    unawaited(_repository.upsertCachedGeneration(decoratedGeneration));
    if (decoratedGeneration.isCompleted) {
      unawaited(_syncCompletedMedia([decoratedGeneration]));
    }
    if (refreshUnreadBadge) {
      unawaited(refreshUnreadCount());
    }
  }

  Future<void> _flushPendingServerDeletes() async {
    if (!_isAuthenticated) {
      return;
    }

    final pendingDeletes = await _galleryStore.loadPendingServerDeleteIds();
    for (final generationId in pendingDeletes) {
      final cancelToken = _activeLoadCancelToken;
      if (!ref.mounted ||
          !_isAuthenticated ||
          cancelToken == null ||
          cancelToken.isCancelled) {
        return;
      }

      try {
        await _repository.deleteGeneration(
          generationId,
          cancelToken: cancelToken,
        );
        if (!ref.mounted || !_isAuthenticated || cancelToken.isCancelled) {
          return;
        }

        await _galleryStore.clearPendingServerDelete(generationId);
      } on Object catch (error) {
        if (_isCancelledRequest(error) ||
            !ref.mounted ||
            cancelToken.isCancelled) {
          return;
        }
        // Keep tombstone locally and retry on a later sync.
        return;
      }
    }
  }

  Future<void> _syncCompletedMedia(List<TemplateGenerationResult> items) async {
    if (!_isAuthenticated) {
      return;
    }

    for (final generation in items) {
      if (!_isAuthenticated || !_isScreenVisible || !generation.isCompleted) {
        continue;
      }

      final localRecord = await _galleryStore.materializeGenerationMedia(
        generation,
        background: true,
      );
      if (!ref.mounted ||
          !_isAuthenticated ||
          !_isScreenVisible ||
          localRecord == null ||
          localRecord.isDeletedLocally) {
        continue;
      }

      _applyLocalRecord(localRecord);
    }
  }

  void _applyLocalRecord(GenerationGalleryMediaRecord record) {
    final updatedItems = <TemplateGenerationResult>[
      for (final item in state.items)
        if (item.generationId == record.generationId)
          _applyLocalRecordToGeneration(item, record)
        else
          item,
    ];
    final updatedCache =
        <GenerationHistoryFilter, List<TemplateGenerationResult>>{
          for (final entry in state.cachedItemsByFilter.entries)
            entry.key: [
              for (final item in entry.value)
                if (item.generationId == record.generationId)
                  _applyLocalRecordToGeneration(item, record)
                else
                  item,
            ],
        };

    state = state.copyWith(
      items: updatedItems,
      cachedItemsByFilter: updatedCache,
    );
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
