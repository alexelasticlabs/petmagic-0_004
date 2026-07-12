import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/lifecycle/app_lifecycle_signal.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/logging/log_correlation_context.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/network/request_identity.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/mappers/template_error_key_mapper.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';

final templateGenerationControllerProvider =
    NotifierProvider<TemplateGenerationController, TemplateGenerationState>(
      TemplateGenerationController.new,
    );

enum TemplateGenerationGateKind { allowed, notEnoughTokens, premiumRequired }

class TemplateGenerationGate {
  const TemplateGenerationGate({
    required this.kind,
    required this.balance,
    required this.isPremium,
  });

  final TemplateGenerationGateKind kind;
  final int balance;
  final bool isPremium;

  bool get isAllowed => kind == TemplateGenerationGateKind.allowed;
}

class TemplateGenerationState {
  const TemplateGenerationState({
    this.selectedPhoto,
    this.generation,
    this.isCreating = false,
    this.isPolling = false,
    this.errorMessage,
    this.queueRejection,
  });

  final XFile? selectedPhoto;
  final TemplateGenerationResult? generation;
  final bool isCreating;
  final bool isPolling;
  final String? errorMessage;
  final GenerationWaitTooLongException? queueRejection;

  TemplateGenerationState copyWith({
    XFile? selectedPhoto,
    TemplateGenerationResult? generation,
    bool? isCreating,
    bool? isPolling,
    String? errorMessage,
    GenerationWaitTooLongException? queueRejection,
    bool clearSelectedPhoto = false,
    bool clearGeneration = false,
    bool clearError = false,
    bool clearQueueRejection = false,
  }) {
    return TemplateGenerationState(
      selectedPhoto: clearSelectedPhoto
          ? null
          : selectedPhoto ?? this.selectedPhoto,
      generation: clearGeneration ? null : generation ?? this.generation,
      isCreating: isCreating ?? this.isCreating,
      isPolling: isPolling ?? this.isPolling,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      queueRejection: clearQueueRejection
          ? null
          : queueRejection ?? this.queueRejection,
    );
  }
}

class TemplateGenerationController extends Notifier<TemplateGenerationState> {
  TemplateGenerationRepository get _repository =>
      ref.read(templateGenerationRepositoryProvider);
  Timer? _pollTimer;
  bool _pollTickInFlight = false;
  bool _disposed = false;
  bool _hasInternet = true;
  bool _isForeground = true;
  bool _canUsePrivateGenerationApi = true;
  int _generationFlowEpoch = 0;
  String? _activeCorrelationId;
  CancelToken? _activeRequestCancelToken;
  VoidCallback? _appLifecycleListener;

