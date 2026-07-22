import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';

enum TemplateGenerationGateKind { allowed, notEnoughTokens, premiumRequired }

final class TemplateGenerationGate {
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

final class TemplateGenerationState {
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
