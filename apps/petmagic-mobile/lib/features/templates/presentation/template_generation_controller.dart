import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/logging/log_correlation_context.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/mappers/template_error_key_mapper.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';

final templateGenerationControllerProvider =
    NotifierProvider<TemplateGenerationController, TemplateGenerationState>(
      TemplateGenerationController.new,
    );

final generationImageUploadOptimizerProvider = Provider<ImageUploadOptimizer>(
  (ref) => const ImageUploadOptimizer(),
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
  static final Random _correlationRandom = Random.secure();

  late final TemplateGenerationRepository _repository;
  late final ImageUploadOptimizer _imageUploadOptimizer;
  Timer? _pollTimer;
  bool _pollTickInFlight = false;
  bool _disposed = false;
  int _generationFlowEpoch = 0;
  String? _activeCorrelationId;
  CancelToken? _activeRequestCancelToken;

  @override
  TemplateGenerationState build() {
    _repository = ref.watch(templateGenerationRepositoryProvider);
    _imageUploadOptimizer = ref.watch(generationImageUploadOptimizerProvider);
    ref.onDispose(() {
      _disposed = true;
      _cancelActiveRequest();
      _stopPolling();
    });
    unawaited(_restoreActiveGeneration());
    return const TemplateGenerationState();
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
    var wallet = ref.read(walletControllerProvider).wallet;
    if (wallet == null) {
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
    if (photo == null || state.isCreating) {
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
    CancelToken? requestCancelToken;
    OptimizedUploadFile? optimizedPhoto;
    try {
      requestCancelToken = _newActiveRequestCancelToken();
      optimizedPhoto = await _imageUploadOptimizer.optimizeGenerationSource(
        photo,
        cancelToken: requestCancelToken,
      );
      if (_disposed) {
        return null;
      }
      final generation = await _repository.startGeneration(
        templateId: template.templateId,
        sourceImage: optimizedPhoto.file,
        correlationId: _activeCorrelationId,
        cancelToken: requestCancelToken,
      );

      if (_disposed) {
        if (!generation.isTerminal) {
          await _repository.rememberActiveGeneration(
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
        await _repository.rememberActiveGeneration(
          generationId: generation.generationId,
          correlationId: _activeCorrelationId,
        );
        if (_disposed) {
          return generation;
        }
        _startPolling(generation.generationId);
      } else {
        await _repository.clearActiveGeneration(generation.generationId);
        if (_disposed) {
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
      await optimizedPhoto?.dispose();
    }
  }

  Future<void> refreshGeneration() async {
    final generationId = state.generation?.generationId;
    if (generationId == null || generationId.isEmpty) {
      return;
    }

    await _pollGeneration(generationId);
  }

  void _startPolling(String generationId) {
    if (_disposed) {
      return;
    }

    _stopPolling();
    _scheduleNextPoll(state.generation);
  }

  void _scheduleNextPoll(TemplateGenerationResult? generation) {
    if (_disposed) {
      return;
    }

    final generationId = generation?.generationId;
    if (generationId == null || generationId.isEmpty) {
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
    if (_disposed) {
      return;
    }

    if (_pollTickInFlight) {
      if (scheduleNext && !_disposed) {
        _scheduleNextPoll(state.generation);
      }
      return;
    }

    _pollTickInFlight = true;
    CancelToken? requestCancelToken;
    try {
      requestCancelToken = _newActiveRequestCancelToken();
      final generation = await _repository.fetchGeneration(
        generationId,
        correlationId: _activeCorrelationId,
        cancelToken: requestCancelToken,
      );
      if (_disposed) {
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
        await _repository.clearActiveGeneration(generation.generationId);
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
    final active = await _repository.readActiveGeneration();
    if (!_isRestoreCurrent(restoreEpoch) || active == null) {
      return;
    }

    _activeCorrelationId = active.correlationId;
    state = state.copyWith(isPolling: true, clearError: true);

    CancelToken? requestCancelToken;
    try {
      requestCancelToken = _newActiveRequestCancelToken();
      final generation = await _repository.fetchGeneration(
        active.generationId,
        correlationId: _activeCorrelationId,
        cancelToken: requestCancelToken,
      );
      if (!_isRestoreCurrent(restoreEpoch)) {
        return;
      }

      state = state.copyWith(
        generation: generation,
        isPolling: !generation.isTerminal,
        clearError: true,
        clearQueueRejection: true,
      );

      if (generation.isTerminal) {
        await _repository.clearActiveGeneration(generation.generationId);
        if (!_isRestoreCurrent(restoreEpoch)) {
          return;
        }
        _activeCorrelationId = null;
        await _refreshWalletIfAlive();
        return;
      }

      await _repository.rememberActiveGeneration(
        generationId: generation.generationId,
        correlationId: _activeCorrelationId,
      );
      if (!_isRestoreCurrent(restoreEpoch)) {
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

  Future<void> _refreshWalletIfAlive() async {
    if (_disposed) {
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
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final suffix = _correlationRandom.nextInt(1 << 24).toRadixString(16);
    return 'generation-$now-$suffix';
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
    TemplateGenerationStatus.finalizing => const Duration(seconds: 3),
    _ => const Duration(seconds: 5),
  };
}
