import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/templates/data/templates_cache_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/templates_dto.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'templates repository logs cleanup failures instead of swallowing them',
    () async {
      final source = await File(
        'lib/features/templates/data/templates_repository.dart',
      ).readAsString();

      expect(source, contains('AppLogger.warn('));
      expect(source, contains("feature: 'Templates.Repository'"));
      expect(source, contains("operation: 'cleanup_deleted_media_url'"));
      expect(source, contains("operation: 'remove_thumbnail_from_cache'"));
      expect(source, contains("operation: 'remove_preview_from_cache'"));
      expect(source, isNot(contains('} catch (_) {')));
    },
  );

  late SharedPreferencesAsyncPlatform? previousPreferencesPlatform;

  setUp(() {
    previousPreferencesPlatform = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = previousPreferencesPlatform;
  });

  test(
    'full catalog resync uses paged catalog metadata instead of feed endpoint',
    () async {
      final backend = _CatalogSyncBackend();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = backend;
      final repository = DefaultTemplatesRepository(
        remoteDataSource: TemplatesRemoteDataSource(dio),
        cacheDataSource: TemplatesCacheDataSource(SharedPreferencesAsync()),
      );

      final items = await repository.readSyncedCatalogItems();

      expect(backend.requestPaths, [
        '/api/templates/catalog-version',
        '/api/templates',
        '/api/templates',
      ]);
      expect(backend.catalogQueries, [
        {'page': 1, 'pageSize': 100},
        {'page': 2, 'pageSize': 100},
      ]);
      expect(backend.requestPaths, isNot(contains('/api/templates/feed')));
      expect(await repository.readLocalCatalogVersion(), 7);
      expect(items.map((item) => item.templateId), [
        'catalog-new',
        'catalog-old',
      ]);
      expect(items.first.version, 7);
      expect(items.first.updatedAtUtc, DateTime.utc(2026, 6, 15, 12));
      expect(
        items.first.thumbnailUrl,
        'https://cdn.petmagic.test/catalog-new-thumb.jpg',
      );
      expect(
        items.first.previewAsset?.url,
        'https://cdn.petmagic.test/catalog-new-thumb.jpg',
      );
    },
  );

  test('local cached feed search matches backend searchable fields', () async {
    final cacheDataSource = TemplatesCacheDataSource(SharedPreferencesAsync());
    await cacheDataSource.replaceCatalog([
      _catalogDto(
        id: 'description-match',
        title: 'Plain title',
        thumbnailUrl: 'https://cdn.petmagic.test/description-thumb.jpg',
        previewUrl: 'https://cdn.petmagic.test/description-preview.jpg',
        shortDescription: 'Works with playful costumes',
      ),
      _catalogDto(
        id: 'requirements-match',
        title: 'Another title',
        thumbnailUrl: 'https://cdn.petmagic.test/requirements-thumb.jpg',
        previewUrl: 'https://cdn.petmagic.test/requirements-preview.jpg',
        petPhotoRequirements: const ['Visible paws required'],
      ),
      _catalogDto(
        id: 'non-match',
        title: 'Studio portrait',
        thumbnailUrl: 'https://cdn.petmagic.test/non-match-thumb.jpg',
        previewUrl: 'https://cdn.petmagic.test/non-match-preview.jpg',
      ),
    ], version: 1);

    final descriptionPage = await cacheDataSource.readFirstPage(
      const TemplatesQuery(search: 'costumes'),
    );
    final requirementsPage = await cacheDataSource.readFirstPage(
      const TemplatesQuery(search: 'paws'),
    );

    expect(descriptionPage?.items.map((item) => item.templateId), [
      'description-match',
    ]);
    expect(requirementsPage?.items.map((item) => item.templateId), [
      'requirements-match',
    ]);
  });

  test(
    'catalog cache strips signed media URL secrets before persistence',
    () async {
      final preferences = SharedPreferencesAsync();
      final cacheDataSource = TemplatesCacheDataSource(preferences);
      await cacheDataSource.replaceCatalog([
        _catalogDto(
          id: 'signed-media',
          title: 'Signed media',
          thumbnailUrl:
              'https://cdn.petmagic.test/signed-thumb.jpg?X-Amz-Signature=thumb-secret&token=raw#thumb-fragment',
          previewUrl:
              'https://cdn.petmagic.test/signed-preview.mp4?X-Amz-Signature=preview-secret&token=raw#preview-fragment',
        ),
      ], version: 1);

      final raw = await preferences.getString('templates_catalog_items_v2');
      final cachedItems = await cacheDataSource.readCatalogItems();

      expect(raw, isNotNull);
      expect(raw, isNot(contains('X-Amz-Signature')));
      expect(raw, isNot(contains('token=raw')));
      expect(raw, isNot(contains('thumb-secret')));
      expect(raw, isNot(contains('preview-secret')));
      expect(raw, isNot(contains('fragment')));
      expect(
        cachedItems.single.thumbnailUrl,
        'https://cdn.petmagic.test/signed-thumb.jpg',
      );
      expect(
        cachedItems.single.previewAsset?.url,
        'https://cdn.petmagic.test/signed-preview.mp4',
      );
    },
  );

  test(
    'catalog cache strips signed media URL secrets from list fields on read',
    () async {
      final preferences = SharedPreferencesAsync();
      final cacheDataSource = TemplatesCacheDataSource(preferences);
      await preferences.setString(
        'templates_catalog_items_v2',
        jsonEncode([
          {
            ..._catalogItem(
              id: 'signed-media-list',
              title: 'Signed media list',
              version: 1,
              updatedAtUtc: '2026-06-15T12:00:00Z',
            ),
            'referenceImageUrls': [
              'https://cdn.petmagic.test/ref-1.jpg?X-Amz-Signature=secret&token=raw#fragment',
              'https://cdn.petmagic.test/ref-2.jpg?signature=secret',
            ],
          },
        ]),
      );

      final cachedItems = await cacheDataSource.readCatalogItems();
      final raw = await preferences.getString('templates_catalog_items_v2');

      expect(cachedItems.single.templateId, 'signed-media-list');
      expect(raw, isNotNull);
      expect(raw, isNot(contains('X-Amz-Signature')));
      expect(raw, isNot(contains('token=raw')));
      expect(raw, isNot(contains('signature=secret')));
      expect(raw, isNot(contains('fragment')));
      expect(raw, contains('https://cdn.petmagic.test/ref-1.jpg'));
      expect(raw, contains('https://cdn.petmagic.test/ref-2.jpg'));
    },
  );

  test(
    'catalog delta ignores signed media URL rotation when cleaning stale media',
    () async {
      final cacheDataSource = TemplatesCacheDataSource(
        SharedPreferencesAsync(),
      );
      await cacheDataSource.replaceCatalog([
        _catalogDto(
          id: 'rotating-signature',
          title: 'Rotating signature',
          thumbnailUrl:
              'https://cdn.petmagic.test/rotating-thumb.jpg?X-Amz-Signature=old-thumb',
          previewUrl:
              'https://cdn.petmagic.test/rotating-preview.mp4?token=old-preview',
        ),
      ], version: 1);

      final staleUrls = await cacheDataSource.applyCatalogChanges(
        TemplatesCatalogChangesDto(
          fromVersion: 1,
          toVersion: 2,
          upserts: [
            _catalogDto(
              id: 'rotating-signature',
              title: 'Rotating signature',
              thumbnailUrl:
                  'https://cdn.petmagic.test/rotating-thumb.jpg?X-Amz-Signature=new-thumb',
              previewUrl:
                  'https://cdn.petmagic.test/rotating-preview.mp4?token=new-preview',
            ),
          ],
          deletedIds: const [],
          needsFullResync: false,
        ),
      );

      expect(staleUrls, isEmpty);
      final cachedItems = await cacheDataSource.readCatalogItems();
      expect(
        cachedItems.single.thumbnailUrl,
        'https://cdn.petmagic.test/rotating-thumb.jpg',
      );
      expect(
        cachedItems.single.previewAsset?.url,
        'https://cdn.petmagic.test/rotating-preview.mp4',
      );
    },
  );

  test(
    'local cached feed preserves backend version ordering for tied timestamps',
    () async {
      final cacheDataSource = TemplatesCacheDataSource(
        SharedPreferencesAsync(),
      );
      await cacheDataSource.replaceCatalog([
        _catalogDto(
          id: 'lower-version',
          title: 'Lower version',
          thumbnailUrl: 'https://cdn.petmagic.test/lower-thumb.jpg',
          previewUrl: 'https://cdn.petmagic.test/lower-preview.jpg',
          version: 1,
        ),
        _catalogDto(
          id: 'higher-version',
          title: 'Higher version',
          thumbnailUrl: 'https://cdn.petmagic.test/higher-thumb.jpg',
          previewUrl: 'https://cdn.petmagic.test/higher-preview.jpg',
          version: 3,
        ),
        _catalogDto(
          id: 'middle-version',
          title: 'Middle version',
          thumbnailUrl: 'https://cdn.petmagic.test/middle-thumb.jpg',
          previewUrl: 'https://cdn.petmagic.test/middle-preview.jpg',
          version: 2,
        ),
      ], version: 3);

      final cachedPage = await cacheDataSource.readFirstPage(
        const TemplatesQuery(),
      );

      expect(cachedPage?.items.map((item) => item.templateId), [
        'higher-version',
        'middle-version',
        'lower-version',
      ]);
    },
  );

  test(
    'fetchCategories prefers fresh remote categories over local catalog cache',
    () async {
      final cacheDataSource = TemplatesCacheDataSource(
        SharedPreferencesAsync(),
      );
      await cacheDataSource.replaceCatalog([
        _catalogDto(
          id: 'local-stale',
          title: 'Local stale',
          category: 'Stale',
          thumbnailUrl: 'https://cdn.petmagic.test/local-stale-thumb.jpg',
          previewUrl: 'https://cdn.petmagic.test/local-stale-preview.jpg',
        ),
      ], version: 1);
      final backend = _CategoriesBackend(
        remoteCategories: const ['Fresh', 'Video'],
      );
      final repository = DefaultTemplatesRepository(
        remoteDataSource: TemplatesRemoteDataSource(
          Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
            ..httpClientAdapter = backend,
        ),
        cacheDataSource: cacheDataSource,
      );

      final categories = await repository.fetchCategories();

      expect(categories, ['Fresh', 'Video']);
      expect(backend.requestPaths, ['/api/templates/categories']);
    },
  );

  test(
    'fetchCategories falls back to local catalog categories when remote fails',
    () async {
      final cacheDataSource = TemplatesCacheDataSource(
        SharedPreferencesAsync(),
      );
      await cacheDataSource.replaceCatalog([
        _catalogDto(
          id: 'local-portrait',
          title: 'Local portrait',
          category: 'Portrait',
          thumbnailUrl: 'https://cdn.petmagic.test/local-portrait-thumb.jpg',
          previewUrl: 'https://cdn.petmagic.test/local-portrait-preview.jpg',
        ),
      ], version: 1);
      final backend = _CategoriesBackend(failCategories: true);
      final repository = DefaultTemplatesRepository(
        remoteDataSource: TemplatesRemoteDataSource(
          Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
            ..httpClientAdapter = backend,
        ),
        cacheDataSource: cacheDataSource,
      );

      final categories = await repository.fetchCategories();

      expect(categories, ['Portrait']);
      expect(backend.requestPaths, ['/api/templates/categories']);
    },
  );

  test(
    'fetchTemplate deduplicates in-flight requests and caches detail',
    () async {
      final backend = _TemplateDetailBackend();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = backend;
      final repository = DefaultTemplatesRepository(
        remoteDataSource: TemplatesRemoteDataSource(dio),
        cacheDataSource: TemplatesCacheDataSource(SharedPreferencesAsync()),
      );

      final results = await Future.wait([
        repository.fetchTemplate(' template-detail-1 '),
        repository.fetchTemplate('template-detail-1'),
      ]);
      final cached = await repository.fetchTemplate('template-detail-1');

      expect(results.map((item) => item.templateId), [
        'template-detail-1',
        'template-detail-1',
      ]);
      expect(cached.templateId, 'template-detail-1');
      expect(backend.detailRequestCount('template-detail-1'), 1);
    },
  );

  test(
    'fetchRandomTemplate seeds detail cache without a second fetch',
    () async {
      final backend = _TemplateDetailBackend(
        randomTemplateId: 'random-template-1',
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = backend;
      final repository = DefaultTemplatesRepository(
        remoteDataSource: TemplatesRemoteDataSource(dio),
        cacheDataSource: TemplatesCacheDataSource(SharedPreferencesAsync()),
      );

      final random = await repository.fetchRandomTemplate(
        mode: TemplateRandomMode.video,
        category: 'Motion',
        includePremium: false,
      );
      final detail = await repository.fetchTemplate('random-template-1');

      expect(random?.templateId, 'random-template-1');
      expect(detail.templateId, 'random-template-1');
      expect(detail.title, 'Random random-template-1');
      expect(backend.randomRequestCount, 1);
      expect(backend.detailRequestCount('random-template-1'), 0);
    },
  );

  test('catalog delta evicts changed template detail cache', () async {
    final backend = _CatalogDeltaBackend();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = backend;
    final repository = DefaultTemplatesRepository(
      remoteDataSource: TemplatesRemoteDataSource(dio),
      cacheDataSource: TemplatesCacheDataSource(SharedPreferencesAsync()),
    );

    await repository.readSyncedCatalogItems();
    final oldDetail = await repository.fetchTemplate('catalog-new');

    backend.catalogVersion = 8;
    backend.detailTitlesById['catalog-new'] = 'Fresh detail';
    await repository.syncCatalog();
    final freshDetail = await repository.fetchTemplate('catalog-new');

    expect(oldDetail.title, 'Old detail');
    expect(freshDetail.title, 'Fresh detail');
    expect(backend.changesRequestCount, 1);
    expect(backend.detailRequestCount('catalog-new'), 2);
  });

  test('catalog delta cleans stale thumbnail and preview media urls', () async {
    final cleanedUrls = <String>[];
    final backend = _CatalogMediaCleanupBackend(needsFullResync: false);
    final cacheDataSource = TemplatesCacheDataSource(SharedPreferencesAsync());
    await _writePreviousMediaCatalog(cacheDataSource);
    final repository = DefaultTemplatesRepository(
      remoteDataSource: TemplatesRemoteDataSource(
        Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
          ..httpClientAdapter = backend,
      ),
      cacheDataSource: cacheDataSource,
      mediaCleanup: (url) async {
        cleanedUrls.add(url);
      },
    );

    await repository.syncCatalog();

    expect(cleanedUrls, unorderedEquals(_expectedStaleMediaUrls));
    expect(cleanedUrls, isNot(contains(_sharedThumbnailUrl)));
    expect(cleanedUrls, isNot(contains(_sharedPreviewUrl)));
    expect(backend.requestPaths, [
      '/api/templates/catalog-version',
      '/api/templates/changes',
    ]);
  });

  test(
    'full catalog resync cleans stale thumbnail and preview media urls',
    () async {
      final cleanedUrls = <String>[];
      final backend = _CatalogMediaCleanupBackend(needsFullResync: true);
      final cacheDataSource = TemplatesCacheDataSource(
        SharedPreferencesAsync(),
      );
      await _writePreviousMediaCatalog(cacheDataSource);
      final repository = DefaultTemplatesRepository(
        remoteDataSource: TemplatesRemoteDataSource(
          Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
            ..httpClientAdapter = backend,
        ),
        cacheDataSource: cacheDataSource,
        mediaCleanup: (url) async {
          cleanedUrls.add(url);
        },
      );

      await repository.syncCatalog();

      expect(cleanedUrls, unorderedEquals(_expectedStaleMediaUrls));
      expect(cleanedUrls, isNot(contains(_sharedThumbnailUrl)));
      expect(cleanedUrls, isNot(contains(_sharedPreviewUrl)));
      expect(backend.requestPaths, [
        '/api/templates/catalog-version',
        '/api/templates/changes',
        '/api/templates',
      ]);
    },
  );

  test(
    'full catalog resync aborts on invalid paging metadata and keeps local cache',
    () async {
      final cacheDataSource = TemplatesCacheDataSource(
        SharedPreferencesAsync(),
      );
      await cacheDataSource.replaceCatalog([
        _catalogDto(
          id: 'local-existing',
          title: 'Local existing',
          thumbnailUrl: 'https://cdn.petmagic.test/local-existing-thumb.jpg',
          previewUrl: 'https://cdn.petmagic.test/local-existing-preview.jpg',
        ),
      ], version: 1);
      final backend = _InvalidFullResyncPagingBackend();
      final repository = DefaultTemplatesRepository(
        remoteDataSource: TemplatesRemoteDataSource(
          Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
            ..httpClientAdapter = backend,
        ),
        cacheDataSource: cacheDataSource,
      );

      await expectLater(
        repository.syncCatalog(),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            'templates.catalog_sync_failed',
          ),
        ),
      );

      expect(await cacheDataSource.readCatalogVersion(), 1);
      expect(
        (await cacheDataSource.readCatalogItems()).map(
          (item) => item.templateId,
        ),
        ['local-existing'],
      );
      expect(backend.catalogPagesRequested, [1, 2]);
    },
  );

  test(
    'full catalog resync stops after bounded page budget and keeps local cache',
    () async {
      final cacheDataSource = TemplatesCacheDataSource(
        SharedPreferencesAsync(),
      );
      await cacheDataSource.replaceCatalog([
        _catalogDto(
          id: 'local-existing',
          title: 'Local existing',
          thumbnailUrl: 'https://cdn.petmagic.test/local-existing-thumb.jpg',
          previewUrl: 'https://cdn.petmagic.test/local-existing-preview.jpg',
        ),
      ], version: 1);
      final backend = _ExcessiveFullResyncPagingBackend();
      final repository = DefaultTemplatesRepository(
        remoteDataSource: TemplatesRemoteDataSource(
          Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
            ..httpClientAdapter = backend,
        ),
        cacheDataSource: cacheDataSource,
      );

      await expectLater(
        repository.syncCatalog(),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            'templates.catalog_sync_failed',
          ),
        ),
      );

      expect(await cacheDataSource.readCatalogVersion(), 1);
      expect(
        (await cacheDataSource.readCatalogItems()).map(
          (item) => item.templateId,
        ),
        ['local-existing'],
      );
      expect(backend.catalogPagesRequested.length, 100);
      expect(backend.catalogPagesRequested.first, 1);
      expect(backend.catalogPagesRequested.last, 100);
    },
  );

  test('template detail cache is bounded', () async {
    final backend = _TemplateDetailBackend();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = backend;
    final repository = DefaultTemplatesRepository(
      remoteDataSource: TemplatesRemoteDataSource(dio),
      cacheDataSource: TemplatesCacheDataSource(SharedPreferencesAsync()),
    );

    for (var index = 0; index < 65; index++) {
      await repository.fetchTemplate('template-$index');
    }
    await repository.fetchTemplate('template-0');

    expect(backend.detailRequestCount('template-0'), 2);
    expect(backend.totalDetailRequestCount, 66);
  });

  test('late detail response after catalog resync is not cached', () async {
    final backend = _DelayedDetailCatalogBackend();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = backend;
    final repository = DefaultTemplatesRepository(
      remoteDataSource: TemplatesRemoteDataSource(dio),
      cacheDataSource: TemplatesCacheDataSource(SharedPreferencesAsync()),
    );

    final firstFetch = repository.fetchTemplate('template-late');
    await backend.firstDetailStarted.future;

    await repository.syncCatalog(knownRemoteVersion: 7);
    backend.releaseFirstDetail();
    await firstFetch;
    await repository.fetchTemplate('template-late');

    expect(backend.detailRequestCount('template-late'), 2);
  });
}

