import 'dart:async';

export 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart'
    show TemplatesRepository, templatesRepositoryProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/features/templates/data/templates_cache_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/templates_dto.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';

part 'templates_catalog_repository_mixin.part.dart';

final defaultTemplatesRepositoryProvider = Provider<TemplatesRepository>((ref) {
  return DefaultTemplatesRepository(
    remoteDataSource: ref.watch(templatesRemoteDataSourceProvider),
    cacheDataSource: ref.watch(templatesCacheDataSourceProvider),
  );
});

typedef TemplateMediaCleanup = Future<void> Function(String url);

abstract class _TemplatesRepositoryBase implements TemplatesRepository {
  _TemplatesRepositoryBase({
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
    final thumbnailUrl = persistentSafeGenerationMediaUrl(item.thumbnailUrl);
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      yield thumbnailUrl;
    }

    final previewUrl = persistentSafeGenerationMediaUrl(item.previewAsset?.url);
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

class DefaultTemplatesRepository extends _TemplatesRepositoryBase
    with _TemplatesCatalogRepositoryMixin {
  DefaultTemplatesRepository({
    required super.remoteDataSource,
    required super.cacheDataSource,
    super.mediaCleanup,
  });
  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async {
    final dto = await _cacheDataSource.readFirstPage(query.copyWith(page: 1));
    return dto?.toDomain();
  }

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async {
    final dto = await _remoteDataSource.fetchFeed(query);
    if (_isCanonicalFirstFeedPage(query)) {
      unawaited(_persistFirstPageBestEffort(query, dto));
    }
    final page = dto.toDomain();
    return TemplatesFeedPage(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      page: query.page <= 0 ? 1 : query.page,
    );
  }

  bool _isCanonicalFirstFeedPage(TemplatesQuery query) {
    return query.page == 1 &&
        query.type == null &&
        (query.category == null || query.category!.trim().isEmpty) &&
        (query.search == null || query.search!.trim().isEmpty) &&
        (query.cursor == null || query.cursor!.trim().isEmpty);
  }

  Future<void> _persistFirstPageBestEffort(
    TemplatesQuery query,
    TemplatesFeedDto page,
  ) async {
    try {
      await _cacheDataSource.writeFirstPage(query, page);
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.Repository',
        operation: 'persist_first_feed_page',
        message: 'Template first feed page persistence failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
    String? analyticsSource,
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
        .fetchTemplate(cacheKey, analyticsSource: analyticsSource)
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
}

class _CachedTemplateDetail {
  const _CachedTemplateDetail(this.template, this.expiresAtUtc);

  final TemplateItem template;
  final DateTime expiresAtUtc;
}
