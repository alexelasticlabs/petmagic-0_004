part of 'generation_gallery_store.dart';

Future<GenerationGalleryMediaRecord> _galleryUpsertReadyItem(
  GenerationGalleryStore store,
  TemplateGenerationResult generation, {
  String? accountScopeOverride,
}) async {
  final accountScope =
      accountScopeOverride ??
      _galleryResolveAccountScope(generation.userId) ??
      await store.readCurrentAccountScope();
  if (accountScope == null || !generation.isCompleted) {
    throw StateError('Cannot persist gallery media without account scope.');
  }

  final entries = await _galleryReadEntriesForScope(store, accountScope);
  final existing = _galleryFindEntry(entries, generation.generationId);
  final previewRemoteUrl = galleryPreviewUrl(generation);
  final outputRemoteUrl = gallerySafeMediaUrl(generation.outputUrl);
  final hasRemoteMedia = previewRemoteUrl != null || outputRemoteUrl != null;
  final canReuseLocalMedia =
      hasRemoteMedia &&
      existing != null &&
      GenerationGalleryStorageCodec.safeNullableMediaUriEquals(
        existing.previewRemoteUrl,
        previewRemoteUrl,
      ) &&
      GenerationGalleryStorageCodec.safeNullableMediaUriEquals(
        existing.outputRemoteUrl,
        outputRemoteUrl,
      );
  final next = GenerationGalleryMediaRecord(
    generationId: generation.generationId,
    accountScope: accountScope,
    userId: generation.userId,
    status: generation.status.name,
    templateTitle: generation.templateTitle,
    templateType: generation.templateType,
    updatedAtUtc: generation.updatedAtUtc.toUtc(),
    previewRemoteUrl: previewRemoteUrl,
    outputRemoteUrl: outputRemoteUrl,
    previewLocalPath: canReuseLocalMedia ? existing.previewLocalPath : null,
    outputLocalPath: canReuseLocalMedia ? existing.outputLocalPath : null,
    isDeletedLocally: existing?.isDeletedLocally ?? false,
    isDownloadComplete: canReuseLocalMedia
        ? existing.isDownloadComplete
        : false,
    lastSyncedAtUtc: DateTime.now().toUtc(),
    version: (existing?.version ?? 0) + 1,
    pendingServerDelete: existing?.pendingServerDelete ?? false,
    materializationFailureCount: canReuseLocalMedia
        ? existing.materializationFailureCount
        : 0,
    materializationBackoffUntilUtc: canReuseLocalMedia
        ? existing.materializationBackoffUntilUtc
        : null,
    materializationFailureCode: canReuseLocalMedia
        ? existing.materializationFailureCode
        : null,
    localBytes: canReuseLocalMedia ? existing.localBytes : 0,
  );
  final updated = _galleryReplaceEntry(entries, next);
  await _galleryWriteEntriesForScope(store, accountScope, updated);
  return next;
}

Future<List<GenerationGalleryMediaRecord>> _galleryReadEntries(
  GenerationGalleryStore store,
) async {
  final accountScope = await store.readCurrentAccountScope();
  if (accountScope == null) {
    return const [];
  }
  return _galleryReadEntriesForScope(store, accountScope);
}

Future<List<GenerationGalleryMediaRecord>> _galleryReadEntriesForScope(
  GenerationGalleryStore store,
  String accountScope,
) async {
  try {
    final key = _galleryEntriesKeyForScope(accountScope);
    final legacyKey = _galleryLegacyEntriesKeyForScope(accountScope);
    var raw = await store._preferences.getString(key);
    final shouldMigrateLegacy = raw == null || raw.isEmpty;
    if (shouldMigrateLegacy) {
      raw = await store._preferences.getString(legacyKey);
    }
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      if (shouldMigrateLegacy) {
        await store._preferences.remove(legacyKey);
      }
      return const [];
    }
    final entries = await store._storageCodec.sanitizeLocalPaths(
      accountScope,
      decoded
          .whereType<Map>()
          .map(
            (entry) => GenerationGalleryMediaRecord.fromJson(
              Map<String, dynamic>.from(entry),
              accountScope: accountScope,
            ),
          )
          .toList(growable: false),
    );
    final sanitizedRaw = await store._storageCodec.encode(entries);
    if (sanitizedRaw != raw) {
      await _galleryRewriteSanitizedEntriesForScope(
        store,
        accountScope,
        entries,
      );
    }
    if (shouldMigrateLegacy) {
      if (sanitizedRaw == raw) {
        await _galleryRewriteSanitizedEntriesForScope(
          store,
          accountScope,
          entries,
        );
      }
      await store._preferences.remove(legacyKey);
    }
    return entries;
  } on Object catch (error, stackTrace) {
    _galleryLogStoreFailure(store, 'read_entries', error, stackTrace);
    return const [];
  }
}

Future<void> _galleryRewriteSanitizedEntriesForScope(
  GenerationGalleryStore store,
  String accountScope,
  List<GenerationGalleryMediaRecord> entries,
) async {
  await store._preferences.setString(
    _galleryEntriesKeyForScope(accountScope),
    await store._storageCodec.encode(entries),
  );
}

Future<void> _galleryWriteEntries(
  GenerationGalleryStore store,
  List<GenerationGalleryMediaRecord> entries,
) async {
  final grouped = <String, List<GenerationGalleryMediaRecord>>{};
  for (final entry in entries) {
    grouped.putIfAbsent(entry.accountScope, () => []).add(entry);
  }

  for (final item in grouped.entries) {
    await _galleryWriteEntriesForScope(store, item.key, item.value);
  }
}

