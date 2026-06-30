import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/log_correlation_context.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';

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
    expect(state.errorMessage, 'templates.server_unavailable');
  });

  test('keeps state quiet when generation start is cancelled', () async {
    final repository = _FakeTemplateGenerationRepository(
      startError: const RequestCancelledException(),
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

    final generation = await controller.startGeneration(
      _template(tokenCost: 50),
    );

    final state = container.read(templateGenerationControllerProvider);
    expect(generation, isNull);
    expect(state.errorMessage, isNull);
    expect(state.isCreating, false);
    expect(state.isPolling, false);
  });

  test(
    'does not expose local source image path for unexpected upload errors',
    () async {
      final repository = _FakeTemplateGenerationRepository(
        startError: const FileSystemException(
          'Cannot open file',
          '/private/user/pet-photo.jpg',
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
      controller.selectPhoto(
        XFile('/private/user/pet-photo.jpg', name: 'pet-photo.jpg'),
      );

      await controller.startGeneration(_template(tokenCost: 50));

      final state = container.read(templateGenerationControllerProvider);
      expect(state.errorMessage, 'templates.generation_failed');
      expect(state.errorMessage, isNot(contains('/private/user')));
    },
  );

  test(
    'optimizes source image before generation upload and deletes temp file',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-optimizer-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final optimizedPath = '${tempDir.path}/optimized-source.jpg';
      await File(optimizedPath).writeAsBytes(const [1, 2, 3], flush: true);
      final optimized = OptimizedUploadFile.temporary(
        XFile(
          optimizedPath,
          name: 'optimized-source.jpg',
          mimeType: 'image/jpeg',
        ),
      );
      final optimizer = _FakeImageUploadOptimizer(optimized);
      final repository = _FakeTemplateGenerationRepository(
        startResult: _generation(status: TemplateGenerationStatus.completed),
      );
      final container = ProviderContainer(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          generationImageUploadOptimizerProvider.overrideWithValue(optimizer),
          walletControllerProvider.overrideWith(
            () => _FakeWalletController(_wallet(balance: 100)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        templateGenerationControllerProvider.notifier,
      );
      controller.selectPhoto(XFile('original-source.png', name: 'source.png'));

      final generation = await controller.startGeneration(
        _template(tokenCost: 50),
      );

      expect(generation?.isTerminal, true);
      expect(optimizer.sources.single.path, 'original-source.png');
      expect(optimizer.cancelTokens.single, isNotNull);
      expect(repository.startSourceImages.single.path, optimizedPath);
      expect(repository.startSourceImages.single.mimeType, 'image/jpeg');
      expect(await File(optimizedPath).exists(), false);
    },
  );

  test(
    'keeps generation correlation id active while refreshing wallet after job',
    () async {
      final repository = _FakeTemplateGenerationRepository(
        startResult: _generation(status: TemplateGenerationStatus.completed),
      );
      final walletController = _FakeWalletController(_wallet(balance: 100));
      final container = ProviderContainer(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          walletControllerProvider.overrideWith(() => walletController),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        templateGenerationControllerProvider.notifier,
      );
      controller.selectPhoto(XFile('pet.jpg', name: 'pet.jpg'));

      await controller.startGeneration(_template(tokenCost: 50));

      expect(repository.startCorrelationIds.single, startsWith('generation-'));
      expect(
        walletController.loadCorrelationIds.single,
        repository.startCorrelationIds.single,
      );
    },
  );

  test(
    'keeps completed generation state when wallet refresh fails after job',
    () async {
      final repository = _FakeTemplateGenerationRepository(
        startResult: _generation(status: TemplateGenerationStatus.completed),
      );
      final walletController = _FakeWalletController(
        _wallet(balance: 100),
        loadError: const AppException('wallet.server_unavailable'),
      );
      final container = ProviderContainer(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          walletControllerProvider.overrideWith(() => walletController),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        templateGenerationControllerProvider.notifier,
      );
      controller.selectPhoto(XFile('pet.jpg', name: 'pet.jpg'));

      final generation = await controller.startGeneration(
        _template(tokenCost: 50),
      );

      final state = container.read(templateGenerationControllerProvider);
      expect(generation?.status, TemplateGenerationStatus.completed);
      expect(state.generation?.status, TemplateGenerationStatus.completed);
      expect(state.isCreating, isFalse);
      expect(state.isPolling, isFalse);
      expect(state.errorMessage, isNull);
      expect(walletController.loadCalls, 1);
    },
  );

  test(
    'keeps generation error mapping when wallet recovery refresh also fails',
    () async {
      final repository = _FakeTemplateGenerationRepository(
        startError: const AppException(
          'economy.insufficient_balance',
          statusCode: 402,
        ),
      );
      final walletController = _FakeWalletController(
        _wallet(balance: 100),
        loadError: const AppException('wallet.server_unavailable'),
      );
      final container = ProviderContainer(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          walletControllerProvider.overrideWith(() => walletController),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        templateGenerationControllerProvider.notifier,
      );
      controller.selectPhoto(XFile('pet.jpg', name: 'pet.jpg'));

      final generation = await controller.startGeneration(
        _template(tokenCost: 50),
      );

      final state = container.read(templateGenerationControllerProvider);
      expect(generation, isNull);
      expect(state.isCreating, isFalse);
      expect(state.isPolling, isFalse);
      expect(state.errorMessage, 'templates.insufficient_balance');
      expect(walletController.loadCalls, 1);
    },
  );

  test(
    'keeps generation correlation id active while polling terminal job',
    () async {
      final repository = _FakeTemplateGenerationRepository(
        startResult: _generation(status: TemplateGenerationStatus.queued),
      );
      final walletController = _FakeWalletController(_wallet(balance: 100));
      final container = ProviderContainer(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          walletControllerProvider.overrideWith(() => walletController),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        templateGenerationControllerProvider.notifier,
      );
      controller.selectPhoto(XFile('pet.jpg', name: 'pet.jpg'));

      await controller.startGeneration(_template(tokenCost: 50));
      await controller.refreshGeneration();

      final correlationId = repository.startCorrelationIds.single;
      expect(repository.fetchCorrelationIds.single, correlationId);
      expect(walletController.loadCorrelationIds.last, correlationId);
    },
  );

  test(
    'restores active generation with repository-provided correlation id',
    () async {
      final repository =
          _FakeTemplateGenerationRepository(
              fetchError: const AppException(
                'templates.server_unavailable',
                statusCode: 503,
              ),
            )
            ..activeGeneration = (
              generationId: 'generation-1',
              correlationId: 'generation-restored-1',
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

      container.read(templateGenerationControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final restored = repository.activeGeneration;
      expect(repository.fetchCalls, 1);
      expect(restored?.generationId, 'generation-1');
      expect(restored?.correlationId, 'generation-restored-1');
      expect(repository.fetchCorrelationIds.single, restored?.correlationId);
    },
  );

  test(
    'stale active generation restore does not override newly selected photo',
    () async {
      final restoreReadCompleter = Completer<void>();
      final repository =
          _FakeTemplateGenerationRepository(
              readActiveCompleter: restoreReadCompleter,
            )
            ..activeGeneration = (
              generationId: 'generation-1',
              correlationId: 'generation-restored-1',
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
      final selectedPhoto = XFile('new-pet.jpg', name: 'new-pet.jpg');
      controller.selectPhoto(selectedPhoto);

      restoreReadCompleter.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(templateGenerationControllerProvider);
      expect(repository.fetchCalls, 0);
      expect(state.selectedPhoto, selectedPhoto);
      expect(state.generation, isNull);
      expect(state.isPolling, isFalse);
    },
  );

  test(
    'remembers created active generation when controller is disposed mid-start',
    () async {
      final startCompleter = Completer<void>();
      final repository = _FakeTemplateGenerationRepository(
        startResult: _generation(status: TemplateGenerationStatus.queued),
        startCompleter: startCompleter,
      );
      final container = ProviderContainer(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          walletControllerProvider.overrideWith(
            () => _FakeWalletController(_wallet(balance: 100)),
          ),
        ],
      );

      final controller = container.read(
        templateGenerationControllerProvider.notifier,
      );
      controller.selectPhoto(XFile('pet.jpg', name: 'pet.jpg'));

      final generationFuture = controller.startGeneration(
        _template(tokenCost: 50),
      );
      await repository.startStarted.future;
      container.dispose();
      startCompleter.complete();

      final generation = await generationFuture;

      expect(generation?.generationId, 'generation-1');
      expect(repository.activeGeneration?.generationId, 'generation-1');
      expect(
        repository.activeGeneration?.correlationId,
        repository.startCorrelationIds.single,
      );
    },
  );

  test(
    'start generation completes safely when disposed while remembering active generation',
    () async {
      final rememberCompleter = Completer<void>();
      final repository = _FakeTemplateGenerationRepository(
        startResult: _generation(status: TemplateGenerationStatus.queued),
        rememberCompleter: rememberCompleter,
      );
      final walletController = _FakeWalletController(_wallet(balance: 100));
      final container = ProviderContainer(
        overrides: [
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          walletControllerProvider.overrideWith(() => walletController),
        ],
      );

      final controller = container.read(
        templateGenerationControllerProvider.notifier,
      );
      controller.selectPhoto(XFile('pet.jpg', name: 'pet.jpg'));

      final generationFuture = controller.startGeneration(
        _template(tokenCost: 50),
      );
      await repository.rememberStarted.future;

      container.dispose();
      rememberCompleter.complete();

      final generation = await generationFuture;

      expect(generation?.generationId, 'generation-1');
      expect(repository.activeGeneration?.generationId, 'generation-1');
      expect(walletController.loadCalls, 0);
    },
  );
}

class _FakeTemplateGenerationRepository
    implements TemplateGenerationRepository {
  _FakeTemplateGenerationRepository({
    this.startResult,
    this.startError,
    this.fetchError,
    this.startCompleter,
    this.rememberCompleter,
    this.readActiveCompleter,
  });

  final TemplateGenerationResult? startResult;
  final Object? startError;
  final Object? fetchError;
  final Completer<void>? startCompleter;
  final Completer<void>? rememberCompleter;
  final Completer<void>? readActiveCompleter;
  final Completer<void> startStarted = Completer<void>();
  final Completer<void> rememberStarted = Completer<void>();
  int startCalls = 0;
  int fetchCalls = 0;
  final List<XFile> startSourceImages = <XFile>[];
  final List<String?> startCorrelationIds = <String?>[];
  final List<String?> fetchCorrelationIds = <String?>[];
  ({String generationId, String correlationId})? activeGeneration;

  @override
  Future<TemplateGenerationResult> startGeneration({
    required String templateId,
    required XFile sourceImage,
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    startCalls++;
    if (!startStarted.isCompleted) {
      startStarted.complete();
    }
    startSourceImages.add(sourceImage);
    startCorrelationIds.add(correlationId);
    final completer = startCompleter;
    if (completer != null) {
      await completer.future;
    }
    final error = startError;
    if (error != null) {
      throw error;
    }

    return startResult ?? _generation(status: TemplateGenerationStatus.queued);
  }

  @override
  Future<TemplateGenerationResult> fetchGeneration(
    String generationId, {
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    fetchCalls++;
    fetchCorrelationIds.add(correlationId);
    final error = fetchError;
    if (error != null) {
      throw error;
    }

    return _generation(status: TemplateGenerationStatus.completed);
  }

  @override
  Future<TemplateGenerationResult?> readCachedGeneration(
    String generationId,
  ) async {
    return null;
  }

  @override
  Future<List<TemplateGenerationResult>?> readCachedGenerations({
    String? status,
  }) async {
    return null;
  }

  @override
  Future<int?> readCachedUnreadGenerationCount() async {
    return null;
  }

  @override
  Future<({String generationId, String correlationId})?>
  readActiveGeneration() async {
    final completer = readActiveCompleter;
    if (completer != null) {
      await completer.future;
    }
    return activeGeneration;
  }

  @override
  Future<void> rememberActiveGeneration({
    required String generationId,
    String? correlationId,
  }) async {
    if (!rememberStarted.isCompleted) {
      rememberStarted.complete();
    }
    activeGeneration = (
      generationId: generationId,
      correlationId: correlationId ?? 'generation-fake-correlation',
    );
    final completer = rememberCompleter;
    if (completer != null) {
      await completer.future;
    }
  }

  @override
  Future<void> clearActiveGeneration(String generationId) async {
    if (activeGeneration?.generationId == generationId) {
      activeGeneration = null;
    }
  }

  @override
  Future<RemoveGenerationWatermarkResult> removeWatermark(
    String generationId, {
    String paymentMethod = 'credit',
    CancelToken? cancelToken,
  }) async {
    return const RemoveGenerationWatermarkResult(
      watermarkRemoved: true,
      creditsSpent: 0,
    );
  }

  @override
  Future<GenerationMediaAccessResult> fetchDownloadUrl(
    String generationId, {
    CancelToken? cancelToken,
  }) async {
    return const GenerationMediaAccessResult(
      mediaUrl: 'https://cdn.example.com/result.jpg',
      hasWatermark: false,
      fileName: 'result.jpg',
    );
  }

  @override
  Future<GenerationMediaAccessResult> fetchShareUrl(
    String generationId, {
    CancelToken? cancelToken,
  }) async {
    return const GenerationMediaAccessResult(
      mediaUrl: 'https://cdn.example.com/result.jpg',
      hasWatermark: false,
      fileName: 'result.jpg',
    );
  }

  @override
  Future<void> upsertCachedGeneration(
    TemplateGenerationResult generation,
  ) async {}

  @override
  Future<void> clearLocalCache() async {}

  @override
  Future<List<TemplateGenerationResult>> fetchGenerations({
    String? status,
    int? skip,
    int? take,
    CancelToken? cancelToken,
  }) async {
    return const [];
  }

  @override
  Future<int> fetchUnreadGenerationCount({CancelToken? cancelToken}) async {
    return 0;
  }

  @override
  Future<void> markGenerationRead(
    String generationId, {
    CancelToken? cancelToken,
  }) async {}

  @override
  Future<void> deleteGeneration(
    String generationId, {
    CancelToken? cancelToken,
  }) async {}

  @override
  Future<void> submitGenerationFeedback({
    required String generationId,
    required int rating,
    List<String> selectedReasons = const [],
    String? comment,
    double? inputPhotoQualityScore,
  }) async {}

  @override
  Future<String> submitFeedback({
    required String type,
    required String category,
    int? rating,
    String? message,
    String? generationId,
    String? templateId,
    String? petId,
    String sourceScreen = 'settings',
    CancelToken? cancelToken,
    bool retryTransientFailures = false,
  }) async {
    return 'feedback-1';
  }

  @override
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
    String? appVersion,
    String? locale,
  }) async {}

  @override
  Future<void> unregisterPushToken(String token) async {}

  @override
  Future<void> recordTemplateAnalyticsEvent({
    required String templateId,
    required String eventType,
    String source = 'mobile',
    String? generationId,
    Map<String, Object?>? metadata,
    CancelToken? cancelToken,
  }) async {}

  @override
  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? generationId,
    Map<String, Object?> metadata = const {},
    CancelToken? cancelToken,
  }) async {}

  @override
  Future<CompatibleGenerationTemplates> fetchCompatibleTemplates(
    String resultId, {
    CancelToken? cancelToken,
  }) async {
    return const CompatibleGenerationTemplates(
      resultId: 'result-1',
      inputMediaType: TemplateType.image,
      templates: [],
    );
  }

  @override
  Future<TemplateGenerationResult> startGenerationFromResult({
    required String parentGenerationResultId,
    required String templateId,
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    return startResult ?? _generation(status: TemplateGenerationStatus.queued);
  }

  @override
  Future<TemplateGenerationResult> startGenerationFromPet({
    required String petId,
    String? petPhotoId,
    required String templateId,
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    return startResult ?? _generation(status: TemplateGenerationStatus.queued);
  }

  @override
  Future<TemplateGenerationResult> generateSimilar({
    required String sourceGenerationId,
    String variationStrength = 'medium',
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    return startResult ?? _generation(status: TemplateGenerationStatus.queued);
  }

  @override
  Future<List<PetProfile>> fetchPets({CancelToken? cancelToken}) async {
    return const [];
  }

  @override
  Future<PetProfile> createPet({
    required String name,
    required String type,
    String? breed,
    CancelToken? cancelToken,
  }) async {
    return PetProfile(
      id: 'pet-1',
      name: name,
      type: type,
      breed: breed,
      photosCount: 0,
      generationsCount: 0,
      createdAtUtc: DateTime(2026),
      updatedAtUtc: DateTime(2026),
    );
  }

  @override
  Future<PetProfile> updatePet({
    required String petId,
    required String name,
    required String type,
    String? breed,
    CancelToken? cancelToken,
  }) async {
    return PetProfile(
      id: petId,
      name: name,
      type: type,
      breed: breed,
      photosCount: 0,
      generationsCount: 0,
      createdAtUtc: DateTime(2026),
      updatedAtUtc: DateTime(2026),
    );
  }

  @override
  Future<void> deletePet(String petId, {CancelToken? cancelToken}) async {}

  @override
  Future<PetPhoto> uploadPetPhoto({
    required String petId,
    required XFile photo,
    CancelToken? cancelToken,
  }) async {
    return PetPhoto(
      id: 'photo-1',
      petId: petId,
      mediaAssetId: 'media-1',
      url: photo.path,
      fileName: photo.name,
      contentType: 'image/jpeg',
      isFavorite: false,
      isAvatar: true,
      sortOrder: 1,
      createdAtUtc: DateTime(2026),
    );
  }

  @override
  Future<List<PetPhoto>> fetchPetPhotos(
    String petId, {
    CancelToken? cancelToken,
  }) async {
    return const [];
  }

  @override
  Future<PetPhoto> setPetPhotoAsAvatar({
    required String petId,
    required String photoId,
    CancelToken? cancelToken,
  }) async {
    return PetPhoto(
      id: photoId,
      petId: petId,
      mediaAssetId: 'media-1',
      url: 'https://cdn.example.com/pet.jpg',
      fileName: 'pet.jpg',
      contentType: 'image/jpeg',
      isFavorite: false,
      isAvatar: true,
      sortOrder: 1,
      createdAtUtc: DateTime(2026),
    );
  }

  @override
  Future<PetPhoto> setPetPhotoFavorite({
    required String petId,
    required String photoId,
    required bool isFavorite,
    CancelToken? cancelToken,
  }) async {
    return PetPhoto(
      id: photoId,
      petId: petId,
      mediaAssetId: 'media-1',
      url: 'https://cdn.example.com/pet.jpg',
      fileName: 'pet.jpg',
      contentType: 'image/jpeg',
      isFavorite: isFavorite,
      isAvatar: false,
      sortOrder: 1,
      createdAtUtc: DateTime(2026),
    );
  }

  @override
  Future<void> deletePetPhoto({
    required String petId,
    required String photoId,
    CancelToken? cancelToken,
  }) async {}

  @override
  Future<List<TemplateGenerationResult>> fetchPetGenerations(
    String petId, {
    CancelToken? cancelToken,
  }) async {
    return const [];
  }
}

class _FakeImageUploadOptimizer extends ImageUploadOptimizer {
  _FakeImageUploadOptimizer(this.optimized);

  final OptimizedUploadFile optimized;
  final List<XFile> sources = <XFile>[];
  final List<CancelToken?> cancelTokens = <CancelToken?>[];

  @override
  Future<OptimizedUploadFile> optimizeGenerationSource(
    XFile source, {
    CancelToken? cancelToken,
  }) async {
    sources.add(source);
    cancelTokens.add(cancelToken);
    return optimized;
  }
}

class _FakeWalletController extends WalletController {
  _FakeWalletController(this.wallet, {this.loadError});

  final WalletStateModel wallet;
  final Object? loadError;
  int loadCalls = 0;
  final List<String?> loadCorrelationIds = <String?>[];

  @override
  WalletState build() {
    return WalletState(wallet: wallet, isLoading: false);
  }

  @override
  Future<void> load({bool refresh = false}) async {
    loadCalls++;
    loadCorrelationIds.add(LogCorrelationContext.currentCorrelationId);
    final error = loadError;
    if (error != null) {
      throw error;
    }
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
