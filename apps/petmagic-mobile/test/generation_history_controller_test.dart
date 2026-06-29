import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'loads remote history by filter and reuses in-memory filter cache',
    () async {
      final active = _generation(
        generationId: 'generation-active',
        status: TemplateGenerationStatus.generating,
      );
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [active, ready],
          'completed': [ready],
        },
        unreadCount: 2,
      );
      final harness = _ControllerHarness(repository: repository);
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

      await controller.load(filter: GenerationHistoryFilter.all);
      expect(harness.state.filter, GenerationHistoryFilter.all);
      expect(harness.state.items.map((item) => item.generationId), [
        'generation-active',
        'generation-ready',
      ]);
      expect(repository.fetchCalls, [
        (status: null, take: 50),
        (status: 'completed', take: 50),
      ]);
      expect(repository.fetchUnreadCountCalls, 2);
    },
  );

  test(
    'queues latest filter change while a history load is in flight',
    () async {
      final allFetchCompleter = Completer<void>();
      final active = _generation(
        generationId: 'generation-active',
        status: TemplateGenerationStatus.generating,
      );
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [active],
          'completed': [ready],
        },
        fetchCompletersByStatus: {null: allFetchCompleter},
      );
      final harness = _ControllerHarness(repository: repository);
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
    final ready = _generation(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.completed,
    );
    final repository = _FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [ready],
      },
      unreadCountError: const AppException('templates.unread_count_failed'),
    );
    final harness = _ControllerHarness(repository: repository);
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
      final active = _generation(
        generationId: 'generation-active',
        status: TemplateGenerationStatus.generating,
      );
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [active],
          'completed': [ready],
        },
        fetchCompletersByStatus: {null: allFetchCompleter},
      );
      final harness = _ControllerHarness(repository: repository);
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
    final ready = _generation(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.completed,
    );
    final repository = _FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [ready],
      },
      fetchCompletersByStatus: {null: allFetchCompleter},
    );
    final harness = _ControllerHarness(repository: repository);
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
    expect(
      repository.fetchUnreadCountCalls,
      greaterThan(unreadCallsBeforeCancellation),
    );
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
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
        unreadCount: 1,
        unreadCountCompleter: unreadCompleter,
      );
      final harness = _ControllerHarness(repository: repository);
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
    final repository = _FakeTemplateGenerationRepository();
    final store = _FakeGenerationGalleryStore();
    final harness = _ControllerHarness(repository: repository, store: store);
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
      final failed = _generation(
        generationId: 'generation-failed',
        status: TemplateGenerationStatus.failed,
      );
      final repository = _FakeTemplateGenerationRepository(
        persistedByStatus: {
          'failed': [failed],
        },
        fetchError: const AppException('templates.connection_timeout'),
      );
      final harness = _ControllerHarness(repository: repository);
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
    'filtered loads subtract unread tombstones found in the all-history cache',
    () async {
      final active = _generation(
        generationId: 'generation-active',
        status: TemplateGenerationStatus.generating,
      );
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          'completed': [ready],
        },
        persistedByStatus: {
          null: [active],
        },
        unreadCount: 2,
      );
      final store = _FakeGenerationGalleryStore()
        ..deletedGenerationIds.add('generation-active');
      final harness = _ControllerHarness(repository: repository, store: store);
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
    final ready = _generation(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.completed,
    );
    final repository = _FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [ready],
      },
    );
    final harness = _ControllerHarness(repository: repository);
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
    final ready = _generation(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.completed,
    );
    final repository = _FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [ready],
      },
    );
    final harness = _ControllerHarness(repository: repository);
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
    final active = _generation(
      generationId: 'generation-active',
      status: TemplateGenerationStatus.generating,
      stage: 'generating',
      progressPercent: 70,
    );
    final repository = _FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [active],
        'active': [active],
        'completed': const <TemplateGenerationResult>[],
      },
      unreadCount: 1,
    );
    final realtimeClient = _FakeRealtimeClient();
    final store = _FakeGenerationGalleryStore();
    final harness = _ControllerHarness(
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
        payload: _generationPayload(
          active.copyWith(
            status: TemplateGenerationStatus.completed,
            stage: 'finalizing',
            progressPercent: 100,
            outputUrl: 'https://cdn.petmagic.app/result.jpg',
            completedAtUtc: DateTime.utc(2026, 6, 14, 12, 3),
          ),
        ),
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
    expect(repository.cachedUpserts.map((item) => item.generationId), [
      'generation-active',
    ]);
    expect(harness.state.unreadCount, 0);
    expect(realtimeClient.connectCalls, 1);
  });

  test(
    'mergeFetchedGeneration updates history state from status refresh',
    () async {
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
        outputUrl: 'https://cdn.petmagic.app/result.jpg',
      );
      final repository = _FakeTemplateGenerationRepository();
      final store = _FakeGenerationGalleryStore();
      final harness = _ControllerHarness(repository: repository, store: store);
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
      final ready = _generation(
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
      final repository = _FakeTemplateGenerationRepository();
      final store = _FakeGenerationGalleryStore(
        localReadyRecords: [localRecord],
      );
      final harness = _ControllerHarness(repository: repository, store: store);
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
      final ready = _generation(
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
      final repository = _FakeTemplateGenerationRepository();
      final store = _FakeGenerationGalleryStore(
        localReadyRecords: [localRecord],
      );
      final harness = _ControllerHarness(repository: repository, store: store);
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
      final oldReady = _generation(
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
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [oldReady],
        },
      );
      final store = _FakeGenerationGalleryStore(
        localReadyRecords: [localRecord],
      );
      final harness = _ControllerHarness(repository: repository, store: store);
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
      final active = _generation(
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
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          'active': [active],
          'completed': const <TemplateGenerationResult>[],
        },
      );
      final store = _FakeGenerationGalleryStore();
      final harness = _ControllerHarness(repository: repository, store: store);
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
    final ready = _generation(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.completed,
    );
    final repository = _FakeTemplateGenerationRepository();
    final store = _FakeGenerationGalleryStore()
      ..deletedGenerationIds.add('generation-ready');
    final harness = _ControllerHarness(repository: repository, store: store);
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
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
        outputUrl: 'https://cdn.petmagic.app/result.jpg',
        completedAtUtc: DateTime.utc(2026, 6, 14, 12, 3),
      );
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
      );
      final store = _FakeGenerationGalleryStore(
        materializeCompleter: materializeCompleter,
      );
      final harness = _ControllerHarness(repository: repository, store: store);
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
    final active = _generation(
      generationId: 'generation-active',
      status: TemplateGenerationStatus.generating,
      stage: 'generating',
      progressPercent: 70,
    );
    final repository = _FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [active],
      },
    );
    final realtimeClient = _FakeRealtimeClient();
    final store = _FakeGenerationGalleryStore();
    final harness = _ControllerHarness(
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
        payload: _generationPayload(
          active.copyWith(
            status: TemplateGenerationStatus.completed,
            stage: 'finalizing',
            progressPercent: 100,
            outputUrl: 'https://cdn.petmagic.app/result.jpg',
            completedAtUtc: DateTime.utc(2026, 6, 14, 12, 3),
          ),
        ),
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

  test(
    'realtime checks persisted tombstones before the first history load',
    () async {
      final active = _generation(
        generationId: 'generation-active',
        status: TemplateGenerationStatus.generating,
        stage: 'generating',
        progressPercent: 70,
      );
      final repository = _FakeTemplateGenerationRepository();
      final realtimeClient = _FakeRealtimeClient();
      final store = _FakeGenerationGalleryStore()
        ..deletedGenerationIds.add('generation-active');
      final harness = _ControllerHarness(
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
          payload: _generationPayload(
            active.copyWith(
              status: TemplateGenerationStatus.completed,
              stage: 'finalizing',
              progressPercent: 100,
              outputUrl: 'https://cdn.petmagic.app/result.jpg',
              completedAtUtc: DateTime.utc(2026, 6, 14, 12, 3),
            ),
          ),
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
      final repository = _FakeTemplateGenerationRepository();
      final realtimeClient = _FakeRealtimeClient(
        connectCompleter: connectCompleter,
      );
      final harness = _ControllerHarness(
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
          payload: _generationPayload(
            _generation(
              generationId: 'generation-hidden',
              status: TemplateGenerationStatus.completed,
              outputUrl: 'https://cdn.petmagic.app/result.jpg',
              completedAtUtc: DateTime.utc(2026, 6, 14, 12, 3),
            ),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(harness.state.items, isEmpty);
    },
  );

  test('markRead locally clears unread before server sync completes', () async {
    final ready = _generation(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.completed,
    );
    final markReadCompleter = Completer<void>();
    final repository = _FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [ready],
      },
      unreadCount: 1,
      markReadCompleter: markReadCompleter,
    );
    final harness = _ControllerHarness(repository: repository);
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
    final ready = _generation(
      generationId: 'generation-ready',
      status: TemplateGenerationStatus.completed,
    );
    final repository = _FakeTemplateGenerationRepository(
      remoteByStatus: {
        null: [ready],
      },
      unreadCount: 1,
      markReadError: const AppException('templates.mark_read_failed'),
    );
    final harness = _ControllerHarness(repository: repository);
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
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final markReadCompleter = Completer<void>();
      final readyFetchCompleter = Completer<void>();
      final repository = _FakeTemplateGenerationRepository(
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
      final harness = _ControllerHarness(repository: repository);
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
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final otherReady = _generation(
        generationId: 'generation-other',
        status: TemplateGenerationStatus.completed,
        completedAtUtc: DateTime.utc(2026, 6, 14, 12, 1),
      );
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready, otherReady],
        },
        unreadCount: 2,
      );
      final realtimeClient = _FakeRealtimeClient();
      final harness = _ControllerHarness(
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
          payload: _generationPayload(
            ready.copyWith(
              updatedAtUtc: ready.updatedAtUtc.add(const Duration(seconds: 2)),
              isUnread: true,
            ),
          ),
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
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
      );
      final harness = _ControllerHarness(repository: repository);
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

  test(
    'deleteGeneration creates tombstone and clears pending on success',
    () async {
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
        unreadCount: 0,
      );
      final store = _FakeGenerationGalleryStore();
      final harness = _ControllerHarness(repository: repository, store: store);
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
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
        unreadCount: 0,
        deleteError: const AppException('templates.delete_failed'),
      );
      final store = _FakeGenerationGalleryStore();
      final harness = _ControllerHarness(repository: repository, store: store);
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
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final markDeletedCompleter = Completer<void>();
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
        unreadCount: 1,
      );
      final store = _FakeGenerationGalleryStore(
        markDeletedCompleter: markDeletedCompleter,
      );
      final harness = _ControllerHarness(repository: repository, store: store);

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
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
        unreadCount: 1,
        deleteError: const AppException('templates.delete_failed'),
      );
      final store = _FakeGenerationGalleryStore();
      final harness = _ControllerHarness(repository: repository, store: store);
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
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
        unreadCount: 1,
      );
      final store = _FakeGenerationGalleryStore();
      final harness = _ControllerHarness(repository: repository, store: store);
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
    final repository = _FakeTemplateGenerationRepository(
      unreadCount: 7,
      unreadCountCompleter: unreadCompleter,
    );
    final harness = _ControllerHarness(repository: repository);
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
    final repository = _FakeTemplateGenerationRepository(
      unreadCount: 7,
      unreadCountCompleter: unreadCompleter,
    );
    final harness = _ControllerHarness(repository: repository);
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
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
        unreadCount: 1,
      );
      final store = _FakeGenerationGalleryStore()
        ..deletedGenerationIds.add('generation-ready')
        ..pendingServerDeleteIds.add('generation-ready');
      final harness = _ControllerHarness(repository: repository, store: store);
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
      final firstReady = _generation(
        generationId: 'generation-ready-1',
        status: TemplateGenerationStatus.completed,
      );
      final secondReady = _generation(
        generationId: 'generation-ready-2',
        status: TemplateGenerationStatus.completed,
      );
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [firstReady, secondReady],
        },
        unreadCount: 2,
        deleteCompleter: deleteCompleter,
      );
      final store = _FakeGenerationGalleryStore()
        ..deletedGenerationIds.addAll([
          'generation-ready-1',
          'generation-ready-2',
        ])
        ..pendingServerDeleteIds.addAll([
          'generation-ready-1',
          'generation-ready-2',
        ]);
      final harness = _ControllerHarness(repository: repository, store: store);
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
      final ready = _generation(
        generationId: 'generation-ready',
        status: TemplateGenerationStatus.completed,
      );
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [ready],
        },
        unreadCount: 1,
        deleteError: const AppException('templates.delete_failed'),
      );
      final store = _FakeGenerationGalleryStore()
        ..deletedGenerationIds.add('generation-ready')
        ..pendingServerDeleteIds.add('generation-ready');
      final harness = _ControllerHarness(repository: repository, store: store);
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
      final firstReady = _generation(
        generationId: 'generation-ready-1',
        status: TemplateGenerationStatus.completed,
      );
      final secondReady = _generation(
        generationId: 'generation-ready-2',
        status: TemplateGenerationStatus.completed,
      );
      final repository = _FakeTemplateGenerationRepository(
        remoteByStatus: {
          null: [firstReady, secondReady],
        },
        unreadCount: 2,
        deleteError: const AppException('templates.delete_failed'),
      );
      final store = _FakeGenerationGalleryStore()
        ..deletedGenerationIds.addAll([
          'generation-ready-1',
          'generation-ready-2',
        ])
        ..pendingServerDeleteIds.addAll([
          'generation-ready-1',
          'generation-ready-2',
        ]);
      final harness = _ControllerHarness(repository: repository, store: store);
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

