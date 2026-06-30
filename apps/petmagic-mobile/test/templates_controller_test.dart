import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';

import 'templates_controller_test_support.dart';

void main() {
  test(
    'coalesces burst realtime invalidations into a single refresh',
    () async {
      final repository = FakeTemplatesControllerRepository();
      final realtimeClient = FakeTemplatesControllerRealtimeClient();
      final container = ProviderContainer(
        overrides: [
          templatesRepositoryProvider.overrideWithValue(repository),
          realtimeClientProvider.overrideWithValue(realtimeClient),
        ],
      );
      addTearDown(container.dispose);

      container.read(templatesControllerProvider);

      realtimeClient.emitTemplatesFeedInvalidated();
      realtimeClient.emitTemplatesFeedInvalidated();
      realtimeClient.emitTemplatesFeedInvalidated();

      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(repository.fetchFeedCalls, 1);
      expect(repository.fetchCategoriesCalls, 1);
    },
  );

  test(
    'replays one deferred refresh after an in-flight realtime refresh',
    () async {
      final repository = FakeTemplatesControllerRepository(
        firstFetchCompleter: Completer<void>(),
      );
      final realtimeClient = FakeTemplatesControllerRealtimeClient();
      final container = ProviderContainer(
        overrides: [
          templatesRepositoryProvider.overrideWithValue(repository),
          realtimeClientProvider.overrideWithValue(realtimeClient),
        ],
      );
      addTearDown(container.dispose);

      container.read(templatesControllerProvider);

      realtimeClient.emitTemplatesFeedInvalidated();
      await Future<void>.delayed(const Duration(milliseconds: 450));
      expect(repository.fetchFeedCalls, 1);

      realtimeClient.emitTemplatesFeedInvalidated();
      realtimeClient.emitTemplatesFeedInvalidated();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repository.fetchFeedCalls, 1);

      repository.completeFirstFetch();
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(repository.fetchFeedCalls, 2);
      expect(repository.fetchCategoriesCalls, 2);
    },
  );

  test(
    'shows cached filter results immediately without clearing list',
    () async {
      final videoFetchCompleter = Completer<void>();
      final repository = FakeTemplatesControllerRepository(
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [templateFixture('all-1', TemplateType.image)],
            hasMore: false,
          ),
          const TemplatesQuery(
            type: TemplateType.video,
          ).cacheKey: TemplatesFeedPage(
            items: [templateFixture('video-1', TemplateType.video)],
            hasMore: false,
          ),
        },
        videoFetchCompleter: videoFetchCompleter,
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
      expect(container.read(templatesControllerProvider).items, hasLength(1));

      controller.setType(TemplateType.video);
      await Future<void>.delayed(Duration.zero);

      final interim = container.read(templatesControllerProvider);
      expect(interim.items.map((item) => item.templateId), ['video-1']);
      expect(interim.isLoading, isFalse);
      expect(interim.isRefreshing, isTrue);
      expect(interim.loadedFromCache, isTrue);
      expect(repository.fetchFeedCalls, 2);

      videoFetchCompleter.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final afterLoad = container.read(templatesControllerProvider);
      expect(afterLoad.items.map((item) => item.templateId), ['video-1']);
      expect(afterLoad.isRefreshing, isFalse);
      expect(repository.fetchFeedCalls, 2);
    },
  );

  test(
    'clears stale visible cards before delayed cache lookup finishes',
    () async {
      final cachedLookupCompleter = Completer<void>();
      final searchQuery = const TemplatesQuery(search: 'magic');
      final repository = FakeTemplatesControllerRepository(
        cachedPagesByKey: const {},
        readCachedFirstPageCompleter: cachedLookupCompleter,
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [templateFixture('old-template', TemplateType.image)],
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
      expect(
        container
            .read(templatesControllerProvider)
            .items
            .map((item) => item.templateId),
        ['old-template'],
      );

      controller.setSearch('magic');
      await Future<void>.delayed(Duration.zero);

      final loadingSearchState = container.read(templatesControllerProvider);
      expect(loadingSearchState.query.search, 'magic');
      expect(loadingSearchState.items, isEmpty);
      expect(loadingSearchState.itemsQueryKey, isNull);
      expect(loadingSearchState.isLoading, isTrue);
      expect(loadingSearchState.isRefreshing, isFalse);
      expect(repository.readCachedFirstPageCalls, 1);
      expect(repository.fetchFeedCalls, 1);

      cachedLookupCompleter.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final loadedSearchState = container.read(templatesControllerProvider);
      expect(loadedSearchState.items.map((item) => item.templateId), [
        'magic-template',
      ]);
      expect(loadedSearchState.isLoading, isFalse);
      expect(repository.fetchFeedCalls, 2);
    },
  );

  test(
    'reuses in-memory cache when returning to previously loaded filter',
    () async {
      final repository = FakeTemplatesControllerRepository(
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [templateFixture('all-1', TemplateType.image)],
            hasMore: false,
          ),
          const TemplatesQuery(
            type: TemplateType.video,
          ).cacheKey: TemplatesFeedPage(
            items: [templateFixture('video-1', TemplateType.video)],
            hasMore: false,
          ),
        },
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
      expect(repository.fetchFeedCalls, 1);

      controller.setType(TemplateType.video);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repository.fetchFeedCalls, 2);
      expect(
        container
            .read(templatesControllerProvider)
            .items
            .map((e) => e.templateId),
        ['video-1'],
      );

      controller.setType(null);
      await Future<void>.delayed(Duration.zero);

      expect(repository.fetchFeedCalls, 2);
      expect(
        container
            .read(templatesControllerProvider)
            .items
            .map((e) => e.templateId),
        ['all-1'],
      );
    },
  );

  test(
    'cancels in-flight feed load and ignores late result when screen hides',
    () async {
      final firstFetchCompleter = Completer<void>();
      final repository = FakeTemplatesControllerRepository(
        firstFetchCompleter: firstFetchCompleter,
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [templateFixture('late-template', TemplateType.image)],
            hasMore: false,
          ),
        },
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
      final loadFuture = controller.loadInitial(forceRefresh: true);
      await Future<void>.delayed(Duration.zero);

      expect(repository.fetchFeedCalls, 1);
      expect(container.read(templatesControllerProvider).isRefreshing, isTrue);

      controller.setScreenVisible(false);

      var state = container.read(templatesControllerProvider);
      expect(repository.cancelPendingFeedRequestCalls, 1);
      expect(repository.cancelPendingMetadataRequestsCalls, 1);
      expect(state.isLoading, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.items, isEmpty);

      firstFetchCompleter.complete();
      await loadFuture;
      await Future<void>.delayed(Duration.zero);

      state = container.read(templatesControllerProvider);
      expect(state.items, isEmpty);
      expect(state.errorMessage, isNull);
    },
  );

  test(
    'bounds in-memory feed cache when many filter queries are visited',
    () async {
      final queries = List<TemplatesQuery>.generate(
        7,
        (index) => TemplatesQuery(category: 'Category $index'),
      );
      final repository = FakeTemplatesControllerRepository(
        cachedPagesByKey: const {},
        pagesByKey: {
          for (final query in queries)
            query.cacheKey: TemplatesFeedPage(
              items: [
                templateFixture(
                  'template-${query.category}',
                  TemplateType.image,
                ),
              ],
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
      for (final query in queries) {
        controller.setCategory(query.category);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      final state = container.read(templatesControllerProvider);
      expect(state.cachedPagesByQueryKey, hasLength(6));
      expect(
        state.cachedPagesByQueryKey.keys,
        queries.skip(1).map((query) => query.cacheKey),
      );
      expect(
        state.cachedPagesByQueryKey,
        isNot(contains(queries.first.cacheKey)),
      );
      expect(repository.fetchFeedCalls, queries.length);
    },
  );

  test('uses remote fetch for cold load when no local cache exists', () async {
    final repository = FakeTemplatesControllerRepository();
    final realtimeClient = FakeTemplatesControllerRealtimeClient();
    final container = ProviderContainer(
      overrides: [
        templatesRepositoryProvider.overrideWithValue(repository),
        realtimeClientProvider.overrideWithValue(realtimeClient),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(templatesControllerProvider.notifier);
    await controller.loadInitial();

    expect(repository.readCachedFirstPageCalls, 1);
    expect(repository.fetchFeedCalls, 1);
  });

  test('deduplicates identical in-flight initial feed loads', () async {
    final fetchCompleter = Completer<void>();
    final repository = FakeTemplatesControllerRepository(
      firstFetchCompleter: fetchCompleter,
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: [templateFixture('template-1', TemplateType.image)],
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
    final firstLoad = controller.loadInitial(forceRefresh: true);
    await Future<void>.delayed(Duration.zero);
    final secondLoad = controller.loadInitial(forceRefresh: true);
    await Future<void>.delayed(Duration.zero);

    expect(repository.fetchFeedCalls, 1);

    fetchCompleter.complete();
    await Future.wait([firstLoad, secondLoad]);

    final state = container.read(templatesControllerProvider);
    expect(repository.fetchFeedCalls, 1);
    expect(state.items.map((item) => item.templateId), ['template-1']);
    expect(state.isLoading, isFalse);
    expect(state.isRefreshing, isFalse);
  });

  test('loadMore uses backend cursor and appends without duplicates', () async {
    final repository = FakeTemplatesControllerRepository(
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: [
            templateFixture('template-1', TemplateType.image),
            templateFixture('template-2', TemplateType.image),
          ],
          nextCursor: 'cursor-2',
          hasMore: true,
        ),
      },
      pagesByCursor: {
        'cursor-2': TemplatesFeedPage(
          items: [
            templateFixture('template-2', TemplateType.image),
            templateFixture('template-3', TemplateType.image),
          ],
          nextCursor: null,
          hasMore: false,
          page: 2,
        ),
      },
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
    await controller.loadMore();

    final state = container.read(templatesControllerProvider);
    expect(repository.fetchedQueries.map((query) => query.cursor), [
      null,
      'cursor-2',
    ]);
    expect(state.items.map((item) => item.templateId), [
      'template-1',
      'template-2',
      'template-3',
    ]);
    expect(state.hasMore, isFalse);
    expect(state.nextCursor, isNull);
  });

  test(
    'keeps 1000 item backend feed paged instead of loading all at once',
    () async {
      final allItems = List<TemplateItem>.generate(
        1005,
        (index) => templateFixture('template-$index', TemplateType.image),
      );
      TemplatesFeedPage page(int pageIndex, {String? nextCursor}) {
        const pageSize = 20;
        final start = (pageIndex - 1) * pageSize;
        return TemplatesFeedPage(
          items: allItems.skip(start).take(pageSize).toList(growable: false),
          nextCursor: nextCursor,
          hasMore: nextCursor != null,
          page: pageIndex,
        );
      }

      final repository = FakeTemplatesControllerRepository(
        pagesByKey: {
          const TemplatesQuery().cacheKey: page(1, nextCursor: '20'),
        },
        pagesByCursor: {
          '20': page(2, nextCursor: '40'),
          '40': page(3, nextCursor: '60'),
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

      var state = container.read(templatesControllerProvider);
      expect(repository.fetchFeedCalls, 1);
      expect(state.items, hasLength(20));
      expect(state.nextCursor, '20');
      expect(state.hasMore, isTrue);

      await controller.loadMore();
      await controller.loadMore();

      state = container.read(templatesControllerProvider);
      expect(repository.fetchedQueries.map((query) => query.cursor), [
        null,
        '20',
        '40',
      ]);
      expect(state.items, hasLength(60));
      expect(state.items.first.templateId, 'template-0');
      expect(state.items.last.templateId, 'template-59');
      expect(state.nextCursor, '60');
      expect(state.hasMore, isTrue);
      expect(state.items.length, lessThan(allItems.length));
    },
  );

  test(
    'ignores duplicate loadMore calls while the same cursor is in-flight',
    () async {
      final loadMoreCompleter = Completer<void>();
      final repository = FakeTemplatesControllerRepository(
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [templateFixture('template-1', TemplateType.image)],
            nextCursor: 'cursor-2',
            hasMore: true,
          ),
        },
        pagesByCursor: {
          'cursor-2': TemplatesFeedPage(
            items: [templateFixture('template-2', TemplateType.image)],
            nextCursor: null,
            hasMore: false,
            page: 2,
          ),
        },
        fetchCompletersByCursor: {'cursor-2': loadMoreCompleter},
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

      final firstLoadMore = controller.loadMore();
      await Future<void>.delayed(Duration.zero);
      final duplicateLoadMore = controller.loadMore();
      await Future<void>.delayed(Duration.zero);

      expect(repository.fetchedQueries.map((query) => query.cursor), [
        null,
        'cursor-2',
      ]);

      loadMoreCompleter.complete();
      await Future.wait([firstLoadMore, duplicateLoadMore]);

      final state = container.read(templatesControllerProvider);
      expect(repository.fetchFeedCalls, 2);
      expect(state.items.map((item) => item.templateId), [
        'template-1',
        'template-2',
      ]);
      expect(state.isLoadingMore, isFalse);
    },
  );

  test(
    'loadMore keeps search filters and backend order across pages',
    () async {
      final query = const TemplatesQuery(
        type: TemplateType.video,
        category: 'Portrait',
        search: 'magic',
      );
      final repository = FakeTemplatesControllerRepository(
        cachedPagesByKey: const {},
        pagesByKey: {
          query.cacheKey: TemplatesFeedPage(
            items: [
              templateFixture('z-backend-first', TemplateType.video),
              templateFixture('a-backend-second', TemplateType.video),
            ],
            nextCursor: 'search-cursor-2',
            hasMore: true,
          ),
        },
        pagesByCursor: {
          'search-cursor-2': TemplatesFeedPage(
            items: [
              templateFixture('m-backend-third', TemplateType.video),
              templateFixture('a-backend-second', TemplateType.video),
              templateFixture('b-backend-fourth', TemplateType.video),
            ],
            nextCursor: null,
            hasMore: false,
            page: 2,
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
      controller.setType(TemplateType.video);
      await Future<void>.delayed(Duration.zero);
      controller.setCategory('Portrait');
      await Future<void>.delayed(Duration.zero);
      controller.setSearch('magic');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await controller.loadMore();

      final loadMoreQuery = repository.fetchedQueries.last;
      final state = container.read(templatesControllerProvider);
      expect(loadMoreQuery.type, TemplateType.video);
      expect(loadMoreQuery.category, 'Portrait');
      expect(loadMoreQuery.search, 'magic');
      expect(loadMoreQuery.cursor, 'search-cursor-2');
      expect(state.items.map((item) => item.templateId), [
        'z-backend-first',
        'a-backend-second',
        'm-backend-third',
        'b-backend-fourth',
      ]);
      expect(state.itemsQueryKey, query.cacheKey);
      expect(state.hasMore, isFalse);
    },
  );

  test(
    'ignores stale search responses and keeps the latest backend results',
    () async {
      final catCompleter = Completer<void>();
      final dogCompleter = Completer<void>();
      final catQuery = const TemplatesQuery(search: 'cat');
      final dogQuery = const TemplatesQuery(search: 'dog');
      final repository = FakeTemplatesControllerRepository(
        cachedPagesByKey: const {},
        pagesByKey: {
          catQuery.cacheKey: TemplatesFeedPage(
            items: [templateFixture('cat-template', TemplateType.image)],
            hasMore: false,
          ),
          dogQuery.cacheKey: TemplatesFeedPage(
            items: [templateFixture('dog-template', TemplateType.image)],
            hasMore: false,
          ),
        },
        fetchCompletersByKey: {
          catQuery.cacheKey: catCompleter,
          dogQuery.cacheKey: dogCompleter,
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
      controller.setSearch('cat');
      await Future<void>.delayed(Duration.zero);

      controller.setSearch('dog');
      await Future<void>.delayed(Duration.zero);
      expect(repository.fetchedQueries.map((query) => query.search), [
        'cat',
        'dog',
      ]);

      dogCompleter.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      var state = container.read(templatesControllerProvider);
      expect(state.query.search, 'dog');
      expect(state.items.map((item) => item.templateId), ['dog-template']);
      expect(state.isLoading, isFalse);

      catCompleter.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      state = container.read(templatesControllerProvider);
      expect(state.query.search, 'dog');
      expect(state.items.map((item) => item.templateId), ['dog-template']);
      expect(state.isLoadingMore, isFalse);
    },
  );

  test('does not append stale loadMore results after type changes', () async {
    final loadMoreCompleter = Completer<void>();
    final videoQuery = const TemplatesQuery(type: TemplateType.video);
    final repository = FakeTemplatesControllerRepository(
      cachedPagesByKey: const {},
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: [templateFixture('image-template-1', TemplateType.image)],
          nextCursor: 'cursor-2',
          hasMore: true,
        ),
        videoQuery.cacheKey: TemplatesFeedPage(
          items: [templateFixture('video-template-1', TemplateType.video)],
          hasMore: false,
        ),
      },
      pagesByCursor: {
        'cursor-2': TemplatesFeedPage(
          items: [templateFixture('image-template-2', TemplateType.image)],
          hasMore: false,
          page: 2,
        ),
      },
      fetchCompletersByCursor: {'cursor-2': loadMoreCompleter},
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

    final loadMoreFuture = controller.loadMore();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(templatesControllerProvider).isLoadingMore, isTrue);

    controller.setType(TemplateType.video);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    var state = container.read(templatesControllerProvider);
    expect(state.query.type, TemplateType.video);
    expect(state.items.map((item) => item.templateId), ['video-template-1']);
    expect(state.isLoadingMore, isFalse);

    loadMoreCompleter.complete();
    await loadMoreFuture;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    state = container.read(templatesControllerProvider);
    expect(state.query.type, TemplateType.video);
    expect(state.items.map((item) => item.templateId), ['video-template-1']);
    expect(state.isLoadingMore, isFalse);
    expect(state.itemsQueryKey, videoQuery.cacheKey);
  });

  test('stops stale thumbnail warmup after filter changes', () async {
    const firstStaleThumbnailUrl =
        'https://cdn.petmagic.test/stale-thumb-1.jpg';
    const secondStaleThumbnailUrl =
        'https://cdn.petmagic.test/stale-thumb-2.jpg';
    const currentThumbnailUrl = 'https://cdn.petmagic.test/current-thumb.jpg';
    final videoQuery = const TemplatesQuery(type: TemplateType.video);
    final warmedUrls = <String>[];
    final staleWarmupStarted = Completer<void>();
    final releaseStaleWarmup = Completer<void>();
    final repository = FakeTemplatesControllerRepository(
      cachedPagesByKey: const {},
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: [
            templateFixture(
              'image-template-1',
              TemplateType.image,
              thumbnailUrl: firstStaleThumbnailUrl,
            ),
            templateFixture(
              'image-template-2',
              TemplateType.image,
              thumbnailUrl: secondStaleThumbnailUrl,
            ),
          ],
          hasMore: false,
        ),
        videoQuery.cacheKey: TemplatesFeedPage(
          items: [
            templateFixture(
              'video-template-1',
              TemplateType.video,
              thumbnailUrl: currentThumbnailUrl,
            ),
          ],
          hasMore: false,
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        templatesRepositoryProvider.overrideWithValue(repository),
        realtimeClientProvider.overrideWithValue(const NoopRealtimeClient()),
        templateThumbnailWarmupProvider.overrideWithValue((url) async {
          warmedUrls.add(url);
          if (url == firstStaleThumbnailUrl) {
            staleWarmupStarted.complete();
            await releaseStaleWarmup.future;
          }
        }),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(templatesControllerProvider.notifier);
    await controller.loadInitial(forceRefresh: true);
    await staleWarmupStarted.future;
    controller.setType(TemplateType.video);
    releaseStaleWarmup.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container.read(templatesControllerProvider);
    expect(state.query.type, TemplateType.video);
    expect(state.items.map((item) => item.templateId), ['video-template-1']);
    expect(warmedUrls, [firstStaleThumbnailUrl, currentThumbnailUrl]);
  });

  test('bounds thumbnail warmup to first preview candidates only', () async {
    final items = List<TemplateItem>.generate(
      50,
      (index) => templateFixture(
        'template-$index',
        TemplateType.image,
        thumbnailUrl: 'https://cdn.petmagic.test/thumb-$index.jpg',
      ),
    );
    final warmedUrls = <String>[];
    final repository = FakeTemplatesControllerRepository(
      cachedPagesByKey: const {},
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: items,
          hasMore: true,
          nextCursor: 'cursor-50',
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        templatesRepositoryProvider.overrideWithValue(repository),
        realtimeClientProvider.overrideWithValue(const NoopRealtimeClient()),
        templateThumbnailWarmupProvider.overrideWithValue((url) async {
          warmedUrls.add(url);
        }),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(templatesControllerProvider.notifier);
    await controller.loadInitial(forceRefresh: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(
      warmedUrls,
      List<String>.generate(
        6,
        (index) => 'https://cdn.petmagic.test/thumb-$index.jpg',
      ),
    );
    expect(
      warmedUrls,
      isNot(contains('https://cdn.petmagic.test/thumb-6.jpg')),
    );
    expect(warmedUrls, hasLength(lessThan(items.length)));
  });
}
