import 'dart:async';

// Public template catalog application state.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

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

const Object _templateOfTheDayUnchanged = Object();
const int _realtimePayloadStringMaxLength = 128;

class _TemplateFeedInvalidation {
  const _TemplateFeedInvalidation({
    required this.scope,
    this.templateId,
    this.category,
    this.mediaVersion,
    this.templateType,
    this.isPubliclyVisible,
    this.isCritical = false,
    this.reason,
  });

  final String scope;
  final String? templateId;
  final String? category;
  final int? mediaVersion;
  final String? templateType;
  final bool? isPubliclyVisible;
  final bool isCritical;
  final String? reason;

  bool get isFull => scope == 'full';
  bool get isTemplate => scope == 'template';
  bool get isCategory => scope == 'category';
  bool get isTemplateOfTheDay => scope == 'templateOfTheDay';
  bool get isUnavailable => isPubliclyVisible == false || isCritical;
  bool get hasMediaChange => mediaVersion != null;

  static _TemplateFeedInvalidation? fromPayload(Map<String, Object?> payload) {
    if (payload.isEmpty) {
      return const _TemplateFeedInvalidation(scope: 'full');
    }

    final scope = _readString(payload['scope']);
    if (scope == null) {
      return null;
    }

    return _TemplateFeedInvalidation(
      scope: scope,
      templateId: _readString(payload['templateId']),
      category: _readString(payload['category']),
      mediaVersion: _readInt(payload['mediaVersion']),
      templateType: _readString(payload['templateType']),
      isPubliclyVisible: _readBool(payload['isPubliclyVisible']),
      isCritical: _readBool(payload['isCritical']) ?? false,
      reason: _readString(payload['reason']),
    );
  }

  static String? _readString(Object? value) {
    if (value is! String) {
      return null;
    }

    final text = value.trim();
    if (text.length > _realtimePayloadStringMaxLength) {
      return null;
    }

    return text.isEmpty ? null : text;
  }

