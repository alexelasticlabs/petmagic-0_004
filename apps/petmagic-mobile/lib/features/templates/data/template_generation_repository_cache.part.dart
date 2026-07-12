part of 'template_generation_repository.dart';

Future<String?> _resolveGenerationCacheScope(
  TemplateGenerationRepository repository,
) async {
  final session = await repository._sessionStorage.read();
  final normalized = session?.user.userId.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
}

String _generationScopedDataKey(String baseKey, String scope) {
  return '$baseKey:${_generationCacheScopeFingerprint(scope)}';
}

String _generationLegacyScopedDataKey(String baseKey, String scope) {
  return '$baseKey:$scope';
}

String _generationCacheKeyForScope(String scope, String? status) {
  final normalized = (status == null || status.trim().isEmpty)
      ? TemplateGenerationRepository._cacheAllStatusKey
      : status.trim().toLowerCase();
  return '${TemplateGenerationRepository._generationsCachePrefix}'
      '${_generationCacheScopeFingerprint(scope)}:$normalized';
}

String _generationLegacyCacheKeyForScope(String scope, String? status) {
  final normalized = (status == null || status.trim().isEmpty)
      ? TemplateGenerationRepository._cacheAllStatusKey
      : status.trim().toLowerCase();
  return '${TemplateGenerationRepository._generationsCachePrefix}$scope:$normalized';
}

String _generationCacheScopeFingerprint(String scope) {
  final normalized = scope.trim().toLowerCase();
  return sha256.convert(utf8.encode(normalized)).toString();
}

Future<List<TemplateGenerationResult>?> _readCachedGenerations(
  TemplateGenerationRepository repository, {
  String? status,
}) async {
  try {
    final scope = await repository._readCacheScope();
    if (scope == null) {
      return null;
    }

    final cacheKey = _generationCacheKeyForScope(scope, status);
    final legacyCacheKey = _generationLegacyCacheKeyForScope(scope, status);
    if (await _isGenerationCacheKeyExpired(repository, cacheKey)) {
      await _clearGenerationCacheKey(repository, cacheKey);
      return null;
    }

    final raw = await _readGenerationCacheString(
      repository,
      dataKey: cacheKey,
      legacyDataKey: legacyCacheKey,
    );
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return null;
    }

    final sanitized = _sanitizePersistentGenerationCacheList(decoded);
    final sanitizedRaw = jsonEncode(sanitized);
    if (sanitizedRaw != raw) {
      await repository._preferences.setString(cacheKey, sanitizedRaw);
    }

    return sanitized
        .whereType<Map>()
        .map(
          (item) => TemplateGenerationDto.fromJson(
            _generationCacheItemWithScope(
              Map<String, dynamic>.from(item),
              scope,
            ),
          ).toDomain(),
        )
        .toList(growable: false);
  } on Object {
    return null;
  }
}

Future<TemplateGenerationResult?> _readCachedGeneration(
  TemplateGenerationRepository repository,
  String generationId,
) async {
  for (final status in TemplateGenerationRepository._cacheStatuses) {
    final items = await repository.readCachedGenerations(
      status: status == TemplateGenerationRepository._cacheAllStatusKey
          ? null
          : status,
    );
    if (items == null || items.isEmpty) {
      continue;
    }

    for (final item in items) {
      if (item.generationId == generationId) {
        return item;
      }
    }
  }

  return null;
}

Future<int?> _readCachedUnreadGenerationCount(
  TemplateGenerationRepository repository,
) async {
  try {
    final scope = await repository._readCacheScope();
    if (scope == null) {
      return null;
    }

    final unreadCountCacheKey = _generationScopedDataKey(
      TemplateGenerationRepository._unreadCountCacheKey,
      scope,
    );
    final legacyUnreadCountCacheKey = _generationLegacyScopedDataKey(
      TemplateGenerationRepository._unreadCountCacheKey,
      scope,
    );
    if (await _isGenerationCacheKeyExpired(repository, unreadCountCacheKey)) {
      await _clearGenerationCacheKey(repository, unreadCountCacheKey);
      return null;
    }

    return await _readGenerationCacheInt(
      repository,
      dataKey: unreadCountCacheKey,
      legacyDataKey: legacyUnreadCountCacheKey,
    );
  } on Object {
    return null;
  }
}

