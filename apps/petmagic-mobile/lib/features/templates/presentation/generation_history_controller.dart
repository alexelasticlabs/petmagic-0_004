import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/generation_media_kind.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

part 'generation_history_controller_cache.part.dart';
part 'generation_history_controller_lifecycle.part.dart';
part 'generation_history_controller_sync.part.dart';

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

abstract class _GenerationHistoryControllerBase
    extends Notifier<GenerationHistoryState> {
  static const Duration _autoRefreshMinInterval = Duration(seconds: 8);
  static const Duration _autoRefreshMaxInterval = Duration(seconds: 30);

  TemplateGenerationRepository get _repository =>
      ref.read(templateGenerationRepositoryProvider);
  GenerationGalleryStore get _galleryStore =>
      ref.read(generationGalleryStoreProvider);
  RealtimeClient? _activeRealtimeClient;
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

  void setScreenVisible(bool visible, {bool clearLoadingState = true}) =>
      _setScreenVisible(visible, clearLoadingState: clearLoadingState);

  Future<void> refreshUnreadCount() => _refreshUnreadCount();

  Future<void> load({GenerationHistoryFilter? filter, bool refresh = false}) =>
      _load(filter: filter, refresh: refresh);

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

  CancelToken _startLoadCancelToken();

  void _clearActiveLoadCancelToken();

  void _drainPendingLoad();

  void _registerAutoRefreshSuccess();

  void _registerAutoRefreshFailure();

  void _scheduleOfflineBannerHide();

  Future<int?> _fetchUnreadGenerationCountBestEffort(CancelToken cancelToken);

  Future<void> _resumeRealtimeIfNeeded();

  Future<void> _mergeExternalGeneration(
    TemplateGenerationResult generation, {
    required bool refreshUnreadBadge,
    required bool requireScreenVisible,
  });

  List<TemplateGenerationResult> _decorateWithLocalMedia(
    List<TemplateGenerationResult> source,
    Set<String> deletedGenerationIds,
    List<GenerationGalleryMediaRecord> localReadyRecords,
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
    GenerationGalleryMediaRecord record,
  );
}

class GenerationHistoryController extends _GenerationHistoryControllerBase
    with
        _GenerationHistoryControllerCache,
        _GenerationHistoryControllerLifecycle,
        _GenerationHistoryControllerSync {
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
}
