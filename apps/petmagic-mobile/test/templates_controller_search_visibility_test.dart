import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';

import 'templates_controller_test_support.dart';

void main() {
  test('skips duplicate normalized search requests', () async {
    final searchQuery = const TemplatesQuery(search: 'magic');
    final repository = FakeTemplatesControllerRepository(
      cachedPagesByKey: const {},
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: [templateFixture('all-template', TemplateType.image)],
          hasMore: false,
        ),
        searchQuery.cacheKey: TemplatesFeedPage(
          items: [templateFixture('magic-template', TemplateType.image)],
          hasMore: false,
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        templatesRepositoryProvider.overrideWithValue(repository),
        realtimeClientProvider.overrideWithValue(const NoopRealtimeClient()),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(templatesControllerProvider.notifier);
    await controller.loadInitial(forceRefresh: true);
    expect(repository.fetchFeedCalls, 1);

    controller.setSearch('magic');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repository.fetchFeedCalls, 2);

    controller.setSearch(' magic ');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repository.fetchFeedCalls, 2);
    expect(
      container.read(templatesControllerProvider).items.single.templateId,
      'magic-template',
    );
  });

  test(
    'keeps only latest results during rapid category type and search changes',
    () async {
      final portraitQuery = const TemplatesQuery(category: 'Portrait');
      final portraitVideoQuery = const TemplatesQuery(
        type: TemplateType.video,
        category: 'Portrait',
      );
      final portraitVideoSearchQuery = const TemplatesQuery(
        type: TemplateType.video,
        category: 'Portrait',
        search: 'magic',
      );
      final actionVideoSearchQuery = const TemplatesQuery(
        type: TemplateType.video,
        category: 'Action',
        search: 'magic',
      );
      final actionImageSearchQuery = const TemplatesQuery(
        type: TemplateType.image,
        category: 'Action',
        search: 'magic',
      );
      final latestQuery = const TemplatesQuery(
        type: TemplateType.image,
        category: 'Action',
        search: 'spark',
      );
      final allQueries = [
        portraitQuery,
        portraitVideoQuery,
        portraitVideoSearchQuery,
        actionVideoSearchQuery,
        actionImageSearchQuery,
        latestQuery,
      ];
      final completersByKey = {
        for (final query in allQueries) query.cacheKey: Completer<void>(),
      };
      final repository = FakeTemplatesControllerRepository(
        cachedPagesByKey: const {},
        pagesByKey: {
          for (final query in allQueries)
            query.cacheKey: TemplatesFeedPage(
              items: [
                templateFixture(
                  query.cacheKey,
                  query.type ?? TemplateType.image,
                ),
              ],
              hasMore: false,
            ),
        },
        fetchCompletersByKey: completersByKey,
      );
      final container = ProviderContainer(
        overrides: [
          templatesRepositoryProvider.overrideWithValue(repository),
          realtimeClientProvider.overrideWithValue(const NoopRealtimeClient()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(templatesControllerProvider.notifier);
      controller.setCategory('Portrait');
      await Future<void>.delayed(Duration.zero);
      controller.setType(TemplateType.video);
      await Future<void>.delayed(Duration.zero);
      controller.setSearch('magic');
      await Future<void>.delayed(Duration.zero);
      controller.setCategory('Action');
      await Future<void>.delayed(Duration.zero);
      controller.setType(TemplateType.image);
      await Future<void>.delayed(Duration.zero);
      controller.setSearch('spark');
      await Future<void>.delayed(Duration.zero);

      expect(
        repository.fetchedQueries.map((query) => query.cacheKey),
        allQueries.map((query) => query.cacheKey),
      );

      completersByKey[latestQuery.cacheKey]!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      var state = container.read(templatesControllerProvider);
      expect(state.query.cacheKey, latestQuery.cacheKey);
      expect(state.items.map((item) => item.templateId), [
        latestQuery.cacheKey,
      ]);
      expect(state.isLoading, isFalse);
      expect(state.isRefreshing, isFalse);

      for (final query in allQueries.take(allQueries.length - 1)) {
        completersByKey[query.cacheKey]!.complete();
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));

      state = container.read(templatesControllerProvider);
      expect(state.query.cacheKey, latestQuery.cacheKey);
      expect(state.items.map((item) => item.templateId), [
        latestQuery.cacheKey,
      ]);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.errorMessage, isNull);
    },
  );

  test('clearing search returns to backend default feed', () async {
    final searchQuery = const TemplatesQuery(search: 'magic');
    final repository = FakeTemplatesControllerRepository(
      cachedPagesByKey: const {},
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: [templateFixture('default-feed-template', TemplateType.image)],
          hasMore: false,
        ),
        searchQuery.cacheKey: TemplatesFeedPage(
          items: [templateFixture('search-template', TemplateType.image)],
          hasMore: false,
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        templatesRepositoryProvider.overrideWithValue(repository),
        realtimeClientProvider.overrideWithValue(const NoopRealtimeClient()),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(templatesControllerProvider.notifier);
    controller.setSearch('magic');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    controller.setSearch('');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container.read(templatesControllerProvider);
    expect(state.query.search, isNull);
    expect(state.items.map((item) => item.templateId), [
      'default-feed-template',
    ]);
    expect(repository.fetchedQueries.map((query) => query.search), [
      'magic',
      null,
    ]);
  });

  test('empty backend search clears previous feed results', () async {
    final searchQuery = const TemplatesQuery(search: 'missing');
    final repository = FakeTemplatesControllerRepository(
      cachedPagesByKey: const {},
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: [templateFixture('default-feed-template', TemplateType.image)],
          hasMore: false,
        ),
        searchQuery.cacheKey: const TemplatesFeedPage(
          items: [],
          hasMore: false,
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        templatesRepositoryProvider.overrideWithValue(repository),
        realtimeClientProvider.overrideWithValue(const NoopRealtimeClient()),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(templatesControllerProvider.notifier);
    await controller.loadInitial(forceRefresh: true);
    expect(container.read(templatesControllerProvider).items, isNotEmpty);

    controller.setSearch('missing');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container.read(templatesControllerProvider);
    expect(state.query.search, 'missing');
    expect(state.items, isEmpty);
    expect(state.itemsQueryKey, searchQuery.cacheKey);
    expect(state.isLoading, isFalse);
    expect(state.isRefreshing, isFalse);
    expect(state.isEmpty, isTrue);
    expect(state.errorMessage, isNull);
  });

  test(
    'filter load error clears stale results and exposes error state',
    () async {
      final videoQuery = const TemplatesQuery(type: TemplateType.video);
      final repository = FakeTemplatesControllerRepository(
        cachedPagesByKey: const {},
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [
              templateFixture('default-feed-template', TemplateType.image),
            ],
            hasMore: false,
          ),
        },
        errorsByKey: {
          videoQuery.cacheKey: const AppException('templates.server_timeout'),
        },
      );
      final container = ProviderContainer(
        overrides: [
          templatesRepositoryProvider.overrideWithValue(repository),
          realtimeClientProvider.overrideWithValue(const NoopRealtimeClient()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(templatesControllerProvider.notifier);
      await controller.loadInitial(forceRefresh: true);
      expect(container.read(templatesControllerProvider).items, isNotEmpty);

      controller.setType(TemplateType.video);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(templatesControllerProvider);
      expect(state.query.type, TemplateType.video);
      expect(state.items, isEmpty);
      expect(state.itemsQueryKey, isNull);
      expect(state.isLoading, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.isEmpty, isFalse);
      expect(state.errorMessage, 'templates.server_timeout');
    },
  );

  testWidgets('does not update categories after provider disposal', (
    tester,
  ) async {
    final categoriesCompleter = Completer<List<String>>();
    final repository = FakeTemplatesControllerRepository(
      categoriesCompleter: categoriesCompleter,
    );
    final realtimeClient = FakeTemplatesControllerRealtimeClient();
    final container = ProviderContainer(
      overrides: [
        templatesRepositoryProvider.overrideWithValue(repository),
        realtimeClientProvider.overrideWithValue(realtimeClient),
      ],
    );

    final controller = container.read(templatesControllerProvider.notifier);
    await controller.loadInitial(forceRefresh: true);

    container.dispose();
    categoriesCompleter.complete(const ['Portrait']);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('does not update categories after screen hides', (tester) async {
    final categoriesCompleter = Completer<List<String>>();
    final repository = FakeTemplatesControllerRepository(
      categoriesCompleter: categoriesCompleter,
    );
    final realtimeClient = FakeTemplatesControllerRealtimeClient();
    final container = ProviderContainer(
      overrides: [
        templatesRepositoryProvider.overrideWithValue(repository),
        realtimeClientProvider.overrideWithValue(realtimeClient),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(templatesControllerProvider.notifier);
    await controller.loadInitial(forceRefresh: true);

    controller.setScreenVisible(false);
    categoriesCompleter.complete(const ['Portrait']);
    await tester.pump();

    final state = container.read(templatesControllerProvider);
    expect(state.categories, isEmpty);
    expect(tester.takeException(), isNull);
  });

  test(
    'disconnects realtime client when connect finishes after disposal',
    () async {
      final repository = FakeTemplatesControllerRepository();
      final connectCompleter = Completer<void>();
      final realtimeClient = FakeTemplatesControllerRealtimeClient(
        connectCompleter: connectCompleter,
      );
      final container = ProviderContainer(
        overrides: [
          templatesRepositoryProvider.overrideWithValue(repository),
          realtimeClientProvider.overrideWithValue(realtimeClient),
        ],
      );

      container.read(templatesControllerProvider);
      container.dispose();
      connectCompleter.complete();
      await Future<void>.delayed(Duration.zero);

      expect(realtimeClient.disconnectCalls, 1);
    },
  );
}