Future<({String generationId, String correlationId})?> _readActiveGeneration(
  TemplateGenerationRepository repository,
) async {
  try {
    final scope = await repository._readCacheScope();
    if (scope == null) {
      return null;
    }

    final activeGenerationIdKey = _generationScopedDataKey(
      TemplateGenerationRepository._activeGenerationIdKey,
      scope,
    );
    final activeGenerationCorrelationIdKey = _generationScopedDataKey(
      TemplateGenerationRepository._activeGenerationCorrelationIdKey,
      scope,
    );
    final legacyActiveGenerationIdKey = _generationLegacyScopedDataKey(
      TemplateGenerationRepository._activeGenerationIdKey,
      scope,
    );
    final legacyActiveGenerationCorrelationIdKey =
        _generationLegacyScopedDataKey(
          TemplateGenerationRepository._activeGenerationCorrelationIdKey,
          scope,
        );
    final secureScope = await repository._secureStorage.read(
      key: TemplateGenerationRepository._activeGenerationSecureScopeKey,
    );
    final scopeFingerprint = _generationCacheScopeFingerprint(scope);
    var generationId = secureScope == scopeFingerprint
        ? await repository._secureStorage.read(
            key: TemplateGenerationRepository
                ._activeGenerationIdSecureStorageKey,
          )
        : null;
    var migratedGenerationIdFromPreferences = false;
    if (generationId == null || generationId.trim().isEmpty) {
      generationId = await _readGenerationCacheString(
        repository,
        dataKey: activeGenerationIdKey,
        legacyDataKey: legacyActiveGenerationIdKey,
      );
      if (generationId != null && generationId.trim().isNotEmpty) {
        migratedGenerationIdFromPreferences = true;
        await repository._secureStorage.write(
          key: TemplateGenerationRepository._activeGenerationIdSecureStorageKey,
          value: generationId.trim(),
        );
        await repository._secureStorage.write(
          key: TemplateGenerationRepository._activeGenerationSecureScopeKey,
          value: scopeFingerprint,
        );
      }
    }
    if (generationId == null || generationId.trim().isEmpty) {
      return null;
    }

    var persistedCorrelationId = secureScope == scopeFingerprint
        ? await repository._secureStorage.read(
            key: TemplateGenerationRepository
                ._activeGenerationCorrelationIdSecureStorageKey,
          )
        : null;
    if (persistedCorrelationId == null ||
        persistedCorrelationId.trim().isEmpty) {
      persistedCorrelationId = await _readGenerationCacheString(
        repository,
        dataKey: activeGenerationCorrelationIdKey,
        legacyDataKey: legacyActiveGenerationCorrelationIdKey,
      );
      if (persistedCorrelationId != null &&
          persistedCorrelationId.trim().isNotEmpty) {
        await repository._secureStorage.write(
          key: TemplateGenerationRepository
              ._activeGenerationCorrelationIdSecureStorageKey,
          value: persistedCorrelationId.trim(),
        );
        await _clearActiveGenerationPreferenceKeys(
          repository,
          activeGenerationIdKey: activeGenerationIdKey,
          activeGenerationCorrelationIdKey: activeGenerationCorrelationIdKey,
          legacyActiveGenerationIdKey: legacyActiveGenerationIdKey,
          legacyActiveGenerationCorrelationIdKey:
              legacyActiveGenerationCorrelationIdKey,
        );
      }
    }
    final normalizedGenerationId = generationId.trim();
    final correlationId =
        persistedCorrelationId == null || persistedCorrelationId.trim().isEmpty
        ? repository._createGenerationCorrelationId()
        : persistedCorrelationId.trim();
    if (persistedCorrelationId == null ||
        persistedCorrelationId.trim().isEmpty) {
      await repository.rememberActiveGeneration(
        generationId: normalizedGenerationId,
        correlationId: correlationId,
      );
    } else if (migratedGenerationIdFromPreferences) {
      await _clearActiveGenerationPreferenceKeys(
        repository,
        activeGenerationIdKey: activeGenerationIdKey,
        activeGenerationCorrelationIdKey: activeGenerationCorrelationIdKey,
        legacyActiveGenerationIdKey: legacyActiveGenerationIdKey,
        legacyActiveGenerationCorrelationIdKey:
            legacyActiveGenerationCorrelationIdKey,
      );
    }

    return (generationId: normalizedGenerationId, correlationId: correlationId);
  } on Object {
    return null;
  }
}

