import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

final templatesControllerProvider =
    NotifierProvider<TemplatesController, TemplatesState>(
      TemplatesController.new,
    );

final templateThumbnailWarmupProvider = Provider<Future<void> Function(String)>(
  (ref) {
    return (url) async {
      await TemplateMediaCache.fetchThumbnailFile(url);
    };
  },
);

const Object _templateOfTheDayUnchanged = Object();

class TemplatesState {
  const TemplatesState({
    this.items = const [],
    this.categories = const [],
    this.query = const TemplatesQuery(),
    this.catalogVersion = 0,
    this.currentPage = 1,
    this.nextCursor,
    this.itemsQueryKey,
    this.cachedPagesByQueryKey = const {},
    this.hasMore = true,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.loadedFromCache = false,
    this.templateOfTheDay,
    this.isTemplateOfTheDayLoading = false,
    this.templateOfTheDayError,
    this.errorMessage,
  });

  final List<TemplateItem> items;
  final List<String> categories;
  final TemplatesQuery query;
  final int catalogVersion;
  final int currentPage;
  final String? nextCursor;
  final String? itemsQueryKey;
  final Map<String, TemplatesFeedPage> cachedPagesByQueryKey;
  final bool hasMore;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool loadedFromCache;
  final TemplateOfTheDayItem? templateOfTheDay;
  final bool isTemplateOfTheDayLoading;
  final String? templateOfTheDayError;
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
    String? nextCursor,
    bool clearNextCursor = false,
    String? itemsQueryKey,
    bool clearItemsQueryKey = false,
    Map<String, TemplatesFeedPage>? cachedPagesByQueryKey,
    bool? hasMore,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? loadedFromCache,
    Object? templateOfTheDay = _templateOfTheDayUnchanged,
    bool? isTemplateOfTheDayLoading,
    String? templateOfTheDayError,
    bool clearTemplateOfTheDayError = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TemplatesState(
      items: items ?? this.items,
      categories: categories ?? this.categories,
      query: query ?? this.query,
      catalogVersion: catalogVersion ?? this.catalogVersion,
      currentPage: currentPage ?? this.currentPage,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
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
      templateOfTheDay: identical(templateOfTheDay, _templateOfTheDayUnchanged)
          ? this.templateOfTheDay
          : templateOfTheDay as TemplateOfTheDayItem?,
      isTemplateOfTheDayLoading:
          isTemplateOfTheDayLoading ?? this.isTemplateOfTheDayLoading,
      templateOfTheDayError: clearTemplateOfTheDayError
          ? null
          : templateOfTheDayError ?? this.templateOfTheDayError,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class TemplatesController extends Notifier<TemplatesState> {
  static const _realtimeRefreshDebounce = Duration(milliseconds: 350);
  static const _warmupPreviewLimit = 6;
  static const _maxInMemoryFeedCaches = 6;

  TemplatesRepository get _repository => ref.read(templatesRepositoryProvider);
  RealtimeClient? _activeRealtimeClient;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  Timer? _realtimeRefreshTimer;
  bool _hasPendingRealtimeRefresh = false;
  int _requestVersion = 0;
  Future<void>? _inFlightInitialLoad;
  String? _inFlightInitialQueryKey;
  bool? _inFlightInitialForceRefresh;
  int? _inFlightInitialKnownCatalogVersion;
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
    _activeRealtimeClient = ref.watch(realtimeClientProvider);
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

    _cancelActiveFeedWork();
    _pauseRealtime();
  }

  void _cancelActiveFeedWork() {
    _requestVersion++;
    _inFlightInitialLoad = null;
    _inFlightInitialQueryKey = null;
    _inFlightInitialForceRefresh = null;
    _inFlightInitialKnownCatalogVersion = null;
    _repository.cancelPendingFeedRequest();
    _repository.cancelPendingMetadataRequests();
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

      await loadInitial(forceRefresh: true, knownCatalogVersion: latestVersion);
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

    try {
      await realtimeClient.connect();
      if (!ref.mounted ||
          !_isScreenVisible ||
          !identical(_activeRealtimeClient, realtimeClient)) {
        unawaited(realtimeClient.disconnect());
        return;
      }
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

    final realtimeClient = _activeRealtimeClient;
    if (_isRealtimeConnected && realtimeClient != null) {
      unawaited(realtimeClient.disconnect());
      _isRealtimeConnected = false;
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
    if (_shouldLoadTemplateOfTheDay(forceRefresh: forceRefresh)) {
      unawaited(_loadTemplateOfTheDay(requestVersion));
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
          unawaited(_refreshCategories(requestVersion));
        }
        _resumePendingRealtimeRefreshIfNeeded();
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
      if (cached != null && requestVersion == _requestVersion) {
        final updatedCache = _rememberFeedPage(
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
          unawaited(_refreshCategories(requestVersion));
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
      if (requestVersion != _requestVersion) return;

      final updatedCache = _rememberFeedPage(
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
        _warmupTemplatePreviews(
          page.items,
          requestVersion: requestVersion,
          queryKey: queryKey,
        ),
      );
      if (state.categories.isEmpty || forceRefresh) {
        unawaited(_refreshCategories(requestVersion));
      }
    } on RequestCancelledException {
      if (requestVersion != _requestVersion) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
      );
    } on AppException catch (error) {
      if (requestVersion != _requestVersion) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        errorMessage: error.message,
      );
    } catch (error) {
      if (requestVersion != _requestVersion) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        errorMessage: 'templates.request_failed',
      );
    } finally {
      _resumePendingRealtimeRefreshIfNeeded();
    }
  }

  bool _shouldLoadTemplateOfTheDay({required bool forceRefresh}) {
    if (forceRefresh) {
      return true;
    }

    return state.templateOfTheDay == null &&
        state.templateOfTheDayError == null &&
        !state.isTemplateOfTheDayLoading;
  }

  Future<void> _refreshCategories(int requestVersion) async {
    try {
      final categories = _normalizeCategories(
        await _repository.fetchCategories(),
      );
      if (!ref.mounted ||
          !_isScreenVisible ||
          requestVersion != _requestVersion) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!ref.mounted ||
            !_isScreenVisible ||
            requestVersion != _requestVersion) {
          return;
        }
        state = state.copyWith(categories: categories);
      });
    } catch (_) {
      // Categories are secondary for first paint.
    }
  }

  Future<void> _loadTemplateOfTheDay(int requestVersion) async {
    state = state.copyWith(
      isTemplateOfTheDayLoading: state.templateOfTheDay == null,
      clearTemplateOfTheDayError: true,
    );

    try {
      final template = await _repository.fetchTemplateOfTheDay();
      if (!ref.mounted || requestVersion != _requestVersion) {
        return;
      }

      state = state.copyWith(
        templateOfTheDay: template,
        isTemplateOfTheDayLoading: false,
        clearTemplateOfTheDayError: true,
      );
      final previewUrl = _normalizeMediaUrl(
        template?.thumbnailUrl ?? template?.previewMediaUrl,
      );
      if (_isScreenVisible && previewUrl != null && !isVideoUrl(previewUrl)) {
        unawaited(_warmTemplateOfTheDayThumbnail(previewUrl));
      }
    } on Object catch (error, stackTrace) {
      if (!ref.mounted || requestVersion != _requestVersion) {
        return;
      }

      AppLogger.warn(
        feature: 'Templates.TemplateOfTheDay',
        operation: 'load',
        message: 'Template of the Day load failed',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        templateOfTheDay: null,
        isTemplateOfTheDayLoading: false,
        templateOfTheDayError: 'templates.template_of_the_day_load_failed',
      );
    }
  }

  Future<void> _warmTemplateOfTheDayThumbnail(String url) async {
    try {
      await ref.read(templateThumbnailWarmupProvider)(url);
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.TemplateOfTheDay',
        operation: 'thumbnail_warmup',
        message: 'Template of the Day thumbnail warmup failed',
        error: error,
        stackTrace: stackTrace,
      );
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
      if (requestVersion != _requestVersion || !isCurrentQuery) {
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
      final updatedCache = _rememberFeedPage(
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

  Map<String, TemplatesFeedPage> _rememberFeedPage(
    Map<String, TemplatesFeedPage> current,
    String queryKey,
    TemplatesFeedPage page,
  ) {
    final updated = Map<String, TemplatesFeedPage>.from(current);
    updated.remove(queryKey);
    updated[queryKey] = page;

    while (updated.length > _maxInMemoryFeedCaches) {
      updated.remove(updated.keys.first);
    }

    return updated;
  }

  Future<void> _warmupTemplatePreviews(
    List<TemplateItem> items, {
    required int requestVersion,
    required String queryKey,
  }) async {
    final uniqueUrls = <String>{};
    for (final item in items.take(_warmupPreviewLimit)) {
      final thumbnailUrl = _normalizeMediaUrl(item.thumbnailUrl);
      final previewUrl = _normalizeMediaUrl(item.previewAsset?.url);
      final isPreviewVideo = isVideoUrl(previewUrl);
      final preferred = thumbnailUrl != null && !isVideoUrl(thumbnailUrl)
          ? thumbnailUrl
          : (!isPreviewVideo ? previewUrl : null);
      if (preferred != null) {
        uniqueUrls.add(preferred);
      }
    }

    const concurrencyLimit = 3;
    final urlList = uniqueUrls.toList();
    for (var i = 0; i < urlList.length; i += concurrencyLimit) {
      if (!_shouldContinuePreviewWarmup(requestVersion, queryKey)) {
        return;
      }

      final chunk = urlList.skip(i).take(concurrencyLimit).toList();
      await Future.wait(
        chunk.map(_warmupSingleUrl),
      );
    }
  }

  Future<void> _warmupSingleUrl(String url) async {
    try {
      await ref.read(templateThumbnailWarmupProvider)(url);
    } catch (_) {
      // Warmup is best-effort only.
    }
  }

  bool _shouldContinuePreviewWarmup(int requestVersion, String queryKey) {
    if (!ref.mounted ||
        !_isScreenVisible ||
        requestVersion != _requestVersion ||
        state.itemsQueryKey != queryKey) {
      return false;
    }

    return state.query.copyWith(resetPage: true).cacheKey == queryKey;
  }

  String? _normalizeMediaUrl(String? rawUrl) {
    final trimmed = rawUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final sanitized = Uri.encodeFull(trimmed.replaceAll('\\', '/'));
    final parsed = Uri.tryParse(sanitized);
    if (parsed?.hasScheme == true) {
      return parsed.toString();
    }

    final baseUri = Uri.tryParse(AppConfig.apiBaseUrl);
    if (baseUri == null) {
      return sanitized;
    }

    if (sanitized.startsWith('//')) {
      final scheme = baseUri.scheme.isNotEmpty ? baseUri.scheme : 'http';
      return '$scheme:$sanitized';
    }

    final relativePath = sanitized.startsWith('/') ? sanitized : '/$sanitized';
    return baseUri.resolve(relativePath).toString();
  }
}