const _deletedThumbnailUrl = 'https://cdn.petmagic.test/deleted-thumb.jpg';
const _deletedPreviewUrl = 'https://cdn.petmagic.test/deleted-preview.mp4';
const _oldChangedThumbnailUrl =
    'https://cdn.petmagic.test/changed-old-thumb.jpg';
const _oldChangedPreviewUrl =
    'https://cdn.petmagic.test/changed-old-preview.mp4';
const _newChangedThumbnailUrl =
    'https://cdn.petmagic.test/changed-new-thumb.jpg';
const _newChangedPreviewUrl =
    'https://cdn.petmagic.test/changed-new-preview.mp4';
const _sharedThumbnailUrl = 'https://cdn.petmagic.test/shared-thumb.jpg';
const _sharedPreviewUrl = 'https://cdn.petmagic.test/shared-preview.mp4';
const _expectedStaleMediaUrls = [
  _deletedThumbnailUrl,
  _deletedPreviewUrl,
  _oldChangedThumbnailUrl,
  _oldChangedPreviewUrl,
];

Future<void> _writePreviousMediaCatalog(
  TemplatesCacheDataSource cacheDataSource,
) async {
  await cacheDataSource.replaceCatalog([
    _catalogDto(
      id: 'deleted',
      title: 'Deleted',
      thumbnailUrl: _deletedThumbnailUrl,
      previewUrl: _deletedPreviewUrl,
    ),
    _catalogDto(
      id: 'changed',
      title: 'Changed old',
      thumbnailUrl: _oldChangedThumbnailUrl,
      previewUrl: _oldChangedPreviewUrl,
    ),
    _catalogDto(
      id: 'shared-keeper',
      title: 'Shared keeper',
      thumbnailUrl: _sharedThumbnailUrl,
      previewUrl: _sharedPreviewUrl,
    ),
    _catalogDto(
      id: 'shared-deleted',
      title: 'Shared deleted',
      thumbnailUrl: _sharedThumbnailUrl,
      previewUrl: _sharedPreviewUrl,
    ),
  ], version: 1);
}