Future<void> _rememberActiveGeneration(
  TemplateGenerationRepository repository, {
  required String generationId,
  String? correlationId,
}) async {
  try {
    final scope = await repository._readCacheScope();
    if (scope == null) {
      return;
    }

    final activeGenerationIdKey = _generationScopedDataKey(
      TemplateGenerationRepository._activeGenerationIdKey,
      scope,
    );
    final activeGenerationCorrelationIdKey = _generationScopedDataKey(
      TemplateGenerationRepository._activeGenerationCorrelationIdKey,
      scope,
    );
    final legacyActiveGenerationIdKey = _generationLegacyScopedDataKey(
      TemplateGenerationRepository._activeGenerationIdKey,
      scope,
    );
    final legacyActiveGenerationCorrelationIdKey =
        _generationLegacyScopedDataKey(
          TemplateGenerationRepository._activeGenerationCorrelationIdKey,
          scope,
        );
    final normalizedGenerationId = generationId.trim();
    if (normalizedGenerationId.isEmpty) {
      return;
    }

    await repository._secureStorage.write(
      key: TemplateGenerationRepository._activeGenerationSecureScopeKey,
      value: _generationCacheScopeFingerprint(scope),
    );
    await repository._secureStorage.write(
      key: TemplateGenerationRepository._activeGenerationIdSecureStorageKey,
      value: normalizedGenerationId,
    );
    final trimmedCorrelationId = correlationId?.trim();
    final normalizedCorrelationId =
        trimmedCorrelationId == null || trimmedCorrelationId.isEmpty
        ? repository._createGenerationCorrelationId()
        : trimmedCorrelationId;
    await repository._secureStorage.write(
      key: TemplateGenerationRepository
          ._activeGenerationCorrelationIdSecureStorageKey,
      value: normalizedCorrelationId,
    );
    await _clearActiveGenerationPreferenceKeys(
      repository,
      activeGenerationIdKey: activeGenerationIdKey,
      activeGenerationCorrelationIdKey: activeGenerationCorrelationIdKey,
      legacyActiveGenerationIdKey: legacyActiveGenerationIdKey,
      legacyActiveGenerationCorrelationIdKey:
          legacyActiveGenerationCorrelationIdKey,
    );
  } on Object {
    // Keep generation flow functional even if local persistence fails.
  }
}

