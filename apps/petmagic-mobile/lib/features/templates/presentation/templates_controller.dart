import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

final templatesControllerProvider =
    NotifierProvider<TemplatesController, TemplatesState>(
      TemplatesController.new,
    );

class TemplatesState {
  const TemplatesState({
    this.items = const [],
    this.categories = const [],
    this.query = const TemplatesQuery(),
    this.catalogVersion = 0,
    this.currentPage = 1,
    this.itemsQueryKey,
    this.cachedPagesByQueryKey = const {},
    this.hasMore = true,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.loadedFromCache = false,
    this.errorMessage,
  });

  final List<TemplateItem> items;
  final List<String> categories;
  final TemplatesQuery query;
  final int catalogVersion;
  final int currentPage;
  final String? itemsQueryKey;
  final Map<String, TemplatesFeedPage> cachedPagesByQueryKey;
  final bool hasMore;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool loadedFromCache;
  final String? errorMessage;

  bool get isInitialLoading => isLoading && items.isEmpty;
  bool get isEmpty =>
      !isLoading && !isRefreshing && items.isEmpty && errorMessage == null;

  TemplatesState copyWith({
    List<TemplateItem>? items,
    List<String>? categories,
    TemplatesQuery? query,
    int? catalogVersion,
    int? currentPage,
    String? itemsQueryKey,
    bool clearItemsQueryKey = false,
    Map<String, TemplatesFeedPage>? cachedPagesByQueryKey,
    bool? hasMore,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? loadedFromCache,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TemplatesState(
      items: items ?? this.items,
      categories: categories ?? this.categories,
      query: query ?? this.query,
      catalogVersion: catalogVersion ?? this.catalogVersion,
      currentPage: currentPage ?? this.currentPage,
      itemsQueryKey: clearItemsQueryKey
          ? null
          : itemsQueryKey ?? this.itemsQueryKey,
      cachedPagesByQueryKey:
          cachedPagesByQueryKey ?? this.cachedPagesByQueryKey,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadedFromCache: loadedFromCache ?? this.loadedFromCache,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class TemplatesController extends Notifier<TemplatesState> {
  static const _realtimeRefreshDebounce = Duration(milliseconds: 350);

  late final TemplatesRepository _repository;
  late final RealtimeClient _realtimeClient;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  Timer? _realtimeRefreshTimer;
  bool _hasPendingRealtimeRefresh = false;
  int _requestVersion = 0;
  bool _isScreenVisible = true;
  bool _isRealtimeConnected = false;

  static String? _normalizeCategory(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static List<String> _normalizeCategories(List<String> values) {
    final unique = <String>{};
    final ordered = <String>[];

    for (final value in values) {
      final normalized = _normalizeCategory(value);
      if (normalized == null) {
        continue;
      }

      final key = normalized.toLowerCase();
      if (unique.add(key)) {
        ordered.add(normalized);
      }
    }

    return ordered;
  }

  @override
  TemplatesState build() {
    _repository = ref.watch(templatesRepositoryProvider);
    _realtimeClient = ref.watch(realtimeClientProvider);
    unawaited(_resumeRealtimeIfNeeded());
    ref.onDispose(() {
      _pauseRealtime();
    });
    return const TemplatesState();
  }

  void setScreenVisible(bool visible) {
    if (_isScreenVisible == visible) {
      return;
    }

    _isScreenVisible = visible;
    if (visible) {
      unawaited(_resumeRealtimeIfNeeded());
      _resumePendingRealtimeRefreshIfNeeded();
      return;
    }

    _pauseRealtime();
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (!_isScreenVisible) {
      return;
    }

    if (event.topic != RealtimeTopics.templatesFeedInvalidated) {
      return;
    }

    _hasPendingRealtimeRefresh = true;
    _scheduleRealtimeRefresh();
  }

  bool get _isFeedBusy =>
      state.isLoading || state.isRefreshing || state.isLoadingMore;

  void _scheduleRealtimeRefresh() {
    if (!_isScreenVisible || _isFeedBusy) {
      return;
    }

    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = Timer(
      _realtimeRefreshDebounce,
      _flushPendingRealtimeRefresh,
    );
  }

  void _flushPendingRealtimeRefresh() {
    _realtimeRefreshTimer = null;
    if (!_hasPendingRealtimeRefresh || _isFeedBusy) {
      return;
    }

    _hasPendingRealtimeRefresh = false;
    unawaited(_refreshFromRealtimeInvalidation());
  }

  Future<void> _refreshFromRealtimeInvalidation() async {
    try {
      final latestVersion = await _repository.fetchCatalogVersion();
      if (!_isScreenVisible) {
        return;
      }

      if (latestVersion <= state.catalogVersion) {
        return;
      }

      await loadInitial(
        forceRefresh: true,
        knownCatalogVersion: latestVersion,
      );
    } on Object {
      await loadInitial(forceRefresh: true);
    }
  }

  void _resumePendingRealtimeRefreshIfNeeded() {
    if (_isScreenVisible && _hasPendingRealtimeRefresh) {
      _scheduleRealtimeRefresh();
    }
  }

  Future<void> _resumeRealtimeIfNeeded() async {
    if (!_isScreenVisible) {
      return;
    }

    _realtimeSubscription ??= _realtimeClient.events.listen(
      _handleRealtimeEvent,
    );
    if (_isRealtimeConnected) {
      return;
    }

    try {
      await _realtimeClient.connect();
      _isRealtimeConnected = true;
    } on Object {
      // Realtime is best-effort; templates feed still works via pull refresh.
    }
  }

  void _pauseRealtime() {
    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = null;
    unawaited(_realtimeSubscription?.cancel());
    _realtimeSubscription = null;

    if (_isRealtimeConnected) {
      unawaited(_realtimeClient.disconnect());
      _isRealtimeConnected = false;
    }
  }

  Future<void> loadInitial({
    bool forceRefresh = false,
    int? knownCatalogVersion,
  }) async {
    final requestVersion = ++_requestVersion;
    final query = state.query.copyWith(clearCursor: true, resetPage: true);
    final queryKey = query.cacheKey;
    final isStaleVisibleItems = state.itemsQueryKey != null
        ? state.itemsQueryKey != queryKey
        : state.items.isNotEmpty;

    if (!forceRefresh) {
      final inMemoryCached = state.cachedPagesByQueryKey[queryKey];
      if (inMemoryCached != null) {
        state = state.copyWith(
          query: query,
          items: inMemoryCached.items,
          currentPage: inMemoryCached.page,
          itemsQueryKey: queryKey,
          hasMore: inMemoryCached.hasMore,
          loadedFromCache: true,
          isLoading: false,
          isRefreshing: false,
          clearError: true,
        );
        _resumePendingRealtimeRefreshIfNeeded();
        return;
      }
    }

    state = state.copyWith(
      query: query,
      items: isStaleVisibleItems ? const [] : state.items,
      clearItemsQueryKey: isStaleVisibleItems,
      isLoading: !forceRefresh,
      isRefreshing: forceRefresh,
      loadedFromCache: false,
      clearError: true,
      currentPage: 1,
      hasMore: true,
    );

    if (!forceRefresh) {
      final cached = await _repository.readCachedFirstPage(query);
      if (cached != null && requestVersion == _requestVersion) {
        final updatedCache = Map<String, TemplatesFeedPage>.from(
          state.cachedPagesByQueryKey,
        )..[queryKey] = cached;
        state = state.copyWith(
          items: cached.items,
          currentPage: cached.page,
          itemsQueryKey: queryKey,
          cachedPagesByQueryKey: updatedCache,
          hasMore: cached.hasMore,
          loadedFromCache: true,
          isLoading: false,
        );
      }
    }

    try {
      final resolvedCatalogVersion = await _repository.syncCatalog(
        knownRemoteVersion: knownCatalogVersion,
      );

      if (state.categories.isEmpty || forceRefresh) {
        final categories = _normalizeCategories(
          await _repository.fetchCategories(),
        );
        if (requestVersion == _requestVersion) {
          state = state.copyWith(categories: categories);
        }
      }

      final page = await _repository.fetchFeed(query);
      if (requestVersion != _requestVersion) return;

      final updatedCache = Map<String, TemplatesFeedPage>.from(
        state.cachedPagesByQueryKey,
      )..[queryKey] = page;
      state = state.copyWith(
        items: page.items,
        catalogVersion: resolvedCatalogVersion,
        currentPage: page.page,
        itemsQueryKey: queryKey,
        cachedPagesByQueryKey: updatedCache,
        hasMore: page.hasMore,
        loadedFromCache: false,
        isLoading: false,
        isRefreshing: false,
        clearError: true,
      );
    } on RequestCancelledException {
      if (requestVersion != _requestVersion) return;
      state = state.copyWith(isLoading: false, isRefreshing: false);
    } on AppException catch (error) {
      if (requestVersion != _requestVersion) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: error.message,
      );
    } catch (error) {
      if (requestVersion != _requestVersion) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: 'templates.request_failed',
      );
    } finally {
      _resumePendingRealtimeRefreshIfNeeded();
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading || !state.hasMore) {
      return;
    }

    final requestVersion = _requestVersion;
    final query = state.query.copyWith(
      page: state.currentPage + 1,
      clearCursor: true,
    );
    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final page = await _repository.fetchFeed(query);
      if (requestVersion != _requestVersion) {
        return;
      }

      final existingIds = state.items.map((item) => item.templateId).toSet();
      final appended = page.items.where(
        (item) => !existingIds.contains(item.templateId),
      );
      final mergedItems = [...state.items, ...appended];
      final queryKey = state.query.copyWith(resetPage: true).cacheKey;
      final updatedCache =
          Map<String, TemplatesFeedPage>.from(state.cachedPagesByQueryKey)
            ..[queryKey] = TemplatesFeedPage(
              items: mergedItems,
              hasMore: page.hasMore,
              page: page.page,
            );

      state = state.copyWith(
        items: mergedItems,
        currentPage: page.page,
        itemsQueryKey: queryKey,
        cachedPagesByQueryKey: updatedCache,
        hasMore: page.hasMore,
        isLoadingMore: false,
        clearError: true,
      );
    } on RequestCancelledException {
      if (requestVersion != _requestVersion) {
        return;
      }

      state = state.copyWith(isLoadingMore: false);
    } on AppException catch (error) {
      if (requestVersion != _requestVersion) {
        return;
      }

      state = state.copyWith(isLoadingMore: false, errorMessage: error.message);
    } catch (error) {
      if (requestVersion != _requestVersion) {
        return;
      }

      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: 'templates.request_failed',
      );
    } finally {
      _resumePendingRealtimeRefreshIfNeeded();
    }
  }

  Future<void> refresh() => loadInitial(forceRefresh: true);

  void setType(TemplateType? type) {
    if (state.query.type == type) {
      return;
    }

    state = state.copyWith(
      query: state.query.copyWith(
        type: type,
        clearType: type == null,
        clearCursor: true,
        resetPage: true,
      ),
      currentPage: 1,
    );
    loadInitial();
  }

  void setCategory(String? category) {
    final normalized = _normalizeCategory(category);

    if (state.query.category == normalized) {
      return;
    }

    state = state.copyWith(
      query: state.query.copyWith(
        category: normalized,
        clearCategory: normalized == null,
        clearCursor: true,
        resetPage: true,
      ),
      currentPage: 1,
    );
    loadInitial();
  }

  void setSearch(String value) {
    final normalized = value.trim();
    final nextSearch = normalized.isEmpty ? null : normalized;

    if (state.query.search == nextSearch) {
      return;
    }

    state = state.copyWith(
      query: state.query.copyWith(
        search: nextSearch,
        clearSearch: normalized.isEmpty,
        clearCursor: true,
        resetPage: true,
      ),
      currentPage: 1,
    );
    loadInitial();
  }
}
