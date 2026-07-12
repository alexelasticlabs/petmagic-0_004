import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';
import 'generation_history_controller_test_support.dart';

void main() {
  configureGenerationHistoryControllerTestHarness();

  test(
    'realtime checks persisted tombstones before the first history load',
    () async {
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
        remoteById: {'generation-active': completed},
      );
      final realtimeClient = FakeRealtimeClient();
      final store = FakeGenerationGalleryStore()
        ..deletedGenerationIds.add('generation-active');
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
        realtimeClient: realtimeClient,
      );
      addTearDown(harness.dispose);

      final controller = harness.controller;
      controller.setScreenVisible(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

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
      expect(repository.cachedUpserts, isEmpty);
      expect(store.materializedGenerationIds, isEmpty);
      expect(realtimeClient.connectCalls, 1);
    },
  );

  test(
    'realtime disconnects if screen hides before connect completes',
    () async {
      final connectCompleter = Completer<void>();
      final repository = FakeTemplateGenerationRepository();
      final realtimeClient = FakeRealtimeClient(
        connectCompleter: connectCompleter,
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        realtimeClient: realtimeClient,
      );
      addTearDown(harness.dispose);

      final controller = harness.controller;
      controller.setScreenVisible(true);
      await Future<void>.delayed(Duration.zero);

      expect(realtimeClient.connectCalls, 1);
      expect(realtimeClient.disconnectCalls, 0);

      controller.setScreenVisible(false);
      connectCompleter.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(realtimeClient.disconnectCalls, 1);

      realtimeClient.emit(
        RealtimeEvent(
          topic: RealtimeTopics.templatesGenerationStatusChanged,
          payload: generationRealtimePayload(generationId: 'generation-hidden'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(harness.state.items, isEmpty);
    },
  );

  test('markRead locally clears unread before server sync completes', () async {
    final ready = generationFixture(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.completed,
    );
    final markReadCompleter = Completer<void>();
    final repository = FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [ready],
      },
      unreadCount: 1,
      markReadCompleter: markReadCompleter,
    );
    final harness = GenerationHistoryControllerHarness(repository: repository);
    addTearDown(harness.dispose);

    await harness.controller.load();
    expect(harness.state.unreadCount, 1);
    expect(harness.state.items.single.isUnread, isTrue);

    final markReadFuture = harness.controller.markRead('generation-ready');

    expect(harness.state.unreadCount, 0);
    expect(harness.state.items.single.isUnread, isFalse);
    expect(repository.markReadCalls, ['generation-ready']);

    markReadCompleter.complete();
    await markReadFuture;

    expect(harness.state.unreadCount, 0);
    expect(harness.state.items.single.isUnread, isFalse);
  });

  test('markRead keeps local unread cleared when server sync fails', () async {
    final ready = generationFixture(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.completed,
    );
    final repository = FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [ready],
      },
      unreadCount: 1,
      markReadError: const AppException('templates.mark_read_failed'),
    );
    final harness = GenerationHistoryControllerHarness(repository: repository);
    addTearDown(harness.dispose);

    await harness.controller.load();
    expect(harness.state.unreadCount, 1);
    expect(harness.state.items.single.isUnread, isTrue);

    await harness.controller.markRead('generation-ready');

    expect(repository.markReadCalls, ['generation-ready']);
    expect(harness.state.unreadCount, 0);
    expect(harness.state.items.single.isUnread, isFalse);

    await harness.controller.load(refresh: true);

    expect(harness.state.unreadCount, 0);
    expect(harness.state.items.single.isUnread, isFalse);
  });

  test(
    'markRead keeps local read state across stale filtered cache while sync is in flight',
    () async {
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final markReadCompleter = Completer<void>();
      final readyFetchCompleter = Completer<void>();
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
          'completed': [ready],
        },
        persistedByStatus: {
          'completed': [ready],
        },
        fetchCompletersByStatus: {'completed': readyFetchCompleter},
        unreadCount: 1,
        markReadCompleter: markReadCompleter,
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
      );
      addTearDown(harness.dispose);

      await harness.controller.load();
      final markReadFuture = harness.controller.markRead('generation-ready');

      expect(harness.state.unreadCount, 0);
      expect(harness.state.items.single.isUnread, isFalse);

      final readyLoad = harness.controller.load(
        filter: GenerationHistoryFilter.ready,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(harness.state.filter, GenerationHistoryFilter.ready);
      expect(harness.state.items.single.generationId, 'generation-ready');
      expect(harness.state.items.single.isUnread, isFalse);
      expect(harness.state.unreadCount, 0);

      readyFetchCompleter.complete();
      await readyLoad;

      expect(harness.state.items.single.generationId, 'generation-ready');
      expect(harness.state.items.single.isUnread, isFalse);
      expect(harness.state.unreadCount, 0);

      markReadCompleter.complete();
      await markReadFuture;
    },
  );

  test(
    'markRead keeps item read after stale realtime without suppressing other unread',
    () async {
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final otherReady = generationFixture(
        generationId: 'generation-other',
        status: TemplateGenerationStatus.completed,
        completedAtUtc: DateTime.utc(2026, 6, 14, 12, 1),
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready, otherReady],
        },
        unreadCount: 2,
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

      await controller.markRead('generation-ready');

      expect(harness.state.unreadCount, 1);
      expect(
        harness.state.items
            .singleWhere((item) => item.generationId == 'generation-ready')
            .isUnread,
        isFalse,
      );

      repository.unreadCount = 1;
      await controller.refreshUnreadCount();

      expect(harness.state.unreadCount, 1);

      realtimeClient.emit(
        RealtimeEvent(
          topic: RealtimeTopics.templatesGenerationStatusChanged,
          payload: generationRealtimePayload(generationId: 'generation-ready'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(harness.state.unreadCount, 1);
      expect(
        harness.state.items
            .singleWhere((item) => item.generationId == 'generation-ready')
            .isUnread,
        isFalse,
      );
      expect(repository.cachedUpserts.single.generationId, 'generation-ready');
      expect(repository.cachedUpserts.single.isUnread, isFalse);
    },
  );

  testWidgets(
    'auto refresh polls every 8 seconds and backs off to 30 after errors',
    (tester) async {
      final active = generationFixture(
        generationId: 'generation-active',
        status: TemplateGenerationStatus.processing,
        stage: 'rendering',
        progressPercent: 42,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [active],
        },
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
      );
      final controller = harness.controller;

      try {
        controller.setScreenVisible(true);
        await controller.load();
        expect(repository.fetchCalls.length, 1);

        repository.fetchError = const AppException(
          'templates.connection_timeout',
        );

        await tester.pump(const Duration(seconds: 7));
        expect(repository.fetchCalls.length, 1);

        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(repository.fetchCalls.length, 2);
        expect(harness.state.syncFailed, isTrue);

        await tester.pump(const Duration(seconds: 15));
        expect(repository.fetchCalls.length, 2);

        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(repository.fetchCalls.length, 3);

        await tester.pump(const Duration(seconds: 29));
        expect(repository.fetchCalls.length, 3);

        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(repository.fetchCalls.length, 4);

        repository.fetchError = null;

        await tester.pump(const Duration(seconds: 30));
        await tester.pump();
        expect(repository.fetchCalls.length, 5);
        expect(harness.state.syncFailed, isFalse);

        await tester.pump(const Duration(seconds: 7));
        expect(repository.fetchCalls.length, 5);

        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(repository.fetchCalls.length, 6);

        controller.setScreenVisible(false);
        await tester.pump(const Duration(seconds: 30));
        await tester.pump();

        expect(repository.fetchCalls.length, 6);
      } finally {
        controller.setScreenVisible(false);
        harness.dispose();
      }
    },
  );

  testWidgets(
    'idle generation history uses sparse refresh cadence when realtime is connected',
    (tester) async {
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
      );
      final controller = harness.controller;

      try {
        controller.setScreenVisible(true);
        await controller.load();
        expect(repository.fetchCalls.length, 1);
        expect(harness.realtimeClient.connectCalls, 1);

        await tester.pump(const Duration(minutes: 4));
        await tester.pump(const Duration(seconds: 59));
        expect(
          repository.fetchCalls.length,
          1,
          reason:
              'idle gallery should not poll every few seconds while realtime is healthy',
        );

        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(repository.fetchCalls.length, 2);
      } finally {
        controller.setScreenVisible(false);
        harness.dispose();
      }
    },
  );

  test(
    'deleteGeneration creates tombstone and clears pending on success',
    () async {
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
        unreadCount: 0,
      );
      final store = FakeGenerationGalleryStore();
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
      );
      addTearDown(harness.dispose);

      await harness.controller.load();
      await harness.controller.deleteGeneration('generation-ready');

      expect(harness.state.items, isEmpty);
      expect(harness.state.unreadCount, 0);
      expect(store.markDeletedCalls, [
        (generationId: 'generation-ready', userId: 'user-1'),
      ]);
      expect(repository.deleteGenerationCalls, ['generation-ready']);
      expect(store.clearPendingServerDeleteCalls, ['generation-ready']);
      expect(store.pendingServerDeleteIds, isEmpty);
    },
  );

  test(
    'deleteGeneration completes locally and keeps pending tombstone when server delete fails',
    () async {
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
        unreadCount: 0,
        deleteError: const AppException('templates.delete_failed'),
      );
      final store = FakeGenerationGalleryStore();
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
      );
      addTearDown(harness.dispose);

      await harness.controller.load();
      await harness.controller.deleteGeneration('generation-ready');

      expect(harness.state.items, isEmpty);
      expect(harness.state.unreadCount, 0);
      expect(store.markDeletedCalls, [
        (generationId: 'generation-ready', userId: 'user-1'),
      ]);
      expect(repository.deleteGenerationCalls, ['generation-ready']);
      expect(store.clearPendingServerDeleteCalls, isEmpty);
      expect(store.pendingServerDeleteIds, ['generation-ready']);
    },
  );

  test(
    'deleteGeneration does not start server delete after controller disposal during local tombstone write',
    () async {
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final markDeletedCompleter = Completer<void>();
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
        unreadCount: 1,
      );
      final store = FakeGenerationGalleryStore(
        markDeletedCompleter: markDeletedCompleter,
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
      );

      await harness.controller.load();
      expect(harness.state.items.map((item) => item.generationId), [
        'generation-ready',
      ]);
      expect(harness.state.unreadCount, 1);

      final deleteFuture = harness.controller.deleteGeneration(
        'generation-ready',
      );
      await Future<void>.delayed(Duration.zero);

      expect(harness.state.items, isEmpty);
      expect(harness.state.unreadCount, 0);
      expect(store.markDeletedCalls, [
        (generationId: 'generation-ready', userId: 'user-1'),
      ]);
      expect(store.pendingServerDeleteIds, ['generation-ready']);

      harness.dispose();
      markDeletedCompleter.complete();
      await deleteFuture;

      expect(repository.deleteGenerationCalls, isEmpty);
      expect(store.clearPendingServerDeleteCalls, isEmpty);
      expect(store.pendingServerDeleteIds, ['generation-ready']);
    },
  );

  test(
    'refreshUnreadCount keeps pending deleted unread generations out of the badge',
    () async {
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
        unreadCount: 1,
        deleteError: const AppException('templates.delete_failed'),
      );
      final store = FakeGenerationGalleryStore();
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
      );
      addTearDown(harness.dispose);

      final controller = harness.controller;
      controller.setScreenVisible(true);
      await controller.load();
      expect(harness.state.unreadCount, 1);

      await controller.deleteGeneration('generation-ready');

      expect(harness.state.items, isEmpty);
      expect(harness.state.unreadCount, 0);
      expect(store.pendingServerDeleteIds, ['generation-ready']);

      final fetchUnreadCountCallsBeforeRefresh =
          repository.fetchUnreadCountCalls;
      await controller.refreshUnreadCount();

      expect(
        repository.fetchUnreadCountCalls,
        fetchUnreadCountCallsBeforeRefresh + 1,
      );
      expect(harness.state.items, isEmpty);
      expect(harness.state.unreadCount, 0);
    },
  );

  test(
    'refreshUnreadCount keeps successfully deleted unread generations out of the badge until next sync',
    () async {
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
        unreadCount: 1,
      );
      final store = FakeGenerationGalleryStore();
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
      );
      addTearDown(harness.dispose);

      final controller = harness.controller;
      controller.setScreenVisible(true);
      await controller.load();
      expect(harness.state.unreadCount, 1);

      await controller.deleteGeneration('generation-ready');

      expect(harness.state.items, isEmpty);
      expect(harness.state.unreadCount, 0);
      expect(store.pendingServerDeleteIds, isEmpty);
      expect(store.clearPendingServerDeleteCalls, ['generation-ready']);

      final fetchUnreadCountCallsBeforeRefresh =
          repository.fetchUnreadCountCalls;
      await controller.refreshUnreadCount();

      expect(
        repository.fetchUnreadCountCalls,
        fetchUnreadCountCallsBeforeRefresh + 1,
      );
      expect(harness.state.items, isEmpty);
      expect(harness.state.unreadCount, 0);

      repository.remoteByStatus[null] = const <TemplateGenerationResult>[];
      repository.unreadCount = 0;
      await controller.load(refresh: true);

      expect(harness.state.items, isEmpty);
      expect(harness.state.unreadCount, 0);
    },
  );

  test('refreshUnreadCount ignores late results after screen hides', () async {
    final unreadCompleter = Completer<void>();
    final repository = FakeTemplateGenerationRepository(
      unreadCount: 7,
      unreadCountCompleter: unreadCompleter,
    );
    final harness = GenerationHistoryControllerHarness(repository: repository);
    addTearDown(harness.dispose);

    final controller = harness.controller;
    await Future<void>.delayed(Duration.zero);
    controller.setScreenVisible(true);

    final refresh = controller.refreshUnreadCount();
    await Future<void>.delayed(Duration.zero);

    expect(repository.fetchUnreadCountCalls, 1);
    expect(repository.fetchUnreadCancelTokens.single?.isCancelled, isFalse);
    expect(harness.state.unreadCount, 0);

    controller.setScreenVisible(false);
    expect(repository.fetchUnreadCancelTokens.single?.isCancelled, isTrue);
    unreadCompleter.complete();
    await refresh;

    expect(harness.state.unreadCount, 0);
  });

  test('refreshUnreadCount cancels superseded unread refreshes', () async {
    final unreadCompleter = Completer<void>();
    final repository = FakeTemplateGenerationRepository(
      unreadCount: 7,
      unreadCountCompleter: unreadCompleter,
    );
    final harness = GenerationHistoryControllerHarness(repository: repository);
    addTearDown(harness.dispose);

    final controller = harness.controller;
    await Future<void>.delayed(Duration.zero);
    controller.setScreenVisible(true);

    final firstRefresh = controller.refreshUnreadCount();
    await Future<void>.delayed(Duration.zero);
    final firstToken = repository.fetchUnreadCancelTokens.single;

    final secondRefresh = controller.refreshUnreadCount();
    await Future<void>.delayed(Duration.zero);

    expect(repository.fetchUnreadCountCalls, 2);
    expect(firstToken?.isCancelled, isTrue);
    expect(repository.fetchUnreadCancelTokens.last?.isCancelled, isFalse);

    unreadCompleter.complete();
    await Future.wait([firstRefresh, secondRefresh]);

    expect(harness.state.unreadCount, 7);
  });

  test(
    'next sync retries pending delete and keeps tombstoned remote item hidden',
    () async {
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
        unreadCount: 1,
      );
      final store = FakeGenerationGalleryStore()
        ..deletedGenerationIds.add('generation-ready')
        ..pendingServerDeleteIds.add('generation-ready');
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
      );
      addTearDown(harness.dispose);

      await harness.controller.load();

      expect(repository.deleteGenerationCalls, ['generation-ready']);
      expect(store.clearPendingServerDeleteCalls, ['generation-ready']);
      expect(store.pendingServerDeleteIds, isEmpty);
      expect(harness.state.items, isEmpty);
      expect(harness.state.unreadCount, 0);
    },
  );

  test(
    'pending delete retry stops when screen hides during a cancelled server delete',
    () async {
      final deleteCompleter = Completer<void>();
      final firstReady = generationFixture(
        generationId: 'generation-ready-1',
        status: TemplateGenerationStatus.completed,
      );
      final secondReady = generationFixture(
        generationId: 'generation-ready-2',
        status: TemplateGenerationStatus.completed,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [firstReady, secondReady],
        },
        unreadCount: 2,
        deleteCompleter: deleteCompleter,
      );
      final store = FakeGenerationGalleryStore()
        ..deletedGenerationIds.addAll([
          'generation-ready-1',
          'generation-ready-2',
        ])
        ..pendingServerDeleteIds.addAll([
          'generation-ready-1',
          'generation-ready-2',
        ]);
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
      );
      addTearDown(harness.dispose);

      final controller = harness.controller;
      controller.setScreenVisible(true);
      final loadFuture = controller.load();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(repository.deleteGenerationCalls, ['generation-ready-1']);
      expect(repository.deleteCancelTokens.single?.isCancelled, isFalse);
      final unreadCallsBeforeHide = repository.fetchUnreadCountCalls;

      controller.setScreenVisible(false);
      expect(repository.deleteCancelTokens.single?.isCancelled, isTrue);

      deleteCompleter.complete();
      await loadFuture;

      expect(repository.deleteGenerationCalls, ['generation-ready-1']);
      expect(store.clearPendingServerDeleteCalls, isEmpty);
      expect(store.pendingServerDeleteIds, [
        'generation-ready-1',
        'generation-ready-2',
      ]);
      expect(repository.fetchCalls, isEmpty);
      expect(repository.fetchUnreadCountCalls, unreadCallsBeforeHide);
      expect(harness.store.cancelActiveDownloadsCalls, 1);
    },
  );

  test(
    'failed pending delete retry keeps tombstoned remote item hidden',
    () async {
      final ready = generationFixture(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
        unreadCount: 1,
        deleteError: const AppException('templates.delete_failed'),
      );
      final store = FakeGenerationGalleryStore()
        ..deletedGenerationIds.add('generation-ready')
        ..pendingServerDeleteIds.add('generation-ready');
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
      );
      addTearDown(harness.dispose);

      await harness.controller.load();

      expect(repository.deleteGenerationCalls, ['generation-ready']);
      expect(store.clearPendingServerDeleteCalls, isEmpty);
      expect(store.pendingServerDeleteIds, ['generation-ready']);
      expect(harness.state.items, isEmpty);
      expect(harness.state.unreadCount, 0);
    },
  );

  test(
    'failed pending delete retry stops the flush without blocking history load',
    () async {
      final firstReady = generationFixture(
        generationId: 'generation-ready-1',
        status: TemplateGenerationStatus.completed,
      );
      final secondReady = generationFixture(
        generationId: 'generation-ready-2',
        status: TemplateGenerationStatus.completed,
      );
      final repository = FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [firstReady, secondReady],
        },
        unreadCount: 2,
        deleteError: const AppException('templates.delete_failed'),
      );
      final store = FakeGenerationGalleryStore()
        ..deletedGenerationIds.addAll([
          'generation-ready-1',
          'generation-ready-2',
        ])
        ..pendingServerDeleteIds.addAll([
          'generation-ready-1',
          'generation-ready-2',
        ]);
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
        store: store,
      );
      addTearDown(harness.dispose);

      await harness.controller.load();

      expect(repository.deleteGenerationCalls, ['generation-ready-1']);
      expect(store.clearPendingServerDeleteCalls, isEmpty);
      expect(store.pendingServerDeleteIds, [
        'generation-ready-1',
        'generation-ready-2',
      ]);
      expect(repository.fetchCalls, [(status: null, take: 50)]);
      expect(harness.state.items, isEmpty);
      expect(harness.state.unreadCount, 0);
    },
  );
}
