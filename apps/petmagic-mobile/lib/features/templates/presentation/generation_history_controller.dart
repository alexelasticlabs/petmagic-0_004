import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/generation_media_kind.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

final generationHistoryControllerProvider =
    NotifierProvider<GenerationHistoryController, GenerationHistoryState>(
      GenerationHistoryController.new,
    );

enum GenerationHistoryFilter { all, active, ready, failed }

extension GenerationHistoryFilterApi on GenerationHistoryFilter {
  String? get apiStatus {
    return switch (this) {
      GenerationHistoryFilter.all => null,
      GenerationHistoryFilter.active => 'active',
      GenerationHistoryFilter.ready => 'ready',
      GenerationHistoryFilter.failed => 'failed',
    };
  }
}

class GenerationHistoryState {
  const GenerationHistoryState({
    this.items = const [],
    this.filter = GenerationHistoryFilter.all,
    this.unreadCount = 0,
    this.isLoading = false,
    this.syncFailed = false,
    this.showOfflineBanner = false,
    this.isConnectionRecovered = false,
    this.lastSyncedAtUtc,
    this.errorMessage,
    this.cachedItemsByFilter = const {},
  });

  final List<TemplateGenerationResult> items;
  final GenerationHistoryFilter filter;
  final int unreadCount;
  final bool isLoading;
  final bool syncFailed;
  final bool showOfflineBanner;
  final bool isConnectionRecovered;
  final DateTime? lastSyncedAtUtc;
  final String? errorMessage;
  final Map<GenerationHistoryFilter, List<TemplateGenerationResult>>
  cachedItemsByFilter;

  bool get shouldShowOfflineBanner => showOfflineBanner && items.isNotEmpty;

  TemplateGenerationResult? get activeGeneration {
    for (final item in items) {
      if (!item.isTerminal) {
        return item;
      }
    }
    return null;
  }

  GenerationHistoryState copyWith({
    List<TemplateGenerationResult>? items,
    GenerationHistoryFilter? filter,
    int? unreadCount,
    bool? isLoading,
    bool? syncFailed,
    bool? showOfflineBanner,
    bool? isConnectionRecovered,
    DateTime? lastSyncedAtUtc,
    bool clearLastSyncedAtUtc = false,
    String? errorMessage,
    Map<GenerationHistoryFilter, List<TemplateGenerationResult>>?
    cachedItemsByFilter,
    bool clearError = false,
  }) {
    return GenerationHistoryState(
      items: items ?? this.items,
      filter: filter ?? this.filter,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      syncFailed: syncFailed ?? this.syncFailed,
      showOfflineBanner: showOfflineBanner ?? this.showOfflineBanner,
      isConnectionRecovered:
          isConnectionRecovered ?? this.isConnectionRecovered,
      lastSyncedAtUtc: clearLastSyncedAtUtc
          ? null
          : lastSyncedAtUtc ?? this.lastSyncedAtUtc,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      cachedItemsByFilter: cachedItemsByFilter ?? this.cachedItemsByFilter,
    );
  }
}

class GenerationHistoryController extends Notifier<GenerationHistoryState> {
  static const Duration _autoRefreshMinInterval = Duration(seconds: 8);
  static const Duration _autoRefreshMaxInterval = Duration(seconds: 30);

  TemplateGenerationRepository get _repository =>
      ref.read(templateGenerationRepositoryProvider);
  GenerationGalleryStore get _galleryStore =>
      ref.read(generationGalleryStoreProvider);
  RealtimeClient? _activeRealtimeClient;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  Future<void>? _realtimeConnectFuture;
  Timer? _offlineBannerTimer;
  Timer? _autoRefreshTimer;
  bool _isScreenVisible = false;
  bool _isRealtimeConnected = false;
  bool _isLoadInFlight = false;
  bool _hasScheduledLocalArtifactCleanup = false;
  CancelToken? _activeLoadCancelToken;
  CancelToken? _activeUnreadRefreshCancelToken;
  _GenerationHistoryLoadRequest? _pendingLoadRequest;
  Completer<void>? _pendingLoadCompleter;
  Set<String> _locallyDeletedGenerationIds = const {};
  Set<String> _locallyDeletedUnreadGenerationIds = const {};
  Set<String> _locallyReadGenerationIds = const {};
  Set<String> _locallyReadUnreadGenerationIds = const {};
  int _autoRefreshFailureStreak = 0;

