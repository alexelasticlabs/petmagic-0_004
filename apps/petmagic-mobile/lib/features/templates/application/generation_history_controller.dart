import 'dart:async';

// Public generation history application state.

import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/application/generation_gallery_cache.dart';
import 'package:petmagic_mobile/features/templates/application/generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/generation_media_kind.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/application/template_error_key_mapper.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

part 'generation_history_controller_cache.part.dart';
part 'generation_history_controller_cache_policy.part.dart';
part 'generation_history_controller_lifecycle.part.dart';
part 'generation_history_controller_realtime.part.dart';
part 'generation_history_controller_sync.part.dart';
part 'generation_history_controller_mutations.part.dart';

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
      GenerationHistoryFilter.ready => 'completed',
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
    this.isLoadingMore = false,
    this.syncFailed = false,
    this.showOfflineBanner = false,
    this.isConnectionRecovered = false,
    this.nextCursor,
    this.hasMore = false,
    this.loadMoreError,
    this.lastSyncedAtUtc,
    this.errorMessage,
    this.cachedItemsByFilter = const {},
  });

  final List<TemplateGenerationResult> items;
  final GenerationHistoryFilter filter;
  final int unreadCount;
  final bool isLoading;
  final bool isLoadingMore;
  final bool syncFailed;
  final bool showOfflineBanner;
  final bool isConnectionRecovered;
  final String? nextCursor;
  final bool hasMore;
  final String? loadMoreError;
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
    bool? isLoadingMore,
    bool? syncFailed,
    bool? showOfflineBanner,
    bool? isConnectionRecovered,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
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
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      syncFailed: syncFailed ?? this.syncFailed,
      showOfflineBanner: showOfflineBanner ?? this.showOfflineBanner,
      isConnectionRecovered:
          isConnectionRecovered ?? this.isConnectionRecovered,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      loadMoreError: clearLoadMoreError
          ? null
          : loadMoreError ?? this.loadMoreError,
      lastSyncedAtUtc: clearLastSyncedAtUtc
          ? null
          : lastSyncedAtUtc ?? this.lastSyncedAtUtc,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      cachedItemsByFilter: cachedItemsByFilter ?? this.cachedItemsByFilter,
    );
  }
}