class _CatalogSyncBackend implements HttpClientAdapter {
  final List<String> requestPaths = [];
  final List<Map<String, Object?>> catalogQueries = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requestPaths.add(options.path);

    switch (options.path) {
      case '/api/templates/catalog-version':
        return _jsonResponse({'version': 7});
      case '/api/templates':
        final query = Map<String, Object?>.from(options.queryParameters);
        catalogQueries.add(query);
        return _catalogPageResponse(
          page: (query['page'] as num?)?.toInt() ?? 1,
        );
      case '/api/templates/feed':
        fail('Catalog resync must not use /api/templates/feed.');
      default:
        fail('Unexpected request path: ${options.path}');
    }
  }

  @override
  void close({bool force = false}) {}

  ResponseBody _catalogPageResponse({required int page}) {
    final items = switch (page) {
      1 => [
        _catalogItem(
          id: 'catalog-new',
          title: 'Catalog New',
          version: 7,
          updatedAtUtc: '2026-06-15T12:00:00Z',
        ),
      ],
      2 => [
        _catalogItem(
          id: 'catalog-old',
          title: 'Catalog Old',
          version: 6,
          updatedAtUtc: '2026-06-14T12:00:00Z',
        ),
      ],
      _ => const <Map<String, Object?>>[],
    };

    return _jsonResponse({
      'items': items,
      'page': page,
      'pageSize': 100,
      'hasMore': page == 1,
      'totalCount': 2,
      'generatedAtUtc': '2026-06-15T12:00:01Z',
    });
  }
}