class _ControllerHarness {
  factory _ControllerHarness({
    required _FakeTemplateGenerationRepository repository,
    _FakeGenerationGalleryStore? store,
    _FakeRealtimeClient? realtimeClient,
  }) {
    final resolvedStore = store ?? _FakeGenerationGalleryStore();
    final resolvedRealtimeClient = realtimeClient ?? _FakeRealtimeClient();
    return _ControllerHarness._(
      repository: repository,
      store: resolvedStore,
      realtimeClient: resolvedRealtimeClient,
    );
  }

  _ControllerHarness._({
    required _FakeTemplateGenerationRepository repository,
    required this.store,
    required this.realtimeClient,
  }) : container = ProviderContainer(
         overrides: [
           templateGenerationRepositoryProvider.overrideWithValue(repository),
           generationGalleryStoreProvider.overrideWithValue(store),
           realtimeClientProvider.overrideWithValue(realtimeClient),
         ],
       );

  final ProviderContainer container;
  final _FakeGenerationGalleryStore store;
  final _FakeRealtimeClient realtimeClient;

  GenerationHistoryController get controller =>
      container.read(generationHistoryControllerProvider.notifier);

  GenerationHistoryState get state =>
      container.read(generationHistoryControllerProvider);

  void dispose() {
    container.dispose();
    realtimeClient.dispose();
  }
}

