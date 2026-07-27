part of 'generation_gallery_store.dart';

String _galleryEntriesKeyForScope(String accountScope) {
  return '${GenerationGalleryStore._entriesKeyPrefix}'
      '${_galleryScopeStorageFingerprint(accountScope)}';
}

String _galleryLegacyEntriesKeyForScope(String accountScope) {
  return '${GenerationGalleryStore._legacyEntriesKeyPrefix}$accountScope';
}

String _galleryScopeStorageFingerprint(String accountScope) {
  final normalized = accountScope.trim().toLowerCase();
  return sha256.convert(utf8.encode(normalized)).toString();
}

Future<Set<String>> _galleryReadKnownAccountScopes(
  GenerationGalleryStore store,
) async {
  try {
    final keys = await store._preferences.getKeys();
    final scopes = <String>{};
    final entryKeys = keys
        .where(
          (key) =>
              key.startsWith(GenerationGalleryStore._entriesKeyPrefix) ||
              key.startsWith(GenerationGalleryStore._legacyEntriesKeyPrefix),
        )
        .toList(growable: false);
    for (final key in entryKeys) {
      final raw = await store._preferences.getString(key);
      if (raw == null || raw.isEmpty) {
        if (key.startsWith(GenerationGalleryStore._legacyEntriesKeyPrefix)) {
          final legacyScope = key.substring(
            GenerationGalleryStore._legacyEntriesKeyPrefix.length,
          );
          if (legacyScope.trim().isNotEmpty) {
            scopes.add(legacyScope);
          }
        }
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final entry in decoded.whereType<Map>()) {
            final scope = entry['accountScope'] as String?;
            if (scope != null && scope.trim().isNotEmpty) {
              scopes.add(scope);
            }
          }
        }
      } on Object {
        if (key.startsWith(GenerationGalleryStore._legacyEntriesKeyPrefix)) {
          final legacyScope = key.substring(
            GenerationGalleryStore._legacyEntriesKeyPrefix.length,
          );
          if (legacyScope.trim().isNotEmpty) {
            scopes.add(legacyScope);
          }
        }
      }
    }
    return scopes;
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

/// Drops only files downloaded for the active account while retaining gallery
/// metadata and pending deletion tombstones for the next server synchronization.
Future<void> _galleryClearCurrentAccountDownloads(
  GenerationGalleryStore store,
) async {
  final accountScope = await store.readCurrentAccountScope();
  if (accountScope == null) {
    return;
  }

  await _galleryCancelActiveDownloads(store);
  final entries = await _galleryReadEntriesForScope(store, accountScope);
  await store._fileStorage.deleteScopeDirectory(accountScope);
  final clearedAtUtc = _galleryNowUtc(store);
  await _galleryWriteEntriesForScope(store, accountScope, [
    for (final entry in entries)
      entry.copyWith(
        previewLocalPath: null,
        outputLocalPath: null,
        isDownloadComplete: false,
        lastSyncedAtUtc: clearedAtUtc,
        version: entry.version + 1,
        materializationFailureCount: 0,
        materializationBackoffUntilUtc: null,
        materializationFailureCode: null,
        localBytes: 0,
      ),
  ]);
}

Future<void> _galleryPurgeAllScopes(GenerationGalleryStore store) async {
  await _galleryCancelActiveDownloads(store);
  try {
    final keys = await store._preferences.getKeys();
    final removableKeys = keys
        .where(
          (key) =>
              key.startsWith(GenerationGalleryStore._entriesKeyPrefix) ||
              key.startsWith(GenerationGalleryStore._legacyEntriesKeyPrefix),
        )
        .toList(growable: false);
    for (final key in removableKeys) {
      await store._preferences.remove(key);
    }
  } on Object catch (error, stackTrace) {
    _galleryLogStoreFailure(store, 'purge_all_scope_keys', error, stackTrace);
    final scopes = await _galleryReadKnownAccountScopes(store);
    for (final scope in scopes) {
      await store._preferences.remove(_galleryEntriesKeyForScope(scope));
      await store._preferences.remove(_galleryLegacyEntriesKeyForScope(scope));
    }
  }
  await store._fileStorage.deleteRootDirectory();
}

Future<void> _galleryCleanupCurrentAccountArtifacts(
  GenerationGalleryStore store,
) async {
  final accountScope = await store.readCurrentAccountScope();
  if (accountScope == null) {
    return;
  }

  await store._cleanupScopeArtifacts(accountScope);
}

Future<void> _galleryPurgeScope(
  GenerationGalleryStore store,
  String accountScope,
) async {
  await _galleryCancelActiveDownloads(store);
  await store._preferences.remove(_galleryEntriesKeyForScope(accountScope));
  await store._preferences.remove(
    _galleryLegacyEntriesKeyForScope(accountScope),
  );
  await store._fileStorage.deleteScopeDirectory(accountScope);
}
