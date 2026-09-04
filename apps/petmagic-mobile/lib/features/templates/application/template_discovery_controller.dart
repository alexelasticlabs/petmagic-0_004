import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/features/templates/application/template_discovery_repository.dart';
import 'package:petmagic_mobile/features/templates/application/template_discovery_state.dart';

export 'template_discovery_state.dart';

final templateDiscoveryControllerProvider =
    NotifierProvider<TemplateDiscoveryController, TemplateDiscoveryState>(
      TemplateDiscoveryController.new,
    );

final templateDiscoveryClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final class TemplateDiscoveryController
    extends Notifier<TemplateDiscoveryState> {
  static const _refreshInterval = Duration(seconds: 45);

  TemplateDiscoveryRepository get _repository =>
      ref.read(templateDiscoveryRepositoryProvider);

  Future<void>? _activeLoad;
  TemplateDiscoveryRepository? _requestRepository;
  DateTime? _lastRemoteRefreshAtUtc;
  int _requestVersion = 0;
  bool _isScreenVisible = true;

  @override
  TemplateDiscoveryState build() {
    final repository = ref.read(templateDiscoveryRepositoryProvider);
    ref.onDispose(() {
      _requestVersion++;
      (_requestRepository ?? repository).cancelPendingRequest();
      _requestRepository = null;
    });
    return const TemplateDiscoveryState();
  }

  void setScreenVisible(bool visible) {
    if (_isScreenVisible == visible) {
      return;
    }

    _isScreenVisible = visible;
    if (!visible) {
      _requestVersion++;
      (_requestRepository ?? _repository).cancelPendingRequest();
      _requestRepository = null;
      _activeLoad = null;
      if (state.isLoading || state.isRefreshing) {
        state = state.copyWith(isLoading: false, isRefreshing: false);
      }
      return;
    }

    unawaited(refreshIfNeeded());
  }

  void handleNetworkUnavailable() {
    if (_activeLoad == null && _requestRepository == null) {
      return;
    }

    _requestVersion++;
    _requestRepository?.cancelPendingRequest();
    _requestRepository = null;
    _activeLoad = null;
    state = state.copyWith(
      isLoading: false,
      isRefreshing: false,
      errorMessage: 'templates.request_failed',
    );
  }

  void resetForLocale() {
    _requestVersion++;
    (_requestRepository ?? _repository).cancelPendingRequest();
    _requestRepository = null;
    _activeLoad = null;
    _lastRemoteRefreshAtUtc = null;
    state = const TemplateDiscoveryState();
    if (_isScreenVisible) {
      unawaited(loadInitial());
    }
  }

  Future<void> refreshIfNeeded() {
    if (!_isScreenVisible || !_needsRefresh) {
      return Future.value();
    }
    return loadInitial(forceRefresh: state.hasLoaded);
  }

  Future<void> loadInitial({bool forceRefresh = false}) {
    final active = _activeLoad;
    if (active != null) {
      return active;
    }

    late final Future<void> load;
    load = _load(forceRefresh: forceRefresh).whenComplete(() {
      if (identical(_activeLoad, load)) {
        _activeLoad = null;
      }
    });
    _activeLoad = load;
    return load;
  }

  Future<void> _load({required bool forceRefresh}) async {
    final requestVersion = ++_requestVersion;
    final repository = _repository;
    _requestRepository = repository;

    try {
      if (!forceRefresh && state.sections.isEmpty) {
        await _restoreCache(repository, requestVersion);
      }
      if (!_isCurrent(requestVersion)) {
        return;
      }

      state = state.copyWith(
        isLoading: state.sections.isEmpty,
        isRefreshing: state.sections.isNotEmpty,
        clearError: true,
      );

      final discovery = await repository.fetch();
      if (!_isCurrent(requestVersion)) {
        return;
      }

      _lastRemoteRefreshAtUtc = ref
          .read(templateDiscoveryClockProvider)()
          .toUtc();
      state = state.copyWith(
        sections: discovery.sections,
        isLoading: false,
        isRefreshing: false,
        loadedFromCache: false,
        hasLoaded: true,
        clearError: true,
      );
    } on RequestCancelledException {
      _finishCancelled(requestVersion);
    } on AppException catch (error, stackTrace) {
      _finishError(requestVersion, error.message, error, stackTrace);
    } catch (error, stackTrace) {
      _finishError(
        requestVersion,
        'templates.request_failed',
        error,
        stackTrace,
      );
    } finally {
      if (_requestVersion == requestVersion &&
          identical(_requestRepository, repository)) {
        _requestRepository = null;
      }
    }
  }

  Future<void> _restoreCache(
    TemplateDiscoveryRepository repository,
    int requestVersion,
  ) async {
    try {
      final cached = await repository.readCached();
      if (cached == null || !_isCurrent(requestVersion)) {
        return;
      }

      state = state.copyWith(
        sections: cached.sections,
        loadedFromCache: true,
        hasLoaded: true,
        clearError: true,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.Discovery',
        operation: 'restore_cache',
        message: 'Template discovery cache could not be restored.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _finishCancelled(int requestVersion) {
    if (!_isCurrent(requestVersion)) {
      return;
    }
    state = state.copyWith(isLoading: false, isRefreshing: false);
  }

  void _finishError(
    int requestVersion,
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!_isCurrent(requestVersion)) {
      return;
    }

    AppLogger.warn(
      feature: 'Templates.Discovery',
      operation: 'load',
      message: 'Template discovery feed could not be loaded.',
      error: error,
      stackTrace: stackTrace,
    );
    state = state.copyWith(
      isLoading: false,
      isRefreshing: false,
      hasLoaded: true,
      errorMessage: message,
    );
  }

  bool _isCurrent(int requestVersion) =>
      ref.mounted && _isScreenVisible && requestVersion == _requestVersion;

  bool get _needsRefresh {
    if (!state.hasLoaded ||
        state.loadedFromCache ||
        state.errorMessage != null) {
      return true;
    }

    final lastRefreshAtUtc = _lastRemoteRefreshAtUtc;
    if (lastRefreshAtUtc == null) {
      return true;
    }
    final age = ref
        .read(templateDiscoveryClockProvider)()
        .toUtc()
        .difference(lastRefreshAtUtc);
    return age >= _refreshInterval;
  }
}