class _FakeTemplateGenerationRepository extends TemplateGenerationRepository {
  _FakeTemplateGenerationRepository({
    Map<String?, List<TemplateGenerationResult>> remoteByStatus = const {},
    Map<String?, List<TemplateGenerationResult>> persistedByStatus = const {},
    this.fetchCompletersByStatus = const {},
    this.fetchError,
    this.deleteError,
    this.deleteCompleter,
    this.markReadError,
    this.markReadCompleter,
    this.unreadCountCompleter,
    this.unreadCountError,
    this.unreadCount = 0,
  }) : remoteByStatus = Map<String?, List<TemplateGenerationResult>>.from(
         remoteByStatus,
       ),
       persistedByStatus = Map<String?, List<TemplateGenerationResult>>.from(
         persistedByStatus,
       ),
       super(
         dio: Dio(),
         sessionStorage: AuthSessionStorage(),
         preferences: SharedPreferencesAsync(),
       );

  final Map<String?, List<TemplateGenerationResult>> remoteByStatus;
  final Map<String?, List<TemplateGenerationResult>> persistedByStatus;
  final Map<String?, Completer<void>> fetchCompletersByStatus;
  final List<({String? status, int? take})> fetchCalls = [];
  final List<CancelToken?> fetchCancelTokens = [];
  final List<CancelToken?> fetchUnreadCancelTokens = [];
  final List<CancelToken?> deleteCancelTokens = [];
  final List<CancelToken?> markReadCancelTokens = [];
  final List<String> deleteGenerationCalls = [];
  final List<String> markReadCalls = [];
  final List<TemplateGenerationResult> cachedUpserts = [];
  int fetchUnreadCountCalls = 0;
  Object? fetchError;
  Object? deleteError;
  Completer<void>? deleteCompleter;
  Object? markReadError;
  Completer<void>? markReadCompleter;
  Completer<void>? unreadCountCompleter;
  Object? unreadCountError;
  int unreadCount;

