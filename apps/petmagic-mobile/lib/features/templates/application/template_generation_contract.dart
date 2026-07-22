// Public generation contract for other feature modules. Consumers depend on
// this boundary instead of the templates module's internal layout.
export '../../pets/domain/pet_models.dart';
export '../domain/template_generation_models.dart';
export '../domain/template_generation_results.dart';
export 'generation_repository.dart';
export 'generation_history_controller.dart'
    show
        GenerationHistoryController,
        GenerationHistoryFilter,
        GenerationHistoryState,
        generationHistoryControllerProvider;