class _CategoriesBackend implements HttpClientAdapter {
  _CategoriesBackend({
    this.remoteCategories = const <String>[],
    this.failCategories = false,
  });

  final List<String> remoteCategories;
  final bool failCategories;
  final List<String> requestPaths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requestPaths.add(options.path);

    switch (options.path) {
      case '/api/templates/categories':
        if (failCategories) {
          return _jsonResponse({
            'message': 'templates.categories_unavailable',
          }, 500);
        }

        return _jsonResponse([
          for (final category in remoteCategories) {'name': category},
        ]);
      default:
        fail('Unexpected request path: ${options.path}');
    }
  }

  @override
  void close({bool force = false}) {}
}

class _CatalogDeltaBackend implements HttpClientAdapter {
  int catalogVersion = 7;
  int changesRequestCount = 0;
  final Map<String, int> detailRequestsById = <String, int>{};
  final Map<String, String> detailTitlesById = <String, String>{
    'catalog-new': 'Old detail',
  };

  int detailRequestCount(String templateId) =>
      detailRequestsById[templateId] ?? 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    switch (options.path) {
      case '/api/templates/catalog-version':
        return _jsonResponse({'version': catalogVersion});
      case '/api/templates':
        return _jsonResponse({
          'items': [
            _catalogItem(
              id: 'catalog-new',
              title: 'Catalog New',
              version: 7,
              updatedAtUtc: '2026-06-15T12:00:00Z',
            ),
          ],
          'page': 1,
          'pageSize': 100,
          'hasMore': false,
          'totalCount': 1,
          'generatedAtUtc': '2026-06-15T12:00:01Z',
        });
      case '/api/templates/changes':
        changesRequestCount++;
        return _jsonResponse({
          'fromVersion':
              (options.queryParameters['sinceVersion'] as num?)?.toInt() ?? 0,
          'toVersion': catalogVersion,
          'upserts': [
            _catalogItem(
              id: 'catalog-new',
              title: 'Catalog New Updated',
              version: catalogVersion,
              updatedAtUtc: '2026-06-15T13:00:00Z',
            ),
          ],
          'deletedIds': const <String>[],
          'needsFullResync': false,
        });
      default:
        const prefix = '/api/templates/';
        if (!options.path.startsWith(prefix)) {
          fail('Unexpected request path: ${options.path}');
        }

        final templateId = options.path.substring(prefix.length);
        detailRequestsById[templateId] = detailRequestCount(templateId) + 1;
        return _jsonResponse(
          _templateDetail(
            id: templateId,
            title: detailTitlesById[templateId] ?? 'Detail $templateId',
          ),
        );
    }
  }

  @override
  void close({bool force = false}) {}
}

