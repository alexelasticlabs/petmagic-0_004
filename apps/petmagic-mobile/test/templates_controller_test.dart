import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';

void main() {
  test(
    'coalesces burst realtime invalidations into a single refresh',
    () async {
      final repository = _FakeTemplatesRepository();
      final realtimeClient = _FakeRealtimeClient();
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
      final repository = _FakeTemplatesRepository(
        firstFetchCompleter: Completer<void>(),
      );
      final realtimeClient = _FakeRealtimeClient();
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
      final repository = _FakeTemplatesRepository(
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [_template('all-1', TemplateType.image)],
            hasMore: false,
          ),
          const TemplatesQuery(
            type: TemplateType.video,
          ).cacheKey: TemplatesFeedPage(
            items: [_template('video-1', TemplateType.video)],
            hasMore: false,
          ),
        },
        videoFetchCompleter: videoFetchCompleter,
      );
      final realtimeClient = _FakeRealtimeClient();
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
      final repository = _FakeTemplatesRepository(
        cachedPagesByKey: const {},
        readCachedFirstPageCompleter: cachedLookupCompleter,
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [_template('old-template', TemplateType.image)],
            hasMore: false,
          ),
          searchQuery.cacheKey: TemplatesFeedPage(
            items: [_template('magic-template', TemplateType.image)],
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
      final repository = _FakeTemplatesRepository(
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [_template('all-1', TemplateType.image)],
            hasMore: false,
          ),
          const TemplatesQuery(
            type: TemplateType.video,
          ).cacheKey: TemplatesFeedPage(
            items: [_template('video-1', TemplateType.video)],
            hasMore: false,
          ),
        },
      );
      final realtimeClient = _FakeRealtimeClient();
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
      final repository = _FakeTemplatesRepository(
        firstFetchCompleter: firstFetchCompleter,
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [_template('late-template', TemplateType.image)],
            hasMore: false,
          ),
        },
      );
      final realtimeClient = _FakeRealtimeClient();
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
      final repository = _FakeTemplatesRepository(
        cachedPagesByKey: const {},
        pagesByKey: {
          for (final query in queries)
            query.cacheKey: TemplatesFeedPage(
              items: [
                _template('template-${query.category}', TemplateType.image),
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
    final repository = _FakeTemplatesRepository();
    final realtimeClient = _FakeRealtimeClient();
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
    final repository = _FakeTemplatesRepository(
      firstFetchCompleter: fetchCompleter,
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: [_template('template-1', TemplateType.image)],
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
    final repository = _FakeTemplatesRepository(
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: [
            _template('template-1', TemplateType.image),
            _template('template-2', TemplateType.image),
          ],
          nextCursor: 'cursor-2',
          hasMore: true,
        ),
      },
      pagesByCursor: {
        'cursor-2': TemplatesFeedPage(
          items: [
            _template('template-2', TemplateType.image),
            _template('template-3', TemplateType.image),
          ],
          nextCursor: null,
          hasMore: false,
          page: 2,
        ),
      },
    );
    final realtimeClient = _FakeRealtimeClient();
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
        (index) => _template('template-$index', TemplateType.image),
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

      final repository = _FakeTemplatesRepository(
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
      final repository = _FakeTemplatesRepository(
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [_template('template-1', TemplateType.image)],
            nextCursor: 'cursor-2',
            hasMore: true,
          ),
        },
        pagesByCursor: {
          'cursor-2': TemplatesFeedPage(
            items: [_template('template-2', TemplateType.image)],
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
      final repository = _FakeTemplatesRepository(
        cachedPagesByKey: const {},
        pagesByKey: {
          query.cacheKey: TemplatesFeedPage(
            items: [
              _template('z-backend-first', TemplateType.video),
              _template('a-backend-second', TemplateType.video),
            ],
            nextCursor: 'search-cursor-2',
            hasMore: true,
          ),
        },
        pagesByCursor: {
          'search-cursor-2': TemplatesFeedPage(
            items: [
              _template('m-backend-third', TemplateType.video),
              _template('a-backend-second', TemplateType.video),
              _template('b-backend-fourth', TemplateType.video),
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
      final repository = _FakeTemplatesRepository(
        cachedPagesByKey: const {},
        pagesByKey: {
          catQuery.cacheKey: TemplatesFeedPage(
            items: [_template('cat-template', TemplateType.image)],
            hasMore: false,
          ),
          dogQuery.cacheKey: TemplatesFeedPage(
            items: [_template('dog-template', TemplateType.image)],
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
    final repository = _FakeTemplatesRepository(
      cachedPagesByKey: const {},
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: [_template('image-template-1', TemplateType.image)],
          nextCursor: 'cursor-2',
          hasMore: true,
        ),
        videoQuery.cacheKey: TemplatesFeedPage(
          items: [_template('video-template-1', TemplateType.video)],
          hasMore: false,
        ),
      },
      pagesByCursor: {
        'cursor-2': TemplatesFeedPage(
          items: [_template('image-template-2', TemplateType.image)],
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
    final repository = _FakeTemplatesRepository(
      cachedPagesByKey: const {},
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: [
            _template(
              'image-template-1',
              TemplateType.image,
              thumbnailUrl: firstStaleThumbnailUrl,
            ),
            _template(
              'image-template-2',
              TemplateType.image,
              thumbnailUrl: secondStaleThumbnailUrl,
            ),
          ],
          hasMore: false,
        ),
        videoQuery.cacheKey: TemplatesFeedPage(
          items: [
            _template(
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
      (index) => _template(
        'template-$index',
        TemplateType.image,
        thumbnailUrl: 'https://cdn.petmagic.test/thumb-$index.jpg',
      ),
    );
    final warmedUrls = <String>[];
    final repository = _FakeTemplatesRepository(
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

  test('skips duplicate normalized search requests', () async {
    final searchQuery = const TemplatesQuery(search: 'magic');
    final repository = _FakeTemplatesRepository(
      cachedPagesByKey: const {},
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: [_template('all-template', TemplateType.image)],
          hasMore: false,
        ),
        searchQuery.cacheKey: TemplatesFeedPage(
          items: [_template('magic-template', TemplateType.image)],
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
      final repository = _FakeTemplatesRepository(
        cachedPagesByKey: const {},
        pagesByKey: {
          for (final query in allQueries)
            query.cacheKey: TemplatesFeedPage(
              items: [
                _template(query.cacheKey, query.type ?? TemplateType.image),
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
    final repository = _FakeTemplatesRepository(
      cachedPagesByKey: const {},
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: [_template('default-feed-template', TemplateType.image)],
          hasMore: false,
        ),
        searchQuery.cacheKey: TemplatesFeedPage(
          items: [_template('search-template', TemplateType.image)],
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
    final repository = _FakeTemplatesRepository(
      cachedPagesByKey: const {},
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: [_template('default-feed-template', TemplateType.image)],
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
      final repository = _FakeTemplatesRepository(
        cachedPagesByKey: const {},
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [_template('default-feed-template', TemplateType.image)],
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
    final repository = _FakeTemplatesRepository(
      categoriesCompleter: categoriesCompleter,
    );
    final realtimeClient = _FakeRealtimeClient();
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
    final repository = _FakeTemplatesRepository(
      categoriesCompleter: categoriesCompleter,
    );
    final realtimeClient = _FakeRealtimeClient();
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
      final repository = _FakeTemplatesRepository();
      final connectCompleter = Completer<void>();
      final realtimeClient = _FakeRealtimeClient(
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

  test('loads template of the day without blocking feed state', () async {
    final today = DateTime.utc(2026, 6, 14);
    final repository = _FakeTemplatesRepository(
      templateOfTheDay: TemplateOfTheDayItem(
        templateId: 'featured-1',
        title: 'Featured pet',
        subtitle: 'Daily idea',
        badgeText: 'Template of the Day',
        templateType: TemplateType.image,
        isPremium: false,
        requiredPlan: 'free',
        date: today,
        source: 'auto',
      ),
      pagesByKey: {
        const TemplatesQuery().cacheKey: TemplatesFeedPage(
          items: [_template('featured-1', TemplateType.image)],
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

    await container
        .read(templatesControllerProvider.notifier)
        .loadInitial(forceRefresh: true);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(templatesControllerProvider);
    expect(state.items.map((item) => item.templateId), ['featured-1']);
    expect(state.templateOfTheDay?.templateId, 'featured-1');
    expect(state.templateOfTheDay?.source, 'auto');
    expect(state.isTemplateOfTheDayLoading, isFalse);
    expect(state.templateOfTheDayError, isNull);
    expect(repository.fetchTemplateOfTheDayCalls, 1);
  });

  test(
    'keeps template of the day visible when thumbnail warmup fails',
    () async {
      const featuredThumbnailUrl =
          'https://cdn.petmagic.test/featured-thumb.jpg';
      final today = DateTime.utc(2026, 6, 14);
      final warmedUrls = <String>[];
      final repository = _FakeTemplatesRepository(
        templateOfTheDay: TemplateOfTheDayItem(
          templateId: 'featured-warmup-failure',
          title: 'Featured pet',
          subtitle: 'Daily idea',
          badgeText: 'Template of the Day',
          templateType: TemplateType.image,
          thumbnailUrl: featuredThumbnailUrl,
          isPremium: false,
          requiredPlan: 'free',
          date: today,
          source: 'auto',
        ),
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [_template('feed-1', TemplateType.image)],
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
            throw StateError('warmup failed');
          }),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(templatesControllerProvider.notifier)
          .loadInitial(forceRefresh: true);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(templatesControllerProvider);
      expect(warmedUrls, [featuredThumbnailUrl]);
      expect(state.items.map((item) => item.templateId), ['feed-1']);
      expect(state.templateOfTheDay?.templateId, 'featured-warmup-failure');
      expect(state.isTemplateOfTheDayLoading, isFalse);
      expect(state.templateOfTheDayError, isNull);
      expect(state.errorMessage, isNull);
    },
  );

  test(
    'skips template of the day thumbnail warmup after screen hides',
    () async {
      const featuredThumbnailUrl =
          'https://cdn.petmagic.test/featured-thumb.jpg';
      final today = DateTime.utc(2026, 6, 14);
      final featuredCompleter = Completer<TemplateOfTheDayItem?>();
      final warmedUrls = <String>[];
      final repository = _FakeTemplatesRepository(
        templateOfTheDayCompleter: featuredCompleter,
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [_template('feed-1', TemplateType.image)],
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
          }),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(templatesControllerProvider.notifier);
      await controller.loadInitial(forceRefresh: true);
      controller.setScreenVisible(false);
      featuredCompleter.complete(
        TemplateOfTheDayItem(
          templateId: 'featured-hidden',
          title: 'Featured pet',
          subtitle: 'Daily idea',
          badgeText: 'Template of the Day',
          templateType: TemplateType.image,
          thumbnailUrl: featuredThumbnailUrl,
          isPremium: false,
          requiredPlan: 'free',
          date: today,
          source: 'auto',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(templatesControllerProvider);
      expect(state.templateOfTheDay, isNull);
      expect(state.isTemplateOfTheDayLoading, isFalse);
      expect(warmedUrls, isEmpty);
    },
  );

  test(
    'does not refetch template of the day on filter changes after it is loaded',
    () async {
      final today = DateTime.utc(2026, 6, 14);
      final repository = _FakeTemplatesRepository(
        templateOfTheDay: TemplateOfTheDayItem(
          templateId: 'featured-1',
          title: 'Featured pet',
          subtitle: 'Daily idea',
          badgeText: 'Template of the Day',
          templateType: TemplateType.image,
          isPremium: false,
          requiredPlan: 'free',
          date: today,
          source: 'auto',
        ),
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [_template('image-1', TemplateType.image)],
            hasMore: false,
          ),
          const TemplatesQuery(
            type: TemplateType.video,
          ).cacheKey: TemplatesFeedPage(
            items: [_template('video-1', TemplateType.video)],
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
      await Future<void>.delayed(Duration.zero);

      expect(repository.fetchTemplateOfTheDayCalls, 1);
      expect(
        container
            .read(templatesControllerProvider)
            .templateOfTheDay
            ?.templateId,
        'featured-1',
      );

      controller.setType(TemplateType.video);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      var state = container.read(templatesControllerProvider);
      expect(state.query.type, TemplateType.video);
      expect(state.items.map((item) => item.templateId), ['video-1']);
      expect(repository.fetchTemplateOfTheDayCalls, 1);

      await controller.refresh();
      await Future<void>.delayed(Duration.zero);

      state = container.read(templatesControllerProvider);
      expect(state.query.type, TemplateType.video);
      expect(state.templateOfTheDay?.templateId, 'featured-1');
      expect(repository.fetchTemplateOfTheDayCalls, 2);
    },
  );

  test(
    'hides template of the day and keeps feed usable when feature load fails',
    () async {
      final repository = _FakeTemplatesRepository(
        throwOnTemplateOfTheDay: true,
        pagesByKey: {
          const TemplatesQuery().cacheKey: TemplatesFeedPage(
            items: [_template('feed-1', TemplateType.image)],
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

      await container
          .read(templatesControllerProvider.notifier)
          .loadInitial(forceRefresh: true);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(templatesControllerProvider);
      expect(state.items.map((item) => item.templateId), ['feed-1']);
      expect(state.templateOfTheDay, isNull);
      expect(state.isTemplateOfTheDayLoading, isFalse);
      expect(
        state.templateOfTheDayError,
        'templates.template_of_the_day_load_failed',
      );
      expect(state.errorMessage, isNull);
      expect(repository.fetchTemplateOfTheDayCalls, 1);
    },
  );
}

class _FakeTemplatesRepository implements TemplatesRepository {
  _FakeTemplatesRepository({
    this.firstFetchCompleter,
    this.videoFetchCompleter,
    this.readCachedFirstPageCompleter,
    this.categoriesCompleter,
    this.pagesByKey = const {},
    this.cachedPagesByKey,
    this.pagesByCursor = const {},
    this.fetchCompletersByKey = const {},
    this.fetchCompletersByCursor = const {},
    this.errorsByKey = const {},
    this.templateOfTheDay,
    this.templateOfTheDayCompleter,
    this.throwOnTemplateOfTheDay = false,
  });

  final Completer<void>? firstFetchCompleter;
  final Completer<void>? videoFetchCompleter;
  final Completer<void>? readCachedFirstPageCompleter;
  final Completer<List<String>>? categoriesCompleter;
  final Map<String, TemplatesFeedPage> pagesByKey;
  final Map<String, TemplatesFeedPage>? cachedPagesByKey;
  final Map<String, TemplatesFeedPage> pagesByCursor;
  final Map<String, Completer<void>> fetchCompletersByKey;
  final Map<String, Completer<void>> fetchCompletersByCursor;
  final Map<String, Object> errorsByKey;
  final TemplateOfTheDayItem? templateOfTheDay;
  final Completer<TemplateOfTheDayItem?>? templateOfTheDayCompleter;
  final bool throwOnTemplateOfTheDay;
  int _catalogVersion = 0;
  int fetchFeedCalls = 0;
  int fetchCategoriesCalls = 0;
  int readCachedFirstPageCalls = 0;
  int fetchTemplateOfTheDayCalls = 0;
  int cancelPendingFeedRequestCalls = 0;
  int cancelPendingMetadataRequestsCalls = 0;
  final List<TemplatesQuery> fetchedQueries = [];

  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async {
    readCachedFirstPageCalls++;
    if (readCachedFirstPageCompleter != null) {
      await readCachedFirstPageCompleter!.future;
    }
    return (cachedPagesByKey ?? pagesByKey)[query.cacheKey];
  }

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async {
    fetchFeedCalls++;
    fetchedQueries.add(query);
    if (fetchFeedCalls == 1 && firstFetchCompleter != null) {
      await firstFetchCompleter!.future;
    }

    if (query.type == TemplateType.video && videoFetchCompleter != null) {
      await videoFetchCompleter!.future;
    }

    final fetchCompleter = query.cursor == null
        ? fetchCompletersByKey[query.cacheKey]
        : fetchCompletersByCursor[query.cursor];
    if (fetchCompleter != null) {
      await fetchCompleter.future;
    }

    final error = errorsByKey[query.cacheKey];
    if (error != null) {
      throw error;
    }

    return (query.cursor == null ? null : pagesByCursor[query.cursor]) ??
        pagesByKey[query.cacheKey] ??
        const TemplatesFeedPage(items: [], hasMore: false);
  }

  @override
  void cancelPendingFeedRequest() {
    cancelPendingFeedRequestCalls++;
  }

  @override
  void cancelPendingRandomTemplateRequest() {}

  @override
  void cancelPendingMetadataRequests() {
    cancelPendingMetadataRequestsCalls++;
  }

  @override
  Future<TemplateItem> fetchTemplate(String templateId) async {
    return pagesByKey.values
        .expand((page) => page.items)
        .firstWhere((item) => item.templateId == templateId);
  }

  @override
  Future<TemplateItem?> fetchRandomTemplate({
    required TemplateRandomMode mode,
    required String? category,
    required bool includePremium,
  }) async {
    for (final page in pagesByKey.values) {
      if (page.items.isNotEmpty) {
        return page.items.first;
      }
    }
    return null;
  }

  @override
  Future<List<TemplateItem>> readSyncedCatalogItems() async {
    return pagesByKey.values
        .expand((page) => page.items)
        .toList(growable: false);
  }

  @override
  Future<TemplateOfTheDayItem?> fetchTemplateOfTheDay() async {
    fetchTemplateOfTheDayCalls++;
    if (templateOfTheDayCompleter != null) {
      return templateOfTheDayCompleter!.future;
    }

    if (throwOnTemplateOfTheDay) {
      throw StateError('template of the day unavailable');
    }

    return templateOfTheDay;
  }

  @override
  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? source,
    String? generationId,
    Map<String, Object?>? metadata,
  }) async {}

  @override
  Future<List<String>> fetchCategories() async {
    fetchCategoriesCalls++;
    if (categoriesCompleter != null) {
      return categoriesCompleter!.future;
    }

    return const ['Portrait'];
  }

  @override
  Future<int> fetchCatalogVersion() async {
    _catalogVersion += 1;
    return _catalogVersion;
  }

  @override
  Future<int> readLocalCatalogVersion() async {
    return _catalogVersion;
  }

  @override
  Future<TemplatesCatalogChanges> fetchCatalogChanges(int sinceVersion) async {
    return TemplatesCatalogChanges(
      fromVersion: sinceVersion,
      toVersion: _catalogVersion,
      upserts: const [],
      deletedIds: const [],
      needsFullResync: false,
    );
  }

  @override
  Future<int> syncCatalog({int? knownRemoteVersion}) async {
    if (knownRemoteVersion != null) {
      _catalogVersion = knownRemoteVersion;
      return _catalogVersion;
    }

    _catalogVersion += 1;
    return _catalogVersion;
  }

  void completeFirstFetch() {
    if (firstFetchCompleter != null && !firstFetchCompleter!.isCompleted) {
      firstFetchCompleter!.complete();
    }
  }
}

TemplateItem _template(String id, TemplateType type, {String? thumbnailUrl}) {
  return TemplateItem(
    templateId: id,
    templateType: type,
    title: id,
    shortDescription: id,
    petPhotoRequirements: const ['Clear photo'],
    category: 'Portrait',
    tags: const ['pet'],
    isPremium: false,
    tokenCost: 1,
    thumbnailUrl: thumbnailUrl,
  );
}

class _FakeRealtimeClient implements RealtimeClient {
  _FakeRealtimeClient({this.connectCompleter});

  final Completer<void>? connectCompleter;
  final StreamController<RealtimeEvent> _controller =
      StreamController<RealtimeEvent>.broadcast();
  int disconnectCalls = 0;

  @override
  Stream<RealtimeEvent> get events => _controller.stream;

  @override
  Future<void> connect() async {
    await connectCompleter?.future;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  void emitTemplatesFeedInvalidated() {
    _controller.add(
      const RealtimeEvent(topic: RealtimeTopics.templatesFeedInvalidated),
    );
  }
}
