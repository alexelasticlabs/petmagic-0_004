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
  final previewRemoteUrl = _previewUrl(generation);
  final outputRemoteUrl = _safeMediaUrl(generation.outputUrl);
  final hasRemoteMedia = previewRemoteUrl != null || outputRemoteUrl != null;
  final canReuseLocalMedia =
      hasRemoteMedia &&
      existing != null &&
      _gallerySafeNullableMediaUriEquals(
        existing.previewRemoteUrl,
        previewRemoteUrl,
      ) &&
      _gallerySafeNullableMediaUriEquals(
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
    final raw = await store._preferences.getString(
      _galleryEntriesKeyForScope(accountScope),
    );
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .whereType<Map>()
        .map(
          (entry) => GenerationGalleryMediaRecord.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .toList(growable: false);
  } on Object catch (error, stackTrace) {
    _galleryLogStoreFailure(store, 'read_entries', error, stackTrace);
    return const [];
  }
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
      jsonEncode(
        prunedEntries.map((entry) => entry.toJson()).toList(growable: false),
      ),
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
  if (entries.length <= GenerationGalleryStore._maxEntriesPerScope) {
    return entries;
  }

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

  for (final entry in ordered) {
    if (entry.pendingServerDelete && retainedIds.add(entry.generationId)) {
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
    if (!entry.isDeletedLocally) {
      await _galleryDeleteGenerationDirectory(
        store,
        accountScope,
        entry.generationId,
      );
    }
  }

  retained.sort(
    (left, right) => right.updatedAtUtc.compareTo(left.updatedAtUtc),
  );
  return retained;
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

String _galleryEntriesKeyForScope(String accountScope) {
  return '${GenerationGalleryStore._entriesKeyPrefix}$accountScope';
}

Future<Set<String>> _galleryReadKnownAccountScopes(
  GenerationGalleryStore store,
) async {
  try {
    final keys = await store._preferences.getKeys();
    return keys
        .where(
          (key) => key.startsWith(GenerationGalleryStore._entriesKeyPrefix),
        )
        .map(
          (key) =>
              key.substring(GenerationGalleryStore._entriesKeyPrefix.length),
        )
        .where((scope) => scope.trim().isNotEmpty)
        .toSet();
  } on Object catch (error, stackTrace) {
    _galleryLogStoreFailure(
      store,
      'read_known_account_scopes',
      error,
      stackTrace,
    );
    final entries = await _galleryReadEntries(store);
    return entries.map((entry) => entry.accountScope).toSet();
  }
}

String? _galleryResolveAccountScope(String? rawUserId) {
  final value = rawUserId?.trim();
  return value == null || value.isEmpty ? null : value;
}

Future<void> _galleryPurgeCurrentAccountScope(
  GenerationGalleryStore store,
) async {
  final accountScope = await store.readCurrentAccountScope();
  if (accountScope == null) {
    await _galleryPurgeAllScopes(store);
    return;
  }

  await _galleryPurgeScope(store, accountScope);
}

Future<void> _galleryPurgeAllScopes(GenerationGalleryStore store) async {
  await _galleryCancelActiveDownloads(store);
  final scopes = await _galleryReadKnownAccountScopes(store);
  for (final scope in scopes) {
    await store._preferences.remove(_galleryEntriesKeyForScope(scope));
    await _galleryDeleteScopeDirectory(store, scope);
  }
}

Future<void> _galleryCleanupCurrentAccountArtifacts(
  GenerationGalleryStore store,
) async {
  final accountScope = await store.readCurrentAccountScope();
  if (accountScope == null) {
    return;
  }

  await _galleryCleanupScopeArtifacts(store, accountScope);
}

Future<void> _galleryPurgeScope(
  GenerationGalleryStore store,
  String accountScope,
) async {
  await _galleryCancelActiveDownloads(store);
  await store._preferences.remove(_galleryEntriesKeyForScope(accountScope));
  await _galleryDeleteScopeDirectory(store, accountScope);
}