  @override
  Future<List<TemplateGenerationResult>?> readCachedGenerations({
    String? status,
  }) async {
    return persistedByStatus[status];
  }

  @override
  Future<int?> readCachedUnreadGenerationCount() async => null;

  @override
  Future<List<TemplateGenerationResult>> fetchGenerations({
    String? status,
    int? skip,
    int? take,
    CancelToken? cancelToken,
  }) async {
    fetchCalls.add((status: status, take: take));
    fetchCancelTokens.add(cancelToken);
    final completer = fetchCompletersByStatus[status];
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }
    if (cancelToken?.isCancelled == true) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/templates/generations'),
        type: DioExceptionType.cancel,
      );
    }
    final error = fetchError;
    if (error != null) {
      throw error;
    }
    return remoteByStatus[status] ?? const [];
  }

  @override
  Future<int> fetchUnreadGenerationCount({CancelToken? cancelToken}) async {
    fetchUnreadCountCalls++;
    fetchUnreadCancelTokens.add(cancelToken);
    final completer = unreadCountCompleter;
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }
    if (cancelToken?.isCancelled == true) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '/api/templates/generations/unread-count',
        ),
        type: DioExceptionType.cancel,
      );
    }
    final error = unreadCountError;
    if (error != null) {
      throw error;
    }
    return unreadCount;
  }

  @override
  Future<void> deleteGeneration(
    String generationId, {
    CancelToken? cancelToken,
  }) async {
    deleteGenerationCalls.add(generationId);
    deleteCancelTokens.add(cancelToken);
    final completer = deleteCompleter;
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }
    if (cancelToken?.isCancelled == true) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '/api/templates/generations/$generationId',
        ),
        type: DioExceptionType.cancel,
      );
    }
    final error = deleteError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> markGenerationRead(
    String generationId, {
    CancelToken? cancelToken,
  }) async {
    markReadCalls.add(generationId);
    markReadCancelTokens.add(cancelToken);
    final completer = markReadCompleter;
    if (completer != null) {
      await completer.future;
    }
    final error = markReadError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> upsertCachedGeneration(
    TemplateGenerationResult generation,
  ) async {
    cachedUpserts.add(generation);
  }
}