class _CatalogMediaCleanupBackend implements HttpClientAdapter {
  _CatalogMediaCleanupBackend({required this.needsFullResync});

  final bool needsFullResync;
  final List<String> requestPaths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requestPaths.add(options.path);

    switch (options.path) {
      case '/api/templates/catalog-version':
        return _jsonResponse({'version': 2});
      case '/api/templates/changes':
        return _jsonResponse({
          'fromVersion': 1,
          'toVersion': 2,
          'upserts': needsFullResync
              ? const <Map<String, Object?>>[]
              : [
                  _catalogItem(
                    id: 'changed',
                    title: 'Changed new',
                    version: 2,
                    updatedAtUtc: '2026-06-15T13:00:00Z',
                    thumbnailUrl: _newChangedThumbnailUrl,
                    previewUrl: _newChangedPreviewUrl,
                  ),
                ],
          'deletedIds': needsFullResync
              ? const <String>[]
              : const ['deleted', 'shared-deleted'],
          'needsFullResync': needsFullResync,
        });
      case '/api/templates':
        if (!needsFullResync) {
          fail('Delta sync must not use full catalog endpoint.');
        }

        return _jsonResponse({
          'items': [
            _catalogItem(
              id: 'changed',
              title: 'Changed new',
              version: 2,
              updatedAtUtc: '2026-06-15T13:00:00Z',
              thumbnailUrl: _newChangedThumbnailUrl,
              previewUrl: _newChangedPreviewUrl,
            ),
            _catalogItem(
              id: 'shared-keeper',
              title: 'Shared keeper',
              version: 2,
              updatedAtUtc: '2026-06-15T13:00:00Z',
              thumbnailUrl: _sharedThumbnailUrl,
              previewUrl: _sharedPreviewUrl,
            ),
          ],
          'page': 1,
          'pageSize': 100,
          'hasMore': false,
          'totalCount': 2,
          'generatedAtUtc': '2026-06-15T13:00:01Z',
        });
      default:
        fail('Unexpected request path: ${options.path}');
    }
  }

  @override
  void close({bool force = false}) {}
}

