import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
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

typedef TemplateMediaCleanup = Future<void> Function(String url);

abstract interface class TemplatesRepository {
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query);

  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query);

  void cancelPendingFeedRequest();

  void cancelPendingRandomTemplateRequest();

  void cancelPendingMetadataRequests();

  Future<TemplateItem> fetchTemplate(
    String templateId, {
    bool forceRefresh = false,
  });

  Future<TemplateItem?> fetchRandomTemplate({
    required TemplateRandomMode mode,
    required String? category,
    required bool includePremium,
    TemplateRandomAccess access = TemplateRandomAccess.available,
  });

  Future<List<TemplateItem>> readSyncedCatalogItems();

  Future<TemplateOfTheDayItem?> fetchTemplateOfTheDay();

  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? source,
    String? generationId,
    Map<String, Object?>? metadata,
  });

  Future<List<String>> fetchCategories();

  Future<int> readLocalCatalogVersion();

  Future<int> fetchCatalogVersion();

  Future<TemplatesCatalogChanges> fetchCatalogChanges(int sinceVersion);

  Future<int> syncCatalog({int? knownRemoteVersion});
}

class DefaultTemplatesRepository implements TemplatesRepository {
  DefaultTemplatesRepository({
    required TemplatesRemoteDataSource remoteDataSource,
    required TemplatesCacheDataSource cacheDataSource,
    TemplateMediaCleanup? mediaCleanup,
  }) : _remoteDataSource = remoteDataSource,
       _cacheDataSource = cacheDataSource,
       _mediaCleanup = mediaCleanup ?? _removeTemplateMediaFromCache;

  final TemplatesRemoteDataSource _remoteDataSource;
  final TemplatesCacheDataSource _cacheDataSource;
  final TemplateMediaCleanup _mediaCleanup;
  final Map<String, _CachedTemplateDetail> _templateDetailsById =
      <String, _CachedTemplateDetail>{};
  final Map<String, Future<TemplateItem>> _templateDetailFetchesById =
      <String, Future<TemplateItem>>{};
  int _templateDetailCacheGeneration = 0;

  static const int _fullResyncPageSize = 100;
  static const int _fullResyncMaxPages = 100;
  static const String _catalogSyncFailedCode = 'templates.catalog_sync_failed';
  static const int _templateDetailCacheLimit = 64;
  static const Duration _templateDetailCacheTtl = Duration(minutes: 10);

  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async {
    final dto = await _cacheDataSource.readFirstPage(query.copyWith(page: 1));
    return dto?.toDomain();
  }

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async {
    final dto = await _remoteDataSource.fetchFeed(query);
    final page = dto.toDomain();
    return TemplatesFeedPage(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      page: query.page <= 0 ? 1 : query.page,
    );
  }

  @override
  void cancelPendingFeedRequest() {
    _remoteDataSource.cancelPendingFeedRequest();
  }

  @override
  void cancelPendingRandomTemplateRequest() {
    _remoteDataSource.cancelPendingRandomTemplateRequest();
  }

  @override
  void cancelPendingMetadataRequests() {
    _remoteDataSource.cancelPendingMetadataRequests();
  }

  @override
  Future<TemplateItem> fetchTemplate(
    String templateId, {
    bool forceRefresh = false,
  }) async {
    final normalizedId = templateId.trim();
    final cacheKey = normalizedId.isEmpty ? templateId : normalizedId;
    final now = DateTime.now().toUtc();
    final cached = _templateDetailsById[cacheKey];
    if (!forceRefresh && cached != null && cached.expiresAtUtc.isAfter(now)) {
      _rememberTemplateDetail(cacheKey, cached.template, now);
      return cached.template;
    }

    if (cached != null) {
      _templateDetailsById.remove(cacheKey);
    }

    final inFlight = _templateDetailFetchesById[cacheKey];
    if (!forceRefresh && inFlight != null) {
      return inFlight;
    }

    final cacheGeneration = _templateDetailCacheGeneration;
    late final Future<TemplateItem> fetch;
    fetch = _remoteDataSource
        .fetchTemplate(cacheKey)
        .then((dto) {
          final template = dto.toDomain();
          if (cacheGeneration == _templateDetailCacheGeneration) {
            _rememberTemplateDetail(cacheKey, template, DateTime.now().toUtc());
          }
          return template;
        })
        .whenComplete(() {
          if (identical(_templateDetailFetchesById[cacheKey], fetch)) {
            _templateDetailFetchesById.remove(cacheKey);
          }
        });
    _templateDetailFetchesById[cacheKey] = fetch;
    return fetch;
  }

