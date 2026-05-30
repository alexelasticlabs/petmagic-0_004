import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';

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
  late final TemplateGenerationRepository _repository;
  late final RealtimeClient _realtimeClient;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  Timer? _offlineBannerTimer;
  bool _isScreenVisible = true;
  bool _isRealtimeConnected = false;

  @override
  GenerationHistoryState build() {
    _repository = ref.watch(templateGenerationRepositoryProvider);
    _realtimeClient = ref.watch(realtimeClientProvider);
    ref.onDispose(() {
      _offlineBannerTimer?.cancel();
      _offlineBannerTimer = null;
      _pauseRealtime();
    });
    Future.microtask(() async {
      final cachedUnread = await _repository.readCachedUnreadGenerationCount();
      if (cachedUnread != null) {
        state = state.copyWith(unreadCount: cachedUnread);
      }
      await refreshUnreadCount();
    });
    return const GenerationHistoryState();
  }

  void setScreenVisible(bool visible) {
    if (_isScreenVisible == visible) {
      return;
    }

    _isScreenVisible = visible;
    if (visible) {
      unawaited(_resumeRealtimeIfNeeded());
      return;
    }

    _pauseRealtime();
  }

  Future<void> load({
    GenerationHistoryFilter? filter,
    bool refresh = false,
  }) async {
    await _resumeRealtimeIfNeeded();

    final nextFilter = filter ?? state.filter;
    if (state.isLoading && !refresh && nextFilter == state.filter) {
      return;
    }

    final cachedItems = state.cachedItemsByFilter[nextFilter];
    if (!refresh && cachedItems != null) {
      state = state.copyWith(
        filter: nextFilter,
        items: cachedItems,
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
    }

    final seedItems = refresh
        ? (cachedItems ?? state.items)
        : (persistedItems ?? const []);

    state = state.copyWith(
      items: seedItems,
      filter: nextFilter,
      isLoading: true,
      syncFailed: false,
      clearError: true,
    );

    if (persistedItems != null) {
      final persistedCache =
          Map<GenerationHistoryFilter, List<TemplateGenerationResult>>.from(
            state.cachedItemsByFilter,
          )..[nextFilter] = persistedItems;
      state = state.copyWith(cachedItemsByFilter: persistedCache);
    }

    try {
      final wasOffline = state.syncFailed;
      final items = await _repository.fetchGenerations(
        status: nextFilter.apiStatus,
        take: 50,
      );
      final unreadCount = await _repository.fetchUnreadGenerationCount();
      final updatedCache =
          Map<GenerationHistoryFilter, List<TemplateGenerationResult>>.from(
            state.cachedItemsByFilter,
          )..[nextFilter] = items;
      final nowUtc = DateTime.now().toUtc();
      state = state.copyWith(
        items: items,
        unreadCount: unreadCount,
        isLoading: false,
        syncFailed: false,
        showOfflineBanner: wasOffline && items.isNotEmpty,
        isConnectionRecovered: wasOffline && items.isNotEmpty,
        lastSyncedAtUtc: nowUtc,
        cachedItemsByFilter: updatedCache,
        clearError: true,
      );

      if (wasOffline && items.isNotEmpty) {
        _scheduleOfflineBannerHide();
      }
    } catch (error) {
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
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  void _scheduleOfflineBannerHide() {
    _offlineBannerTimer?.cancel();
    _offlineBannerTimer = Timer(const Duration(seconds: 3), () {
      state = state.copyWith(
        showOfflineBanner: false,
        isConnectionRecovered: false,
      );
    });
  }

  Future<void> refreshUnreadCount() async {
    try {
      final unreadCount = await _repository.fetchUnreadGenerationCount();
      state = state.copyWith(unreadCount: unreadCount);
    } catch (_) {}
  }

  Future<void> markRead(String generationId) async {
    await _repository.markGenerationRead(generationId);
    final updated = _markReadInList(state.items, generationId);
    final updatedCache = _markReadInCaches(
      state.cachedItemsByFilter,
      generationId,
    );
    state = state.copyWith(
      items: updated,
      cachedItemsByFilter: updatedCache,
      unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
    );
  }

  Future<void> deleteGeneration(String generationId) async {
    await _repository.deleteGeneration(generationId);

    final wasUnread = state.items.any(
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

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (!_isScreenVisible) {
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
      _upsertGeneration(generation);
      unawaited(refreshUnreadCount());
    } catch (_) {}
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
      // Realtime is best-effort; gallery remains available via manual refresh.
    }
  }

  void _pauseRealtime() {
    unawaited(_realtimeSubscription?.cancel());
    _realtimeSubscription = null;

    if (_isRealtimeConnected) {
      unawaited(_realtimeClient.disconnect());
      _isRealtimeConnected = false;
    }
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
    final next = [
      for (final item in source)
        if (item.generationId != generation.generationId) item,
    ];

    if (_matchesFilter(generation, filter)) {
      next.insert(0, generation);
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
          _copyWithUnread(item, isUnread: false)
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

  TemplateGenerationResult _copyWithUnread(
    TemplateGenerationResult item, {
    required bool isUnread,
  }) {
    return TemplateGenerationResult(
      generationId: item.generationId,
      userId: item.userId,
      templateId: item.templateId,
      status: item.status,
      tokenCost: item.tokenCost,
      attemptCount: item.attemptCount,
      createdAtUtc: item.createdAtUtc,
      updatedAtUtc: item.updatedAtUtc,
      userMediaExpired: item.userMediaExpired,
      templateTitle: item.templateTitle,
      templateType: item.templateType,
      stage: item.stage,
      progressPercent: item.progressPercent,
      estimatedDurationLabel: item.estimatedDurationLabel,
      sourceImageAsset: item.sourceImageAsset,
      normalizedImageUrl: item.normalizedImageUrl,
      referenceMotionUrl: item.referenceMotionUrl,
      outputUrl: item.outputUrl,
      usedPreprocessingModel: item.usedPreprocessingModel,
      usedKlingModel: item.usedKlingModel,
      outputVideoDurationSeconds: item.outputVideoDurationSeconds,
      failureCode: item.failureCode,
      failureMessage: item.failureMessage,
      startedAtUtc: item.startedAtUtc,
      preprocessingCompletedAtUtc: item.preprocessingCompletedAtUtc,
      motionGenerationCompletedAtUtc: item.motionGenerationCompletedAtUtc,
      mediaImportCompletedAtUtc: item.mediaImportCompletedAtUtc,
      completedAtUtc: item.completedAtUtc,
      chargedAtUtc: item.chargedAtUtc,
      refundedAtUtc: item.refundedAtUtc,
      isUnread: isUnread,
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
}