  @override
  TemplateGenerationState build() {
    _hasInternet = ref.read(networkStatusControllerProvider).hasInternet;
    _isForeground = AppLifecycleSignal.instance.isResumed;
    _canUsePrivateGenerationApi = _isLaunchAuthorized(
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
      _cancelActiveRequest();
      _stopPolling();
    });
    unawaited(_restoreActiveGeneration());
    return const TemplateGenerationState();
  }

  bool _isLaunchAuthorized(AppLaunchState state) {
    return state.isLoading || state.isAuthenticated;
  }

  void _handleAuthStatusChanged(AppLaunchState launchState) {
    final canUsePrivateApi = _isLaunchAuthorized(launchState);
    if (_canUsePrivateGenerationApi == canUsePrivateApi) {
      return;
    }

    _canUsePrivateGenerationApi = canUsePrivateApi;
    if (canUsePrivateApi) {
      return;
    }

    _generationFlowEpoch++;
    _stopPolling();
    _cancelActiveRequest();
    _activeCorrelationId = null;
    _pollTickInFlight = false;
    state = const TemplateGenerationState();
  }

  void selectPhoto(XFile photo) {
    _generationFlowEpoch++;
    _stopPolling();
    _cancelActiveRequest();
    _activeCorrelationId = null;
    state = state.copyWith(
      selectedPhoto: photo,
      clearGeneration: true,
      clearError: true,
      clearQueueRejection: true,
      isCreating: false,
      isPolling: false,
    );
  }

  void clearPhoto() {
    _generationFlowEpoch++;
    _stopPolling();
    _cancelActiveRequest();
    _activeCorrelationId = null;
    state = state.copyWith(
      clearSelectedPhoto: true,
      clearGeneration: true,
      clearError: true,
      clearQueueRejection: true,
      isCreating: false,
      isPolling: false,
    );
  }

  Future<TemplateGenerationGate> checkGate(TemplateItem template) async {
    if (!_canUsePrivateGenerationApi) {
      return const TemplateGenerationGate(
        kind: TemplateGenerationGateKind.notEnoughTokens,
        balance: 0,
        isPremium: false,
      );
    }

    var wallet = ref.read(walletControllerProvider).wallet;
    if (wallet == null &&
        ref.read(networkStatusControllerProvider).hasInternet) {
      await ref.read(walletControllerProvider.notifier).load(refresh: true);
      wallet = ref.read(walletControllerProvider).wallet;
    }

    wallet ??= const WalletStateModel(
      userId: '',
      balance: 0,
      adRewardsRemainingToday: 0,
      isPremium: false,
      updatedAtUtc: null,
    );

    if (template.isPremium && !wallet.isPremium) {
      return TemplateGenerationGate(
        kind: TemplateGenerationGateKind.premiumRequired,
        balance: wallet.balance,
        isPremium: wallet.isPremium,
      );
    }

    if (wallet.balance < template.tokenCost) {
      return TemplateGenerationGate(
        kind: TemplateGenerationGateKind.notEnoughTokens,
        balance: wallet.balance,
        isPremium: wallet.isPremium,
      );
    }

    return TemplateGenerationGate(
      kind: TemplateGenerationGateKind.allowed,
      balance: wallet.balance,
      isPremium: wallet.isPremium,
    );
  }

  Future<TemplateGenerationResult?> startGeneration(
    TemplateItem template,
  ) async {
    final photo = state.selectedPhoto;
    if (!_canUsePrivateGenerationApi || photo == null || state.isCreating) {
      return null;
    }

    _generationFlowEpoch++;
    _stopPolling();
    _cancelActiveRequest();
    _activeCorrelationId = _createGenerationCorrelationId();
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
    CancelToken? requestCancelToken;
    try {
      requestCancelToken = _newActiveRequestCancelToken();
      if (_disposed || !_canUsePrivateGenerationApi) {
        return null;
      }
      final generation = await repository.startGeneration(
        templateId: template.templateId,
        sourceImage: photo,
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
        _startPolling(generation.generationId);
      } else {
        await repository.clearActiveGeneration(generation.generationId);
        if (_disposed || !_canUsePrivateGenerationApi) {
          return generation;
        }
      }

      await _refreshWalletIfAlive();
      return generation;
    } catch (error) {
      if (_disposed) {
        return null;
      }
      if (_isCancelled(error)) {
        state = state.copyWith(isCreating: false, isPolling: false);
        return null;
      }
      await _refreshWalletIfAlive();
      if (_disposed) {
        return null;
      }
      state = state.copyWith(
        isCreating: false,
        isPolling: false,
        errorMessage: _mapGenerationError(error),
        queueRejection: error is GenerationWaitTooLongException ? error : null,
      );
      return null;
    } finally {
      final cancelToken = requestCancelToken;
      if (cancelToken != null) {
        _clearActiveRequest(cancelToken);
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

  void _startPolling(String generationId) {
    if (_disposed || !_canUsePrivateGenerationApi || !_isForeground) {
      return;
    }

    _stopPolling();
    _scheduleNextPoll(state.generation);
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
    _pollTimer = Timer(_generationPollInterval(generation), () {
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
    CancelToken? requestCancelToken;
    try {
      requestCancelToken = _newActiveRequestCancelToken();
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
        await _refreshWalletIfAlive();
      } else if (scheduleNext) {
        _scheduleNextPoll(generation);
      }
    } catch (error) {
      if (_disposed) {
        return;
      }
      if (_isCancelled(error)) {
        return;
      }
      _stopPolling();
      _activeCorrelationId = null;
      state = state.copyWith(
        errorMessage: _mapGenerationError(error),
        isPolling: false,
        queueRejection: error is GenerationWaitTooLongException ? error : null,
      );
    } finally {
      final cancelToken = requestCancelToken;
      if (cancelToken != null) {
        _clearActiveRequest(cancelToken);
      }
      _pollTickInFlight = false;
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  CancelToken _newActiveRequestCancelToken() {
    _cancelActiveRequest();
    final cancelToken = CancelToken();
    _activeRequestCancelToken = cancelToken;
    return cancelToken;
  }

  void _cancelActiveRequest() {
    final cancelToken = _activeRequestCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('generation_request_cancelled');
    }
    _activeRequestCancelToken = null;
  }

  void _clearActiveRequest(CancelToken cancelToken) {
    if (identical(_activeRequestCancelToken, cancelToken)) {
      _activeRequestCancelToken = null;
    }
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

    CancelToken? requestCancelToken;
    try {
      requestCancelToken = _newActiveRequestCancelToken();
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
        await _refreshWalletIfAlive();
        return;
      }

      await repository.rememberActiveGeneration(
        generationId: generation.generationId,
        correlationId: _activeCorrelationId,
      );
      if (!_isRestoreCurrent(restoreEpoch) || !_canUsePrivateGenerationApi) {
        return;
      }
      _startPolling(generation.generationId);
    } catch (error) {
      if (!_isRestoreCurrent(restoreEpoch)) {
        return;
      }
      if (_isCancelled(error)) {
        return;
      }

      state = state.copyWith(
        errorMessage: _mapGenerationError(error),
        isPolling: false,
        queueRejection: error is GenerationWaitTooLongException ? error : null,
      );
    } finally {
      final cancelToken = requestCancelToken;
      if (cancelToken != null) {
        _clearActiveRequest(cancelToken);
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
      _cancelActiveRequest();
      final generation = state.generation;
      if (state.isCreating || generation != null && !generation.isTerminal) {
        state = state.copyWith(isCreating: false, isPolling: false);
      }
      return;
    }

    if (!_isForeground || !_canUsePrivateGenerationApi) {
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

  void _handleAppLifecycleSignal() {
    final isForeground = AppLifecycleSignal.instance.isResumed;
    if (_disposed || _isForeground == isForeground) {
      return;
    }

    _isForeground = isForeground;
    if (!isForeground) {
      _stopPolling();
      if (!state.isCreating) {
        _cancelActiveRequest();
      }

      final generation = state.generation;
      if (generation != null && !generation.isTerminal && state.isPolling) {
        state = state.copyWith(isPolling: false);
      }
      return;
    }

    if (!_hasInternet || !_canUsePrivateGenerationApi) {
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

  Future<void> _refreshWalletIfAlive() async {
    if (_disposed || !_canUsePrivateGenerationApi || !_hasInternet) {
      return;
    }

    try {
      await ref.read(walletControllerProvider.notifier).load(refresh: true);
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.GenerationController',
        operation: 'refresh_wallet_after_generation',
        message: 'Wallet refresh failed after generation state change.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String _createGenerationCorrelationId() {
    return RequestIdentity.createCorrelationId().replaceFirst(
      'flow-',
      'generation-',
    );
  }

  bool _isCancelled(Object error) {
    return error is RequestCancelledException ||
        (error is DioException && error.type == DioExceptionType.cancel);
  }

  String _mapGenerationError(Object error) {
    if (error is GenerationWaitTooLongException) {
      return error.message;
    }

    if (error is AppException && error.statusCode == 401) {
      return 'auth.sign_in_required';
    }

    if (error is AppException && error.statusCode == 402) {
      return 'templates.insufficient_balance';
    }

    if (error is AppException) {
      final message = normalizeTemplateErrorKey(error.message);
      if (message != null) {
        return message;
      }
    }

    return 'templates.generation_failed';
  }
}

Duration _generationPollInterval(TemplateGenerationResult? generation) {
  return switch (generation?.status) {
    TemplateGenerationStatus.queued => const Duration(seconds: 8),
    TemplateGenerationStatus.submittingToProvider ||
    TemplateGenerationStatus.providerQueued => const Duration(seconds: 5),
    TemplateGenerationStatus.processing ||
    TemplateGenerationStatus.preprocessing ||
    TemplateGenerationStatus.generating ||
    TemplateGenerationStatus.providerProcessing ||
    TemplateGenerationStatus.importingMedia ||
    TemplateGenerationStatus.cancellationRequested ||
    TemplateGenerationStatus.finalizing => const Duration(seconds: 3),
    _ => const Duration(seconds: 5),
  };
}