Future<void> _galleryWriteEntriesForScope(
  GenerationGalleryStore store,
  String accountScope,
  List<GenerationGalleryMediaRecord> entries,
) async {
  try {
    final prunedEntries = await _galleryPruneEntriesForScope(
      store,
      accountScope,
      entries,
    );
    await store._preferences.setString(
      _galleryEntriesKeyForScope(accountScope),
      await store._storageCodec.encode(prunedEntries),
    );
  } on Object catch (error, stackTrace) {
    _galleryLogStoreFailure(store, 'write_entries', error, stackTrace);
  }
}

Future<List<GenerationGalleryMediaRecord>> _galleryPruneEntriesForScope(
  GenerationGalleryStore store,
  String accountScope,
  List<GenerationGalleryMediaRecord> entries,
) async {
  final ordered = List<GenerationGalleryMediaRecord>.from(entries)
    ..sort((left, right) {
      final bySyncedAt = right.lastSyncedAtUtc.compareTo(left.lastSyncedAtUtc);
      if (bySyncedAt != 0) {
        return bySyncedAt;
      }
      return right.updatedAtUtc.compareTo(left.updatedAtUtc);
    });

  final retained = <GenerationGalleryMediaRecord>[];
  final retainedIds = <String>{};
  final activeDownloadIds = ordered
      .where(
        (entry) => store._downloadCancelTokens.containsKey(
          galleryDownloadKey(accountScope, entry.generationId),
        ),
      )
      .map((entry) => entry.generationId)
      .toSet();

  for (final entry in ordered) {
    if ((entry.pendingServerDelete ||
            activeDownloadIds.contains(entry.generationId)) &&
        retainedIds.add(entry.generationId)) {
      retained.add(entry);
    }
  }

  for (final entry in ordered) {
    if (retained.length >= GenerationGalleryStore._maxEntriesPerScope) {
      break;
    }
    if (retainedIds.add(entry.generationId)) {
      retained.add(entry);
    }
  }

  final retainedIdSet = retained.map((entry) => entry.generationId).toSet();
  for (final entry in ordered) {
    if (retainedIdSet.contains(entry.generationId)) {
      continue;
    }
    if (activeDownloadIds.contains(entry.generationId)) {
      retained.add(entry);
      retainedIdSet.add(entry.generationId);
      continue;
    }
    if (!entry.isDeletedLocally) {
      await store._fileStorage.deleteGenerationDirectory(
        accountScope,
        entry.generationId,
      );
    }
  }

  final bytePruned = await _galleryPruneRetainedEntriesByBytes(
    store,
    accountScope,
    retained,
  );
  await store._cleanupScopeArtifactsForKnownIds(
    accountScope,
    bytePruned.map((entry) => entry.generationId).toSet(),
  );

  bytePruned.sort(
    (left, right) => right.updatedAtUtc.compareTo(left.updatedAtUtc),
  );
  return bytePruned;
}

Future<List<GenerationGalleryMediaRecord>> _galleryPruneRetainedEntriesByBytes(
  GenerationGalleryStore store,
  String accountScope,
  List<GenerationGalleryMediaRecord> retained,
) async {
  final maxBytes = store._maxGalleryCacheBytesPerScope;
  if (maxBytes <= 0) {
    return retained;
  }

  var usedBytes = 0;
  final updated = <GenerationGalleryMediaRecord>[];
  for (final entry in retained) {
    final isActiveDownload = store._downloadCancelTokens.containsKey(
      galleryDownloadKey(accountScope, entry.generationId),
    );
    final localBytes = await GenerationGalleryFileStorage.calculateLocalBytes([
      entry.previewLocalPath,
      entry.outputLocalPath,
    ]);
    if (localBytes <= 0) {
      updated.add(entry.copyWith(localBytes: 0));
      continue;
    }
    if (isActiveDownload || usedBytes + localBytes <= maxBytes) {
      usedBytes += localBytes;
      updated.add(entry.copyWith(localBytes: localBytes));
      continue;
    }

    await store._fileStorage.deleteLocalPath(
      accountScope,
      entry.generationId,
      entry.previewLocalPath,
    );
    await store._fileStorage.deleteLocalPath(
      accountScope,
      entry.generationId,
      entry.outputLocalPath,
    );
    updated.add(
      entry.copyWith(
        previewLocalPath: null,
        outputLocalPath: null,
        isDownloadComplete: false,
        localBytes: 0,
        materializationFailureCode: 'cache_byte_pruned',
      ),
    );
  }
  return updated;
}

Future<GenerationGalleryMediaRecord?> _galleryUpdateEntry(
  GenerationGalleryStore store,
  String accountScope,
  String generationId,
  GenerationGalleryMediaRecord Function(GenerationGalleryMediaRecord entry)
  mutate,
) async {
  final entries = await _galleryReadEntriesForScope(store, accountScope);
  GenerationGalleryMediaRecord? next;
  final updated = [
    for (final entry in entries)
      if (entry.generationId == generationId) next = mutate(entry) else entry,
  ].cast<GenerationGalleryMediaRecord>();
  if (next != null) {
    await _galleryWriteEntriesForScope(store, accountScope, updated);
  }
  return next;
}

List<GenerationGalleryMediaRecord> _galleryReplaceEntry(
  List<GenerationGalleryMediaRecord> entries,
  GenerationGalleryMediaRecord next,
) {
  final updated = <GenerationGalleryMediaRecord>[
    for (final entry in entries)
      if (entry.generationId != next.generationId) entry,
  ];
  updated.add(next);
  updated.sort(
    (left, right) => right.updatedAtUtc.compareTo(left.updatedAtUtc),
  );
  return updated;
}

GenerationGalleryMediaRecord? _galleryFindEntry(
  List<GenerationGalleryMediaRecord> entries,
  String generationId,
) {
  for (final entry in entries) {
    if (entry.generationId == generationId) {
      return entry;
    }
  }
  return null;
}