class _FakeGenerationGalleryStore extends GenerationGalleryStore {
  _FakeGenerationGalleryStore({
    this.materializeCompleter,
    this.markDeletedCompleter,
    List<GenerationGalleryMediaRecord> localReadyRecords = const [],
  }) : localReadyRecords = List<GenerationGalleryMediaRecord>.from(
         localReadyRecords,
       ),
       super(
         dio: Dio(),
         preferences: SharedPreferencesAsync(),
         sessionStorage: AuthSessionStorage(),
         rootDirectoryResolver: () async => Directory.systemTemp,
       );

  final Completer<GenerationGalleryMediaRecord?>? materializeCompleter;
  final Completer<void>? markDeletedCompleter;
  final List<GenerationGalleryMediaRecord> localReadyRecords;
  final List<String> materializedGenerationIds = [];
  final List<({String generationId, String? userId})> markDeletedCalls = [];
  final List<String> clearPendingServerDeleteCalls = [];
  final Set<String> deletedGenerationIds = {};
  final List<String> pendingServerDeleteIds = [];
  int cancelActiveDownloadsCalls = 0;
  int cleanupCurrentAccountArtifactsCalls = 0;

  @override
  Future<Set<String>> loadDeletedGenerationIds() async => deletedGenerationIds;

  @override
  Future<List<String>> loadPendingServerDeleteIds() async =>
      pendingServerDeleteIds;

  @override
  Future<List<GenerationGalleryMediaRecord>> loadLocalReadyItems() async =>
      localReadyRecords;