  @override
  GenerationHistoryState build() {
    ref.watch(templateGenerationRepositoryProvider);
    final galleryStore = ref.watch(generationGalleryStoreProvider);
    _activeRealtimeClient = ref.watch(realtimeClientProvider);
    ref.onDispose(() {
      _isScreenVisible = false;
      _offlineBannerTimer?.cancel();
      _offlineBannerTimer = null;
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
      _cancelActiveLoad(
        'generation_history_disposed',
        clearPending: true,
        clearLoadingState: false,
      );
      _cancelActiveUnreadRefresh('generation_history_disposed');
      unawaited(galleryStore.cancelActiveDownloads());
      _pauseRealtime();
    });
    Future.microtask(() async {
      if (!ref.mounted) {
        return;
      }

      final cachedUnread = await _repository.readCachedUnreadGenerationCount();
      if (!ref.mounted) {
        return;
      }

      if (cachedUnread != null) {
        state = state.copyWith(unreadCount: cachedUnread);
      }
      if (!_isScreenVisible) {
        return;
      }

      await refreshUnreadCount();
    });
    return const GenerationHistoryState();
  }

  void setScreenVisible(bool visible, {bool clearLoadingState = true}) {
    if (_isScreenVisible == visible) {
      return;
    }

    _isScreenVisible = visible;
    if (visible) {
      _scheduleLocalArtifactCleanup();
      _startAutoRefresh();
      unawaited(_resumeRealtimeIfNeeded());
      return;
    }

    _stopAutoRefresh();
    _cancelActiveLoad(
      'generation_history_hidden',
      clearPending: true,
      clearLoadingState: clearLoadingState,
    );
    _cancelActiveUnreadRefresh('generation_history_hidden');
    unawaited(_galleryStore.cancelActiveDownloads());
    _pauseRealtime();
  }

