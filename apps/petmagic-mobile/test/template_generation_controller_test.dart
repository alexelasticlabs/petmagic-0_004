import 'dart:async';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/core/files/local_media_file.dart';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/log_correlation_context.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('template generation controller does not cache repository in build', () {
    final source = File(
      'lib/features/templates/presentation/template_generation_controller.dart',
    ).readAsStringSync();

    expect(
      source,
      isNot(contains('late final GenerationRepository _repository')),
    );
    expect(
      source,
      contains(
        'GenerationRepository get _repository =>\n'
        '      ref.read(templateGenerationRepositoryProvider)',
      ),
    );
    expect(source, contains('AppLifecycleSignal.instance.addListener'));
    expect(source, contains('AppLifecycleSignal.instance.removeListener'));
    expect(source, contains('void _handleAppLifecycleSignal()'));
    expect(
      source,
      isNot(
        contains(
          '_repository = ref.watch(templateGenerationRepositoryProvider)',
        ),
      ),
    );
  });

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
          _authenticatedLaunchOverride(),
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

  test(
    'template generation controller stays idle for explicit unauthenticated app state',
    () async {
      final repository = _FakeTemplateGenerationRepository()
        ..activeGeneration = (
          generationId: 'generation-restored',
          correlationId: 'generation-restored-correlation',
        );
      final walletController = _FakeWalletController(_wallet(balance: 100));
      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            () => _MutableTemplateAppLaunchController(false),
          ),
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          walletControllerProvider.overrideWith(() => walletController),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        templateGenerationControllerProvider.notifier,
      );

      await Future<void>.delayed(Duration.zero);
      controller.selectPhoto(XFile('pet.jpg', name: 'pet.jpg'));
      final gate = await controller.checkGate(_template(tokenCost: 50));
      final generation = await controller.startGeneration(
        _template(tokenCost: 50),
      );
      await controller.refreshGeneration();

      expect(gate.kind, TemplateGenerationGateKind.notEnoughTokens);
      expect(generation, isNull);
      expect(repository.startCalls, 0);
      expect(repository.fetchCalls, 0);
      expect(walletController.loadCalls, 0);
      expect(
        container.read(templateGenerationControllerProvider).isPolling,
        false,
      );
    },
  );

  test(
    'template generation controller stops polling and private refresh after sign out',
    () async {
      final repository = _FakeTemplateGenerationRepository(
        startResult: _generation(status: TemplateGenerationStatus.queued),
      );
      final walletController = _FakeWalletController(_wallet(balance: 100));
      final launchController = _MutableTemplateAppLaunchController(true);
      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(() => launchController),
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

      expect(generation?.status, TemplateGenerationStatus.queued);
      expect(
        container.read(templateGenerationControllerProvider).isPolling,
        true,
      );
      expect(repository.startCalls, 1);
      expect(repository.fetchCalls, 0);

      launchController.setAuthenticated(false);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(templateGenerationControllerProvider).isPolling,
        false,
      );

      controller.selectPhoto(XFile('pet-2.jpg', name: 'pet-2.jpg'));
      final blocked = await controller.startGeneration(
        _template(tokenCost: 50),
      );
      await controller.refreshGeneration();

      expect(blocked, isNull);
      expect(repository.startCalls, 1);
      expect(repository.fetchCalls, 0);
      expect(
        walletController.loadCalls,
        1,
        reason:
            'initial queued creation refreshes wallet once, sign-out must not add more refreshes',
      );
    },
  );

  test(
    'normalizes wrapped balance error keys before exposing UI state',
    () async {
      final repository = _FakeTemplateGenerationRepository(
        startError: const AppException(
          '  AppException: ECONOMY.INSUFFICIENT_BALANCE  ',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          _authenticatedLaunchOverride(),
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

      final state = container.read(templateGenerationControllerProvider);
      expect(state.errorMessage, 'templates.insufficient_balance');
    },
  );

  test(
    'keeps structured queue rejection for high-load generation errors',
    () async {
      const rejection = GenerationWaitTooLongException(
        mediaType: 'video',
        tier: 'free',
        estimatedWaitSeconds: 1800,
        maxAllowedWaitSeconds: 1200,
        retryAfterSeconds: 300,
        canRetry: true,
        canUpgradeForPriority: true,
      );
      final repository = _FakeTemplateGenerationRepository(
        startError: rejection,
      );
      final container = ProviderContainer(
        overrides: [
          _authenticatedLaunchOverride(),
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

      final state = container.read(templateGenerationControllerProvider);
      expect(state.isCreating, false);
      expect(state.isPolling, false);
      expect(state.errorMessage, 'templates.generation_wait_too_long');
      expect(state.queueRejection, same(rejection));
      expect(state.queueRejection?.retryAfterSeconds, 300);
      expect(state.queueRejection?.canUpgradeForPriority, true);
    },
  );

  test('premium wallet can pass premium template generation gate', () async {
    final container = ProviderContainer(
      overrides: [
        _authenticatedLaunchOverride(),
        templateGenerationRepositoryProvider.overrideWithValue(
          _FakeTemplateGenerationRepository(),
        ),
        walletControllerProvider.overrideWith(
          () => _FakeWalletController(_wallet(balance: 100, isPremium: true)),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      templateGenerationControllerProvider.notifier,
    );

    final gate = await controller.checkGate(
      _template(tokenCost: 50, isPremium: true),
    );

    expect(gate.kind, TemplateGenerationGateKind.allowed);
    expect(gate.isPremium, isTrue);
  });

  test('free wallet keeps premium template generation gated', () async {
    final repository = _FakeTemplateGenerationRepository();
    final container = ProviderContainer(
      overrides: [
        _authenticatedLaunchOverride(),
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

    final gate = await controller.checkGate(
      _template(tokenCost: 50, isPremium: true),
    );

    expect(gate.kind, TemplateGenerationGateKind.premiumRequired);
    expect(gate.isPremium, isFalse);
    expect(repository.startCalls, 0);
  });

  test('checkGate skips wallet reload while offline', () async {
    late _FakeWalletController walletController;
    final container = ProviderContainer(
      overrides: [
        _authenticatedLaunchOverride(),
        templateGenerationRepositoryProvider.overrideWithValue(
          _FakeTemplateGenerationRepository(),
        ),
        walletControllerProvider.overrideWith(() {
          walletController = _FakeWalletController.withState(
            const WalletState(isLoading: false),
          );
          return walletController;
        }),
        networkStatusControllerProvider.overrideWith(
          () => _TestTemplateNetworkStatusController(false),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      templateGenerationControllerProvider.notifier,
    );

    final gate = await controller.checkGate(_template(tokenCost: 50));

    expect(walletController.loadCalls, 0);
    expect(gate.kind, TemplateGenerationGateKind.notEnoughTokens);
    expect(gate.balance, 0);
    expect(gate.isPremium, isFalse);
  });

  test(
    'premium generation flow starts after premium gate is allowed',
    () async {
      final repository = _FakeTemplateGenerationRepository();
      final container = ProviderContainer(
        overrides: [
          _authenticatedLaunchOverride(),
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          walletControllerProvider.overrideWith(
            () => _FakeWalletController(_wallet(balance: 100, isPremium: true)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        templateGenerationControllerProvider.notifier,
      );
      controller.selectPhoto(XFile('pet.jpg', name: 'pet.jpg'));

      final gate = await controller.checkGate(
        _template(tokenCost: 50, isPremium: true),
      );
      expect(gate.kind, TemplateGenerationGateKind.allowed);

      final generation = await controller.startGeneration(
        _template(tokenCost: 50, isPremium: true),
      );

      expect(generation, isNotNull);
      expect(repository.startCalls, 1);
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
        _authenticatedLaunchOverride(),
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

  test(
    'normalizes wrapped polling error keys before exposing UI state',
    () async {
      final repository = _FakeTemplateGenerationRepository(
        startResult: _generation(status: TemplateGenerationStatus.queued),
        fetchError: const AppException(
          ' RuntimeError: templates.server_unavailable ',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          _authenticatedLaunchOverride(),
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
      await controller.refreshGeneration();

      final state = container.read(templateGenerationControllerProvider);
      expect(state.isPolling, false);
      expect(state.errorMessage, 'templates.server_unavailable');
    },
  );

  test('keeps state quiet when generation start is cancelled', () async {
    final repository = _FakeTemplateGenerationRepository(
      startError: const RequestCancelledException(),
    );
    final container = ProviderContainer(
      overrides: [
        _authenticatedLaunchOverride(),
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
          _authenticatedLaunchOverride(),
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
    'passes selected source image to repository for validation and upload',
    () async {
      final repository = _FakeTemplateGenerationRepository(
        startResult: _generation(status: TemplateGenerationStatus.completed),
      );
      final container = ProviderContainer(
        overrides: [
          _authenticatedLaunchOverride(),
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
      controller.selectPhoto(XFile('original-source.png', name: 'source.png'));

      final generation = await controller.startGeneration(
        _template(tokenCost: 50),
      );

      expect(generation?.isTerminal, true);
      expect(repository.startSourceImages.single.path, 'original-source.png');
      expect(repository.startCancelTokens.single, isNotNull);
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
          _authenticatedLaunchOverride(),
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
          _authenticatedLaunchOverride(),
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
          _authenticatedLaunchOverride(),
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
          _authenticatedLaunchOverride(),
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
          _authenticatedLaunchOverride(),
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
    'active generation restore waits for reconnect before fetching status',
    () async {
      final networkStatusController = _TestTemplateNetworkStatusController(
        false,
      );
      final repository = _FakeTemplateGenerationRepository()
        ..activeGeneration = (
          generationId: 'generation-1',
          correlationId: 'generation-restored-offline',
        );
      final container = ProviderContainer(
        overrides: [
          _authenticatedLaunchOverride(),
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          walletControllerProvider.overrideWith(
            () => _FakeWalletController(_wallet(balance: 100)),
          ),
          networkStatusControllerProvider.overrideWith(
            () => networkStatusController,
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(templateGenerationControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repository.fetchCalls, 0);
      expect(
        container.read(templateGenerationControllerProvider).isPolling,
        isFalse,
      );

      networkStatusController.setHasInternet(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repository.fetchCalls, 1);
      expect(
        repository.fetchCorrelationIds.single,
        'generation-restored-offline',
      );
    },
  );

  test(
    'restored terminal generation clears active marker and stops polling',
    () async {
      final repository = _FakeTemplateGenerationRepository()
        ..activeGeneration = (
          generationId: 'generation-1',
          correlationId: 'generation-restored-terminal',
        );
      final walletController = _FakeWalletController(_wallet(balance: 100));
      final container = ProviderContainer(
        overrides: [
          _authenticatedLaunchOverride(),
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          walletControllerProvider.overrideWith(() => walletController),
        ],
      );
      addTearDown(container.dispose);

      container.read(templateGenerationControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(templateGenerationControllerProvider);
      expect(repository.fetchCalls, 1);
      expect(repository.clearActiveCalls, 1);
      expect(repository.rememberActiveCalls, 0);
      expect(repository.activeGeneration, isNull);
      expect(
        repository.fetchCorrelationIds.single,
        'generation-restored-terminal',
      );
      expect(state.generation?.status, TemplateGenerationStatus.completed);
      expect(state.isPolling, isFalse);
      expect(state.errorMessage, isNull);
      expect(walletController.loadCalls, 1);
    },
  );

  test(
    'active generation polling pauses offline and resumes on reconnect',
    () async {
      final networkStatusController = _TestTemplateNetworkStatusController(
        true,
      );
      final repository = _FakeTemplateGenerationRepository(
        startResult: _generation(status: TemplateGenerationStatus.queued),
      );
      final container = ProviderContainer(
        overrides: [
          _authenticatedLaunchOverride(),
          templateGenerationRepositoryProvider.overrideWithValue(repository),
          walletControllerProvider.overrideWith(
            () => _FakeWalletController(_wallet(balance: 100)),
          ),
          networkStatusControllerProvider.overrideWith(
            () => networkStatusController,
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
      expect(repository.fetchCalls, 0);

      networkStatusController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(templateGenerationControllerProvider).isPolling,
        false,
      );

      networkStatusController.setHasInternet(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repository.fetchCalls, 1);
      expect(
        repository.fetchCorrelationIds.single,
        repository.startCorrelationIds.single,
      );
    },
  );

  testWidgets(
    'active generation polling pauses in background and resumes in foreground',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );

      final repository = _FakeTemplateGenerationRepository(
        startResult: _generation(status: TemplateGenerationStatus.queued),
      );
      final container = ProviderContainer(
        overrides: [
          _authenticatedLaunchOverride(),
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

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(
        container.read(templateGenerationControllerProvider).isPolling,
        false,
      );

      await controller.refreshGeneration();
      expect(repository.fetchCalls, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(repository.fetchCalls, 1);
      expect(
        repository.fetchCorrelationIds.single,
        repository.startCorrelationIds.single,
      );
    },
  );

  test('manual generation refresh skips backend fetch while offline', () async {
    final networkStatusController = _TestTemplateNetworkStatusController(true);
    final repository = _FakeTemplateGenerationRepository(
      startResult: _generation(status: TemplateGenerationStatus.queued),
    );
    final container = ProviderContainer(
      overrides: [
        _authenticatedLaunchOverride(),
        templateGenerationRepositoryProvider.overrideWithValue(repository),
        walletControllerProvider.overrideWith(
          () => _FakeWalletController(_wallet(balance: 100)),
        ),
        networkStatusControllerProvider.overrideWith(
          () => networkStatusController,
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      templateGenerationControllerProvider.notifier,
    );
    controller.selectPhoto(XFile('pet.jpg', name: 'pet.jpg'));
    await controller.startGeneration(_template(tokenCost: 50));

    networkStatusController.setHasInternet(false);
    await Future<void>.delayed(Duration.zero);
    await controller.refreshGeneration();

    final state = container.read(templateGenerationControllerProvider);
    expect(repository.fetchCalls, 0);
    expect(state.generation?.status, TemplateGenerationStatus.queued);
    expect(state.isPolling, isFalse);
    expect(state.errorMessage, isNull);
  });

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
          _authenticatedLaunchOverride(),
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
          _authenticatedLaunchOverride(),
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
          _authenticatedLaunchOverride(),
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

  test('completed generation skips wallet refresh while offline', () async {
    final repository = _FakeTemplateGenerationRepository(
      startResult: _generation(status: TemplateGenerationStatus.completed),
    );
    final walletController = _FakeWalletController(_wallet(balance: 100));
    final container = ProviderContainer(
      overrides: [
        _authenticatedLaunchOverride(),
        templateGenerationRepositoryProvider.overrideWithValue(repository),
        walletControllerProvider.overrideWith(() => walletController),
        networkStatusControllerProvider.overrideWith(
          () => _TestTemplateNetworkStatusController(false),
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

    expect(generation?.status, TemplateGenerationStatus.completed);
    expect(walletController.loadCalls, 0);
  });
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
  int rememberActiveCalls = 0;
  int clearActiveCalls = 0;
  final List<LocalMediaFile> startSourceImages = <LocalMediaFile>[];
  final List<String?> startCorrelationIds = <String?>[];
  final List<RequestCancellation?> startCancelTokens = <RequestCancellation?>[];
  final List<String?> fetchCorrelationIds = <String?>[];
  ({String generationId, String correlationId})? activeGeneration;

  @override
  TemplateGenerationResult parseRealtimePayload(Map<String, dynamic> payload) {
    throw UnsupportedError('Realtime parsing is not used by this fake.');
  }

  @override
  Future<TemplateGenerationResult> startGeneration({
    required String templateId,
    required LocalMediaFile sourceImage,
    int? expectedTemplateVersion,
    String? correlationId,
    RequestCancellation? cancelToken,
  }) async {
    startCalls++;
    if (!startStarted.isCompleted) {
      startStarted.complete();
    }
    startSourceImages.add(sourceImage);
    startCorrelationIds.add(correlationId);
    startCancelTokens.add(cancelToken);
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
    RequestCancellation? cancelToken,
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
  Future<GenerationCancelResult> cancelGeneration(
    String generationId, {
    String? correlationId,
    RequestCancellation? cancelToken,
  }) async {
    return GenerationCancelResult(
      generation: _generation(
        generationId: generationId,
        status: TemplateGenerationStatus.cancelled,
      ),
      refunded: false,
    );
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
    rememberActiveCalls++;
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
    clearActiveCalls++;
    if (activeGeneration?.generationId == generationId) {
      activeGeneration = null;
    }
  }

  @override
  Future<RemoveGenerationWatermarkResult> removeWatermark(
    String generationId, {
    String paymentMethod = 'credit',
    RequestCancellation? cancelToken,
  }) async {
    return const RemoveGenerationWatermarkResult(
      watermarkRemoved: true,
      creditsSpent: 0,
    );
  }

  @override
  Future<GenerationMediaAccessResult> fetchDownloadUrl(
    String generationId, {
    RequestCancellation? cancelToken,
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
    RequestCancellation? cancelToken,
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
    RequestCancellation? cancelToken,
  }) async {
    return const [];
  }

  @override
  Future<TemplateGenerationGalleryPage> fetchGenerationPage({
    String? status,
    String? cursor,
    int? take,
    RequestCancellation? cancelToken,
  }) async {
    return TemplateGenerationGalleryPage(
      items: const [],
      hasMore: false,
      unreadCount: 0,
      appliedFilter: status ?? 'all',
    );
  }

  @override
  Future<int> fetchUnreadGenerationCount({
    RequestCancellation? cancelToken,
  }) async {
    return 0;
  }

  @override
  Future<void> markGenerationRead(
    String generationId, {
    RequestCancellation? cancelToken,
  }) async {}

  @override
  Future<void> deleteGeneration(
    String generationId, {
    RequestCancellation? cancelToken,
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
    RequestCancellation? cancelToken,
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
    RequestCancellation? cancelToken,
  }) async {}

  @override
  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? generationId,
    Map<String, Object?> metadata = const {},
    RequestCancellation? cancelToken,
  }) async {}

  @override
  Future<CompatibleGenerationTemplates> fetchCompatibleTemplates(
    String resultId, {
    RequestCancellation? cancelToken,
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
    int? expectedTemplateVersion,
    String? correlationId,
    RequestCancellation? cancelToken,
  }) async {
    return startResult ?? _generation(status: TemplateGenerationStatus.queued);
  }

  @override
  Future<TemplateGenerationResult> startGenerationFromPet({
    required String petId,
    String? petPhotoId,
    required String templateId,
    int? expectedTemplateVersion,
    String? correlationId,
    RequestCancellation? cancelToken,
  }) async {
    return startResult ?? _generation(status: TemplateGenerationStatus.queued);
  }

  @override
  Future<TemplateGenerationResult> generateSimilar({
    required String sourceGenerationId,
    String variationStrength = 'medium',
    String? correlationId,
    RequestCancellation? cancelToken,
  }) async {
    return startResult ?? _generation(status: TemplateGenerationStatus.queued);
  }

  @override
  Future<List<PetProfile>> fetchPets({RequestCancellation? cancelToken}) async {
    return const [];
  }

  @override
  Future<PetProfile> createPet({
    required String name,
    required String type,
    String? breed,
    RequestCancellation? cancelToken,
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
    RequestCancellation? cancelToken,
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
  Future<void> deletePet(
    String petId, {
    RequestCancellation? cancelToken,
  }) async {}

  @override
  Future<PetPhoto> uploadPetPhoto({
    required String petId,
    required XFile photo,
    RequestCancellation? cancelToken,
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
    RequestCancellation? cancelToken,
  }) async {
    return const [];
  }

  @override
  Future<PetPhoto> setPetPhotoAsAvatar({
    required String petId,
    required String photoId,
    RequestCancellation? cancelToken,
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
    RequestCancellation? cancelToken,
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
    RequestCancellation? cancelToken,
  }) async {}

  @override
  Future<List<TemplateGenerationResult>> fetchPetGenerations(
    String petId, {
    RequestCancellation? cancelToken,
  }) async {
    return const [];
  }
}

class _MutableTemplateAppLaunchController extends AppLaunchController {
  _MutableTemplateAppLaunchController(this._isAuthenticated);

  bool _isAuthenticated;

  @override
  AppLaunchState build() {
    return AppLaunchState(
      isLoading: false,
      isAuthenticated: _isAuthenticated,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: _isAuthenticated,
    );
  }

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: value,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: value,
    );
  }
}

dynamic _authenticatedLaunchOverride() {
  return appLaunchControllerProvider.overrideWith(
    () => _MutableTemplateAppLaunchController(true),
  );
}

class _FakeWalletController extends WalletController {
  _FakeWalletController(this.wallet, {this.loadError}) : _initialState = null;

  final WalletStateModel wallet;
  final Object? loadError;
  int loadCalls = 0;
  final List<String?> loadCorrelationIds = <String?>[];
  final WalletState? _initialState;

  _FakeWalletController.withState(WalletState initialState)
    : wallet = const WalletStateModel(
        userId: '',
        balance: 0,
        adRewardsRemainingToday: 0,
        isPremium: false,
        updatedAtUtc: null,
      ),
      loadError = null,
      _initialState = initialState;

  @override
  WalletState build() {
    return _initialState ?? WalletState(wallet: wallet, isLoading: false);
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

class _TestTemplateNetworkStatusController extends NetworkStatusController {
  _TestTemplateNetworkStatusController(bool hasInternet)
    : _initialHasInternet = hasInternet;

  final bool _initialHasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: _initialHasInternet);
  }

  void setHasInternet(bool value) {
    state = state.copyWith(hasInternet: value);
  }
}

TemplateItem _template({required int tokenCost, bool isPremium = false}) {
  return TemplateItem(
    templateId: 'template-1',
    templateType: TemplateType.image,
    title: 'Magic portrait',
    shortDescription: 'A bright portrait.',
    petPhotoRequirements: const ['Clear face'],
    category: 'Portrait',
    tags: const ['portrait'],
    isPremium: isPremium,
    tokenCost: tokenCost,
  );
}

TemplateGenerationResult _generation({
  required TemplateGenerationStatus status,
  String generationId = 'generation-1',
}) {
  final now = DateTime.utc(2026, 5, 25);
  return TemplateGenerationResult(
    generationId: generationId,
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

WalletStateModel _wallet({required int balance, bool isPremium = false}) {
  return WalletStateModel(
    userId: 'user-1',
    balance: balance,
    adRewardsRemainingToday: 0,
    isPremium: isPremium,
    updatedAtUtc: DateTime.utc(2026, 5, 25),
  );
}
