import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(interim.loadedFromCache, isTrue);
      expect(repository.fetchFeedCalls, 1);

      videoFetchCompleter.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final afterLoad = container.read(templatesControllerProvider);
      expect(afterLoad.items.map((item) => item.templateId), ['video-1']);
      expect(repository.fetchFeedCalls, 1);
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
      expect(repository.fetchFeedCalls, 1);
      expect(
        container
            .read(templatesControllerProvider)
            .items
            .map((e) => e.templateId),
        ['video-1'],
      );

      controller.setType(null);
      await Future<void>.delayed(Duration.zero);

      expect(repository.fetchFeedCalls, 1);
      expect(
        container
            .read(templatesControllerProvider)
            .items
            .map((e) => e.templateId),
        ['all-1'],
      );
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
    this.categoriesCompleter,
    this.pagesByKey = const {},
    this.templateOfTheDay,
    this.throwOnTemplateOfTheDay = false,
  });

  final Completer<void>? firstFetchCompleter;
  final Completer<void>? videoFetchCompleter;
  final Completer<List<String>>? categoriesCompleter;
  final Map<String, TemplatesFeedPage> pagesByKey;
  final TemplateOfTheDayItem? templateOfTheDay;
  final bool throwOnTemplateOfTheDay;
  int _catalogVersion = 0;
  int fetchFeedCalls = 0;
  int fetchCategoriesCalls = 0;
  int readCachedFirstPageCalls = 0;
  int fetchTemplateOfTheDayCalls = 0;

  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async {
    readCachedFirstPageCalls++;
    return pagesByKey[query.cacheKey];
  }

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async {
    fetchFeedCalls++;
    if (fetchFeedCalls == 1 && firstFetchCompleter != null) {
      await firstFetchCompleter!.future;
    }

    if (query.type == TemplateType.video && videoFetchCompleter != null) {
      await videoFetchCompleter!.future;
    }

    return pagesByKey[query.cacheKey] ??
        const TemplatesFeedPage(items: [], hasMore: false);
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

TemplateItem _template(String id, TemplateType type) {
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
