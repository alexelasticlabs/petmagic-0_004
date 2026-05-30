import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/features/templates/data/templates_cache_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/templates_dto.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

final templatesRepositoryProvider = Provider<TemplatesRepository>((ref) {
  return DefaultTemplatesRepository(
    remoteDataSource: ref.watch(templatesRemoteDataSourceProvider),
    cacheDataSource: ref.watch(templatesCacheDataSourceProvider),
  );
});

abstract interface class TemplatesRepository {
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query);

  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query);

  Future<List<String>> fetchCategories();

  Future<int> readLocalCatalogVersion();

  Future<int> fetchCatalogVersion();

  Future<TemplatesCatalogChanges> fetchCatalogChanges(int sinceVersion);

  Future<int> syncCatalog({int? knownRemoteVersion});
}

class DefaultTemplatesRepository implements TemplatesRepository {
  const DefaultTemplatesRepository({
    required TemplatesRemoteDataSource remoteDataSource,
    required TemplatesCacheDataSource cacheDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _cacheDataSource = cacheDataSource;

  final TemplatesRemoteDataSource _remoteDataSource;
  final TemplatesCacheDataSource _cacheDataSource;

  static const int _fullResyncPageSize = 100;

  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async {
    final dto = await _cacheDataSource.readFirstPage(query.copyWith(page: 1));
    return dto?.toDomain();
  }

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async {
    final dto = await _cacheDataSource.readPage(query);
    if (dto != null) {
      return dto.toDomain();
    }

    if (query.page > 1) {
      return TemplatesFeedPage(
        items: const [],
        hasMore: false,
        page: query.page,
      );
    }

    await syncCatalog();
    final refreshedDto = await _cacheDataSource.readPage(query);
    if (refreshedDto != null) {
      return refreshedDto.toDomain();
    }

    return const TemplatesFeedPage(items: [], hasMore: false, page: 1);
  }

  @override
  Future<int> readLocalCatalogVersion() =>
      _cacheDataSource.readCatalogVersion();

  @override
  Future<List<String>> fetchCategories() async {
    final localCategories = await _cacheDataSource.readCategories();
    if (localCategories.isNotEmpty) {
      return localCategories;
    }

    return _remoteDataSource.fetchCategories();
  }

  @override
  Future<int> fetchCatalogVersion() async {
    final dto = await _remoteDataSource.fetchCatalogVersion();
    return dto.version;
  }

  @override
  Future<TemplatesCatalogChanges> fetchCatalogChanges(int sinceVersion) async {
    final dto = await _remoteDataSource.fetchCatalogChanges(sinceVersion);
    return dto.toDomain();
  }

  @override
  Future<int> syncCatalog({int? knownRemoteVersion}) async {
    final localVersion = await _cacheDataSource.readCatalogVersion();
    final hasLocalCatalogItems =
        (await _cacheDataSource.readCatalogItems()).isNotEmpty;
    final remoteVersion = knownRemoteVersion ?? await fetchCatalogVersion();

    // Self-heal scenarios when metadata version exists but local catalog payload
    // is missing/corrupted (e.g. interrupted writes or legacy cache drift).
    if (!hasLocalCatalogItems) {
      return _performFullResync(knownRemoteVersion: remoteVersion);
    }

    if (remoteVersion <= localVersion) {
      return localVersion;
    }

    final changesDto = await _remoteDataSource.fetchCatalogChanges(
      localVersion,
    );
    if (changesDto.needsFullResync) {
      return _performFullResync(knownRemoteVersion: remoteVersion);
    }

    final deletedPreviewUrls = await _cacheDataSource.applyCatalogChanges(
      changesDto,
    );
    await _cleanupDeletedPreviewUrls(deletedPreviewUrls);
    return _cacheDataSource.readCatalogVersion();
  }

  Future<int> _performFullResync({int? knownRemoteVersion}) async {
    final targetVersion = knownRemoteVersion ?? await fetchCatalogVersion();
    final previousItems = await _cacheDataSource.readCatalogItems();
    final allItems = <TemplateItemDto>[];
    var page = 1;

    while (true) {
      final response = await _remoteDataSource.fetchFeed(
        TemplatesQuery(page: page, pageSize: _fullResyncPageSize),
      );
      allItems.addAll(response.items);
      if (!response.hasMore) {
        break;
      }
      page += 1;
    }

    final incomingIds = allItems.map((item) => item.templateId).toSet();
    final removedPreviewUrls = previousItems
        .where((item) => !incomingIds.contains(item.templateId))
        .map((item) => item.previewAsset?.url.trim())
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toList(growable: false);

    await _cacheDataSource.replaceCatalog(allItems, version: targetVersion);
    await _cleanupDeletedPreviewUrls(removedPreviewUrls);
    return targetVersion;
  }

  Future<void> _cleanupDeletedPreviewUrls(List<String> urls) async {
    for (final url in urls) {
      try {
        await TemplateMediaCache.removePreviewFile(url);
      } catch (_) {
        // Best-effort cleanup only.
      }
    }
  }
}