Future<void> _clearActiveGeneration(
  TemplateGenerationRepository repository,
  String generationId,
) async {
  try {
    final scope = await repository._readCacheScope();
    if (scope == null) {
      return;
    }

    final activeGenerationIdKey = _generationScopedDataKey(
      TemplateGenerationRepository._activeGenerationIdKey,
      scope,
    );
    final activeGenerationCorrelationIdKey = _generationScopedDataKey(
      TemplateGenerationRepository._activeGenerationCorrelationIdKey,
      scope,
    );
    final legacyActiveGenerationIdKey = _generationLegacyScopedDataKey(
      TemplateGenerationRepository._activeGenerationIdKey,
      scope,
    );
    final legacyActiveGenerationCorrelationIdKey =
        _generationLegacyScopedDataKey(
          TemplateGenerationRepository._activeGenerationCorrelationIdKey,
          scope,
        );
    final secureScope = await repository._secureStorage.read(
      key: TemplateGenerationRepository._activeGenerationSecureScopeKey,
    );
    final scopeFingerprint = _generationCacheScopeFingerprint(scope);
    final secureScopeMatchesCurrentAccount = secureScope == scopeFingerprint;
    final current = secureScopeMatchesCurrentAccount
        ? await repository._secureStorage.read(
            key: TemplateGenerationRepository
                ._activeGenerationIdSecureStorageKey,
          )
        : await _readGenerationCacheString(
            repository,
            dataKey: activeGenerationIdKey,
            legacyDataKey: legacyActiveGenerationIdKey,
          );
    if (current != null && current != generationId) {
      return;
    }

    if (secureScopeMatchesCurrentAccount) {
      await _clearSecureActiveGeneration(repository);
    }
    await _clearActiveGenerationPreferenceKeys(
      repository,
      activeGenerationIdKey: activeGenerationIdKey,
      activeGenerationCorrelationIdKey: activeGenerationCorrelationIdKey,
      legacyActiveGenerationIdKey: legacyActiveGenerationIdKey,
      legacyActiveGenerationCorrelationIdKey:
          legacyActiveGenerationCorrelationIdKey,
    );
  } on Object {
    // Keep cleanup best-effort.
  }
}

Future<void> _clearSecureActiveGeneration(
  TemplateGenerationRepository repository,
) async {
  await Future.wait<void>([
    repository._secureStorage.delete(
      key: TemplateGenerationRepository._activeGenerationSecureScopeKey,
    ),
    repository._secureStorage.delete(
      key: TemplateGenerationRepository._activeGenerationIdSecureStorageKey,
    ),
    repository._secureStorage.delete(
      key: TemplateGenerationRepository
          ._activeGenerationCorrelationIdSecureStorageKey,
    ),
  ]);
}

Future<void> _clearActiveGenerationPreferenceKeys(
  TemplateGenerationRepository repository, {
  required String activeGenerationIdKey,
  required String activeGenerationCorrelationIdKey,
  required String legacyActiveGenerationIdKey,
  required String legacyActiveGenerationCorrelationIdKey,
}) async {
  await Future.wait<void>([
    repository._preferences.remove(activeGenerationIdKey),
    repository._preferences.remove(activeGenerationCorrelationIdKey),
    repository._preferences.remove(legacyActiveGenerationIdKey),
    repository._preferences.remove(legacyActiveGenerationCorrelationIdKey),
  ]);
}

Future<void> _clearLocalCache(TemplateGenerationRepository repository) async {
  try {
    final keys = await repository._preferences.getKeys();
    final generationKeyPrefixes = <String>[
      TemplateGenerationRepository._generationsCachePrefix,
      TemplateGenerationRepository._generationsCacheUpdatedAtPrefix,
      TemplateGenerationRepository._unreadCountCacheKey,
      TemplateGenerationRepository._unreadCountCacheUpdatedAtKey,
      TemplateGenerationRepository._activeGenerationIdKey,
      TemplateGenerationRepository._activeGenerationCorrelationIdKey,
    ];
    final removableKeys = keys
        .where(
          (key) => generationKeyPrefixes.any(
            (prefix) => key == prefix || key.startsWith('$prefix:'),
          ),
        )
        .toList(growable: false);
    for (final key in removableKeys) {
      await repository._preferences.remove(key);
    }
    await _clearSecureActiveGeneration(repository);
  } on Object {
    // Keep best-effort semantics for logout cleanup.
  }
}

String _buildGenerationCorrelationId(TemplateGenerationRepository repository) {
  return RequestIdentity.createCorrelationId().replaceFirst(
    'flow-',
    'generation-',
  );
}

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
    await repository._writeCachedUnreadGenerationCount(
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
  await repository._writeCachedUnreadGenerationCount(count);
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

  await repository._markCachedGenerationRead(generationId);
}