  static int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String && value.length <= 20) {
      return int.tryParse(value);
    }
    return null;
  }

  static bool? _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is! String || value.length > 5) {
      return null;
    }

    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
    return null;
  }
}

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

  TemplatesRepository get _repository =>
      _activeRepository ?? ref.read(templatesRepositoryProvider);
  TemplatesRepository? _activeRepository;
  RealtimeClient? _activeRealtimeClient;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  Timer? _realtimeRefreshTimer;
  bool _hasPendingRealtimeRefresh = false;
  bool _isRealtimeRefreshInFlight = false;
  int _requestVersion = 0;
  int _preloadVersion = 0;
  int _activePreviewWarmupTasks = 0;
  int _staleResponsesDiscarded = 0;
  int _preloadCancellations = 0;
  Future<void>? _inFlightInitialLoad;
  String? _inFlightInitialQueryKey;
  bool? _inFlightInitialForceRefresh;
  int? _inFlightInitialKnownCatalogVersion;
  bool _hasInternet = true;
  bool _isScreenVisible = true;
  bool _isRealtimeConnected = false;

  int get staleResponsesDiscarded => _staleResponsesDiscarded;
  int get preloadCancellations => _preloadCancellations;

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
    _activeRepository = ref.read(templatesRepositoryProvider);
    _activeRealtimeClient = ref.read(realtimeClientProvider);
    _hasInternet = ref.read(networkStatusControllerProvider).hasInternet;
    ref.listen<bool>(
      networkStatusControllerProvider.select((state) => state.hasInternet),
      (_, hasInternet) => _handleNetworkStatusChanged(hasInternet),
    );
    unawaited(_resumeRealtimeIfNeeded());
    ref.onDispose(() {
      _invalidateActiveFeedWork(
        clearLoadingState: false,
        reason: 'dispose',
        repository: _activeRepository,
      );
      _pauseRealtime();
    });
    return const TemplatesState();
  }

  void _handleNetworkStatusChanged(bool hasInternet) {
    if (_hasInternet == hasInternet) {
      return;
    }

    _hasInternet = hasInternet;
    if (!hasInternet) {
      _pauseRealtime();
      _invalidateActiveFeedWork(
        clearLoadingState: true,
        reason: 'network_offline',
      );
      return;
    }

    if (!_isScreenVisible) {
      return;
    }

    unawaited(_resumeRealtimeIfNeeded());
    _resumePendingRealtimeRefreshIfNeeded();
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
    _isRealtimeRefreshInFlight = false;
    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = null;
    _hasPendingRealtimeRefresh = false;
    final resolvedRepository = repository ?? _repository;
    final cancelledPreviewPreloads = _invalidatePreviewPreloads(
      reason,
      repository: resolvedRepository,
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

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (!_isScreenVisible) {
      return;
    }

    if (event.topic != RealtimeTopics.templatesFeedInvalidated) {
      return;
    }

    final invalidation = _TemplateFeedInvalidation.fromPayload(event.payload);
    if (invalidation == null) {
      return;
    }

    if (invalidation.isFull) {
      _handleFullRealtimeInvalidation();
      return;
    }

    if (invalidation.isCategory) {
      _recordScopedRealtimeInvalidation(invalidation);
      unawaited(_refreshCategoriesFromRealtime());
      return;
    }

    if (invalidation.isTemplateOfTheDay) {
      _recordScopedRealtimeInvalidation(invalidation);
      unawaited(_loadTemplateOfTheDay(_requestVersion));
      return;
    }

    if (invalidation.isTemplate) {
      _recordScopedRealtimeInvalidation(invalidation);
      unawaited(_applyTemplateRealtimeInvalidation(invalidation));
      return;
    }

    _handleFullRealtimeInvalidation();
  }

  void _handleFullRealtimeInvalidation() {
    if (state.isLoadingMore) {
      _recordRealtimeBusyIntersection('pagination');
      _hasPendingRealtimeRefresh = true;
      return;
    }

    if (state.isLoading || state.isRefreshing) {
      _recordRealtimeBusyIntersection(
        _isRealtimeRefreshInFlight ? 'realtime_refresh' : 'initial_refresh',
      );
      _hasPendingRealtimeRefresh = _isRealtimeRefreshInFlight;
      if (_hasPendingRealtimeRefresh) {
        _scheduleRealtimeRefresh();
      }
      return;
    }

    _hasPendingRealtimeRefresh = true;
    _scheduleRealtimeRefresh();
  }

  Future<void> _applyTemplateRealtimeInvalidation(
    _TemplateFeedInvalidation invalidation,
  ) async {
    final templateId = invalidation.templateId;
    if (templateId == null || templateId.isEmpty || !ref.mounted) {
      return;
    }

    final existingIndex = state.items.indexWhere(
      (item) => item.templateId == templateId,
    );
    final existing = existingIndex == -1 ? null : state.items[existingIndex];

    if (invalidation.isUnavailable) {
      _removeTemplateFromState(templateId);
      return;
    }

    if (existing == null) {
      return;
    }

    if (invalidation.hasMediaChange &&
        invalidation.mediaVersion != existing.mediaVersion) {
      await _invalidateTemplateMediaCache(existing);
    }

    try {
      final updated = await _repository.fetchTemplate(
        templateId,
        forceRefresh: true,
      );
      if (!ref.mounted || !_isScreenVisible) {
        return;
      }

      final currentIndex = state.items.indexWhere(
        (item) => item.templateId == templateId,
      );
      if (currentIndex == -1) {
        return;
      }

      final current = state.items[currentIndex];
      final resolved = invalidation.hasMediaChange
          ? updated
          : _mergeTemplateMetadataKeepingMedia(current, updated);
      _replaceTemplateInState(resolved);
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.Controller',
        operation: 'scoped_template_invalidation',
        message: 'Scoped template invalidation failed.',
        error: error,
        stackTrace: stackTrace,
        context: {
          'templateId': templateId,
          'scope': invalidation.scope,
          'reason': invalidation.reason,
        },
      );
    }
  }

  Future<void> _refreshCategoriesFromRealtime() async {
    try {
      final categories = _normalizeCategories(
        await _repository.fetchCategories(),
      );
      if (!ref.mounted || !_isScreenVisible) {
        return;
      }

      state = state.copyWith(categories: categories);
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.Controller',
        operation: 'realtime_category_invalidation',
        message: 'Template categories scoped invalidation failed.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _replaceTemplateInState(TemplateItem template) {
    final replacedItems = state.items
        .map((item) => item.templateId == template.templateId ? template : item)
        .toList(growable: false);
    final replacedCache = _mapCachedPages((page) {
      final pageItems = page.items
          .map(
            (item) => item.templateId == template.templateId ? template : item,
          )
          .toList(growable: false);
      return TemplatesFeedPage(
        items: pageItems,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        page: page.page,
      );
    });

    state = state.copyWith(
      items: replacedItems,
      cachedPagesByQueryKey: replacedCache,
    );
  }

  void _removeTemplateFromState(String templateId) {
    if (!ref.mounted) {
      return;
    }

    final filteredItems = state.items
        .where((item) => item.templateId != templateId)
        .toList(growable: false);
    if (filteredItems.length == state.items.length) {
      return;
    }

    final filteredCache = _mapCachedPages((page) {
      final pageItems = page.items
          .where((item) => item.templateId != templateId)
          .toList(growable: false);
      return TemplatesFeedPage(
        items: pageItems,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        page: page.page,
      );
    });

    state = state.copyWith(
      items: filteredItems,
      cachedPagesByQueryKey: filteredCache,
    );
  }

  Map<String, TemplatesFeedPage> _mapCachedPages(
    TemplatesFeedPage Function(TemplatesFeedPage page) mapPage,
  ) {
    if (state.cachedPagesByQueryKey.isEmpty) {
      return state.cachedPagesByQueryKey;
    }

    return state.cachedPagesByQueryKey.map(
      (key, page) => MapEntry(key, mapPage(page)),
    );
  }

  Future<void> _invalidateTemplateMediaCache(TemplateItem template) async {
    final mediaUrls = <String>{
      ...[
        _normalizeMediaUrl(template.thumbnailUrl),
        _normalizeMediaUrl(template.animatedPreviewUrl),
        _normalizeMediaUrl(template.feedLoopLowUrl),
        _normalizeMediaUrl(template.feedLoopMediumUrl),
        _normalizeMediaUrl(template.detailPreviewUrl),
        _normalizeMediaUrl(template.previewAsset?.url),
      ].whereType<String>(),
    };

    for (final url in mediaUrls) {
      await TemplateMediaCache.removeThumbnailFile(
        url,
        mediaVersion: template.mediaVersion,
      );
      await TemplateMediaCache.removePreviewFile(
        url,
        mediaVersion: template.mediaVersion,
      );
    }

    AppLogger.debug(
      feature: 'Templates.Controller',
      operation: 'mobile_media_redownload_after_sse',
      message: 'Invalidated scoped template media cache after SSE.',
      context: {
        'templateId': template.templateId,
        'mediaVersion': template.mediaVersion,
        'mediaUrls': mediaUrls.length,
      },
    );
  }

  TemplateItem _mergeTemplateMetadataKeepingMedia(
    TemplateItem current,
    TemplateItem updated,
  ) {
    return TemplateItem(
      templateId: updated.templateId,
      templateType: updated.templateType,
      title: updated.title,
      shortDescription: updated.shortDescription,
      petPhotoRequirements: updated.petPhotoRequirements,
      category: updated.category,
      tags: updated.tags,
      isPremium: updated.isPremium,
      tokenCost: updated.tokenCost,
      effectivePromoBadge: updated.effectivePromoBadge,
      thumbnailUrl: current.thumbnailUrl,
      animatedPreviewUrl: current.animatedPreviewUrl,
      feedLoopLowUrl: current.feedLoopLowUrl,
      feedLoopMediumUrl: current.feedLoopMediumUrl,
      detailPreviewUrl: current.detailPreviewUrl,
      mediaKind: current.mediaKind,
      durationMs: current.durationMs,
      sizeBytes: current.sizeBytes,
      mediaVersion: current.mediaVersion,
      previewAsset: current.previewAsset,
      musicDescription: updated.musicDescription,
      referenceVideoDurationSeconds: updated.referenceVideoDurationSeconds,
      supportsGenerationResultInput: updated.supportsGenerationResultInput,
      requiredInputMediaType: updated.requiredInputMediaType,
      recommendedAfterImageGeneration: updated.recommendedAfterImageGeneration,
      supportsGenerateSimilar: updated.supportsGenerateSimilar,
      defaultVariationStrength: updated.defaultVariationStrength,
      version: updated.version,
      updatedAtUtc: updated.updatedAtUtc,
    );
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
    _isRealtimeRefreshInFlight = true;
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
    } finally {
      _isRealtimeRefreshInFlight = false;
    }
  }

  void _recordRealtimeBusyIntersection(String activeRequest) {
    AppLogger.debug(
      feature: 'Templates.Controller',
      operation: 'realtime_invalidation_during_active_request',
      message: 'Templates feed invalidation arrived during an active request.',
      context: {
        'activeRequest': activeRequest,
        'requestVersion': _requestVersion,
      },
    );
  }

  void _recordScopedRealtimeInvalidation(
    _TemplateFeedInvalidation invalidation,
  ) {
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

  void _resumePendingRealtimeRefreshIfNeeded() {
    if (_isScreenVisible && _hasPendingRealtimeRefresh) {
      _scheduleRealtimeRefresh();
    }
  }

  Future<void> _resumeRealtimeIfNeeded() async {
    if (!_isScreenVisible || !_hasInternet) {
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
          !_hasInternet ||
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
    _invalidatePreviewPreloads('initial_request_started');
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
      if (!_isCurrentFeedRequest(requestVersion)) {
        _recordStaleResponseDiscarded(
          requestVersion: requestVersion,
          operation: 'read_cached_first_page',
        );
        return;
      }

      if (cached != null) {
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
      if (!_isCurrentFeedRequest(requestVersion)) {
        _recordStaleResponseDiscarded(
          requestVersion: requestVersion,
          operation: 'fetch_feed_initial',
        );
        return;
      }

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
          preloadVersion: _preloadVersion,
          queryKey: queryKey,
        ),
      );
      if (state.categories.isEmpty || forceRefresh) {
        unawaited(_refreshCategories(requestVersion));
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
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.Controller',
        operation: 'refresh_categories',
        message: 'Template categories refresh failed.',
        error: error,
        stackTrace: stackTrace,
        context: {
          'screenVisible': _isScreenVisible,
          'requestVersion': requestVersion,
        },
      );
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
      items: const [],
      clearItemsQueryKey: true,
      clearNextCursor: true,
      hasMore: true,
      isLoading: true,
      isRefreshing: false,
      isLoadingMore: false,
      clearError: true,
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
      items: const [],
      clearItemsQueryKey: true,
      clearNextCursor: true,
      hasMore: true,
      isLoading: true,
      isRefreshing: false,
      isLoadingMore: false,
      clearError: true,
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
      items: const [],
      clearItemsQueryKey: true,
      clearNextCursor: true,
      hasMore: true,
      isLoading: true,
      isRefreshing: false,
      isLoadingMore: false,
      clearError: true,
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
    required int preloadVersion,
    required String queryKey,
  }) async {
    final uniqueItems = <({String url, int? mediaVersion})>[];
    final uniqueKeys = <String>{};
    for (final item in items.take(_warmupPreviewLimit)) {
      final thumbnailUrl = _normalizeMediaUrl(item.thumbnailUrl);
      final previewUrl = _normalizeMediaUrl(item.previewAsset?.url);
      final isPreviewVideo = isVideoUrl(previewUrl);
      final preferred = thumbnailUrl != null && !isVideoUrl(thumbnailUrl)
          ? thumbnailUrl
          : (!isPreviewVideo ? previewUrl : null);
      if (preferred != null &&
          uniqueKeys.add(
            TemplateMediaCache.cacheKeyForMedia(
              preferred,
              mediaVersion: item.mediaVersion,
            ),
          )) {
        uniqueItems.add((url: preferred, mediaVersion: item.mediaVersion));
      }
    }

    _activePreviewWarmupTasks++;
    try {
      for (final item in uniqueItems) {
        if (!_shouldContinuePreviewWarmup(
          requestVersion,
          preloadVersion,
          queryKey,
        )) {
          _recordPreloadCancellation('before_url');
          return;
        }
        await _warmupSingleUrl(item.url, mediaVersion: item.mediaVersion);
        if (!_shouldContinuePreviewWarmup(
          requestVersion,
          preloadVersion,
          queryKey,
        )) {
          _recordPreloadCancellation('after_url');
          return;
        }
      }
    } finally {
      _activePreviewWarmupTasks -= 1;
    }
  }

  Future<void> _warmupSingleUrl(String url, {int? mediaVersion}) async {
    try {
      await ref.read(templateThumbnailWarmupProvider)(
        url,
        mediaVersion: mediaVersion,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.Controller',
        operation: 'warmup_single_url',
        message: 'Template preview warmup failed.',
        error: error,
        stackTrace: stackTrace,
        context: {'screenVisible': _isScreenVisible},
      );
    }
  }

  bool _shouldContinuePreviewWarmup(
    int requestVersion,
    int preloadVersion,
    String queryKey,
  ) {
    if (!ref.mounted ||
        !_isScreenVisible ||
        requestVersion != _requestVersion ||
        preloadVersion != _preloadVersion ||
        state.itemsQueryKey != queryKey) {
      return false;
    }

    return state.query.copyWith(resetPage: true).cacheKey == queryKey;
  }

  bool _invalidatePreviewPreloads(
    String reason, {
    TemplatesRepository? repository,
  }) {
    _preloadVersion++;
    if (_activePreviewWarmupTasks <= 0) {
      return false;
    }

    (repository ?? _repository).cancelPendingMetadataRequests();
    _recordPreloadCancellation(reason);
    return true;
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

  void _recordPreloadCancellation(String reason) {
    _preloadCancellations++;
    AppLogger.debug(
      feature: 'Templates.Controller',
      operation: 'preload_cancellations',
      message: 'Cancelled stale template preview preload work.',
      context: {
        'reason': reason,
        'requestVersion': _requestVersion,
        'preloadVersion': _preloadVersion,
        'count': _preloadCancellations,
      },
    );
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

// Public templates application controller.
