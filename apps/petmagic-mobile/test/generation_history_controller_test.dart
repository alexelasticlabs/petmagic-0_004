import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';
import 'generation_history_controller_test_support.dart';

void main() {
  configureGenerationHistoryControllerTestHarness();

  test(
    'generation history controller does not watch dependencies into fields',
    () {
      final source = File(
        'lib/features/templates/application/generation_history_controller.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('_activeRealtimeClient = ref.read(realtimeClientProvider);'),
      );
      expect(
        source,
        contains(
          'final galleryStore = ref.read(generationGalleryStoreProvider);',
        ),
      );
      expect(
        source,
        isNot(
          contains('_activeRealtimeClient = ref.watch(realtimeClientProvider)'),
        ),
      );
      expect(
        source,
        isNot(contains('ref.watch(templateGenerationRepositoryProvider)')),
      );
    },
  );

  test(
    'generation history controller stops realtime and private requests after sign out',
    () async {
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
      );
      final realtimeClient = FakeRealtimeClient();
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        realtimeClient: realtimeClient,
      );
      addTearDown(harness.dispose);

      final controller = harness.controller;

      controller.setScreenVisible(true);
      await controller.load();
      await Future<void>.delayed(Duration.zero);

      expect(repository.fetchPageCalls, hasLength(1));
      expect(realtimeClient.connectCalls, 1);

      harness.appLaunchController.setAuthenticated(false);
      await Future<void>.delayed(Duration.zero);

      expect(realtimeClient.disconnectCalls, 1);
      expect(harness.state.items, isEmpty);

      await controller.load(refresh: true);
      await controller.loadMore();
      await controller.markRead('generation-ready');
      await controller.deleteGeneration('generation-ready');

      expect(
        repository.fetchPageCalls,
        hasLength(1),
        reason: 'history refresh must not call private API after sign out',
      );
      expect(repository.markReadCalls, isEmpty);
      expect(repository.deleteGenerationCalls, isEmpty);
      expect(realtimeClient.connectCalls, 1);
    },
  );

  test(
    'generation history controller stays idle for explicit unauthenticated app state',
    () async {
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [
            generationFixture(
              generationId: 'generation-ready',
              status: TemplateGenerationStatus.completed,
            ),
          ],
        },
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        authenticated: false,
      );
      addTearDown(harness.dispose);

      final controller = harness.controller;

      controller.setScreenVisible(true);
      await controller.load();
      await controller.refreshUnreadCount();
      await Future<void>.delayed(Duration.zero);

      expect(repository.fetchPageCalls, isEmpty);
      expect(repository.fetchUnreadCountCalls, 0);
      expect(harness.store.cleanupCurrentAccountArtifactsCalls, 0);
      expect(harness.realtimeClient.connectCalls, 0);
      expect(harness.state.isLoading, isFalse);
    },
  );

  test(
    'loads remote history by filter and reuses in-memory filter cache',
    () async {
      final active = generationFixture(
        generationId: 'generation-active',
        status: TemplateGenerationStatus.generating,
      );
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [active, ready],
          'completed': [ready],
        },
        unreadCount: 2,
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
      );
      addTearDown(harness.dispose);

      final controller = harness.controller;

      await controller.load();
      expect(harness.state.items.map((item) => item.generationId), [
        'generation-active',
        'generation-ready',
      ]);

      await controller.load(filter: GenerationHistoryFilter.ready);
      expect(harness.state.filter, GenerationHistoryFilter.ready);
      expect(harness.state.items.map((item) => item.generationId), [
        'generation-ready',
      ]);

      final fetchCallsBeforeCachedFilter = List.of(repository.fetchCalls);
      await controller.load(filter: GenerationHistoryFilter.all);
      expect(harness.state.filter, GenerationHistoryFilter.all);
      expect(harness.state.items.map((item) => item.generationId), [
        'generation-active',
        'generation-ready',
      ]);
      expect(repository.fetchCalls, fetchCallsBeforeCachedFilter);
      expect(repository.fetchCalls, [
        (status: null, take: 50),
        (status: 'completed', take: 50),
      ]);
      expect(repository.fetchUnreadCountCalls, 0);
    },
  );

  test(
    'queues latest filter change while a history load is in flight',
    () async {
      final allFetchCompleter = Completer<void>();
      final active = generationFixture(
        generationId: 'generation-active',
        status: TemplateGenerationStatus.generating,
      );
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [active],
          'completed': [ready],
        },
        fetchCompletersByStatus: {null: allFetchCompleter},
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
      );
      addTearDown(harness.dispose);

      final allLoad = harness.controller.load();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(repository.fetchCalls, [(status: null, take: 50)]);

      final readyLoad = harness.controller.load(
        filter: GenerationHistoryFilter.ready,
      );
      await Future<void>.delayed(Duration.zero);
      expect(repository.fetchCalls, [(status: null, take: 50)]);

      allFetchCompleter.complete();
      await allLoad;
      await readyLoad;

      expect(repository.fetchCalls, [
        (status: null, take: 50),
        (status: 'completed', take: 50),
      ]);
      expect(harness.state.filter, GenerationHistoryFilter.ready);
      expect(harness.state.items.map((item) => item.generationId), [
        'generation-ready',
      ]);
    },
  );

  test('loads remote history when unread count refresh fails', () async {
    final ready = generationFixture(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.completed,
    );
    final repository = FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [ready],
      },
      remotePagesByCursor: {
        generationHistoryPageKey(null, null): TemplateGenerationGalleryPage(
          items: [ready],
          hasMore: false,
          unreadCount: 0,
          appliedFilter: 'all',
        ),
      },
      unreadCountError: const AppException('templates.unread_count_failed'),
    );
    final harness = GenerationHistoryControllerHarness(repository: repository);
    addTearDown(harness.dispose);

    await harness.controller.load();

    expect(repository.fetchCalls, [(status: null, take: 50)]);
    expect(repository.fetchUnreadCountCalls, 1);
    expect(harness.state.items.map((item) => item.generationId), [
      'generation-ready',
    ]);
    expect(harness.state.isLoading, isFalse);
    expect(harness.state.syncFailed, isFalse);
    expect(harness.state.errorMessage, isNull);
    expect(harness.state.unreadCount, 0);
  });

  test(
    'clears queued filter load when screen hides during in-flight history load',
    () async {
      final allFetchCompleter = Completer<void>();
      final active = generationFixture(
        generationId: 'generation-active',
        status: TemplateGenerationStatus.generating,
      );
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [active],
          'completed': [ready],
        },
        fetchCompletersByStatus: {null: allFetchCompleter},
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
      );
      addTearDown(harness.dispose);

      final controller = harness.controller;
      controller.setScreenVisible(true);
      final allLoad = controller.load();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final readyLoad = controller.load(filter: GenerationHistoryFilter.ready);
      await Future<void>.delayed(Duration.zero);

      expect(repository.fetchCalls, [(status: null, take: 50)]);
      expect(repository.fetchCancelTokens.single?.isCancelled, isFalse);
      final unreadCallsBeforeHide = repository.fetchUnreadCountCalls;

      controller.setScreenVisible(false);

      expect(repository.fetchCancelTokens.single?.isCancelled, isTrue);
      expect(harness.state.isLoading, isFalse);

      allFetchCompleter.complete();
      await allLoad;
      await readyLoad;
      await Future<void>.delayed(Duration.zero);

      expect(repository.fetchCalls, [(status: null, take: 50)]);
      expect(repository.fetchUnreadCountCalls, unreadCallsBeforeHide);
      expect(harness.state.filter, GenerationHistoryFilter.all);
      expect(harness.state.isLoading, isFalse);
      expect(harness.store.cancelActiveDownloadsCalls, 1);
    },
  );

  test('cancels in-flight history load when screen hides', () async {
    final allFetchCompleter = Completer<void>();
    final ready = generationFixture(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.completed,
    );
    final repository = FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [ready],
      },
      fetchCompletersByStatus: {null: allFetchCompleter},
    );
    final harness = GenerationHistoryControllerHarness(repository: repository);
    addTearDown(harness.dispose);

    final controller = harness.controller;
    controller.setScreenVisible(true);
    final loadFuture = controller.load();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(repository.fetchCalls, [(status: null, take: 50)]);
    expect(repository.fetchCancelTokens.single?.isCancelled, isFalse);
    final unreadCallsBeforeCancellation = repository.fetchUnreadCountCalls;

    controller.setScreenVisible(false);

    expect(repository.fetchCancelTokens.single?.isCancelled, isTrue);
    expect(harness.state.isLoading, isFalse);

    controller.setScreenVisible(true);
    final retryLoad = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(repository.fetchCalls, [(status: null, take: 50)]);

    allFetchCompleter.complete();
    await loadFuture;
    await retryLoad;

    expect(repository.fetchCalls, [
      (status: null, take: 50),
      (status: null, take: 50),
    ]);
    expect(repository.fetchCancelTokens.last?.isCancelled, isFalse);
    expect(repository.fetchUnreadCountCalls, unreadCallsBeforeCancellation);
    expect(harness.state.syncFailed, isFalse);
    expect(harness.state.errorMessage, isNull);
    expect(harness.state.isLoading, isFalse);
    expect(harness.state.items.map((item) => item.generationId), [
      'generation-ready',
    ]);
  });

  test(
    'cancels post-load unread count before applying fetched history',
    () async {
      final unreadCompleter = Completer<void>();
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
        remotePagesByCursor: {
          generationHistoryPageKey(null, null): TemplateGenerationGalleryPage(
            items: [ready],
            hasMore: false,
            unreadCount: 1,
            appliedFilter: 'all',
          ),
        },
        unreadCount: 1,
        unreadCountCompleter: unreadCompleter,
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
      );
      addTearDown(harness.dispose);

      final controller = harness.controller;
      controller.setScreenVisible(true);
      final loadFuture = controller.load();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(repository.fetchCalls, [(status: null, take: 50)]);
      expect(repository.fetchUnreadCountCalls, 1);
      expect(repository.fetchUnreadCancelTokens.single?.isCancelled, isFalse);
      expect(harness.state.isLoading, isTrue);

      controller.setScreenVisible(false);

      expect(repository.fetchUnreadCancelTokens.single?.isCancelled, isTrue);
      expect(harness.state.isLoading, isFalse);

      unreadCompleter.complete();
      await loadFuture;

      expect(harness.state.items, isEmpty);
      expect(harness.state.unreadCount, 0);
      expect(harness.state.syncFailed, isFalse);
      expect(harness.state.errorMessage, isNull);
    },
  );

  test('screen visibility schedules local artifact cleanup once', () async {
    final repository = FakeTemplateGenerationRepository();
    final store = FakeGenerationGalleryStore();
    final harness = GenerationHistoryControllerHarness(
      repository: repository,
      store: store,
    );
    addTearDown(harness.dispose);

    final controller = harness.controller;

    controller.setScreenVisible(true);
    await Future<void>.delayed(Duration.zero);

    expect(store.cleanupCurrentAccountArtifactsCalls, 1);

    controller.setScreenVisible(false);
    controller.setScreenVisible(true);
    controller.setScreenVisible(true);
    await Future<void>.delayed(Duration.zero);

    expect(store.cleanupCurrentAccountArtifactsCalls, 1);
  });

  test(
    'uses persistent cache as seed and keeps items visible when refresh fails',
    () async {
      final failed = generationFixture(
        generationId: 'generation-failed',
        status: TemplateGenerationStatus.failed,
      );
      final repository = FakeTemplateGenerationRepository(
        persistedByStatus: {
          'failed': [failed],
        },
        fetchError: const AppException('templates.connection_timeout'),
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
      );
      addTearDown(harness.dispose);

      await harness.controller.load(filter: GenerationHistoryFilter.failed);

      expect(harness.state.filter, GenerationHistoryFilter.failed);
      expect(harness.state.items.map((item) => item.generationId), [
        'generation-failed',
      ]);
      expect(harness.state.syncFailed, isTrue);
      expect(harness.state.showOfflineBanner, isTrue);
      expect(harness.state.isConnectionRecovered, isFalse);
    },
  );

  test(
    'normalizes wrapped history timeout errors before exposing UI state',
    () async {
      final failed = generationFixture(
        generationId: 'generation-failed',
        status: TemplateGenerationStatus.failed,
      );
      final repository = FakeTemplateGenerationRepository(
        persistedByStatus: {
          'failed': [failed],
        },
        fetchError: const AppException(
          '  RuntimeError: templates.connection_timeout  ',
        ),
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
      );
      addTearDown(harness.dispose);

      await harness.controller.load(filter: GenerationHistoryFilter.failed);

      expect(harness.state.items.map((item) => item.generationId), [
        'generation-failed',
      ]);
      expect(harness.state.syncFailed, isTrue);
      expect(harness.state.showOfflineBanner, isTrue);
      expect(harness.state.isConnectionRecovered, isFalse);
    },
  );

  test(
    'filtered loads subtract unread tombstones found in the all-history cache',
    () async {
      final active = generationFixture(
        generationId: 'generation-active',
        status: TemplateGenerationStatus.generating,
      );
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          'completed': [ready],
        },
        persistedByStatus: {
          null: [active],
        },
        unreadCount: 2,
      );
      final store = FakeGenerationGalleryStore()
        ..deletedGenerationIds.add('generation-active');
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
      );
      addTearDown(harness.dispose);

      await harness.controller.load(filter: GenerationHistoryFilter.ready);

      expect(repository.fetchCalls, [(status: 'completed', take: 50)]);
      expect(harness.state.filter, GenerationHistoryFilter.ready);
      expect(harness.state.items.map((item) => item.generationId), [
        'generation-ready',
      ]);
      expect(harness.state.unreadCount, 1);
    },
  );

  test('shows recovered banner after a failed refresh succeeds', () async {
    final ready = generationFixture(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.completed,
    );
    final repository = FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [ready],
      },
    );
    final harness = GenerationHistoryControllerHarness(repository: repository);
    addTearDown(harness.dispose);

    await harness.controller.load();
    expect(harness.state.syncFailed, isFalse);

    repository.fetchError = const AppException('templates.connection_timeout');
    await harness.controller.load(refresh: true);

    expect(harness.state.items.map((item) => item.generationId), [
      'generation-ready',
    ]);
    expect(harness.state.syncFailed, isTrue);
    expect(harness.state.showOfflineBanner, isTrue);
    expect(harness.state.isConnectionRecovered, isFalse);

    repository.fetchError = null;
    await harness.controller.load(refresh: true);

    expect(harness.state.syncFailed, isFalse);
    expect(harness.state.showOfflineBanner, isTrue);
    expect(harness.state.isConnectionRecovered, isTrue);
  });

  testWidgets('hides recovered banner after three seconds', (tester) async {
    final ready = generationFixture(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.completed,
    );
    final repository = FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [ready],
      },
    );
    final harness = GenerationHistoryControllerHarness(repository: repository);
    addTearDown(harness.dispose);

    await harness.controller.load();

    repository.fetchError = const AppException('templates.connection_timeout');
    await harness.controller.load(refresh: true);

    expect(harness.state.showOfflineBanner, isTrue);
    expect(harness.state.isConnectionRecovered, isFalse);

    repository.fetchError = null;
    await harness.controller.load(refresh: true);

    expect(harness.state.showOfflineBanner, isTrue);
    expect(harness.state.isConnectionRecovered, isTrue);

    await tester.pump(const Duration(milliseconds: 2999));
    expect(harness.state.showOfflineBanner, isTrue);
    expect(harness.state.isConnectionRecovered, isTrue);

    await tester.pump(const Duration(milliseconds: 1));
    expect(harness.state.showOfflineBanner, isFalse);
    expect(harness.state.isConnectionRecovered, isFalse);
  });

  test('realtime upserts completed generation and syncs local media', () async {
    final active = generationFixture(
      generationId: 'generation-active',
      status: TemplateGenerationStatus.generating,
      stage: 'generating',
      progressPercent: 70,
    );
    final completed = active.copyWith(
      status: TemplateGenerationStatus.completed,
      stage: 'finalizing',
      progressPercent: 100,
      outputUrl: 'https://cdn.petmagic.app/result.jpg',
      completedAtUtc: DateTime.utc(2026, 6, 14, 12, 3),
    );
    final repository = FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [active],
        'active': [active],
        'completed': const <TemplateGenerationResult>[],
      },
      remoteById: {'generation-active': completed},
      unreadCount: 1,
    );
    final realtimeClient = FakeRealtimeClient();
    final store = FakeGenerationGalleryStore();
    final harness = GenerationHistoryControllerHarness(
      repository: repository,
      store: store,
      realtimeClient: realtimeClient,
    );
    addTearDown(harness.dispose);

    final controller = harness.controller;
    controller.setScreenVisible(true);
    await controller.load();
    await controller.load(filter: GenerationHistoryFilter.active);
    expect(harness.state.items.map((item) => item.generationId), [
      'generation-active',
    ]);
    await controller.load(filter: GenerationHistoryFilter.ready);
    expect(harness.state.items, isEmpty);
    await controller.load(filter: GenerationHistoryFilter.all);

    repository.unreadCount = 0;
    realtimeClient.emit(
      RealtimeEvent(
        topic: RealtimeTopics.templatesGenerationStatusChanged,
        payload: generationRealtimePayload(generationId: 'generation-active'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final updated = harness.state.items.single;
    expect(updated.generationId, 'generation-active');
    expect(updated.isCompleted, isTrue);
    expect(updated.localPreviewPath, '/local/generation-active-preview.jpg');
    expect(updated.localOutputPath, '/local/generation-active-output.jpg');
    expect(updated.isLocalMediaReady, isTrue);
    expect(
      harness.state.cachedItemsByFilter[GenerationHistoryFilter.active]?.map(
        (item) => item.generationId,
      ),
      isEmpty,
    );
    final readyCached =
        harness.state.cachedItemsByFilter[GenerationHistoryFilter.ready];
    expect(readyCached, isNotNull);
    expect(readyCached!.map((item) => item.generationId), [
      'generation-active',
    ]);
    expect(readyCached.single.localPreviewPath, updated.localPreviewPath);
    expect(readyCached.single.localOutputPath, updated.localOutputPath);
    expect(readyCached.single.isLocalMediaReady, isTrue);
    expect(store.materializedGenerationIds, ['generation-active']);
    expect(repository.fetchGenerationCalls, ['generation-active']);
    expect(repository.cachedUpserts.map((item) => item.generationId), [
      'generation-active',
    ]);
    expect(harness.state.unreadCount, 0);
    expect(realtimeClient.connectCalls, 1);
  });

  test('realtime ignores stale refetched generation', () async {
    final current = generationFixture(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.completed,
      stage: 'completed',
      progressPercent: 100,
      outputUrl: 'https://cdn.petmagic.app/result.jpg',
      completedAtUtc: DateTime.utc(2026, 6, 14, 12, 5),
    );
    final stale = generationFixture(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.generating,
      stage: 'generating',
      progressPercent: 40,
    );
    final repository = FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [current],
      },
      remoteById: {'generation-ready': stale},
    );
    final realtimeClient = FakeRealtimeClient();
    final harness = GenerationHistoryControllerHarness(
      repository: repository,
      realtimeClient: realtimeClient,
    );
    addTearDown(harness.dispose);

    final controller = harness.controller;
    controller.setScreenVisible(true);
    await controller.load();

    realtimeClient.emit(
      RealtimeEvent(
        topic: RealtimeTopics.templatesGenerationStatusChanged,
        payload: generationRealtimePayload(generationId: 'generation-ready'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(repository.fetchGenerationCalls, ['generation-ready']);
    expect(
      harness.state.items.single.status,
      TemplateGenerationStatus.completed,
    );
    expect(harness.state.items.single.progressPercent, 100);
    expect(repository.cachedUpserts, isEmpty);
  });

  test('realtime ignores malformed generation status payload ids', () async {
    final current = generationFixture(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.completed,
      stage: 'completed',
      progressPercent: 100,
      outputUrl: 'https://cdn.petmagic.app/result.jpg',
      completedAtUtc: DateTime.utc(2026, 6, 14, 12, 5),
    );
    final repository = FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [current],
      },
    );
    final realtimeClient = FakeRealtimeClient();
    final harness = GenerationHistoryControllerHarness(
      repository: repository,
      realtimeClient: realtimeClient,
    );
    addTearDown(harness.dispose);

    final controller = harness.controller;
    controller.setScreenVisible(true);
    await controller.load();

    realtimeClient.emit(
      RealtimeEvent(
        topic: RealtimeTopics.templatesGenerationStatusChanged,
        payload: {
          'eventType': 'generation.status_changed',
          'generationId': 123,
        },
      ),
    );
    realtimeClient.emit(
      RealtimeEvent(
        topic: RealtimeTopics.templatesGenerationStatusChanged,
        payload: {
          'eventType': 'generation.status_changed',
          'generationId': 'g' * 160,
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(repository.fetchGenerationCalls, isEmpty);
  });

  test(
    'realtime disconnects when connect completes after network loss',
    () async {
      final connectCompleter = Completer<void>();
      final realtimeClient = FakeRealtimeClient(
        connectCompleter: connectCompleter,
      );
      final networkStatusController =
          FakeGenerationHistoryNetworkStatusController();
      final harness = GenerationHistoryControllerHarness(
        repository: FakeTemplateGenerationRepository(),
        realtimeClient: realtimeClient,
        networkStatusController: networkStatusController,
      );
      addTearDown(harness.dispose);

      harness.controller.setScreenVisible(true);

      expect(realtimeClient.connectCalls, 1);

      networkStatusController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);
      expect(realtimeClient.disconnectCalls, 0);

      connectCompleter.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(realtimeClient.disconnectCalls, 1);
    },
  );

  test(
    'mergeFetchedGeneration updates history state from status refresh',
    () async {
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
        outputUrl: 'https://cdn.petmagic.app/result.jpg',
      );
      final repository = FakeTemplateGenerationRepository();
      final store = FakeGenerationGalleryStore();
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
      );
      addTearDown(harness.dispose);

      await harness.controller.mergeFetchedGeneration(ready);
      await Future<void>.delayed(Duration.zero);

      expect(harness.state.items.map((item) => item.generationId), [
        'generation-ready',
      ]);
      expect(harness.state.items.single.isCompleted, isTrue);
      expect(repository.cachedUpserts.map((item) => item.generationId), [
        'generation-ready',
      ]);
      expect(store.materializedGenerationIds, isEmpty);
    },
  );

  test(
    'mergeFetchedGeneration decorates status refresh with local media record',
    () async {
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
        outputUrl: 'https://cdn.petmagic.app/result.jpg',
      );
      final localRecord = GenerationGalleryMediaRecord(
        generationId: 'generation-ready',
        accountScope: 'user-1',
        userId: 'user-1',
        status: TemplateGenerationStatus.completed.name,
        updatedAtUtc: ready.updatedAtUtc,
        lastSyncedAtUtc: DateTime.utc(2026, 6, 14, 12, 4),
        version: 1,
        previewRemoteUrl: ready.outputUrl,
        outputRemoteUrl: ready.outputUrl,
        previewLocalPath: '/local/generation-ready-preview.jpg',
        outputLocalPath: '/local/generation-ready-output.jpg',
        isDownloadComplete: true,
      );
      final repository = FakeTemplateGenerationRepository();
      final store = FakeGenerationGalleryStore(
        localReadyRecords: [localRecord],
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
      );
      addTearDown(harness.dispose);

      await harness.controller.mergeFetchedGeneration(ready);
      await Future<void>.delayed(Duration.zero);

      final item = harness.state.items.single;
      expect(item.localPreviewPath, '/local/generation-ready-preview.jpg');
      expect(item.localOutputPath, '/local/generation-ready-output.jpg');
      expect(item.isLocalMediaReady, isTrue);
      expect(
        repository.cachedUpserts.single.localOutputPath,
        item.localOutputPath,
      );
    },
  );

  test(
    'mergeFetchedGeneration ignores stale local media records for changed URLs',
    () async {
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
        outputUrl: 'https://cdn.petmagic.app/new-result.jpg',
      );
      final localRecord = GenerationGalleryMediaRecord(
        generationId: 'generation-ready',
        accountScope: 'user-1',
        userId: 'user-1',
        status: TemplateGenerationStatus.completed.name,
        updatedAtUtc: ready.updatedAtUtc,
        lastSyncedAtUtc: DateTime.utc(2026, 6, 14, 12, 4),
        version: 1,
        previewRemoteUrl: 'https://cdn.petmagic.app/old-result.jpg',
        outputRemoteUrl: 'https://cdn.petmagic.app/old-result.jpg',
        previewLocalPath: '/local/old-preview.jpg',
        outputLocalPath: '/local/old-output.jpg',
        isDownloadComplete: true,
      );
      final repository = FakeTemplateGenerationRepository();
      final store = FakeGenerationGalleryStore(
        localReadyRecords: [localRecord],
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
      );
      addTearDown(harness.dispose);

      await harness.controller.mergeFetchedGeneration(ready);
      await Future<void>.delayed(Duration.zero);

      final item = harness.state.items.single;
      expect(item.localPreviewPath, isNull);
      expect(item.localOutputPath, isNull);
      expect(item.isLocalMediaReady, isFalse);
      expect(repository.cachedUpserts.single.localOutputPath, isNull);
      expect(store.materializedGenerationIds, isEmpty);
    },
  );

  test(
    'mergeFetchedGeneration clears existing local media when URLs change',
    () async {
      final oldReady = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
        outputUrl: 'https://cdn.petmagic.app/old-result.jpg',
      );
      final newReady = oldReady.copyWith(
        outputUrl: 'https://cdn.petmagic.app/new-result.jpg',
        updatedAtUtc: oldReady.updatedAtUtc.add(const Duration(minutes: 1)),
      );
      final localRecord = GenerationGalleryMediaRecord(
        generationId: 'generation-ready',
        accountScope: 'user-1',
        userId: 'user-1',
        status: TemplateGenerationStatus.completed.name,
        updatedAtUtc: oldReady.updatedAtUtc,
        lastSyncedAtUtc: DateTime.utc(2026, 6, 14, 12, 4),
        version: 1,
        previewRemoteUrl: oldReady.outputUrl,
        outputRemoteUrl: oldReady.outputUrl,
        previewLocalPath: '/local/old-preview.jpg',
        outputLocalPath: '/local/old-output.jpg',
        isDownloadComplete: true,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [oldReady],
        },
      );
      final store = FakeGenerationGalleryStore(
        localReadyRecords: [localRecord],
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
      );
      addTearDown(harness.dispose);

      await harness.controller.load();
      expect(
        harness.state.items.single.localPreviewPath,
        '/local/old-preview.jpg',
      );
      expect(
        harness.state.items.single.localOutputPath,
        '/local/old-output.jpg',
      );

      await harness.controller.mergeFetchedGeneration(newReady);
      await Future<void>.delayed(Duration.zero);

      final item = harness.state.items.single;
      expect(item.outputUrl, newReady.outputUrl);
      expect(item.localPreviewPath, isNull);
      expect(item.localOutputPath, isNull);
      expect(item.isLocalMediaReady, isFalse);
      expect(repository.cachedUpserts.last.localOutputPath, isNull);
      expect(store.materializedGenerationIds, isEmpty);
    },
  );

  test(
    'mergeFetchedGeneration keeps completed status refresh out of active filter',
    () async {
      final active = generationFixture(
        generationId: 'generation-active',
        status: TemplateGenerationStatus.generating,
        stage: 'generating',
        progressPercent: 45,
      );
      final completed = active.copyWith(
        status: TemplateGenerationStatus.completed,
        stage: 'completed',
        progressPercent: 100,
        outputUrl: 'https://cdn.petmagic.app/result.jpg',
        completedAtUtc: DateTime.utc(2026, 6, 14, 12, 5),
        updatedAtUtc: DateTime.utc(2026, 6, 14, 12, 5),
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          'active': [active],
          'completed': const <TemplateGenerationResult>[],
        },
      );
      final store = FakeGenerationGalleryStore();
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
      );
      addTearDown(harness.dispose);

      await harness.controller.load(filter: GenerationHistoryFilter.active);

      expect(harness.state.filter, GenerationHistoryFilter.active);
      expect(harness.state.items.map((item) => item.generationId), [
        'generation-active',
      ]);

      await harness.controller.mergeFetchedGeneration(completed);

      expect(harness.state.filter, GenerationHistoryFilter.active);
      expect(harness.state.items, isEmpty);
      expect(
        harness.state.cachedItemsByFilter[GenerationHistoryFilter.active],
        isEmpty,
      );
      expect(
        harness.state.cachedItemsByFilter.containsKey(
          GenerationHistoryFilter.ready,
        ),
        isFalse,
      );
    },
  );

  test('mergeFetchedGeneration does not resurrect tombstoned items', () async {
    final ready = generationFixture(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.completed,
    );
    final repository = FakeTemplateGenerationRepository();
    final store = FakeGenerationGalleryStore()
      ..deletedGenerationIds.add('generation-ready');
    final harness = GenerationHistoryControllerHarness(
      repository: repository,
      store: store,
    );
    addTearDown(harness.dispose);

    await harness.controller.mergeFetchedGeneration(ready);
    await Future<void>.delayed(Duration.zero);

    expect(harness.state.items, isEmpty);
    expect(repository.cachedUpserts, isEmpty);
  });

  test(
    'hidden screen cancels active media sync and does not apply local media',
    () async {
      final materializeCompleter = Completer<GenerationGalleryMediaRecord?>();
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
        outputUrl: 'https://cdn.petmagic.app/result.jpg',
        completedAtUtc: DateTime.utc(2026, 6, 14, 12, 3),
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
      );
      final store = FakeGenerationGalleryStore(
        materializeCompleter: materializeCompleter,
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
      );
      addTearDown(harness.dispose);

      final controller = harness.controller;
      controller.setScreenVisible(true);
      await controller.load();
      await Future<void>.delayed(Duration.zero);

      expect(store.materializedGenerationIds, ['generation-ready']);
      expect(harness.state.items.single.isLocalMediaReady, isFalse);

      controller.setScreenVisible(false);

      expect(store.cancelActiveDownloadsCalls, 1);

      final nowUtc = DateTime.now().toUtc();
      materializeCompleter.complete(
        GenerationGalleryMediaRecord(
          generationId: ready.generationId,
          accountScope: ready.userId,
          userId: ready.userId,
          status: ready.status.name,
          updatedAtUtc: ready.updatedAtUtc,
          previewLocalPath: '/local/hidden-preview.jpg',
          outputLocalPath: '/local/hidden-output.jpg',
          isDownloadComplete: true,
          lastSyncedAtUtc: nowUtc,
          version: 1,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(harness.state.items.single.isLocalMediaReady, isFalse);
      expect(harness.state.items.single.localPreviewPath, isNull);
      expect(harness.state.items.single.localOutputPath, isNull);
    },
  );

  test('realtime ignores locally tombstoned generations', () async {
    final active = generationFixture(
      generationId: 'generation-active',
      status: TemplateGenerationStatus.generating,
      stage: 'generating',
      progressPercent: 70,
    );
    final completed = active.copyWith(
      status: TemplateGenerationStatus.completed,
      stage: 'finalizing',
      progressPercent: 100,
      outputUrl: 'https://cdn.petmagic.app/result.jpg',
      completedAtUtc: DateTime.utc(2026, 6, 14, 12, 3),
    );
    final repository = FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [active],
      },
      remoteById: {'generation-active': completed},
    );
    final realtimeClient = FakeRealtimeClient();
    final store = FakeGenerationGalleryStore();
    final harness = GenerationHistoryControllerHarness(
      repository: repository,
      store: store,
      realtimeClient: realtimeClient,
    );
    addTearDown(harness.dispose);

    final controller = harness.controller;
    controller.setScreenVisible(true);
    await controller.load();
    await controller.deleteGeneration('generation-active');

    realtimeClient.emit(
      RealtimeEvent(
        topic: RealtimeTopics.templatesGenerationStatusChanged,
        payload: generationRealtimePayload(generationId: 'generation-active'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(harness.state.items, isEmpty);
    expect(store.materializedGenerationIds, isEmpty);
    expect(repository.deleteGenerationCalls, ['generation-active']);
    expect(store.clearPendingServerDeleteCalls, ['generation-active']);
  });
}