class _InvalidFullResyncPagingBackend implements HttpClientAdapter {
  final List<int> catalogPagesRequested = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    switch (options.path) {
      case '/api/templates/catalog-version':
        return _jsonResponse({'version': 2});
      case '/api/templates/changes':
        return _jsonResponse({
          'fromVersion': 1,
          'toVersion': 2,
          'upserts': const <Map<String, Object?>>[],
          'deletedIds': const <String>[],
          'needsFullResync': true,
        });
      case '/api/templates':
        final requestedPage =
            (options.queryParameters['page'] as num?)?.toInt() ?? 1;
        catalogPagesRequested.add(requestedPage);
        return _jsonResponse({
          'items': [
            _catalogItem(
              id: 'remote-page-$requestedPage',
              title: 'Remote page $requestedPage',
              version: 2,
              updatedAtUtc: '2026-06-15T13:00:00Z',
            ),
          ],
          'page': 1,
          'pageSize': 100,
          'hasMore': true,
          'totalCount': 2,
          'generatedAtUtc': '2026-06-15T13:00:01Z',
        });
      default:
        fail('Unexpected request path: ${options.path}');
    }
  }

  @override
  void close({bool force = false}) {}
}

class _ExcessiveFullResyncPagingBackend implements HttpClientAdapter {
  final List<int> catalogPagesRequested = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    switch (options.path) {
      case '/api/templates/catalog-version':
        return _jsonResponse({'version': 2});
      case '/api/templates/changes':
        return _jsonResponse({
          'fromVersion': 1,
          'toVersion': 2,
          'upserts': const <Map<String, Object?>>[],
          'deletedIds': const <String>[],
          'needsFullResync': true,
        });
      case '/api/templates':
        final requestedPage =
            (options.queryParameters['page'] as num?)?.toInt() ?? 1;
        catalogPagesRequested.add(requestedPage);
        return _jsonResponse({
          'items': [
            _catalogItem(
              id: 'remote-page-$requestedPage',
              title: 'Remote page $requestedPage',
              version: 2,
              updatedAtUtc: '2026-06-15T13:00:00Z',
            ),
          ],
          'page': requestedPage,
          'pageSize': 100,
          'hasMore': true,
          'totalCount': 1000,
          'generatedAtUtc': '2026-06-15T13:00:01Z',
        });
      default:
        fail('Unexpected request path: ${options.path}');
    }
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Object? body, [int statusCode = 200]) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _TemplateDetailBackend implements HttpClientAdapter {
  _TemplateDetailBackend({this.randomTemplateId});

  final String? randomTemplateId;
  final Map<String, int> detailRequestsById = <String, int>{};
  int randomRequestCount = 0;

  int get totalDetailRequestCount =>
      detailRequestsById.values.fold(0, (total, count) => total + count);

  int detailRequestCount(String templateId) =>
      detailRequestsById[templateId] ?? 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    if (options.path == '/api/templates/random') {
      randomRequestCount++;
      final templateId = randomTemplateId ?? 'template-random';
      return _jsonResponse({
        'template': _templateDetail(
          id: templateId,
          title: 'Random $templateId',
          type: 'Video',
        ),
      });
    }

    const prefix = '/api/templates/';
    if (!options.path.startsWith(prefix)) {
      fail('Unexpected request path: ${options.path}');
    }

    final templateId = options.path.substring(prefix.length);
    detailRequestsById[templateId] = detailRequestCount(templateId) + 1;
    return _jsonResponse(
      _templateDetail(id: templateId, title: 'Detail $templateId'),
    );
  }

  @override
  void close({bool force = false}) {}
}