  @override
  Future<TemplateItem?> fetchRandomTemplate({
    required TemplateRandomMode mode,
    required String? category,
    required bool includePremium,
    TemplateRandomAccess access = TemplateRandomAccess.available,
  }) async {
    final cacheGeneration = _templateDetailCacheGeneration;
    final dto = await _remoteDataSource.fetchRandomTemplate(
      mode: mode,
      category: category,
      includePremium: includePremium,
      access: access,
    );
    final template = dto.toDomain();
    if (template != null && cacheGeneration == _templateDetailCacheGeneration) {
      _rememberTemplateDetail(
        template.templateId,
        template,
        DateTime.now().toUtc(),
      );
    }
    return template;
  }

  @override
  Future<List<TemplateItem>> readSyncedCatalogItems() async {
    await syncCatalog();
    final items = await _cacheDataSource.readCatalogItems();
    return items.map((item) => item.toDomain()).toList(growable: false);
  }

  @override
  Future<TemplateOfTheDayItem?> fetchTemplateOfTheDay() async {
    final dto = await _remoteDataSource.fetchTemplateOfTheDay();
    return dto.toDomain();
  }

  @override
  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? source,
    String? generationId,
    Map<String, Object?>? metadata,
  }) {
    return _remoteDataSource.recordAnalyticsEvent(
      templateId: templateId,
      eventType: eventType,
      source: source,
      generationId: generationId,
      metadata: metadata,
    );
  }

  @override
  Future<int> readLocalCatalogVersion() =>
      _cacheDataSource.readCatalogVersion();

  @override
  Future<List<String>> fetchCategories() async {
    try {
      return await _remoteDataSource.fetchCategories();
    } on RequestCancelledException {
      rethrow;
    } on AppException {
      final localCategories = await _cacheDataSource.readCategories();
      if (localCategories.isNotEmpty) {
        return localCategories;
      }
      rethrow;
    }
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

    // Self-heal scenarios when metadata version exists but the local catalog
    // payload is missing/corrupted (for example after interrupted writes or
    // stale cache drift).
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

    final staleMediaUrls = await _cacheDataSource.applyCatalogChanges(
      changesDto,
    );
    _forgetTemplateDetails([
      ...changesDto.deletedIds,
      ...changesDto.upserts.map((item) => item.templateId),
    ]);
    await _cleanupDeletedMediaUrls(staleMediaUrls);
    return _cacheDataSource.readCatalogVersion();
  }

  Future<int> _performFullResync({int? knownRemoteVersion}) async {
    final targetVersion = knownRemoteVersion ?? await fetchCatalogVersion();
    final previousItems = await _cacheDataSource.readCatalogItems();
    final allItems = <TemplateItemDto>[];
    var page = 1;
    var pagesFetched = 0;

    while (true) {
      if (pagesFetched >= _fullResyncMaxPages) {
        throw _buildCatalogSyncFailure(
          reason: 'page_limit_exceeded',
          requestedPage: page,
          targetVersion: targetVersion,
        );
      }

      final response = await _remoteDataSource.fetchCatalogPage(
        page: page,
        pageSize: _fullResyncPageSize,
      );
      pagesFetched++;
      if (response.page != page) {
        throw _buildCatalogSyncFailure(
          reason: 'page_mismatch',
          requestedPage: page,
          receivedPage: response.page,
          targetVersion: targetVersion,
        );
      }

      allItems.addAll(response.items);
      if (!response.hasMore || response.items.isEmpty) {
        break;
      }

      page++;
    }

    final incomingMediaUrls = allItems.expand(_templateMediaUrls).toSet();
    final staleMediaUrls = previousItems
        .expand(_templateMediaUrls)
        .where((url) => !incomingMediaUrls.contains(url))
        .toSet()
        .toList(growable: false);

    await _cacheDataSource.replaceCatalog(allItems, version: targetVersion);
    _clearTemplateDetails(forceGeneration: true);
    await _cleanupDeletedMediaUrls(staleMediaUrls);
    return targetVersion;
  }

  AppException _buildCatalogSyncFailure({
    required String reason,
    required int requestedPage,
    required int targetVersion,
    int? receivedPage,
  }) {
    final error = AppException(_catalogSyncFailedCode);
    AppLogger.warn(
      feature: 'Templates.Repository',
      operation: 'full_catalog_resync',
      message:
          'Template catalog full resync aborted due to invalid paging contract.',
      error: error,
      context: {
        'reason': reason,
        'requestedPage': requestedPage,
        'receivedPage': receivedPage,
        'targetVersion': targetVersion,
        'pageSize': _fullResyncPageSize,
        'maxPages': _fullResyncMaxPages,
      },
    );
    return error;
  }

  void _rememberTemplateDetail(
    String templateId,
    TemplateItem template,
    DateTime nowUtc,
  ) {
    final normalizedId = templateId.trim();
    final cacheKey = normalizedId.isEmpty ? templateId : normalizedId;
    _templateDetailsById.remove(cacheKey);
    _templateDetailsById[cacheKey] = _CachedTemplateDetail(
      template,
      nowUtc.add(_templateDetailCacheTtl),
    );

    while (_templateDetailsById.length > _templateDetailCacheLimit) {
      _templateDetailsById.remove(_templateDetailsById.keys.first);
    }
  }

  void _forgetTemplateDetails(Iterable<String> templateIds) {
    var changedAnyTemplate = false;
    for (final templateId in templateIds) {
      final normalizedId = templateId.trim();
      final cacheKey = normalizedId.isEmpty ? templateId : normalizedId;
      changedAnyTemplate = true;
      _templateDetailsById.remove(cacheKey);
      _templateDetailFetchesById.remove(cacheKey);
    }

    if (changedAnyTemplate) {
      _templateDetailCacheGeneration++;
    }
  }

  void _clearTemplateDetails({bool forceGeneration = false}) {
    final hadCachedDetails =
        _templateDetailsById.isNotEmpty ||
        _templateDetailFetchesById.isNotEmpty;
    _templateDetailsById.clear();
    _templateDetailFetchesById.clear();
    if (forceGeneration || hadCachedDetails) {
      _templateDetailCacheGeneration++;
    }
  }

  Future<void> _cleanupDeletedMediaUrls(List<String> urls) async {
    for (final url in urls.toSet()) {
      try {
        await _mediaCleanup(url);
      } catch (error, stackTrace) {
        AppLogger.warn(
          feature: 'Templates.Repository',
          operation: 'cleanup_deleted_media_url',
          message: 'Deleted template media cleanup failed',
          context: {'media_kind': _mediaKindLabel(url)},
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  static Future<void> _removeTemplateMediaFromCache(String url) async {
    try {
      await TemplateMediaCache.removeThumbnailFile(url);
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.Repository',
        operation: 'remove_thumbnail_from_cache',
        message: 'Template thumbnail cache cleanup failed',
        context: {'media_kind': _mediaKindLabel(url)},
        error: error,
        stackTrace: stackTrace,
      );
    }

    try {
      await TemplateMediaCache.removePreviewFile(url);
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.Repository',
        operation: 'remove_preview_from_cache',
        message: 'Template preview cache cleanup failed',
        context: {'media_kind': _mediaKindLabel(url)},
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Iterable<String> _templateMediaUrls(TemplateItemDto item) sync* {
    final thumbnailUrl = item.thumbnailUrl?.trim();
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      yield thumbnailUrl;
    }

    final previewUrl = item.previewAsset?.url.trim();
    if (previewUrl != null && previewUrl.isNotEmpty) {
      yield previewUrl;
    }
  }

  static String _mediaKindLabel(String url) {
    final normalized = url.trim().toLowerCase();
    if (normalized.endsWith('.mp4') || normalized.endsWith('.mov')) {
      return 'video';
    }

    if (normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.endsWith('.png') ||
        normalized.endsWith('.webp') ||
        normalized.endsWith('.gif')) {
      return 'image';
    }

    return 'unknown';
  }
}

class _CachedTemplateDetail {
  const _CachedTemplateDetail(this.template, this.expiresAtUtc);

  final TemplateItem template;
  final DateTime expiresAtUtc;
}
