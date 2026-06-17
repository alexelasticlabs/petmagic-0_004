import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'controller uses backend cursor pages and cancels stale slow search requests',
    () async {
      final backend = _SlowTemplateFeedBackend(totalTemplates: 1005);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = backend;
      final repository = _RemoteBackedTemplatesRepository(
        TemplatesRemoteDataSource(dio),
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
      expect(state.items, hasLength(20));
      expect(state.items.first.templateId, 'template-0000');
      expect(state.items.last.templateId, 'template-0019');
      expect(state.nextCursor, 'cursor-20');
      expect(state.hasMore, isTrue);
      expect(backend.feedQueries.single, {'take': 20});

      await controller.loadMore();

      state = container.read(templatesControllerProvider);
      expect(state.items, hasLength(40));
      expect(state.items.last.templateId, 'template-0039');
      expect(state.nextCursor, 'cursor-40');
      expect(backend.feedQueries.map((query) => query['cursor']).toList(), [
        null,
        'cursor-20',
      ]);
      expect(
        backend.feedQueries.map((query) => query['page']).whereType<Object>(),
        isEmpty,
      );

      controller.setSearch('cat');
      await _waitUntil(() => backend.startedSearches.contains('cat'));

      controller.setSearch('dog');
      await _waitUntil(() {
        final current = container.read(templatesControllerProvider);
        return current.query.search == 'dog' &&
            current.items.any((item) => item.templateId == 'dog-template-000');
      });

      state = container.read(templatesControllerProvider);
      expect(backend.cancelledSearches, contains('cat'));
      expect(state.query.search, 'dog');
      expect(state.items.map((item) => item.templateId), [
        'dog-template-000',
        'dog-template-001',
        'dog-template-002',
      ]);
      expect(
        state.items.any((item) => item.templateId.startsWith('cat')),
        isFalse,
      );
      expect(state.errorMessage, isNull);
      expect(state.isLoading, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(
        backend.feedQueries
            .where((query) => query['search'] != null)
            .map((query) => query['search'])
            .toList(),
        ['cat', 'dog'],
      );
    },
  );
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _RemoteBackedTemplatesRepository implements TemplatesRepository {
  const _RemoteBackedTemplatesRepository(this._dataSource);

  final TemplatesRemoteDataSource _dataSource;

  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async {
    return null;
  }

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async {
    return (await _dataSource.fetchFeed(query)).toDomain();
  }

  @override
  void cancelPendingFeedRequest() {
    _dataSource.cancelPendingFeedRequest();
  }

  @override
  void cancelPendingRandomTemplateRequest() {
    _dataSource.cancelPendingRandomTemplateRequest();
  }

  @override
  void cancelPendingMetadataRequests() {
    _dataSource.cancelPendingMetadataRequests();
  }

  @override
  Future<TemplateItem> fetchTemplate(String templateId) async {
    return (await _dataSource.fetchTemplate(templateId)).toDomain();
  }

  @override
  Future<TemplateItem?> fetchRandomTemplate({
    required TemplateRandomMode mode,
    required String? category,
    required bool includePremium,
    TemplateRandomAccess access = TemplateRandomAccess.available,
  }) async {
    return (await _dataSource.fetchRandomTemplate(
      mode: mode,
      category: category,
      includePremium: includePremium,
      access: access,
    )).toDomain();
  }

  @override
  Future<List<TemplateItem>> readSyncedCatalogItems() async {
    return const [];
  }

  @override
  Future<TemplateOfTheDayItem?> fetchTemplateOfTheDay() async {
    return null;
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
    return const ['Portrait', 'Search'];
  }

  @override
  Future<int> readLocalCatalogVersion() async {
    return 0;
  }

  @override
  Future<int> fetchCatalogVersion() async {
    return 1;
  }

  @override
  Future<TemplatesCatalogChanges> fetchCatalogChanges(int sinceVersion) async {
    return TemplatesCatalogChanges(
      fromVersion: sinceVersion,
      toVersion: 1,
      upserts: const [],
      deletedIds: const [],
      needsFullResync: false,
    );
  }

  @override
  Future<int> syncCatalog({int? knownRemoteVersion}) async {
    return knownRemoteVersion ?? 1;
  }
}

class _SlowTemplateFeedBackend implements HttpClientAdapter {
  _SlowTemplateFeedBackend({required this.totalTemplates});

  final int totalTemplates;
  final List<Map<String, Object?>> feedQueries = [];
  final List<String> startedSearches = [];
  final List<String> cancelledSearches = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    if (options.path != '/api/templates/feed') {
      return _jsonResponse({'template': null});
    }

    final query = Map<String, Object?>.from(options.queryParameters);
    feedQueries.add(query);
    final search = query['search'] as String?;
    if (search != null) {
      startedSearches.add(search);
    }

    if (search == 'cat') {
      await (cancelFuture ?? Completer<void>().future);
      cancelledSearches.add(search!);
      throw DioException.requestCancelled(
        requestOptions: options,
        reason: 'superseded slow search',
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 30));

    if (search == 'dog') {
      return _jsonResponse({
        'items': List<Map<String, Object?>>.generate(
          3,
          (index) =>
              _templateJson('dog-template-${index.toString().padLeft(3, '0')}'),
        ),
        'nextCursor': null,
        'hasMore': false,
        'page': 1,
      });
    }

    final take = (query['take'] as int?) ?? 20;
    final cursor = query['cursor'] as String?;
    final start = cursor == null
        ? 0
        : int.tryParse(cursor.replaceFirst('cursor-', '')) ?? 0;
    final end = (start + take).clamp(0, totalTemplates);
    final nextCursor = end < totalTemplates ? 'cursor-$end' : null;
    return _jsonResponse({
      'items': List<Map<String, Object?>>.generate(
        end - start,
        (index) => _templateJson(
          'template-${(start + index).toString().padLeft(4, '0')}',
        ),
      ),
      'nextCursor': nextCursor,
      'hasMore': nextCursor != null,
      'page': (start ~/ take) + 1,
    });
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Map<String, Object?> json) {
  return ResponseBody.fromString(
    jsonEncode(json),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Map<String, Object?> _templateJson(String templateId) {
  return {
    'templateId': templateId,
    'templateType': 'Image',
    'title': templateId,
    'shortDescription': templateId,
    'category': 'Portrait',
    'tags': ['pet', 'portrait'],
    'isPremium': false,
    'tokenCost': 1,
  };
}
