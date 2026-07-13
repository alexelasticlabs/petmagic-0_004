import 'dart:async';

import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/core/files/local_media_file.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/lifecycle/app_lifecycle_signal.dart';
import 'package:petmagic_mobile/core/logging/log_correlation_context.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/application/generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_policy.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_request_tracker.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_state.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_wallet_coordinator.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';

export 'template_generation_state.dart';

final templateGenerationControllerProvider =
    NotifierProvider<TemplateGenerationController, TemplateGenerationState>(
      TemplateGenerationController.new,
    );

class TemplateGenerationController extends Notifier<TemplateGenerationState> {
  GenerationRepository get _repository =>
      ref.read(templateGenerationRepositoryProvider);
  Timer? _pollTimer;
  bool _pollTickInFlight = false;
  bool _disposed = false;
  bool _hasInternet = true;
  bool _isForeground = true;
  bool _canUsePrivateGenerationApi = true;
  int _generationFlowEpoch = 0;
  String? _activeCorrelationId;
  late final TemplateGenerationRequestTracker _requestTracker;
  late final TemplateGenerationWalletCoordinator _walletCoordinator;
  VoidCallback? _appLifecycleListener;

  @override
  TemplateGenerationState build() {
    _requestTracker = TemplateGenerationRequestTracker();
    _walletCoordinator = TemplateGenerationWalletCoordinator(
      readWallet: () => ref.read(walletControllerProvider).wallet,
      loadWallet: () =>
          ref.read(walletControllerProvider.notifier).load(refresh: true),
      hasInternet: () => _hasInternet,
      canUsePrivateApi: () => _canUsePrivateGenerationApi,
      isDisposed: () => _disposed,
    );
    _hasInternet = ref.read(networkStatusControllerProvider).hasInternet;
    _isForeground = AppLifecycleSignal.instance.isResumed;
    _canUsePrivateGenerationApi = TemplateGenerationPolicy.canUsePrivateApi(
      ref.read(appLaunchControllerProvider),
    );
    _appLifecycleListener = _handleAppLifecycleSignal;
    AppLifecycleSignal.instance.addListener(_appLifecycleListener!);
    ref.listen<AppLaunchState>(
      appLaunchControllerProvider,
      (_, next) => _handleAuthStatusChanged(next),
    );
    ref.listen<bool>(
      networkStatusControllerProvider.select((status) => status.hasInternet),
      (_, hasInternet) => _handleNetworkStatusChanged(hasInternet),
    );
    ref.onDispose(() {
      _disposed = true;
      final lifecycleListener = _appLifecycleListener;
      if (lifecycleListener != null) {
        AppLifecycleSignal.instance.removeListener(lifecycleListener);
        _appLifecycleListener = null;
      }
      _requestTracker.cancel();
      _stopPolling();
    });
    unawaited(_restoreActiveGeneration());
    return const TemplateGenerationState();
  }

  void _handleAuthStatusChanged(AppLaunchState launchState) {
    final canUsePrivateApi = TemplateGenerationPolicy.canUsePrivateApi(
      launchState,
    );
    if (_canUsePrivateGenerationApi == canUsePrivateApi) {
      return;
    }

    _canUsePrivateGenerationApi = canUsePrivateApi;
    if (canUsePrivateApi) {
      return;
    }

    _generationFlowEpoch++;
    _stopPolling();
    _requestTracker.cancel();
    _activeCorrelationId = null;
    _pollTickInFlight = false;
    state = const TemplateGenerationState();
  }

  void selectPhoto(XFile photo) => _resetPhoto(photo);

  void clearPhoto() => _resetPhoto(null);

  void _resetPhoto(XFile? photo) {
    _generationFlowEpoch++;
    _stopPolling();
    _requestTracker.cancel();
    _activeCorrelationId = null;
    state = state.copyWith(
      selectedPhoto: photo,
      clearSelectedPhoto: photo == null,
      clearGeneration: true,
      clearError: true,
      clearQueueRejection: true,
      isCreating: false,
      isPolling: false,
    );
  }

  Future<TemplateGenerationGate> checkGate(TemplateItem template) =>
      _walletCoordinator.checkGate(template);

  Future<TemplateGenerationResult?> startGeneration(
    TemplateItem template,
  ) async {
    final photo = state.selectedPhoto;
    if (!_canUsePrivateGenerationApi || photo == null || state.isCreating) {
      return null;
    }

    _generationFlowEpoch++;
    _stopPolling();
    _requestTracker.cancel();
    _activeCorrelationId = TemplateGenerationPolicy.createCorrelationId();
    state = state.copyWith(
      isCreating: true,
      isPolling: false,
      clearGeneration: true,
      clearError: true,
      clearQueueRejection: true,
    );

    return LogCorrelationContext.runWithCorrelationId(
      _activeCorrelationId,
      () => _startGenerationWithActiveCorrelation(template, photo),
    );
  }