Future<void> _upsertCachedGeneration(
  TemplateGenerationRepository repository,
  TemplateGenerationResult generation,
) async {
  final scope = await repository._readCacheScope();
  if (scope == null) {
    return;
  }

  for (final status in TemplateGenerationRepository._cacheStatuses) {
    try {
      final cacheStatus =
          status == TemplateGenerationRepository._cacheAllStatusKey
          ? null
          : status;
      final key = _generationCacheKeyForScope(scope, cacheStatus);
      final legacyKey = _generationLegacyCacheKeyForScope(scope, cacheStatus);
      final raw = await _readGenerationCacheString(
        repository,
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
          .map(_sanitizePersistentGenerationCacheMap)
          .toList(growable: false);
      await repository._preferences.setString(key, jsonEncode(bounded));
      await _touchGenerationCacheKey(repository, key);
      await _clearGenerationCacheKey(repository, legacyKey);
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

    final cacheKey = _generationCacheKeyForScope(scope, status);
    final legacyCacheKey = _generationLegacyCacheKeyForScope(scope, status);
    final sanitizedItems = items
        .map(_sanitizePersistentGenerationCacheMap)
        .toList(growable: false);
    await repository._preferences.setString(
      cacheKey,
      jsonEncode(sanitizedItems),
    );
    await _touchGenerationCacheKey(repository, cacheKey);
    await _clearGenerationCacheKey(repository, legacyCacheKey);
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

    final unreadCountCacheKey = _generationScopedDataKey(
      TemplateGenerationRepository._unreadCountCacheKey,
      scope,
    );
    final legacyUnreadCountCacheKey = _generationLegacyScopedDataKey(
      TemplateGenerationRepository._unreadCountCacheKey,
      scope,
    );
    await repository._preferences.setInt(unreadCountCacheKey, count);
    await _touchGenerationCacheKey(repository, unreadCountCacheKey);
    await _clearGenerationCacheKey(repository, legacyUnreadCountCacheKey);
  } on Object {
    // Ignore local cache write errors to keep network flow stable.
  }
}

bool _matchesCachedGenerationStatusImpl(
  TemplateGenerationRepository repository,
  TemplateGenerationResult generation,
  String? status,
) {
  if (status == null || status.isEmpty) {
    return true;
  }

  return switch (status.toLowerCase()) {
    'active' => !generation.isTerminal,
    'completed' => generation.isCompleted,
    'failed' => generation.isFailed,
    _ => true,
  };
}

Map<String, Object?> _generationToCachedJsonImpl(
  TemplateGenerationRepository repository,
  TemplateGenerationResult generation,
) {
  return _sanitizePersistentGenerationCacheMap({
    'generationId': generation.generationId,
    'templateId': generation.templateId,
    'status': generation.status.name,
    'tokenCost': generation.tokenCost,
    'sourceImageAsset': generation.sourceImageAsset == null
        ? null
        : {
            'url': generation.sourceImageAsset!.url,
            'fileName': generation.sourceImageAsset!.fileName,
            'contentType': generation.sourceImageAsset!.contentType,
            'fileSizeBytes': generation.sourceImageAsset!.fileSizeBytes,
            'durationSeconds': generation.sourceImageAsset!.durationSeconds,
          },
    'normalizedImageUrl': generation.normalizedImageUrl,
    'referenceMotionUrl': generation.referenceMotionUrl,
    'outputUrl': generation.outputUrl,
    'attemptCount': generation.attemptCount,
    'usedPreprocessingModel': generation.usedPreprocessingModel,
    'usedKlingModel': generation.usedKlingModel,
    'outputVideoDurationSeconds': generation.outputVideoDurationSeconds,
    'failureCode': generation.failureCode,
    'failureMessage': generation.failureMessage,
    'createdAtUtc': generation.createdAtUtc.toUtc().toIso8601String(),
    'updatedAtUtc': generation.updatedAtUtc.toUtc().toIso8601String(),
    'startedAtUtc': generation.startedAtUtc?.toUtc().toIso8601String(),
    'preprocessingCompletedAtUtc': generation.preprocessingCompletedAtUtc
        ?.toUtc()
        .toIso8601String(),
    'motionGenerationCompletedAtUtc': generation.motionGenerationCompletedAtUtc
        ?.toUtc()
        .toIso8601String(),
    'mediaImportCompletedAtUtc': generation.mediaImportCompletedAtUtc
        ?.toUtc()
        .toIso8601String(),
    'completedAtUtc': generation.completedAtUtc?.toUtc().toIso8601String(),
    'templateTitle': generation.templateTitle,
    'templateType': generation.templateType,
    'stage': generation.stage,
    'progressPercent': generation.progressPercent,
    'estimatedDurationLabel': generation.estimatedDurationLabel,
    'chargedAtUtc': generation.chargedAtUtc?.toUtc().toIso8601String(),
    'refundedAtUtc': generation.refundedAtUtc?.toUtc().toIso8601String(),
    'userMediaExpired': generation.userMediaExpired,
    'isUnread': generation.isUnread,
    'queuePosition': generation.queuePosition,
    'estimatedWaitSeconds': generation.estimatedWaitSeconds,
    'estimatedCompletionAtUtc': generation.estimatedCompletionAtUtc
        ?.toUtc()
        .toIso8601String(),
    'estimatedTotalSeconds': generation.estimatedTotalSeconds,
    'mediaType': generation.mediaType,
    'media': {
      'state': generation.galleryMedia.state.name,
      'mediaType': generation.galleryMedia.mediaType,
      'previewUrl': generation.galleryMedia.previewUrl,
      'resultUrl': generation.galleryMedia.resultUrl,
      'resultExpiresAtUtc': generation.galleryMedia.resultExpiresAtUtc
          ?.toUtc()
          .toIso8601String(),
      'durationSeconds': generation.galleryMedia.durationSeconds,
      'hasWatermark': generation.galleryMedia.hasWatermark,
      'canRemoveWatermark': generation.galleryMedia.canRemoveWatermark,
      'isWatermarkRemoved': generation.galleryMedia.isWatermarkRemoved,
      'canDownload': generation.galleryMedia.canDownload,
      'canShare': generation.galleryMedia.canShare,
      'reasonCode': generation.galleryMedia.reasonCode,
      'userMessageKey': generation.galleryMedia.userMessageKey,
      'retryAfterSeconds': generation.galleryMedia.retryAfterSeconds,
    },
    'tier': generation.tier,
    'queueStatus': generation.queueStatus,
    'canCancel': generation.canCancel,
    'hasWatermark': generation.hasWatermark,
    'canRemoveWatermark': generation.canRemoveWatermark,
    'isWatermarkRemoved': generation.isWatermarkRemoved,
    'removeWatermarkCostCredits': generation.removeWatermarkCostCredits,
    'userPlan': generation.userPlan,
    'watermarkMessage': generation.watermarkMessage,
    'supportsGenerateSimilar': generation.supportsGenerateSimilar,
    'inputSourceType': generation.inputSourceType,
    'inputMediaAssetId': generation.inputMediaAssetId,
    'resultMediaAssetId': generation.resultMediaAssetId,
    'inputPreviewUrl': generation.inputPreviewUrl,
    'resultPreviewUrl': generation.resultPreviewUrl,
    'canCompareBeforeAfter': generation.canCompareBeforeAfter,
    'petId': generation.petId,
    'petPhotoId': generation.petPhotoId,
  });
}

Future<void> _markCachedGenerationReadImpl(
  TemplateGenerationRepository repository,
  String generationId,
) async {
  final scope = await repository._readCacheScope();
  if (scope == null) {
    return;
  }

  for (final status in TemplateGenerationRepository._cacheStatuses) {
    try {
      final key = _generationCacheKeyForScope(
        scope,
        status == TemplateGenerationRepository._cacheAllStatusKey
            ? null
            : status,
      );
      final legacyKey = _generationLegacyCacheKeyForScope(
        scope,
        status == TemplateGenerationRepository._cacheAllStatusKey
            ? null
            : status,
      );
      final raw = await _readGenerationCacheString(
        repository,
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
            return _sanitizePersistentGenerationCacheMap({
              ...generation,
              'isUnread': false,
            });
          })
          .toList(growable: false);

      if (changed) {
        await repository._preferences.setString(key, jsonEncode(updated));
        await _touchGenerationCacheKey(repository, key);
        await _clearGenerationCacheKey(repository, legacyKey);
      }
    } on Object {
      // Keep mark-read cache mutation best-effort per bucket.
    }
  }

  final unread = await repository.readCachedUnreadGenerationCount();
  if (unread != null && unread > 0) {
    await repository._writeCachedUnreadGenerationCount(unread - 1);
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

  for (final status in TemplateGenerationRepository._cacheStatuses) {
    try {
      final key = _generationCacheKeyForScope(
        scope,
        status == TemplateGenerationRepository._cacheAllStatusKey
            ? null
            : status,
      );
      final legacyKey = _generationLegacyCacheKeyForScope(
        scope,
        status == TemplateGenerationRepository._cacheAllStatusKey
            ? null
            : status,
      );
      final raw = await _readGenerationCacheString(
        repository,
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
        updated.add(_sanitizePersistentGenerationCacheMap(generation));
      }

      if (changed) {
        await repository._preferences.setString(key, jsonEncode(updated));
        await _touchGenerationCacheKey(repository, key);
        await _clearGenerationCacheKey(repository, legacyKey);
      }
    } on Object {
      // Keep delete cache mutation best-effort per bucket.
    }
  }

  if (removedUnread) {
    final unread = await repository.readCachedUnreadGenerationCount();
    if (unread != null && unread > 0) {
      await repository._writeCachedUnreadGenerationCount(unread - 1);
    }
  }
}

String _generationCacheUpdatedAtKeyForDataKey(String dataKey) {
  if (dataKey == TemplateGenerationRepository._unreadCountCacheKey ||
      dataKey.startsWith(
        '${TemplateGenerationRepository._unreadCountCacheKey}:',
      )) {
    final suffix = dataKey.substring(
      TemplateGenerationRepository._unreadCountCacheKey.length,
    );
    return '${TemplateGenerationRepository._unreadCountCacheUpdatedAtKey}$suffix';
  }

  if (dataKey.startsWith(
    TemplateGenerationRepository._generationsCachePrefix,
  )) {
    final suffix = dataKey.substring(
      TemplateGenerationRepository._generationsCachePrefix.length,
    );
    return '${TemplateGenerationRepository._generationsCacheUpdatedAtPrefix}$suffix';
  }

  return '${dataKey}_updated_at_v1';
}

Future<String?> _readGenerationCacheString(
  TemplateGenerationRepository repository, {
  required String dataKey,
  required String legacyDataKey,
}) async {
  final current = await repository._preferences.getString(dataKey);
  if (current != null) {
    return current;
  }

  if (await _isGenerationCacheKeyExpired(repository, legacyDataKey)) {
    await _clearGenerationCacheKey(repository, legacyDataKey);
    return null;
  }

  final legacy = await repository._preferences.getString(legacyDataKey);
  if (legacy == null) {
    return null;
  }

  await repository._preferences.setString(dataKey, legacy);
  await _migrateGenerationCacheTimestamp(
    repository,
    fromDataKey: legacyDataKey,
    toDataKey: dataKey,
  );
  await _clearGenerationCacheKey(repository, legacyDataKey);
  return legacy;
}

Future<int?> _readGenerationCacheInt(
  TemplateGenerationRepository repository, {
  required String dataKey,
  required String legacyDataKey,
}) async {
  final current = await repository._preferences.getInt(dataKey);
  if (current != null) {
    return current;
  }

  if (await _isGenerationCacheKeyExpired(repository, legacyDataKey)) {
    await _clearGenerationCacheKey(repository, legacyDataKey);
    return null;
  }

  final legacy = await repository._preferences.getInt(legacyDataKey);
  if (legacy == null) {
    return null;
  }

  await repository._preferences.setInt(dataKey, legacy);
  await _migrateGenerationCacheTimestamp(
    repository,
    fromDataKey: legacyDataKey,
    toDataKey: dataKey,
  );
  await _clearGenerationCacheKey(repository, legacyDataKey);
  return legacy;
}

Future<void> _migrateGenerationCacheTimestamp(
  TemplateGenerationRepository repository, {
  required String fromDataKey,
  required String toDataKey,
}) async {
  final legacyUpdatedAtKey = _generationCacheUpdatedAtKeyForDataKey(
    fromDataKey,
  );
  final updatedAt = await repository._preferences.getString(legacyUpdatedAtKey);
  if (updatedAt == null || updatedAt.isEmpty) {
    return;
  }

  await repository._preferences.setString(
    _generationCacheUpdatedAtKeyForDataKey(toDataKey),
    updatedAt,
  );
}

Future<void> _touchGenerationCacheKey(
  TemplateGenerationRepository repository,
  String dataKey,
) async {
  await repository._preferences.setString(
    _generationCacheUpdatedAtKeyForDataKey(dataKey),
    DateTime.now().toUtc().toIso8601String(),
  );
}

Future<bool> _isGenerationCacheKeyExpired(
  TemplateGenerationRepository repository,
  String dataKey,
) async {
  try {
    final timestampRaw = await repository._preferences.getString(
      _generationCacheUpdatedAtKeyForDataKey(dataKey),
    );
    if (timestampRaw == null || timestampRaw.isEmpty) {
      return false;
    }

    final updatedAtUtc = DateTime.tryParse(timestampRaw)?.toUtc();
    if (updatedAtUtc == null) {
      return true;
    }

    return DateTime.now().toUtc().difference(updatedAtUtc) >
        AppConfig.generationCacheTtl;
  } on Object {
    return false;
  }
}

Future<void> _clearGenerationCacheKey(
  TemplateGenerationRepository repository,
  String dataKey,
) async {
  try {
    await repository._preferences.remove(dataKey);
    await repository._preferences.remove(
      _generationCacheUpdatedAtKeyForDataKey(dataKey),
    );
  } on Object {
    // Keep best-effort semantics for cache cleanup.
  }
}

List<Object?> _sanitizePersistentGenerationCacheList(List<Object?> items) {
  return items
      .map((item) => _sanitizePersistentGenerationCacheValue(item))
      .toList(growable: false);
}

Map<String, Object?> _sanitizePersistentGenerationCacheMap(Map item) {
  return Map<String, Object?>.fromEntries(
    item.entries.where((entry) => entry.key != 'userId').map((entry) {
      final key = entry.key.toString();
      return MapEntry(
        key,
        _sanitizePersistentGenerationCacheValue(entry.value, key: key),
      );
    }),
  );
}

Map<String, dynamic> _generationCacheItemWithScope(
  Map<String, dynamic> item,
  String scope,
) {
  return <String, dynamic>{...item, 'userId': scope};
}

Object? _sanitizePersistentGenerationCacheValue(Object? value, {String? key}) {
  if (value == null) {
    return null;
  }

  if (value is String && _isPersistentGenerationMediaUrlKey(key)) {
    return persistentSafeGenerationMediaUrl(value);
  }

  if (value is String && _isPersistentGenerationMediaFileNameKey(key)) {
    return persistentSafeMediaFileName(value);
  }

  if (value is Map) {
    return _sanitizePersistentGenerationCacheMap(value);
  }

  if (value is List) {
    return value
        .map((item) => _sanitizePersistentGenerationCacheValue(item, key: key))
        .toList(growable: false);
  }

  return value;
}

bool _isPersistentGenerationMediaUrlKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return false;
  }

  return normalized == 'url' ||
      normalized.endsWith('url') ||
      normalized.endsWith('urls') ||
      normalized.endsWith('mediaurl');
}

bool _isPersistentGenerationMediaFileNameKey(String? key) {
  return key?.trim().toLowerCase() == 'filename';
}
