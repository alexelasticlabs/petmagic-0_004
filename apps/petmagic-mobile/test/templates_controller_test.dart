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
    'clears stale list immediately when switching to uncached filter',
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
      expect(interim.items, isEmpty);
      expect(interim.isLoading, isTrue);

      videoFetchCompleter.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final afterLoad = container.read(templatesControllerProvider);
      expect(afterLoad.items.map((item) => item.templateId), ['video-1']);
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
}

class _FakeTemplatesRepository implements TemplatesRepository {
  _FakeTemplatesRepository({
    this.firstFetchCompleter,
    this.videoFetchCompleter,
    this.pagesByKey = const {},
  });

  final Completer<void>? firstFetchCompleter;
  final Completer<void>? videoFetchCompleter;
  final Map<String, TemplatesFeedPage> pagesByKey;
  int _catalogVersion = 0;
  int fetchFeedCalls = 0;
  int fetchCategoriesCalls = 0;

  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async {
    return null;
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
  Future<List<String>> fetchCategories() async {
    fetchCategoriesCalls++;
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
  final StreamController<RealtimeEvent> _controller =
      StreamController<RealtimeEvent>.broadcast();

  @override
  Stream<RealtimeEvent> get events => _controller.stream;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {
    await _controller.close();
  }

  void emitTemplatesFeedInvalidated() {
    _controller.add(
      const RealtimeEvent(topic: RealtimeTopics.templatesFeedInvalidated),
    );
  }
}