  Future<TemplateGenerationResult?> _startGenerationWithActiveCorrelation(
    TemplateItem template,
    XFile photo,
  ) async {
    final repository = _repository;
    RequestCancellation? requestCancelToken;
    try {
      requestCancelToken = _requestTracker.start();
      if (_disposed || !_canUsePrivateGenerationApi) {
        return null;
      }
      final generation = await repository.startGeneration(
        templateId: template.templateId,
        sourceImage: LocalMediaFile(
          path: photo.path,
          name: photo.name,
          mimeType: photo.mimeType,
        ),
        expectedTemplateVersion: template.version,
        correlationId: _activeCorrelationId,
        cancelToken: requestCancelToken,
      );

      if (_disposed || !_canUsePrivateGenerationApi) {
        if (!generation.isTerminal) {
          await repository.rememberActiveGeneration(
            generationId: generation.generationId,
            correlationId: _activeCorrelationId,
          );
        }
        return generation;
      }

      state = state.copyWith(
        generation: generation,
        isCreating: false,
        isPolling: !generation.isTerminal,
        clearQueueRejection: true,
      );

      if (!generation.isTerminal) {
        await repository.rememberActiveGeneration(
          generationId: generation.generationId,
          correlationId: _activeCorrelationId,
        );
        if (_disposed || !_canUsePrivateGenerationApi) {
          return generation;
        }
        _stopPolling();
        _scheduleNextPoll(generation);
      } else {
        await repository.clearActiveGeneration(generation.generationId);
        if (_disposed || !_canUsePrivateGenerationApi) {
          return generation;
        }
      }

      await _walletCoordinator.refreshAfterGeneration();
      return generation;
    } catch (error) {
      if (_disposed) {
        return null;
      }
      if (TemplateGenerationPolicy.isCancelled(error)) {
        state = state.copyWith(isCreating: false, isPolling: false);
        return null;
      }
      await _walletCoordinator.refreshAfterGeneration();
      if (_disposed) {
        return null;
      }
      state = state.copyWith(
        isCreating: false,
        isPolling: false,
        errorMessage: TemplateGenerationPolicy.mapError(error),
        queueRejection: TemplateGenerationPolicy.queueRejection(error),
      );
      return null;
    } finally {
      final cancelToken = requestCancelToken;
      if (cancelToken != null) {
        _requestTracker.clear(cancelToken);
      }
    }
  }

  Future<void> refreshGeneration() async {
    final generationId = state.generation?.generationId;
    if (generationId == null ||
        generationId.isEmpty ||
        !_canUsePrivateGenerationApi ||
        !_hasInternet ||
        !_isForeground) {
      return;
    }

    await _pollGeneration(generationId);
  }

  void _scheduleNextPoll(TemplateGenerationResult? generation) {
    if (_disposed || !_canUsePrivateGenerationApi || !_isForeground) {
      return;
    }

    final generationId = generation?.generationId;
    if (generationId == null || generationId.isEmpty) {
      return;
    }
    if (!_hasInternet) {
      return;
    }

    _pollTimer?.cancel();
    _pollTimer = Timer(TemplateGenerationPolicy.pollInterval(generation), () {
      _pollTimer = null;
      unawaited(_pollGeneration(generationId, scheduleNext: true));
    });
  }

  Future<void> _pollGeneration(
    String generationId, {
    bool scheduleNext = false,
  }) async {
    await LogCorrelationContext.runWithCorrelationId(
      _activeCorrelationId,
      () => _pollGenerationWithActiveCorrelation(
        generationId,
        scheduleNext: scheduleNext,
      ),
    );
  }