abstract class _GenerationHistoryControllerBase
    extends Notifier<GenerationHistoryState> {
  static const Duration _autoRefreshMinInterval = Duration(seconds: 8);
  static const Duration _autoRefreshMaxInterval = Duration(seconds: 30);
  static const Duration _idleRealtimeRefreshInterval = Duration(minutes: 5);

  GenerationRepository get _repository =>
      ref.read(templateGenerationRepositoryProvider);
  GenerationGalleryCache get _galleryStore =>
      ref.read(generationGalleryStoreProvider);
  RealtimeClient? _activeRealtimeClient;
  Future<void>? _realtimeConnectFuture;
  Timer? _offlineBannerTimer;
  Timer? _autoRefreshTimer;
  bool _isScreenVisible = false;
  bool _hasInternet = true;
  bool _isAuthenticated = false;
  bool _isRealtimeConnected = false;
  bool _isLoadInFlight = false;
  bool _isLoadMoreInFlight = false;
  bool _hasScheduledLocalArtifactCleanup = false;
  RequestCancellation? _activeLoadRequestCancellation;
  RequestCancellation? _activeLoadMoreRequestCancellation;
  RequestCancellation? _activeUnreadRefreshRequestCancellation;
  final Map<String, RequestCancellation>
  _activeRealtimeRefetchRequestCancellations = <String, RequestCancellation>{};
  _GenerationHistoryLoadRequest? _pendingLoadRequest;
  Completer<void>? _pendingLoadCompleter;
  Set<String> _locallyDeletedGenerationIds = const {};
  Set<String> _locallyDeletedUnreadGenerationIds = const {};
  Set<String> _locallyReadGenerationIds = const {};
  Set<String> _locallyReadUnreadGenerationIds = const {};
  int _autoRefreshFailureStreak = 0;
  int _loadEpoch = 0;

  void setScreenVisible(bool visible, {bool clearLoadingState = true}) =>
      _setScreenVisible(visible, clearLoadingState: clearLoadingState);

  Future<void> refreshUnreadCount() => _refreshUnreadCount();

  Future<void> load({GenerationHistoryFilter? filter, bool refresh = false}) =>
      _load(filter: filter, refresh: refresh);

  Future<void> loadMore() => _loadMore();

  Future<void> markRead(String generationId) => _markRead(generationId);

  Future<void> deleteGeneration(String generationId) =>
      _deleteGeneration(generationId);

  Future<void> submitFeedback({
    required String generationId,
    required int rating,
    List<String> selectedReasons = const [],
    String? comment,
  }) => _submitFeedback(
    generationId: generationId,
    rating: rating,
    selectedReasons: selectedReasons,
    comment: comment,
  );

  Future<void> mergeFetchedGeneration(TemplateGenerationResult generation) =>
      _mergeFetchedGeneration(generation);

  void _setScreenVisible(bool visible, {bool clearLoadingState = true});

  Future<void> _refreshUnreadCount();

  Future<void> _load({GenerationHistoryFilter? filter, bool refresh = false});

  Future<void> _loadMore();

  Future<void> _markRead(String generationId);

  Future<void> _deleteGeneration(String generationId);

  Future<void> _submitFeedback({
    required String generationId,
    required int rating,
    List<String> selectedReasons = const [],
    String? comment,
  });

  Future<void> _mergeFetchedGeneration(TemplateGenerationResult generation);

  void _completeCancelledLoad();

  RequestCancellation _startLoadRequestCancellation();

  void _clearActiveLoadRequestCancellation(RequestCancellation cancelToken);

  RequestCancellation _startLoadMoreRequestCancellation();

  void _clearActiveLoadMoreRequestCancellation();

  void _cancelActiveLoadMore(String reason);

  void _drainPendingLoad();

  void _registerAutoRefreshSuccess();

  void _registerAutoRefreshFailure();

  void _scheduleOfflineBannerHide();

  void _scheduleNextAutoRefresh();

  Future<int?> _fetchUnreadGenerationCountBestEffort(
    RequestCancellation cancelToken,
  );

  Future<void> _resumeRealtimeIfNeeded();

  void _pauseRealtime();

  void _cancelActiveRealtimeRefetches(String reason);

  Future<void> _mergeExternalGeneration(
    TemplateGenerationResult generation, {
    required bool refreshUnreadBadge,
    required bool requireScreenVisible,
  });

  List<TemplateGenerationResult> _decorateWithLocalMedia(
    List<TemplateGenerationResult> source,
    Set<String> deletedGenerationIds,
    List<GenerationGalleryMediaRecordView> localReadyRecords,
  );

  Future<Set<String>> _loadDeletedUnreadGenerationIds({
    required Set<String> deletedGenerationIds,
    required List<TemplateGenerationResult> remoteItems,
  });

  int _visibleUnreadCount(int unreadCount);

  void _reconcileLocallyReadIds(List<TemplateGenerationResult> remoteItems);

  TemplateGenerationResult? _findGeneration(String generationId);

  List<TemplateGenerationResult> _markReadInList(
    List<TemplateGenerationResult> source,
    String generationId,
  );

  Map<GenerationHistoryFilter, List<TemplateGenerationResult>>
  _markReadInCaches(
    Map<GenerationHistoryFilter, List<TemplateGenerationResult>> caches,
    String generationId,
  );

  List<TemplateGenerationResult> _removeGenerationFromList(
    List<TemplateGenerationResult> source,
    String generationId,
  );

  Map<GenerationHistoryFilter, List<TemplateGenerationResult>>
  _removeGenerationFromCaches(
    Map<GenerationHistoryFilter, List<TemplateGenerationResult>> caches,
    String generationId,
  );

  void _upsertGeneration(TemplateGenerationResult generation);

  TemplateGenerationResult _applyLocalRecordToGeneration(
    TemplateGenerationResult generation,
    GenerationGalleryMediaRecordView record,
  );
}

class GenerationHistoryController extends _GenerationHistoryControllerBase
    with
        _GenerationHistoryControllerCache,
        _GenerationHistoryControllerLifecycle,
        _GenerationHistoryControllerMutations,
        _GenerationHistoryControllerSync,
        _GenerationHistoryControllerRealtime {
  @override
  GenerationHistoryState build() {
    final galleryStore = ref.read(generationGalleryStoreProvider);
    _activeRealtimeClient = ref.read(realtimeClientProvider);
    _hasInternet = ref.read(networkStatusControllerProvider).hasInternet;
    _isAuthenticated = ref.read(appLaunchControllerProvider).isAuthenticated;
    ref.listen<bool>(
      appLaunchControllerProvider.select((state) => state.isAuthenticated),
      (_, isAuthenticated) => _handleAuthStatusChanged(isAuthenticated),
    );
    ref.listen<bool>(
      networkStatusControllerProvider.select((state) => state.hasInternet),
      (_, hasInternet) => _handleNetworkStatusChanged(hasInternet),
    );
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
      _cancelActiveLoadMore('generation_history_disposed');
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
}

// Public generation history application controller.