  @override
  Future<void> clearPendingServerDelete(String generationId) async {
    clearPendingServerDeleteCalls.add(generationId);
    pendingServerDeleteIds.remove(generationId);
  }

  @override
  Future<void> markDeletedLocally(String generationId, {String? userId}) async {
    markDeletedCalls.add((generationId: generationId, userId: userId));
    deletedGenerationIds.add(generationId);
    if (!pendingServerDeleteIds.contains(generationId)) {
      pendingServerDeleteIds.add(generationId);
    }
    final completer = markDeletedCompleter;
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }
  }

  @override
  Future<void> cancelActiveDownloads() async {
    cancelActiveDownloadsCalls++;
  }

  @override
  Future<void> cleanupCurrentAccountArtifacts() async {
    cleanupCurrentAccountArtifactsCalls++;
  }

  @override
  Future<GenerationGalleryMediaRecord?> materializeGenerationMedia(
    TemplateGenerationResult generation,
  ) async {
    materializedGenerationIds.add(generation.generationId);
    final completer = materializeCompleter;
    if (completer != null) {
      return completer.future;
    }

    final nowUtc = DateTime.now().toUtc();
    final outputRemoteUrl = generation.outputUrl;
    final previewRemoteUrl = generation.resultPreviewUrl ?? outputRemoteUrl;
    return GenerationGalleryMediaRecord(
      generationId: generation.generationId,
      accountScope: generation.userId,
      userId: generation.userId,
      status: generation.status.name,
      updatedAtUtc: generation.updatedAtUtc,
      previewRemoteUrl: previewRemoteUrl,
      outputRemoteUrl: outputRemoteUrl,
      previewLocalPath: '/local/${generation.generationId}-preview.jpg',
      outputLocalPath: '/local/${generation.generationId}-output.jpg',
      isDownloadComplete: true,
      lastSyncedAtUtc: nowUtc,
      version: 1,
    );
  }
}

class _FakeRealtimeClient implements RealtimeClient {
  _FakeRealtimeClient({this.connectCompleter});

  final StreamController<RealtimeEvent> _controller =
      StreamController<RealtimeEvent>.broadcast();

  final Completer<void>? connectCompleter;
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Stream<RealtimeEvent> get events => _controller.stream;

  @override
  Future<void> connect() async {
    connectCalls++;
    final completer = connectCompleter;
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }

  void emit(RealtimeEvent event) {
    _controller.add(event);
  }

  void dispose() {
    unawaited(_controller.close());
  }
}

TemplateGenerationResult _generation({
  required String generationId,
  required TemplateGenerationStatus status,
  String stage = 'queued',
  int progressPercent = 0,
  String? outputUrl,
  DateTime? completedAtUtc,
}) {
  final nowUtc = DateTime.utc(2026, 6, 14, 12);
  return TemplateGenerationResult(
    generationId: generationId,
    userId: 'user-1',
    templateId: 'template-1',
    status: status,
    tokenCost: 6,
    attemptCount: 1,
    createdAtUtc: nowUtc,
    updatedAtUtc: completedAtUtc ?? nowUtc,
    userMediaExpired: false,
    templateTitle: 'Magic Portrait',
    templateType: 'image',
    stage: stage,
    progressPercent: progressPercent,
    outputUrl: outputUrl,
    completedAtUtc: completedAtUtc,
    isUnread: true,
  );
}

Map<String, Object?> _generationPayload(TemplateGenerationResult generation) {
  return {
    'generationId': generation.generationId,
    'userId': generation.userId,
    'templateId': generation.templateId,
    'status': generation.status.name,
    'tokenCost': generation.tokenCost,
    'attemptCount': generation.attemptCount,
    'createdAtUtc': generation.createdAtUtc.toIso8601String(),
    'updatedAtUtc': generation.updatedAtUtc.toIso8601String(),
    'userMediaExpired': generation.userMediaExpired,
    'templateTitle': generation.templateTitle,
    'templateType': generation.templateType,
    'stage': generation.stage,
    'progressPercent': generation.progressPercent,
    'outputUrl': generation.outputUrl,
    'completedAtUtc': generation.completedAtUtc?.toIso8601String(),
    'isUnread': generation.isUnread,
  };
}
