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
  return '$baseKey:$scope';
}

String _generationCacheKeyForScope(String scope, String? status) {
  final normalized = (status == null || status.trim().isEmpty)
      ? TemplateGenerationRepository._cacheAllStatusKey
      : status.trim().toLowerCase();
  return '${TemplateGenerationRepository._generationsCachePrefix}$scope:$normalized';
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
    if (await _isGenerationCacheKeyExpired(repository, cacheKey)) {
      await _clearGenerationCacheKey(repository, cacheKey);
      return null;
    }

    final raw = await repository._preferences.getString(cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return null;
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => TemplateGenerationDto.fromJson(
            Map<String, dynamic>.from(item),
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
    if (await _isGenerationCacheKeyExpired(repository, unreadCountCacheKey)) {
      await _clearGenerationCacheKey(repository, unreadCountCacheKey);
      return null;
    }

    return await repository._preferences.getInt(unreadCountCacheKey);
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
    final generationId = await repository._preferences.getString(
      activeGenerationIdKey,
    );
    if (generationId == null || generationId.trim().isEmpty) {
      return null;
    }

    final persistedCorrelationId = await repository._preferences.getString(
      activeGenerationCorrelationIdKey,
    );
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
    final normalizedGenerationId = generationId.trim();
    if (normalizedGenerationId.isEmpty) {
      return;
    }

    await repository._preferences.setString(
      activeGenerationIdKey,
      normalizedGenerationId,
    );
    final trimmedCorrelationId = correlationId?.trim();
    final normalizedCorrelationId =
        trimmedCorrelationId == null || trimmedCorrelationId.isEmpty
        ? repository._createGenerationCorrelationId()
        : trimmedCorrelationId;
    await repository._preferences.setString(
      activeGenerationCorrelationIdKey,
      normalizedCorrelationId,
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
    final current = await repository._preferences.getString(
      activeGenerationIdKey,
    );
    if (current != null && current != generationId) {
      return;
    }

    await repository._preferences.remove(activeGenerationIdKey);
    await repository._preferences.remove(activeGenerationCorrelationIdKey);
  } on Object {
    // Keep cleanup best-effort.
  }
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
  } on Object {
    // Keep best-effort semantics for logout cleanup.
  }
}

String _buildGenerationCorrelationId(TemplateGenerationRepository repository) {
  final now = DateTime.now().toUtc().microsecondsSinceEpoch;
  final suffix = TemplateGenerationRepository._correlationRandom
      .nextInt(1 << 24)
      .toRadixString(16);
  return 'generation-$now-$suffix';
}

Future<List<TemplateGenerationResult>> _fetchGenerations(
  TemplateGenerationRepository repository, {
  String? status,
  int? skip,
  int? take,
  CancelToken? cancelToken,
}) async {
  final queryParameters = <String, Object?>{};
  if (status != null && status.isNotEmpty) {
    queryParameters['status'] = status;
  }
  if (skip != null) {
    queryParameters['skip'] = skip;
  }
  if (take != null) {
    queryParameters['take'] = take;
  }

  final response = await repository._authorizedRequest<List<dynamic>>(
    (session) => repository._dio.get<List<dynamic>>(
      '/api/templates/generations',
      queryParameters: queryParameters,
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken,
    ),
  );

  final itemsJson = (response.data ?? const [])
      .whereType<Map>()
      .map(Map<String, Object?>.from)
      .toList(growable: false);

  await repository._writeCachedGenerations(status: status, items: itemsJson);

  return itemsJson
      .whereType<Map>()
      .map(
        (item) => TemplateGenerationDto.fromJson(
          Map<String, dynamic>.from(item),
        ).toDomain(),
      )
      .toList(growable: false);
}

Future<int> _fetchUnreadGenerationCount(
  TemplateGenerationRepository repository, {
  CancelToken? cancelToken,
}) async {
  final response = await repository._authorizedRequest<Map<String, dynamic>>(
    (session) => repository._dio.get<Map<String, dynamic>>(
      '/api/templates/generations/unread-count',
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken,
    ),
  );

  final count = (response.data?['count'] as num?)?.toInt() ?? 0;
  await repository._writeCachedUnreadGenerationCount(count);
  return count;
}

Future<void> _markGenerationRead(
  TemplateGenerationRepository repository,
  String generationId, {
  CancelToken? cancelToken,
}) async {
  final encodedGenerationId = repository._apiPathSegment(generationId);
  await repository._authorizedRequest<void>(
    (session) => repository._dio.post<void>(
      '/api/templates/generations/$encodedGenerationId/mark-read',
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken,
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
      final raw = await repository._preferences.getString(key);
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

      final bounded = updated.take(50).toList(growable: false);
      await repository._preferences.setString(key, jsonEncode(bounded));
      await _touchGenerationCacheKey(repository, key);
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
    await repository._preferences.setString(cacheKey, jsonEncode(items));
    await _touchGenerationCacheKey(repository, cacheKey);
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
    await repository._preferences.setInt(unreadCountCacheKey, count);
    await _touchGenerationCacheKey(repository, unreadCountCacheKey);
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
  return {
    'generationId': generation.generationId,
    'userId': generation.userId,
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
  };
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
      final raw = await repository._preferences.getString(key);
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
            return {...generation, 'isUnread': false};
          })
          .toList(growable: false);

      if (changed) {
        await repository._preferences.setString(key, jsonEncode(updated));
        await _touchGenerationCacheKey(repository, key);
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
      final raw = await repository._preferences.getString(key);
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
        updated.add(generation);
      }

      if (changed) {
        await repository._preferences.setString(key, jsonEncode(updated));
        await _touchGenerationCacheKey(repository, key);
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
