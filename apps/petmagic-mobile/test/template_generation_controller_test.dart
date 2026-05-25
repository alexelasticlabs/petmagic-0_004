import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';

void main() {
  test(
    'maps backend payment required error to balance recovery state',
    () async {
      final repository = _FakeTemplateGenerationRepository(
        startError: const AppException(
          'economy.insufficient_balance',
          statusCode: 402,
        ),
      );
      late _FakeWalletController walletController;
      final container = ProviderContainer(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          walletControllerProvider.overrideWith(() {
            walletController = _FakeWalletController(_wallet(balance: 10));
            return walletController;
          }),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        templateGenerationControllerProvider.notifier,
      );
      controller.selectPhoto(XFile('pet.jpg', name: 'pet.jpg'));

      await controller.startGeneration(_template(tokenCost: 50));

      final state = container.read(templateGenerationControllerProvider);
      expect(repository.startCalls, 1);
      expect(walletController.loadCalls, 1);
      expect(state.isCreating, false);
      expect(state.isPolling, false);
      expect(state.errorMessage, 'templates.insufficient_balance');
    },
  );

  test('stops polling when generation refresh fails', () async {
    final repository = _FakeTemplateGenerationRepository(
      startResult: _generation(status: TemplateGenerationStatus.queued),
      fetchError: const AppException(
        'templates.server_unavailable',
        statusCode: 503,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        templateGenerationRepositoryProvider.overrideWithValue(repository),
        walletControllerProvider.overrideWith(
          () => _FakeWalletController(_wallet(balance: 100)),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      templateGenerationControllerProvider.notifier,
    );
    controller.selectPhoto(XFile('pet.jpg', name: 'pet.jpg'));

    await controller.startGeneration(_template(tokenCost: 50));
    expect(
      container.read(templateGenerationControllerProvider).isPolling,
      true,
    );

    await controller.refreshGeneration();

    final state = container.read(templateGenerationControllerProvider);
    expect(repository.fetchCalls, 1);
    expect(state.isPolling, false);
    expect(
      state.errorMessage,
      'AppException(503): templates.server_unavailable',
    );
  });
}

class _FakeTemplateGenerationRepository
    implements TemplateGenerationRepository {
  _FakeTemplateGenerationRepository({
    this.startResult,
    this.startError,
    this.fetchError,
  });

  final TemplateGenerationResult? startResult;
  final Object? startError;
  final Object? fetchError;
  int startCalls = 0;
  int fetchCalls = 0;

  @override
  Future<TemplateGenerationResult> startGeneration({
    required String templateId,
    required XFile sourceImage,
  }) async {
    startCalls++;
    final error = startError;
    if (error != null) {
      throw error;
    }

    return startResult ?? _generation(status: TemplateGenerationStatus.queued);
  }

  @override
  Future<TemplateGenerationResult> fetchGeneration(String generationId) async {
    fetchCalls++;
    final error = fetchError;
    if (error != null) {
      throw error;
    }

    return _generation(status: TemplateGenerationStatus.completed);
  }
}

class _FakeWalletController extends WalletController {
  _FakeWalletController(this.wallet);

  final WalletStateModel wallet;
  int loadCalls = 0;

  @override
  WalletState build() {
    return WalletState(wallet: wallet, isLoading: false);
  }

  @override
  Future<void> load({bool refresh = false}) async {
    loadCalls++;
    state = state.copyWith(
      wallet: wallet,
      isLoading: false,
      isRefreshing: false,
    );
  }
}

TemplateItem _template({required int tokenCost}) {
  return TemplateItem(
    templateId: 'template-1',
    templateType: TemplateType.image,
    title: 'Magic portrait',
    shortDescription: 'A bright portrait.',
    petPhotoRequirements: const ['Clear face'],
    category: 'Portrait',
    tags: const ['portrait'],
    isPremium: false,
    tokenCost: tokenCost,
  );
}

TemplateGenerationResult _generation({
  required TemplateGenerationStatus status,
}) {
  final now = DateTime.utc(2026, 5, 25);
  return TemplateGenerationResult(
    generationId: 'generation-1',
    userId: 'user-1',
    templateId: 'template-1',
    status: status,
    tokenCost: 50,
    attemptCount: 1,
    createdAtUtc: now,
    updatedAtUtc: now,
    userMediaExpired: false,
    outputUrl: status == TemplateGenerationStatus.completed
        ? 'https://cdn.example.com/result.jpg'
        : null,
  );
}

WalletStateModel _wallet({required int balance}) {
  return WalletStateModel(
    userId: 'user-1',
    balance: balance,
    adRewardsRemainingToday: 0,
    isPremium: false,
    updatedAtUtc: DateTime.utc(2026, 5, 25),
  );
}