class _DelayedDetailCatalogBackend implements HttpClientAdapter {
  final Completer<void> firstDetailStarted = Completer<void>();
  final Completer<void> _releaseFirstDetail = Completer<void>();
  final Map<String, int> detailRequestsById = <String, int>{};

  int detailRequestCount(String templateId) =>
      detailRequestsById[templateId] ?? 0;

  void releaseFirstDetail() {
    if (!_releaseFirstDetail.isCompleted) {
      _releaseFirstDetail.complete();
    }
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    if (options.path == '/api/templates') {
      return _jsonResponse({
        'items': const <Map<String, Object?>>[],
        'page': 1,
        'pageSize': 100,
        'hasMore': false,
        'totalCount': 0,
        'generatedAtUtc': '2026-06-15T12:00:01Z',
      });
    }

    const prefix = '/api/templates/';
    if (!options.path.startsWith(prefix)) {
      fail('Unexpected request path: ${options.path}');
    }

    final templateId = options.path.substring(prefix.length);
    final requestCount = detailRequestCount(templateId) + 1;
    detailRequestsById[templateId] = requestCount;
    if (requestCount == 1) {
      firstDetailStarted.complete();
      await _releaseFirstDetail.future;
    }

    return _jsonResponse(
      _templateDetail(id: templateId, title: 'Late Detail $requestCount'),
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _catalogItem({
  required String id,
  required String title,
  required int version,
  required String updatedAtUtc,
  String category = 'Portrait',
  String? thumbnailUrl,
  String? previewUrl,
  String? shortDescription,
  List<String>? petPhotoRequirements,
}) {
  return {
    'id': id,
    'type': 'Image',
    'title': title,
    'shortDescription': shortDescription,
    'category': category,
    'thumbnailUrl': thumbnailUrl ?? 'https://cdn.petmagic.test/$id-thumb.jpg',
    'previewUrl': previewUrl ?? 'https://cdn.petmagic.test/$id-thumb.jpg',
    'priceTokens': 10,
    'isPremium': false,
    'tags': ['catalog'],
    'petPhotoRequirements': petPhotoRequirements,
    'version': version,
    'updatedAtUtc': updatedAtUtc,
  };
}

TemplateItemDto _catalogDto({
  required String id,
  required String title,
  required String thumbnailUrl,
  required String previewUrl,
  String category = 'Portrait',
  String? shortDescription,
  List<String>? petPhotoRequirements,
  int version = 1,
}) {
  return TemplateItemDto.fromJson(
    _catalogItem(
      id: id,
      title: title,
      version: version,
      updatedAtUtc: '2026-06-15T12:00:00Z',
      category: category,
      thumbnailUrl: thumbnailUrl,
      previewUrl: previewUrl,
      shortDescription: shortDescription,
      petPhotoRequirements: petPhotoRequirements,
    ),
  );
}

Map<String, Object?> _templateDetail({
  required String id,
  required String title,
  String type = 'Image',
}) {
  final isVideo = type.toLowerCase() == 'video';
  final extension = isVideo ? 'mp4' : 'jpg';
  final contentType = isVideo ? 'video/mp4' : 'image/jpeg';
  return {
    'templateId': id,
    'templateType': type,
    'title': title,
    'shortDescription': 'Cached detail payload',
    'category': 'Portrait',
    'tags': ['detail'],
    'isPremium': false,
    'tokenCost': 10,
    'thumbnailUrl': 'https://cdn.petmagic.test/$id-thumb.jpg',
    'previewAsset': {
      'url': 'https://cdn.petmagic.test/$id-preview.$extension',
      'fileName': '$id-preview.$extension',
      'contentType': contentType,
      if (isVideo) 'durationSeconds': 4.5,
    },
    'petPhotoRequirements': ['Clear face'],
    'supportsGenerateSimilar': true,
  };
}
