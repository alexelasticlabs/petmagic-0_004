import 'dart:async';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';
import 'generation_history_controller_test_support.dart';

void main() {
  configureGenerationHistoryControllerTestHarness();

  test(
    'initial load stores cursor metadata and unread count from page',
    () async {
      final first = generationFixture(
        generationId: 'g-1',
        status: TemplateGenerationStatus.completed,
      );
      final repository = FakeTemplateGenerationRepository(
        remotePagesByCursor: {
          generationHistoryPageKey(null, null): TemplateGenerationGalleryPage(
            items: [first],
            nextCursor: 'cursor-2',
            hasMore: true,
            serverTimeUtc: DateTime.utc(2026, 7, 2),
            unreadCount: 3,
            appliedFilter: 'all',
          ),
        },
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
      );
      addTearDown(harness.dispose);

      harness.controller.setScreenVisible(true);
      await harness.controller.load();

      expect(harness.state.items.map((item) => item.generationId), ['g-1']);
      expect(harness.state.nextCursor, 'cursor-2');
      expect(harness.state.hasMore, isTrue);
      expect(harness.state.unreadCount, 3);
      expect(repository.fetchPageCalls.single.cursor, isNull);
    },
  );

  test('loadMore appends next cursor page and suppresses duplicates', () async {
    final first = generationFixture(
      generationId: 'g-1',
      status: TemplateGenerationStatus.completed,
    );
    final duplicate = generationFixture(
      generationId: 'g-1',
      status: TemplateGenerationStatus.completed,
    );
    final second = generationFixture(
      generationId: 'g-2',
      status: TemplateGenerationStatus.completed,
    );
    final repository = FakeTemplateGenerationRepository(
      remotePagesByCursor: {
        generationHistoryPageKey(null, null): TemplateGenerationGalleryPage(
          items: [first],
          nextCursor: 'cursor-2',
          hasMore: true,
          serverTimeUtc: DateTime.utc(2026, 7, 2),
          unreadCount: 2,
          appliedFilter: 'all',
        ),
        generationHistoryPageKey(
          null,
          'cursor-2',
        ): TemplateGenerationGalleryPage(
          items: [duplicate, second],
          hasMore: false,
          serverTimeUtc: DateTime.utc(2026, 7, 2),
          unreadCount: 2,
          appliedFilter: 'all',
        ),
      },
    );
    final harness = GenerationHistoryControllerHarness(repository: repository);
    addTearDown(harness.dispose);

    harness.controller.setScreenVisible(true);
    await harness.controller.load();
    await harness.controller.loadMore();

    expect(harness.state.items.map((item) => item.generationId).toList(), [
      'g-1',
      'g-2',
    ]);
    expect(harness.state.hasMore, isFalse);
    expect(harness.state.nextCursor, isNull);
    expect(repository.fetchPageCalls.last.cursor, 'cursor-2');
  });

  test('loadMore stops when backend does not advance cursor', () async {
    final first = generationFixture(
      generationId: 'g-1',
      status: TemplateGenerationStatus.completed,
    );
    final duplicate = generationFixture(
      generationId: 'g-1',
      status: TemplateGenerationStatus.completed,
    );
    final repository = FakeTemplateGenerationRepository(
      remotePagesByCursor: {
        generationHistoryPageKey(null, null): TemplateGenerationGalleryPage(
          items: [first],
          nextCursor: 'cursor-2',
          hasMore: true,
          serverTimeUtc: DateTime.utc(2026, 7, 2),
          unreadCount: 1,
          appliedFilter: 'all',
        ),
        generationHistoryPageKey(
          null,
          'cursor-2',
        ): TemplateGenerationGalleryPage(
          items: [duplicate],
          nextCursor: 'cursor-2',
          hasMore: true,
          serverTimeUtc: DateTime.utc(2026, 7, 2),
          unreadCount: 1,
          appliedFilter: 'all',
        ),
      },
    );
    final harness = GenerationHistoryControllerHarness(repository: repository);
    addTearDown(harness.dispose);

    harness.controller.setScreenVisible(true);
    await harness.controller.load();
    await harness.controller.loadMore();
    await harness.controller.loadMore();

    expect(harness.state.items.map((item) => item.generationId), ['g-1']);
    expect(harness.state.hasMore, isFalse);
    expect(harness.state.nextCursor, isNull);
    expect(repository.fetchPageCalls.map((call) => call.cursor), [
      null,
      'cursor-2',
    ]);
  });

  test('filter change and pull-to-refresh reset cursor', () async {
    final all = generationFixture(
      generationId: 'g-all',
      status: TemplateGenerationStatus.completed,
    );
    final ready = generationFixture(
      generationId: 'g-ready',
      status: TemplateGenerationStatus.completed,
    );
    final refreshed = generationFixture(
      generationId: 'g-ready-new',
      status: TemplateGenerationStatus.completed,
    );
    var completedCalls = 0;
    final repository = _SwitchingPaginationRepository(
      pages: {
        generationHistoryPageKey(null, null): TemplateGenerationGalleryPage(
          items: [all],
          nextCursor: 'all-cursor',
          hasMore: true,
          serverTimeUtc: DateTime.utc(2026, 7, 2),
          unreadCount: 1,
          appliedFilter: 'all',
        ),
      },
      completedPageFactory: () {
        completedCalls++;
        return TemplateGenerationGalleryPage(
          items: [completedCalls == 1 ? ready : refreshed],
          nextCursor: completedCalls == 1 ? 'ready-cursor' : null,
          hasMore: completedCalls == 1,
          serverTimeUtc: DateTime.utc(2026, 7, 2),
          unreadCount: 1,
          appliedFilter: 'completed',
        );
      },
    );
    final harness = GenerationHistoryControllerHarness(repository: repository);
    addTearDown(harness.dispose);

    harness.controller.setScreenVisible(true);
    await harness.controller.load();
    await harness.controller.load(filter: GenerationHistoryFilter.ready);
    await harness.controller.load(refresh: true);

    expect(
      repository.fetchPageCalls.map((call) => (call.status, call.cursor)),
      [(null, null), ('completed', null), ('completed', null)],
    );
    expect(harness.state.items.single.generationId, 'g-ready-new');
    expect(harness.state.hasMore, isFalse);
    expect(harness.state.nextCursor, isNull);
  });

  test('loadMore error keeps current items and exposes retry state', () async {
    final first = generationFixture(
      generationId: 'g-1',
      status: TemplateGenerationStatus.completed,
    );
    final repository = FakeTemplateGenerationRepository(
      remotePagesByCursor: {
        generationHistoryPageKey(null, null): TemplateGenerationGalleryPage(
          items: [first],
          nextCursor: 'cursor-2',
          hasMore: true,
          serverTimeUtc: DateTime.utc(2026, 7, 2),
          unreadCount: 1,
          appliedFilter: 'all',
        ),
      },
    );
    final harness = GenerationHistoryControllerHarness(repository: repository);
    addTearDown(harness.dispose);

    harness.controller.setScreenVisible(true);
    await harness.controller.load();
    repository.fetchError = const AppException('templates.server_timeout');
    await harness.controller.loadMore();

    expect(harness.state.items.map((item) => item.generationId), ['g-1']);
    expect(harness.state.hasMore, isTrue);
    expect(harness.state.nextCursor, 'cursor-2');
    expect(harness.state.loadMoreError, 'templates.server_timeout');
  });

  test(
    'stale loadMore response is ignored after refresh changes cursor',
    () async {
      final first = generationFixture(
        generationId: 'g-1',
        status: TemplateGenerationStatus.completed,
      );
      final refreshed = generationFixture(
        generationId: 'g-refresh',
        status: TemplateGenerationStatus.completed,
      );
      final stale = generationFixture(
        generationId: 'g-stale',
        status: TemplateGenerationStatus.completed,
      );
      final loadMoreCompleter = Completer<void>();
      final repository = FakeTemplateGenerationRepository(
        remotePagesByCursor: {
          generationHistoryPageKey(null, null): TemplateGenerationGalleryPage(
            items: [first],
            nextCursor: 'cursor-2',
            hasMore: true,
            serverTimeUtc: DateTime.utc(2026, 7, 2),
            unreadCount: 1,
            appliedFilter: 'all',
          ),
          generationHistoryPageKey(
            null,
            'cursor-2',
          ): TemplateGenerationGalleryPage(
            items: [stale],
            hasMore: false,
            serverTimeUtc: DateTime.utc(2026, 7, 2),
            unreadCount: 1,
            appliedFilter: 'all',
          ),
        },
        fetchCompletersByStatus: {null: loadMoreCompleter},
      );
      final harness = GenerationHistoryControllerHarness(
        repository: repository,
      );
      addTearDown(harness.dispose);

      harness.controller.setScreenVisible(true);
      loadMoreCompleter.complete();
      await harness.controller.load();

      repository.remotePagesByCursor[generationHistoryPageKey(
        null,
        null,
      )] = TemplateGenerationGalleryPage(
        items: [refreshed],
        hasMore: false,
        serverTimeUtc: DateTime.utc(2026, 7, 2),
        unreadCount: 1,
        appliedFilter: 'all',
      );
      final staleCompleter = Completer<void>();
      repository.fetchCompletersByStatus[null] = staleCompleter;
      final staleFuture = harness.controller.loadMore();
      await Future<void>.delayed(Duration.zero);
      final refreshFuture = harness.controller.load(refresh: true);
      staleCompleter.complete();
      await Future.wait([staleFuture, refreshFuture]);

      expect(harness.state.items.map((item) => item.generationId), [
        'g-refresh',
      ]);
      expect(harness.state.hasMore, isFalse);
    },
  );

  test('generation history load cancel-token cleanup is identity safe', () {
    final contractSource = File(
      'lib/features/templates/application/generation_history_controller.dart',
    ).readAsStringSync();
    final lifecycleSource = File(
      'lib/features/templates/application/generation_history_controller_lifecycle.part.dart',
    ).readAsStringSync();
    final syncSource = [
      'lib/features/templates/application/generation_history_controller_sync.part.dart',
      'lib/features/templates/application/generation_history_controller_mutations.part.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(
      contractSource,
      contains(
        'void _clearActiveLoadRequestCancellation(RequestCancellation cancelToken);',
      ),
    );
    expect(
      lifecycleSource,
      contains('if (identical(_activeLoadRequestCancellation, cancelToken))'),
    );
    expect(
      syncSource,
      contains(
        '_clearActiveLoadRequestCancellation(activeLoadRequestCancellation);',
      ),
    );
    expect(
      lifecycleSource,
      isNot(contains('void _clearActiveLoadRequestCancellation()')),
    );
  });
}

class _SwitchingPaginationRepository extends FakeTemplateGenerationRepository {
  _SwitchingPaginationRepository({
    required Map<String, TemplateGenerationGalleryPage> pages,
    required this.completedPageFactory,
  }) : super(remotePagesByCursor: pages);

  final TemplateGenerationGalleryPage Function() completedPageFactory;

  @override
  Future<TemplateGenerationGalleryPage> fetchGenerationPage({
    String? status,
    String? cursor,
    int? take,
    RequestCancellation? cancelToken,
  }) {
    if (status == 'completed' && cursor == null) {
      fetchPageCalls.add((status: status, cursor: cursor, take: take));
      fetchCalls.add((status: status, take: take));
      return Future.value(completedPageFactory());
    }
    return super.fetchGenerationPage(
      status: status,
      cursor: cursor,
      take: take,
      cancelToken: cancelToken,
    );
  }
}
