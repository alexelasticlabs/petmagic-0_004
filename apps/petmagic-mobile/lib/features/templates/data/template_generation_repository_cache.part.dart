part of 'template_generation_repository.dart';

Future<List<TemplateGenerationResult>> _fetchGenerations(
  TemplateGenerationRepository repository, {
  String? status,
  int? skip,
  int? take,
  RequestCancellation? cancelToken,
}) async {
  final page = await _fetchGenerationPage(
    repository,
    status: status,
    cursor: null,
    skip: skip,
    take: take,
    cancelToken: cancelToken,
  );
  return page.items;
}

Future<TemplateGenerationGalleryPage> _fetchGenerationPage(
  TemplateGenerationRepository repository, {
  String? status,
  String? cursor,
  int? skip,
  int? take,
  RequestCancellation? cancelToken,
}) async {
  final queryParameters = <String, Object?>{};
  if (status != null && status.isNotEmpty) {
    queryParameters['status'] = status;
  }
  if (cursor != null && cursor.isNotEmpty) {
    queryParameters['cursor'] = cursor;
  }
  if (skip != null && cursor == null) {
    queryParameters['skip'] = skip < 0 ? 0 : skip;
  }
  if (take != null) {
    queryParameters['take'] = take.clamp(1, 100);
  }

  final response = await repository._authorizedRequest<dynamic>(
    (session) => repository._dio.get<dynamic>(
      '/api/templates/generations',
      queryParameters: queryParameters,
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken.toDioCancelToken(),
    ),
  );

  final rawData = response.data;
  if (rawData is List<dynamic>) {
    final itemsJson = rawData
        .whereType<Map>()
        .map(Map<String, Object?>.from)
        .toList(growable: false);

    await repository._writeCachedGenerations(status: status, items: itemsJson);

    return TemplateGenerationGalleryPage(
      items: itemsJson
          .map(
            (item) => TemplateGenerationDto.fromJson(
              Map<String, dynamic>.from(item),
            ).toDomain(),
          )
          .toList(growable: false),
      hasMore: false,
      unreadCount: 0,
      appliedFilter: status == null || status.isEmpty ? 'all' : status,
    );
  }

  final responseJson = rawData is Map
      ? Map<String, dynamic>.from(rawData)
      : <String, dynamic>{};
  final itemsJson = (responseJson['items'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map(Map<String, Object?>.from)
      .toList(growable: false);

  if (cursor == null || cursor.isEmpty) {
    await repository._writeCachedGenerations(status: status, items: itemsJson);
    await _writeCachedUnreadGenerationCountImpl(
      repository,
      (responseJson['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  return TemplateGenerationGalleryPageDto.fromJson(responseJson).toDomain();
}

Future<int> _fetchUnreadGenerationCount(
  TemplateGenerationRepository repository, {
  RequestCancellation? cancelToken,
}) async {
  final response = await repository._authorizedRequest<Map<String, dynamic>>(
    (session) => repository._dio.get<Map<String, dynamic>>(
      '/api/templates/generations/unread-count',
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken.toDioCancelToken(),
    ),
  );

  final count = (response.data?['count'] as num?)?.toInt() ?? 0;
  await _writeCachedUnreadGenerationCountImpl(repository, count);
  return count;
}

Future<void> _markGenerationRead(
  TemplateGenerationRepository repository,
  String generationId, {
  RequestCancellation? cancelToken,
}) async {
  final encodedGenerationId = repository._apiPathSegment(generationId);
  await repository._authorizedRequest<void>(
    (session) => repository._dio.post<void>(
      '/api/templates/generations/$encodedGenerationId/mark-read',
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken.toDioCancelToken(),
    ),
    retryTransientFailures: false,
  );

  await _markCachedGenerationReadImpl(repository, generationId);
}

Future<void> _upsertCachedGeneration(
  TemplateGenerationRepository repository,
  TemplateGenerationResult generation,
) async {
  final scope = await repository._readCacheScope();
  if (scope == null) {
    return;
  }

  for (final status in GenerationCacheReader.cacheStatuses) {
    try {
      final cacheStatus = GenerationCacheReader.statusFilter(status);
      final key = GenerationCacheReader.cacheKeyForScope(scope, cacheStatus);
      final legacyKey = GenerationCacheReader.legacyCacheKeyForScope(
        scope,
        cacheStatus,
      );
      final raw = await repository._cacheStorage.readString(
        dataKey: key,
        legacyDataKey: legacyKey,
      );
      if (raw == null || raw.isEmpty) {
        continue;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        continue;
      }

      final updated = <Map<String, Object?>>[];
      for (final entry in decoded.whereType<Map>()) {
        final cachedGeneration = Map<String, Object?>.from(entry);
        if (cachedGeneration['generationId'] != generation.generationId) {
          updated.add(cachedGeneration);
        }
      }

      if (repository._matchesCachedGenerationStatus(generation, cacheStatus)) {
        updated.insert(0, repository._generationToCachedJson(generation));
      }

      updated.sort((left, right) {
        final leftUpdated = DateTime.tryParse(
          left['updatedAtUtc'] as String? ?? '',
        );
        final rightUpdated = DateTime.tryParse(
          right['updatedAtUtc'] as String? ?? '',
        );
        if (leftUpdated == null && rightUpdated == null) {
          return 0;
        }
        if (leftUpdated == null) {
          return 1;
        }
        if (rightUpdated == null) {
          return -1;
        }
        return rightUpdated.compareTo(leftUpdated);
      });

      final bounded = updated
          .take(50)
          .map(GenerationCacheCodec.sanitizeMap)
          .toList(growable: false);
      await repository._preferences.setString(key, jsonEncode(bounded));
      await repository._cacheStorage.touch(key);
      await repository._cacheStorage.clear(legacyKey);
    } on Object {
      // Persistent cache updates are best-effort; realtime remains in memory.
    }
  }
}

Future<void> _writeCachedGenerationsImpl(
  TemplateGenerationRepository repository, {
  required String? status,
  required List<Map<String, Object?>> items,
}) async {
  try {
    final scope = await repository._readCacheScope();
    if (scope == null) {
      return;
    }

    final cacheKey = GenerationCacheReader.cacheKeyForScope(scope, status);
    final legacyCacheKey = GenerationCacheReader.legacyCacheKeyForScope(
      scope,
      status,
    );
    final sanitizedItems = items
        .map(GenerationCacheCodec.sanitizeMap)
        .toList(growable: false);
    await repository._preferences.setString(
      cacheKey,
      jsonEncode(sanitizedItems),
    );
    await repository._cacheStorage.touch(cacheKey);
    await repository._cacheStorage.clear(legacyCacheKey);
  } on Object {
    // Ignore local cache write errors to keep network flow stable.
  }
}

Future<void> _writeCachedUnreadGenerationCountImpl(
  TemplateGenerationRepository repository,
  int count,
) async {
  try {
    final scope = await repository._readCacheScope();
    if (scope == null) {
      return;
    }

    final unreadCountCacheKey = GenerationCacheReader.scopedDataKey(
      TemplateGenerationRepository._unreadCountCacheKey,
      scope,
    );
    final legacyUnreadCountCacheKey = GenerationCacheReader.legacyScopedDataKey(
      TemplateGenerationRepository._unreadCountCacheKey,
      scope,
    );
    await repository._preferences.setInt(unreadCountCacheKey, count);
    await repository._cacheStorage.touch(unreadCountCacheKey);
    await repository._cacheStorage.clear(legacyUnreadCountCacheKey);
  } on Object {
    // Ignore local cache write errors to keep network flow stable.
  }
}

Future<void> _markCachedGenerationReadImpl(
  TemplateGenerationRepository repository,
  String generationId,
) async {
  final scope = await repository._readCacheScope();
  if (scope == null) {
    return;
  }

  for (final status in GenerationCacheReader.cacheStatuses) {
    try {
      final key = GenerationCacheReader.cacheKeyForScope(
        scope,
        GenerationCacheReader.statusFilter(status),
      );
      final legacyKey = GenerationCacheReader.legacyCacheKeyForScope(
        scope,
        GenerationCacheReader.statusFilter(status),
      );
      final raw = await repository._cacheStorage.readString(
        dataKey: key,
        legacyDataKey: legacyKey,
      );
      if (raw == null || raw.isEmpty) {
        continue;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        continue;
      }

      var changed = false;
      final updated = decoded
          .map((entry) {
            if (entry is! Map) {
              return entry;
            }

            final generation = Map<String, Object?>.from(entry);
            if (generation['generationId'] != generationId) {
              return generation;
            }

            if (generation['isUnread'] == false) {
              return generation;
            }

            changed = true;
            return GenerationCacheCodec.sanitizeMap({
              ...generation,
              'isUnread': false,
            });
          })
          .toList(growable: false);

      if (changed) {
        await repository._preferences.setString(key, jsonEncode(updated));
        await repository._cacheStorage.touch(key);
        await repository._cacheStorage.clear(legacyKey);
      }
    } on Object {
      // Keep mark-read cache mutation best-effort per bucket.
    }
  }

  final unread = await repository.readCachedUnreadGenerationCount();
  if (unread != null && unread > 0) {
    await _writeCachedUnreadGenerationCountImpl(repository, unread - 1);
  }
}

Future<void> _removeCachedGenerationImpl(
  TemplateGenerationRepository repository,
  String generationId,
) async {
  final scope = await repository._readCacheScope();
  if (scope == null) {
    return;
  }

  var removedUnread = false;

  for (final status in GenerationCacheReader.cacheStatuses) {
    try {
      final key = GenerationCacheReader.cacheKeyForScope(
        scope,
        GenerationCacheReader.statusFilter(status),
      );
      final legacyKey = GenerationCacheReader.legacyCacheKeyForScope(
        scope,
        GenerationCacheReader.statusFilter(status),
      );
      final raw = await repository._cacheStorage.readString(
        dataKey: key,
        legacyDataKey: legacyKey,
      );
      if (raw == null || raw.isEmpty) {
        continue;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        continue;
      }

      var changed = false;
      final updated = <Map<String, Object?>>[];
      for (final entry in decoded.whereType<Map>()) {
        final generation = Map<String, Object?>.from(entry);
        if (generation['generationId'] == generationId) {
          changed = true;
          if (generation['isUnread'] == true) {
            removedUnread = true;
          }
          continue;
        }
        updated.add(GenerationCacheCodec.sanitizeMap(generation));
      }

      if (changed) {
        await repository._preferences.setString(key, jsonEncode(updated));
        await repository._cacheStorage.touch(key);
        await repository._cacheStorage.clear(legacyKey);
      }
    } on Object {
      // Keep delete cache mutation best-effort per bucket.
    }
  }

  if (removedUnread) {
    final unread = await repository.readCachedUnreadGenerationCount();
    if (unread != null && unread > 0) {
      await _writeCachedUnreadGenerationCountImpl(repository, unread - 1);
    }
  }
}
