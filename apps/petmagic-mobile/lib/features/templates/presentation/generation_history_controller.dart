import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
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
  static const Duration _autoRefreshMinInterval = Duration(seconds: 8);
  static const Duration _autoRefreshMaxInterval = Duration(seconds: 30);

  TemplateGenerationRepository get _repository =>
      ref.read(templateGenerationRepositoryProvider);
  RealtimeClient get _realtimeClient => ref.read(realtimeClientProvider);
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  Timer? _offlineBannerTimer;
  Timer? _autoRefreshTimer;
  bool _isScreenVisible = false;
  bool _isRealtimeConnected = false;
  bool _isLoadInFlight = false;
  int _autoRefreshFailureStreak = 0;

  @override
  GenerationHistoryState build() {
    ref.watch(templateGenerationRepositoryProvider);
    ref.watch(realtimeClientProvider);
    ref.onDispose(() {
      _isScreenVisible = false;
      _offlineBannerTimer?.cancel();
      _offlineBannerTimer = null;
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
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

  void setScreenVisible(bool visible) {
    if (_isScreenVisible == visible) {
      return;
    }

    _isScreenVisible = visible;
    if (visible) {
      _startAutoRefresh();
      unawaited(_resumeRealtimeIfNeeded());
      return;
    }

    _stopAutoRefresh();
    _pauseRealtime();
  }

  Future<void> load({
    GenerationHistoryFilter? filter,
    bool refresh = false,
  }) async {
    if (_isLoadInFlight) {
      return;
    }

    _isLoadInFlight = true;
    try {
      await _resumeRealtimeIfNeeded();
      if (!ref.mounted) {
        return;
      }

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
        if (!ref.mounted) {
          return;
        }
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
        if (!ref.mounted) {
          return;
        }

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
        _registerAutoRefreshSuccess();

        if (wasOffline && items.isNotEmpty) {
          _scheduleOfflineBannerHide();
        }
      } catch (error) {
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
      _isLoadInFlight = false;
    }
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
    if (!ref.mounted || !_isScreenVisible) {
      return;
    }

    try {
      final unreadCount = await _repository.fetchUnreadGenerationCount();
      if (!ref.mounted) {
        return;
      }

      state = state.copyWith(unreadCount: unreadCount);
    } catch (_) {}
  }

  Future<void> markRead(String generationId) async {
    await _repository.markGenerationRead(generationId);
    if (!ref.mounted) {
      return;
    }

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
    if (!ref.mounted) {
      return;
    }

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
      _upsertGeneration(generation);
      unawaited(refreshUnreadCount());
    } catch (_) {}
  }

  Future<void> _resumeRealtimeIfNeeded() async {
    if (!ref.mounted || !_isScreenVisible) {
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
      if (!ref.mounted) {
        return;
      }

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
