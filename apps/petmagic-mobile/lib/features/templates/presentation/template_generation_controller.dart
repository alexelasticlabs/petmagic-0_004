import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
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
  });

  final XFile? selectedPhoto;
  final TemplateGenerationResult? generation;
  final bool isCreating;
  final bool isPolling;
  final String? errorMessage;

  TemplateGenerationState copyWith({
    XFile? selectedPhoto,
    TemplateGenerationResult? generation,
    bool? isCreating,
    bool? isPolling,
    String? errorMessage,
    bool clearSelectedPhoto = false,
    bool clearGeneration = false,
    bool clearError = false,
  }) {
    return TemplateGenerationState(
      selectedPhoto: clearSelectedPhoto
          ? null
          : selectedPhoto ?? this.selectedPhoto,
      generation: clearGeneration ? null : generation ?? this.generation,
      isCreating: isCreating ?? this.isCreating,
      isPolling: isPolling ?? this.isPolling,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class TemplateGenerationController extends Notifier<TemplateGenerationState> {
  late final TemplateGenerationRepository _repository;
  Timer? _pollTimer;
  bool _pollTickInFlight = false;

  @override
  TemplateGenerationState build() {
    _repository = ref.watch(templateGenerationRepositoryProvider);
    ref.onDispose(_stopPolling);
    return const TemplateGenerationState();
  }

  void selectPhoto(XFile photo) {
    state = state.copyWith(
      selectedPhoto: photo,
      clearGeneration: true,
      clearError: true,
      isCreating: false,
      isPolling: false,
    );
  }

  void clearPhoto() {
    state = state.copyWith(
      clearSelectedPhoto: true,
      clearGeneration: true,
      clearError: true,
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

    _stopPolling();
    state = state.copyWith(
      isCreating: true,
      isPolling: false,
      clearGeneration: true,
      clearError: true,
    );

    try {
      final generation = await _repository.startGeneration(
        templateId: template.templateId,
        sourceImage: photo,
      );

      state = state.copyWith(
        generation: generation,
        isCreating: false,
        isPolling: !generation.isTerminal,
      );

      if (!generation.isTerminal) {
        _startPolling(generation.generationId);
      }

      await ref.read(walletControllerProvider.notifier).load(refresh: true);
      return generation;
    } catch (error) {
      await ref.read(walletControllerProvider.notifier).load(refresh: true);
      state = state.copyWith(
        isCreating: false,
        isPolling: false,
        errorMessage: _mapGenerationError(error),
      );
      return null;
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
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollGeneration(generationId));
    });
  }

  Future<void> _pollGeneration(String generationId) async {
    if (_pollTickInFlight) {
      return;
    }

    _pollTickInFlight = true;
    try {
      final generation = await _repository.fetchGeneration(generationId);
      state = state.copyWith(
        generation: generation,
        isPolling: !generation.isTerminal,
        clearError: true,
      );

      if (generation.isTerminal) {
        _stopPolling();
        await ref.read(walletControllerProvider.notifier).load(refresh: true);
      }
    } catch (error) {
      _stopPolling();
      state = state.copyWith(
        errorMessage: _mapGenerationError(error),
        isPolling: false,
      );
    } finally {
      _pollTickInFlight = false;
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  String _mapGenerationError(Object error) {
    if (error is AppException && error.statusCode == 402) {
      return 'templates.insufficient_balance';
    }

    final message = error.toString();
    if (message.contains('economy.insufficient_balance')) {
      return 'templates.insufficient_balance';
    }

    return message;
  }
}