  Future<void> load({
    GenerationHistoryFilter? filter,
    bool refresh = false,
  }) async {
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
    try {
      await _resumeRealtimeIfNeeded();
      if (!ref.mounted) {
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
          clearError: true,
        );
        return;
      }

      List<TemplateGenerationResult>? persistedItems;
      if (!refresh) {
        persistedItems = await _repository.readCachedGenerations(
          status: nextFilter.apiStatus,
        );
        if (!ref.mounted) {
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
        syncFailed: false,
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

      try {
        final loadCancelToken = _startLoadCancelToken();
        await _flushPendingServerDeletes();
        if (!ref.mounted || loadCancelToken.isCancelled) {
          _completeCancelledLoad();
          return;
        }

        final remoteItems = await _repository.fetchGenerations(
          status: nextFilter.apiStatus,
          take: 50,
          cancelToken: loadCancelToken,
        );
        final items = _decorateWithLocalMedia(
          remoteItems,
          deletedGenerationIds,
          localReadyRecords,
        );
        final unreadCount = await _fetchUnreadGenerationCountBestEffort(
          loadCancelToken,
        );
        _reconcileLocallyReadIds(remoteItems);
        _locallyDeletedUnreadGenerationIds =
            await _loadDeletedUnreadGenerationIds(
              deletedGenerationIds: deletedGenerationIds,
              remoteItems: remoteItems,
            );
        if (!ref.mounted) {
          return;
        }
        final visibleUnreadCount = unreadCount == null
            ? state.unreadCount
            : _visibleUnreadCount(unreadCount);
        if (!ref.mounted) {
          return;
        }
        if (loadCancelToken.isCancelled) {
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
          syncFailed: false,
          showOfflineBanner: wasOfflineBeforeLoad && items.isNotEmpty,
          isConnectionRecovered: wasOfflineBeforeLoad && items.isNotEmpty,
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
      _clearActiveLoadCancelToken();
      _isLoadInFlight = false;
      _drainPendingLoad();
    }
  }

  void _completeCancelledLoad() {
    if (!ref.mounted || !state.isLoading) {
      return;
    }

    state = state.copyWith(isLoading: false);
  }

  CancelToken _startLoadCancelToken() {
    _cancelActiveLoad('generation_history_superseded', clearPending: false);
    final cancelToken = CancelToken();
    _activeLoadCancelToken = cancelToken;
    return cancelToken;
  }

  void _clearActiveLoadCancelToken() {
    _activeLoadCancelToken = null;
  }

  void _cancelActiveLoad(
    String reason, {
    required bool clearPending,
    bool clearLoadingState = true,
  }) {
    final cancelToken = _activeLoadCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel(reason);
    }
    _activeLoadCancelToken = null;
    if (clearPending && clearLoadingState) {
      _completeCancelledLoad();
    }

    if (!clearPending) {
      return;
    }

    final pendingCompleter = _pendingLoadCompleter;
    _pendingLoadRequest = null;
    _pendingLoadCompleter = null;
    if (pendingCompleter != null && !pendingCompleter.isCompleted) {
      pendingCompleter.complete();
    }
  }

  CancelToken _startUnreadRefreshCancelToken() {
    _cancelActiveUnreadRefresh('generation_history_unread_superseded');
    final cancelToken = CancelToken();
    _activeUnreadRefreshCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveUnreadRefresh(String reason) {
    final cancelToken = _activeUnreadRefreshCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel(reason);
    }
    _activeUnreadRefreshCancelToken = null;
  }

  void _drainPendingLoad() {
    final pendingRequest = _pendingLoadRequest;
    final pendingCompleter = _pendingLoadCompleter;
    _pendingLoadRequest = null;
    _pendingLoadCompleter = null;
    if (pendingRequest == null) {
      return;
    }

    if (!ref.mounted) {
      if (pendingCompleter != null && !pendingCompleter.isCompleted) {
        pendingCompleter.complete();
      }
      return;
    }

    unawaited(() async {
      try {
        await load(
          filter: pendingRequest.filter,
          refresh: pendingRequest.refresh,
        );
        if (pendingCompleter != null && !pendingCompleter.isCompleted) {
          pendingCompleter.complete();
        }
      } catch (error, stackTrace) {
        if (pendingCompleter != null && !pendingCompleter.isCompleted) {
          pendingCompleter.completeError(error, stackTrace);
        }
      }
    }());
  }

  void _scheduleLocalArtifactCleanup() {
    if (_hasScheduledLocalArtifactCleanup) {
      return;
    }

    _hasScheduledLocalArtifactCleanup = true;
    final galleryStore = _galleryStore;
    unawaited(() async {
      try {
        await galleryStore.cleanupCurrentAccountArtifacts();
      } on Object {
        // Cache cleanup is opportunistic; history loading remains authoritative.
      }
    }());
  }

  void _startAutoRefresh() {
    _scheduleNextAutoRefresh();
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  void _scheduleNextAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (!ref.mounted || !_isScreenVisible) {
      return;
    }

    _autoRefreshTimer = Timer(_currentAutoRefreshInterval(), () {
      if (!ref.mounted) {
        return;
      }

      if (!_isScreenVisible || _isLoadInFlight) {
        _scheduleNextAutoRefresh();
        return;
      }

      unawaited(load(refresh: true).whenComplete(_scheduleNextAutoRefresh));
    });
  }

  Duration _currentAutoRefreshInterval() {
    final multiplier = 1 << _autoRefreshFailureStreak.clamp(0, 3);
    final nextSeconds = _autoRefreshMinInterval.inSeconds * multiplier;
    final maxSeconds = _autoRefreshMaxInterval.inSeconds;
    final boundedSeconds = nextSeconds > maxSeconds ? maxSeconds : nextSeconds;
    return Duration(seconds: boundedSeconds);
  }

  void _registerAutoRefreshSuccess() {
    if (!ref.mounted) {
      return;
    }

    if (_autoRefreshFailureStreak == 0) {
      return;
    }

    _autoRefreshFailureStreak = 0;
    _scheduleNextAutoRefresh();
  }

  void _registerAutoRefreshFailure() {
    if (!ref.mounted) {
      return;
    }

    final next = _autoRefreshFailureStreak + 1;
    _autoRefreshFailureStreak = next > 3 ? 3 : next;
    _scheduleNextAutoRefresh();
  }

  void _scheduleOfflineBannerHide() {
    _offlineBannerTimer?.cancel();
    _offlineBannerTimer = Timer(const Duration(seconds: 3), () {
      if (!ref.mounted) {
        return;
      }

      state = state.copyWith(
        showOfflineBanner: false,
        isConnectionRecovered: false,
      );
    });
  }

  Future<void> refreshUnreadCount() async {
    if (!ref.mounted || !_isScreenVisible || _isLoadInFlight) {
      return;
    }

    final cancelToken = _startUnreadRefreshCancelToken();
    try {
      final unreadCount = await _repository.fetchUnreadGenerationCount(
        cancelToken: cancelToken,
      );
      if (!ref.mounted || !_isScreenVisible || cancelToken.isCancelled) {
        return;
      }

      state = state.copyWith(unreadCount: _visibleUnreadCount(unreadCount));
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || cancelToken.isCancelled) {
        return;
      }
    } catch (_) {
    } finally {
      if (identical(_activeUnreadRefreshCancelToken, cancelToken)) {
        _activeUnreadRefreshCancelToken = null;
      }
    }
  }

  Future<int?> _fetchUnreadGenerationCountBestEffort(
    CancelToken cancelToken,
  ) async {
    try {
      return await _repository.fetchUnreadGenerationCount(
        cancelToken: cancelToken,
      );
    } on Object catch (error) {
      if (_isCancelledRequest(error) || cancelToken.isCancelled) {
        rethrow;
      }
      return null;
    }
  }

  Future<void> markRead(String generationId) async {
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

  Future<void> deleteGeneration(String generationId) async {
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
    if (!ref.mounted) {
      return;
    }

    try {
      await _repository.deleteGeneration(generationId);
      if (!ref.mounted) {
        return;
      }

      await _galleryStore.clearPendingServerDelete(generationId);
    } on Object {
      // Local tombstone remains visible immediately; server delete retries on sync.
    }
  }

  Future<void> submitFeedback({
    required String generationId,
    required int rating,
    List<String> selectedReasons = const [],
    String? comment,
  }) {
    return _repository.submitGenerationFeedback(
      generationId: generationId,
      rating: rating,
      selectedReasons: selectedReasons,
      comment: comment,
    );
  }

  Future<void> mergeFetchedGeneration(
    TemplateGenerationResult generation,
  ) async {
    await _mergeExternalGeneration(
      generation,
      refreshUnreadBadge: false,
      requireScreenVisible: false,
    );
  }

  Future<void> _mergeExternalGeneration(
    TemplateGenerationResult generation, {
    required bool refreshUnreadBadge,
    required bool requireScreenVisible,
  }) async {
    final deletedGenerationIds = await _galleryStore.loadDeletedGenerationIds();
    _locallyDeletedGenerationIds = Set<String>.from(deletedGenerationIds);
    if (!ref.mounted ||
        (requireScreenVisible && !_isScreenVisible) ||
        deletedGenerationIds.contains(generation.generationId)) {
      return;
    }

    final localReadyRecords = await _galleryStore.loadLocalReadyItems();
    if (!ref.mounted || (requireScreenVisible && !_isScreenVisible)) {
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
    _upsertGeneration(decoratedGeneration);
    unawaited(_repository.upsertCachedGeneration(decoratedGeneration));
    if (decoratedGeneration.isCompleted) {
      unawaited(_syncCompletedMedia([decoratedGeneration]));
    }
    if (refreshUnreadBadge) {
      unawaited(refreshUnreadCount());
    }
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (!ref.mounted || !_isScreenVisible) {
      return;
    }

    if (event.topic != RealtimeTopics.templatesGenerationStatusChanged ||
        event.payload.isEmpty) {
      return;
    }

    try {
      final generation = TemplateGenerationDto.fromJson(
        Map<String, dynamic>.from(event.payload),
      ).toDomain();
      unawaited(
        _mergeExternalGeneration(
          generation,
          refreshUnreadBadge: true,
          requireScreenVisible: true,
        ),
      );
    } catch (_) {}
  }

  Future<void> _resumeRealtimeIfNeeded() async {
    if (!ref.mounted || !_isScreenVisible) {
      return;
    }

    final realtimeClient = _activeRealtimeClient;
    if (realtimeClient == null) {
      return;
    }

    _realtimeSubscription ??= realtimeClient.events.listen(
      _handleRealtimeEvent,
    );
    if (_isRealtimeConnected) {
      return;
    }

    final connectFuture = _realtimeConnectFuture;
    if (connectFuture != null) {
      await connectFuture;
      return;
    }

    try {
      final nextConnectFuture = realtimeClient.connect();
      _realtimeConnectFuture = nextConnectFuture;
      await nextConnectFuture;
      if (!ref.mounted) {
        return;
      }

      if (!_isScreenVisible ||
          !identical(_activeRealtimeClient, realtimeClient)) {
        unawaited(realtimeClient.disconnect());
        return;
      }

      _isRealtimeConnected = true;
    } on Object {
      // Realtime is best-effort; gallery remains available via manual refresh.
    } finally {
      _realtimeConnectFuture = null;
    }
  }

  void _pauseRealtime() {
    unawaited(_realtimeSubscription?.cancel());
    _realtimeSubscription = null;

    if (_isRealtimeConnected) {
      final realtimeClient = _activeRealtimeClient;
      if (realtimeClient != null) {
        unawaited(realtimeClient.disconnect());
      }
      _isRealtimeConnected = false;
    }
    _realtimeConnectFuture = null;
  }

  void _upsertGeneration(TemplateGenerationResult generation) {
    final updatedCache = _upsertGenerationInCaches(
      state.cachedItemsByFilter,
      generation,
    );

    final visibleItems = state.cachedItemsByFilter.containsKey(state.filter)
        ? (updatedCache[state.filter] ?? const <TemplateGenerationResult>[])
        : _upsertGenerationInList(state.items, generation, state.filter);

    state = state.copyWith(
      items: visibleItems,
      cachedItemsByFilter: updatedCache,
    );
  }

  Map<GenerationHistoryFilter, List<TemplateGenerationResult>>
  _upsertGenerationInCaches(
    Map<GenerationHistoryFilter, List<TemplateGenerationResult>> caches,
    TemplateGenerationResult generation,
  ) {
    final updated = <GenerationHistoryFilter, List<TemplateGenerationResult>>{};
    for (final entry in caches.entries) {
      updated[entry.key] = _upsertGenerationInList(
        entry.value,
        generation,
        entry.key,
      );
    }
    return updated;
  }

  List<TemplateGenerationResult> _upsertGenerationInList(
    List<TemplateGenerationResult> source,
    TemplateGenerationResult generation,
    GenerationHistoryFilter filter,
  ) {
    final localizedGeneration = _applyLocalReadState(generation);
    final next = [
      for (final item in source)
        if (item.generationId != generation.generationId) item,
    ];

    if (_matchesFilter(localizedGeneration, filter)) {
      next.insert(0, localizedGeneration);
    }

    next.sort((left, right) => right.updatedAtUtc.compareTo(left.updatedAtUtc));
    return next;
  }

  Map<GenerationHistoryFilter, List<TemplateGenerationResult>>
  _markReadInCaches(
    Map<GenerationHistoryFilter, List<TemplateGenerationResult>> caches,
    String generationId,
  ) {
    final updated = <GenerationHistoryFilter, List<TemplateGenerationResult>>{};
    for (final entry in caches.entries) {
      updated[entry.key] = _markReadInList(entry.value, generationId);
    }
    return updated;
  }

  List<TemplateGenerationResult> _markReadInList(
    List<TemplateGenerationResult> source,
    String generationId,
  ) {
    return [
      for (final item in source)
        if (item.generationId == generationId)
          item.copyWith(isUnread: false)
        else
          item,
    ];
  }

  Map<GenerationHistoryFilter, List<TemplateGenerationResult>>
  _removeGenerationFromCaches(
    Map<GenerationHistoryFilter, List<TemplateGenerationResult>> caches,
    String generationId,
  ) {
    final updated = <GenerationHistoryFilter, List<TemplateGenerationResult>>{};
    for (final entry in caches.entries) {
      updated[entry.key] = _removeGenerationFromList(entry.value, generationId);
    }
    return updated;
  }

  List<TemplateGenerationResult> _removeGenerationFromList(
    List<TemplateGenerationResult> source,
    String generationId,
  ) {
    return [
      for (final item in source)
        if (item.generationId != generationId) item,
    ];
  }

  Set<String> _deletedUnreadGenerationIds(
    List<TemplateGenerationResult> remoteItems,
    Set<String> deletedGenerationIds,
  ) {
    if (deletedGenerationIds.isEmpty) {
      return const {};
    }

    return remoteItems
        .where(
          (item) =>
              item.isUnread && deletedGenerationIds.contains(item.generationId),
        )
        .map((item) => item.generationId)
        .toSet();
  }

  Future<Set<String>> _loadDeletedUnreadGenerationIds({
    required Set<String> deletedGenerationIds,
    required List<TemplateGenerationResult> remoteItems,
  }) async {
    if (deletedGenerationIds.isEmpty) {
      return const {};
    }

    final deletedUnreadIds = <String>{};
    void collect(List<TemplateGenerationResult>? items) {
      if (items == null || items.isEmpty) {
        return;
      }

      deletedUnreadIds.addAll(
        _deletedUnreadGenerationIds(items, deletedGenerationIds),
      );
    }

    collect(remoteItems);
    collect(state.items);
    for (final items in state.cachedItemsByFilter.values) {
      collect(items);
    }

    if (deletedUnreadIds.length < deletedGenerationIds.length) {
      collect(await _repository.readCachedGenerations());
    }

    return deletedUnreadIds;
  }

  int _visibleUnreadCount(int unreadCount) {
    if (unreadCount <= 0) {
      return unreadCount;
    }

    final locallyHiddenUnreadIds = {
      ..._locallyDeletedUnreadGenerationIds,
      ..._locallyReadUnreadGenerationIds,
    };
    if (locallyHiddenUnreadIds.isEmpty) {
      return unreadCount;
    }

    final adjusted = unreadCount - locallyHiddenUnreadIds.length;
    return adjusted < 0 ? 0 : adjusted;
  }

  void _reconcileLocallyReadIds(List<TemplateGenerationResult> remoteItems) {
    if ((_locallyReadGenerationIds.isEmpty &&
            _locallyReadUnreadGenerationIds.isEmpty) ||
        remoteItems.isEmpty) {
      return;
    }

    final serverReadIds = remoteItems
        .where(
          (item) =>
              (_locallyReadGenerationIds.contains(item.generationId) ||
                  _locallyReadUnreadGenerationIds.contains(
                    item.generationId,
                  )) &&
              !item.isUnread,
        )
        .map((item) => item.generationId)
        .toSet();
    if (serverReadIds.isEmpty) {
      return;
    }

    _locallyReadGenerationIds = {
      for (final id in _locallyReadGenerationIds)
        if (!serverReadIds.contains(id)) id,
    };
    _locallyReadUnreadGenerationIds = {
      for (final id in _locallyReadUnreadGenerationIds)
        if (!serverReadIds.contains(id)) id,
    };
  }

  TemplateGenerationResult? _findGeneration(String generationId) {
    for (final item in state.items) {
      if (item.generationId == generationId) {
        return item;
      }
    }

    for (final items in state.cachedItemsByFilter.values) {
      for (final item in items) {
        if (item.generationId == generationId) {
          return item;
        }
      }
    }

    return null;
  }

  List<TemplateGenerationResult> _decorateWithLocalMedia(
    List<TemplateGenerationResult> source,
    Set<String> deletedGenerationIds,
    List<GenerationGalleryMediaRecord> localReadyRecords,
  ) {
    if (source.isEmpty) {
      return const [];
    }

    if (localReadyRecords.isEmpty && deletedGenerationIds.isEmpty) {
      return source;
    }

    final localById = {
      for (final record in localReadyRecords) record.generationId: record,
    };

    return source
        .where((item) => !deletedGenerationIds.contains(item.generationId))
        .map((item) {
          final localRecord = localById[item.generationId];
          if (localRecord == null ||
              localRecord.isDeletedLocally ||
              !_localRecordMatchesGeneration(localRecord, item)) {
            if (item.localPreviewPath == null &&
                item.localOutputPath == null &&
                !item.isLocalMediaReady) {
              return item;
            }
            return _applyLocalReadState(
              item.copyWith(
                clearLocalPreviewPath: true,
                clearLocalOutputPath: true,
                isLocalMediaReady: false,
              ),
            );
          }

          if (item.localPreviewPath == localRecord.previewLocalPath &&
              item.localOutputPath == localRecord.outputLocalPath &&
              item.isLocalMediaReady == localRecord.isDownloadComplete) {
            return item;
          }
          return _applyLocalReadState(
            item.copyWith(
              localPreviewPath: localRecord.previewLocalPath,
              localOutputPath: localRecord.outputLocalPath,
              isLocalMediaReady: localRecord.isDownloadComplete,
            ),
          );
        })
        .toList(growable: false);
  }

  TemplateGenerationResult _applyLocalReadState(
    TemplateGenerationResult generation,
  ) {
    if (!_locallyReadGenerationIds.contains(generation.generationId)) {
      return generation;
    }

    return generation.copyWith(isUnread: false);
  }

  Future<void> _flushPendingServerDeletes() async {
    final pendingDeletes = await _galleryStore.loadPendingServerDeleteIds();
    for (final generationId in pendingDeletes) {
      final cancelToken = _activeLoadCancelToken;
      if (!ref.mounted || cancelToken == null || cancelToken.isCancelled) {
        return;
      }

      try {
        await _repository.deleteGeneration(
          generationId,
          cancelToken: cancelToken,
        );
        if (!ref.mounted || cancelToken.isCancelled) {
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
    for (final generation in items) {
      if (!_isScreenVisible || !generation.isCompleted) {
        continue;
      }

      final localRecord = await _galleryStore.materializeGenerationMedia(
        generation,
      );
      if (!ref.mounted ||
          !_isScreenVisible ||
          localRecord == null ||
          localRecord.isDeletedLocally) {
        continue;
      }

      _applyLocalRecord(localRecord);
    }
  }

  void _applyLocalRecord(GenerationGalleryMediaRecord record) {
    final updatedItems = [
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

  bool _matchesFilter(
    TemplateGenerationResult generation,
    GenerationHistoryFilter filter,
  ) {
    return switch (filter) {
      GenerationHistoryFilter.all => true,
      GenerationHistoryFilter.active => !generation.isTerminal,
      GenerationHistoryFilter.ready => generation.isCompleted,
      GenerationHistoryFilter.failed => generation.isFailed,
    };
  }

  TemplateGenerationResult _applyLocalRecordToGeneration(
    TemplateGenerationResult generation,
    GenerationGalleryMediaRecord record,
  ) {
    if (!_localRecordMatchesGeneration(record, generation)) {
      return generation.copyWith(
        clearLocalPreviewPath: true,
        clearLocalOutputPath: true,
        isLocalMediaReady: false,
      );
    }

    return generation.copyWith(
      localPreviewPath: record.previewLocalPath,
      localOutputPath: record.outputLocalPath,
      isLocalMediaReady: record.isDownloadComplete,
    );
  }
}

class _GenerationHistoryLoadRequest {
  const _GenerationHistoryLoadRequest({
    required this.filter,
    required this.refresh,
  });

  final GenerationHistoryFilter filter;
  final bool refresh;
}

String _historyLoadErrorMessage(Object error) {
  if (error is AppException) {
    final message = error.message.trim();
    if (_isSafeHistoryErrorKey(message)) {
      return message;
    }

    final statusCode = error.statusCode;
    if (statusCode == 401) {
      return 'auth.session_expired';
    }
    if (statusCode == 408) {
      return 'templates.connection_timeout';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'templates.server_timeout';
    }

    return 'templates.request_failed';
  }

  return 'templates.request_failed';
}

bool _isSafeHistoryErrorKey(String value) {
  return value == 'templates.connection_timeout' ||
      value == 'templates.server_timeout' ||
      value == 'templates.request_failed';
}

bool _isCancelledRequest(Object error) {
  return error is DioException && CancelToken.isCancel(error);
}

bool _localRecordMatchesGeneration(
  GenerationGalleryMediaRecord record,
  TemplateGenerationResult generation,
) {
  final previewUrl = _historyPreviewUrl(generation);
  final outputUrl = _safeGenerationMediaUrl(generation.outputUrl);
  if (previewUrl == null && outputUrl == null) {
    return false;
  }

  return _safeNullableMediaUrlEquals(record.previewRemoteUrl, previewUrl) &&
      _safeNullableMediaUrlEquals(record.outputRemoteUrl, outputUrl);
}

String? _historyPreviewUrl(TemplateGenerationResult generation) {
  final resultPreview = _safeGenerationMediaUrl(generation.resultPreviewUrl);
  final output = _safeGenerationMediaUrl(generation.outputUrl);
  final source = _safeGenerationMediaUrl(generation.sourceImageAsset?.url);
  final normalized = _safeGenerationMediaUrl(generation.normalizedImageUrl);
  final generationIsVideo = isVideoGenerationResult(generation);

  if (resultPreview != null && !isLikelyGenerationVideoUrl(resultPreview)) {
    return resultPreview;
  }

  if (generationIsVideo) {
    if (source != null) {
      return source;
    }
    if (normalized != null) {
      return normalized;
    }
    return output != null && isLikelyGenerationImageUrl(output) ? output : null;
  }

  if (output != null && !isLikelyGenerationVideoUrl(output)) {
    return output;
  }
  if (source != null) {
    return source;
  }
  if (normalized != null) {
    return normalized;
  }
  return null;
}

String? _safeGenerationMediaUrl(String? raw) {
  return parseSafeGenerationMediaUri(raw)?.toString();
}

bool _safeNullableMediaUrlEquals(String? left, String? right) {
  if (left == null && right == null) {
    return true;
  }
  if (left == null || right == null) {
    return false;
  }
  final leftUri = parseSafeGenerationMediaUri(left);
  final rightUri = parseSafeGenerationMediaUri(right);
  return leftUri != null &&
      rightUri != null &&
      leftUri.toString() == rightUri.toString();
}