  Future<void> _pollGenerationWithActiveCorrelation(
    String generationId, {
    required bool scheduleNext,
  }) async {
    if (_disposed ||
        !_canUsePrivateGenerationApi ||
        !_hasInternet ||
        !_isForeground) {
      return;
    }

    if (_pollTickInFlight) {
      if (scheduleNext && !_disposed) {
        _scheduleNextPoll(state.generation);
      }
      return;
    }

    _pollTickInFlight = true;
    final repository = _repository;
    RequestCancellation? requestCancelToken;
    try {
      requestCancelToken = _requestTracker.start();
      final generation = await repository.fetchGeneration(
        generationId,
        correlationId: _activeCorrelationId,
        cancelToken: requestCancelToken,
      );
      if (_disposed || !_canUsePrivateGenerationApi) {
        return;
      }

      state = state.copyWith(
        generation: generation,
        isPolling: !generation.isTerminal,
        clearError: true,
        clearQueueRejection: true,
      );

      if (generation.isTerminal) {
        _stopPolling();
        await repository.clearActiveGeneration(generation.generationId);
        if (_disposed) {
          return;
        }
        _activeCorrelationId = null;
        await _walletCoordinator.refreshAfterGeneration();
      } else if (scheduleNext) {
        _scheduleNextPoll(generation);
      }
    } catch (error) {
      if (_disposed) {
        return;
      }
      if (TemplateGenerationPolicy.isCancelled(error)) {
        return;
      }
      _stopPolling();
      _activeCorrelationId = null;
      state = state.copyWith(
        errorMessage: TemplateGenerationPolicy.mapError(error),
        isPolling: false,
        queueRejection: TemplateGenerationPolicy.queueRejection(error),
      );
    } finally {
      final cancelToken = requestCancelToken;
      if (cancelToken != null) {
        _requestTracker.clear(cancelToken);
      }
      _pollTickInFlight = false;
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _restoreActiveGeneration() async {
    final restoreEpoch = _generationFlowEpoch;
    if (!_canUsePrivateGenerationApi) {
      return;
    }

    final repository = _repository;
    final active = await repository.readActiveGeneration();
    if (!_isRestoreCurrent(restoreEpoch) || active == null) {
      return;
    }
    if (!_canUsePrivateGenerationApi || !_hasInternet || !_isForeground) {
      return;
    }

    _activeCorrelationId = active.correlationId;
    state = state.copyWith(isPolling: true, clearError: true);

    RequestCancellation? requestCancelToken;
    try {
      requestCancelToken = _requestTracker.start();
      final generation = await repository.fetchGeneration(
        active.generationId,
        correlationId: _activeCorrelationId,
        cancelToken: requestCancelToken,
      );
      if (!_isRestoreCurrent(restoreEpoch) || !_canUsePrivateGenerationApi) {
        return;
      }

      state = state.copyWith(
        generation: generation,
        isPolling: !generation.isTerminal,
        clearError: true,
        clearQueueRejection: true,
      );

      if (generation.isTerminal) {
        await repository.clearActiveGeneration(generation.generationId);
        if (!_isRestoreCurrent(restoreEpoch) || !_canUsePrivateGenerationApi) {
          return;
        }
        _activeCorrelationId = null;
        await _walletCoordinator.refreshAfterGeneration();
        return;
      }

      await repository.rememberActiveGeneration(
        generationId: generation.generationId,
        correlationId: _activeCorrelationId,
      );
      if (!_isRestoreCurrent(restoreEpoch) || !_canUsePrivateGenerationApi) {
        return;
      }
      _stopPolling();
      _scheduleNextPoll(generation);
    } catch (error) {
      if (!_isRestoreCurrent(restoreEpoch)) {
        return;
      }
      if (TemplateGenerationPolicy.isCancelled(error)) {
        return;
      }

      state = state.copyWith(
        errorMessage: TemplateGenerationPolicy.mapError(error),
        isPolling: false,
        queueRejection: TemplateGenerationPolicy.queueRejection(error),
      );
    } finally {
      final cancelToken = requestCancelToken;
      if (cancelToken != null) {
        _requestTracker.clear(cancelToken);
      }
    }
  }

  bool _isRestoreCurrent(int restoreEpoch) {
    return !_disposed && _generationFlowEpoch == restoreEpoch;
  }

  void _handleNetworkStatusChanged(bool hasInternet) {
    if (_disposed || _hasInternet == hasInternet) {
      return;
    }

    _hasInternet = hasInternet;
    if (!hasInternet) {
      _stopPolling();
      _requestTracker.cancel();
      final generation = state.generation;
      if (state.isCreating || generation != null && !generation.isTerminal) {
        state = state.copyWith(isCreating: false, isPolling: false);
      }
      return;
    }

    _resumeGenerationWork();
  }

  void _handleAppLifecycleSignal() {
    final isForeground = AppLifecycleSignal.instance.isResumed;
    if (_disposed || _isForeground == isForeground) {
      return;
    }

    _isForeground = isForeground;
    if (!isForeground) {
      _stopPolling();
      if (!state.isCreating) {
        _requestTracker.cancel();
      }

      final generation = state.generation;
      if (generation != null && !generation.isTerminal && state.isPolling) {
        state = state.copyWith(isPolling: false);
      }
      return;
    }

    _resumeGenerationWork();
  }

  void _resumeGenerationWork() {
    if (!_hasInternet || !_isForeground || !_canUsePrivateGenerationApi) {
      return;
    }

    final generation = state.generation;
    if (generation != null && !generation.isTerminal) {
      state = state.copyWith(isPolling: true, clearError: true);
      unawaited(_pollGeneration(generation.generationId, scheduleNext: true));
      return;
    }

    unawaited(_restoreActiveGeneration());
  }
}
