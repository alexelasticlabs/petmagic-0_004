part of 'templates_repository.dart';

mixin _TemplatesCatalogRepositoryMixin on _TemplatesRepositoryBase {
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
      if (pagesFetched >= _TemplatesRepositoryBase._fullResyncMaxPages) {
        throw _buildCatalogSyncFailure(
          reason: 'page_limit_exceeded',
          requestedPage: page,
          targetVersion: targetVersion,
        );
      }

      final response = await _remoteDataSource.fetchCatalogPage(
        page: page,
        pageSize: _TemplatesRepositoryBase._fullResyncPageSize,
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

    final incomingMediaUrls = allItems
        .expand(_TemplatesRepositoryBase._templateMediaUrls)
        .toSet();
    final staleMediaUrls = previousItems
        .expand(_TemplatesRepositoryBase._templateMediaUrls)
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
    final error = AppException(_TemplatesRepositoryBase._catalogSyncFailedCode);
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
        'pageSize': _TemplatesRepositoryBase._fullResyncPageSize,
        'maxPages': _TemplatesRepositoryBase._fullResyncMaxPages,
      },
    );
    return error;
  }
}
