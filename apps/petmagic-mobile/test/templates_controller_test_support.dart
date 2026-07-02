import 'dart:async';

import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

class FakeTemplatesControllerRepository implements TemplatesRepository {
  FakeTemplatesControllerRepository({
    this.firstFetchCompleter,
    this.videoFetchCompleter,
    this.readCachedFirstPageCompleter,
    this.categoriesCompleter,
    this.pagesByKey = const {},
    this.cachedPagesByKey,
    this.pagesByCursor = const {},
    this.templatesById = const {},
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
  final Map<String, TemplateItem> templatesById;
  final Map<String, Completer<void>> fetchCompletersByKey;
  final Map<String, Completer<void>> fetchCompletersByCursor;
  final Map<String, Object> errorsByKey;
  final TemplateOfTheDayItem? templateOfTheDay;
  final Completer<TemplateOfTheDayItem?>? templateOfTheDayCompleter;
  final bool throwOnTemplateOfTheDay;
  int _catalogVersion = 0;
  int fetchFeedCalls = 0;
  int fetchCategoriesCalls = 0;
  int fetchTemplateCalls = 0;
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
  Future<TemplateItem> fetchTemplate(
    String templateId, {
    bool forceRefresh = false,
  }) async {
    fetchTemplateCalls++;
    final template = templatesById[templateId];
    if (template != null) {
      return template;
    }

    return pagesByKey.values
        .expand((page) => page.items)
        .firstWhere((item) => item.templateId == templateId);
  }

  @override
  Future<TemplateItem?> fetchRandomTemplate({
    required TemplateRandomMode mode,
    required String? category,
    required bool includePremium,
    TemplateRandomAccess access = TemplateRandomAccess.available,
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

TemplateItem templateFixture(
  String id,
  TemplateType type, {
  String? title,
  String? shortDescription,
  String? thumbnailUrl,
  String? animatedPreviewUrl,
  String? feedLoopLowUrl,
  String? feedLoopMediumUrl,
  String? detailPreviewUrl,
  int? mediaVersion,
}) {
  return TemplateItem(
    templateId: id,
    templateType: type,
    title: title ?? id,
    shortDescription: shortDescription ?? id,
    petPhotoRequirements: const ['Clear photo'],
    category: 'Portrait',
    tags: const ['pet'],
    isPremium: false,
    tokenCost: 1,
    thumbnailUrl: thumbnailUrl,
    animatedPreviewUrl: animatedPreviewUrl,
    feedLoopLowUrl: feedLoopLowUrl,
    feedLoopMediumUrl: feedLoopMediumUrl,
    detailPreviewUrl: detailPreviewUrl,
    mediaVersion: mediaVersion,
  );
}

class FakeTemplatesControllerRealtimeClient implements RealtimeClient {
  FakeTemplatesControllerRealtimeClient({this.connectCompleter});

  final Completer<void>? connectCompleter;
  final StreamController<RealtimeEvent> _controller =
      StreamController<RealtimeEvent>.broadcast();
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Stream<RealtimeEvent> get events => _controller.stream;

  @override
  Future<void> connect() async {
    connectCalls++;
    await connectCompleter?.future;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  void emitTemplatesFeedInvalidated({Map<String, Object?> payload = const {}}) {
    _controller.add(
      RealtimeEvent(
        topic: RealtimeTopics.templatesFeedInvalidated,
        payload: payload,
      ),
    );
  }
}
