export 'package:petmagic_mobile/features/templates/application/generation_gallery_cache.dart'
    show
        GenerationGalleryCache,
        GenerationGalleryMediaRecordView,
        generationGalleryStoreProvider;
export 'package:petmagic_mobile/features/templates/data/generation_gallery_media_record.dart'
    show GenerationGalleryMediaRecord;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/domain/generation_media_kind.dart';
import 'package:petmagic_mobile/features/templates/application/generation_gallery_cache.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'template_generation_repository.dart';
import 'generation_gallery_file_storage.dart';
import 'generation_gallery_deletion_coordinator.dart';
import 'generation_gallery_media_record.dart';
import 'generation_gallery_materialization_policy.dart';
import 'generation_gallery_remote_file_materializer.dart';
import 'generation_gallery_storage_codec.dart';

part 'generation_gallery_store_entries.part.dart';
part 'generation_gallery_store_scopes.part.dart';
part 'generation_gallery_store_storage.part.dart';

typedef GenerationGalleryRootDirectoryResolver = Future<Directory> Function();

final generationGalleryRootDirectoryResolverProvider =
    Provider<GenerationGalleryRootDirectoryResolver>((ref) {
      return () async {
        try {
          return await getApplicationSupportDirectory();
        } on Object {
          final fallback = Directory.systemTemp.uri.resolve('petmagic_mobile/');
          return Directory.fromUri(fallback);
        }
      };
    });

final fileGenerationGalleryStoreProvider = Provider<GenerationGalleryCache>((
  ref,
) {
  final store = GenerationGalleryStore(
    dio: ref.watch(dioProvider),
    preferences: ref.watch(templateGenerationSharedPreferencesProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    rootDirectoryResolver: ref.watch(
      generationGalleryRootDirectoryResolverProvider,
    ),
  );
  ref.onDispose(() {
    unawaited(store.cancelActiveDownloads());
  });
  return store;
});

class GenerationGalleryStore implements GenerationGalleryCache {
  GenerationGalleryStore({
    required Dio dio,
    required SharedPreferencesAsync preferences,
    required AuthSessionStore sessionStorage,
    required GenerationGalleryRootDirectoryResolver rootDirectoryResolver,
    int maxBackgroundMaterializationsPerSession =
        _defaultMaxBackgroundMaterializationsPerSession,
    int maxBackgroundVideoOutputsPerSession =
        _defaultMaxBackgroundVideoOutputsPerSession,
    int maxBackgroundBytesPerSession = _defaultMaxBackgroundBytesPerSession,
    int maxBackgroundFileBytes = _defaultMaxBackgroundFileBytes,
    int maxGalleryCacheBytesPerScope = _defaultMaxGalleryCacheBytesPerScope,
    int maxMaterializationRetryCount = _defaultMaxMaterializationRetryCount,
    Duration materializationRetryBaseBackoff =
        _defaultMaterializationRetryBaseBackoff,
    DateTime Function()? clock,
  }) : _preferences = preferences,
       _sessionStorage = sessionStorage,
       _maxBackgroundMaterializationsPerSession =
           maxBackgroundMaterializationsPerSession,
       _maxBackgroundVideoOutputsPerSession =
           maxBackgroundVideoOutputsPerSession,
       _maxBackgroundBytesPerSession = maxBackgroundBytesPerSession,
       _maxGalleryCacheBytesPerScope = maxGalleryCacheBytesPerScope,
       _maxMaterializationRetryCount = maxMaterializationRetryCount,
       _materializationRetryBaseBackoff = materializationRetryBaseBackoff,
       _clock = clock ?? DateTime.now,
       _fileStorage = GenerationGalleryFileStorage(
         rootDirectoryResolver: rootDirectoryResolver,
         scopeRoot: _generationScopeRoot,
       ),
       _remoteFileMaterializer = GenerationGalleryRemoteFileMaterializer(
         dio: dio,
         maxBackgroundFileBytes: maxBackgroundFileBytes,
       ),
       _storageCodec = GenerationGalleryStorageCodec(
         rootDirectoryResolver: rootDirectoryResolver,
         fileStorage: GenerationGalleryFileStorage(
           rootDirectoryResolver: rootDirectoryResolver,
           scopeRoot: _generationScopeRoot,
         ),
       );

  static const _legacyEntriesKeyPrefix = 'generation_gallery_entries_v1:';
  static const _entriesKeyPrefix = 'generation_gallery_entries_v2:';
  static const _generationScopeRoot = 'generation_gallery';
  static const _maxEntriesPerScope = 120;
  static const _defaultMaxBackgroundMaterializationsPerSession = 12;
  static const _defaultMaxBackgroundVideoOutputsPerSession = 0;
  static const _defaultMaxBackgroundBytesPerSession = 64 * 1024 * 1024;
  static const _defaultMaxBackgroundFileBytes = 32 * 1024 * 1024;
  static const _defaultMaxGalleryCacheBytesPerScope = 256 * 1024 * 1024;
  static const _defaultMaxMaterializationRetryCount = 3;
  static const _defaultMaterializationRetryBaseBackoff = Duration(minutes: 15);

  final SharedPreferencesAsync _preferences;
  final AuthSessionStore _sessionStorage;
  final int _maxBackgroundMaterializationsPerSession;
  final int _maxBackgroundVideoOutputsPerSession;
  final int _maxBackgroundBytesPerSession;
  final int _maxGalleryCacheBytesPerScope;
  final int _maxMaterializationRetryCount;
  final Duration _materializationRetryBaseBackoff;
  final DateTime Function() _clock;
  final GenerationGalleryFileStorage _fileStorage;
  final GenerationGalleryRemoteFileMaterializer _remoteFileMaterializer;
  final GenerationGalleryStorageCodec _storageCodec;
  final Map<String, CancelToken> _downloadCancelTokens = {};
  final Map<String, Future<GenerationGalleryMediaRecord?>> _inFlightDownloads =
      {};
  int _backgroundMaterializationsThisSession = 0;
  int _backgroundVideoOutputsThisSession = 0;
  int _backgroundBytesThisSession = 0;

  @override
  Future<String?> readCurrentAccountScope() async {
    final session = await _sessionStorage.read();
    return _galleryResolveAccountScope(session?.user.userId);
  }

  @override
  Future<List<GenerationGalleryMediaRecord>> loadLocalReadyItems() async {
    final entries = await _galleryReadEntries(this);
    return entries
        .where((entry) => !entry.isDeletedLocally)
        .toList(growable: false);
  }

  @override
  Future<GenerationGalleryMediaRecord?> readLocalRecord(
    String generationId,
  ) async {
    final entries = await _galleryReadEntries(this);
    for (final entry in entries) {
      if (entry.generationId == generationId) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<Set<String>> loadDeletedGenerationIds() async {
    final entries = await _galleryReadEntries(this);
    return entries
        .where((entry) => entry.isDeletedLocally)
        .map((entry) => entry.generationId)
        .toSet();
  }

  @override
  Future<List<String>> loadPendingServerDeleteIds() async {
    final entries = await _galleryReadEntries(this);
    return entries
        .where((entry) => entry.isDeletedLocally && entry.pendingServerDelete)
        .map((entry) => entry.generationId)
        .toList(growable: false);
  }

  @override
  Future<void> clearPendingServerDelete(String generationId) async {
    final entries = await _galleryReadEntries(this);
    final updated = [
      for (final entry in entries)
        if (entry.generationId == generationId)
          entry.copyWith(pendingServerDelete: false)
        else
          entry,
    ];
    await _galleryWriteEntries(this, updated);
  }

  @override
  Future<void> removeRecord(String generationId) async {
    final entries = await _galleryReadEntries(this);
    final target = entries
        .where((entry) => entry.generationId == generationId)
        .toList(growable: false);
    for (final entry in target) {
      await _fileStorage.deleteGenerationDirectory(
        entry.accountScope,
        generationId,
      );
    }
    final updated = [
      for (final entry in entries)
        if (entry.generationId != generationId) entry,
    ];
    await _galleryWriteEntries(this, updated);
    final updatedScopes = updated.map((entry) => entry.accountScope).toSet();
    for (final scope in target.map((entry) => entry.accountScope).toSet()) {
      if (!updatedScopes.contains(scope)) {
        await _galleryWriteEntriesForScope(this, scope, const []);
      }
    }
  }

  @override
  Future<GenerationGalleryMediaRecord> upsertReadyItem(
    TemplateGenerationResult generation,
  ) {
    return _galleryUpsertReadyItem(this, generation);
  }

  @override
  Future<void> markDeletedLocally(String generationId, {String? userId}) {
    return _galleryMarkDeletedLocally(this, generationId, userId: userId);
  }

  @override
  Future<GenerationGalleryMediaRecord?> materializeGenerationMedia(
    TemplateGenerationResult generation, {
    bool background = false,
  }) {
    return _galleryMaterializeGenerationMedia(
      this,
      generation,
      background: background,
    );
  }

  @override
  Future<void> cancelActiveDownloads() {
    return _galleryCancelActiveDownloads(this);
  }

  @override
  Future<void> clearCurrentAccountDownloads() {
    return _galleryClearCurrentAccountDownloads(this);
  }

  @override
  Future<void> purgeCurrentAccountScope() {
    return _galleryPurgeCurrentAccountScope(this);
  }

  @override
  Future<void> purgeAllScopes() {
    return _galleryPurgeAllScopes(this);
  }

  @override
  Future<void> cleanupCurrentAccountArtifacts() {
    return _galleryCleanupCurrentAccountArtifacts(this);
  }

  Future<GenerationGalleryMaterializeFileResult> _materializeRemoteFile({
    required String remoteUrl,
    required Directory targetDirectory,
    required String prefix,
    required String fallbackExtension,
    required CancelToken cancelToken,
    required bool background,
  }) {
    return _remoteFileMaterializer.materialize(
      remoteUrl: remoteUrl,
      targetDirectory: targetDirectory,
      prefix: prefix,
      fallbackExtension: fallbackExtension,
      cancelToken: cancelToken,
      background: background,
      remainingBackgroundBytes:
          _maxBackgroundBytesPerSession - _backgroundBytesThisSession,
    );
  }

  Future<void> _cleanupScopeArtifacts(String accountScope) async {
    final entries = await _galleryReadEntriesForScope(this, accountScope);
    await _cleanupScopeArtifactsForKnownIds(
      accountScope,
      entries.map((entry) => entry.generationId).toSet(),
    );
  }

  Future<void> _cleanupScopeArtifactsForKnownIds(
    String accountScope,
    Set<String> knownGenerationIds,
  ) {
    final activeGenerationIds = _downloadCancelTokens.keys
        .where((key) => key.startsWith('$accountScope\u{1F}'))
        .map((key) => key.substring(accountScope.length + 1))
        .toSet();
    return _fileStorage.cleanupScopeArtifactsForKnownIds(
      accountScope,
      knownGenerationIds,
      activeGenerationIds: activeGenerationIds,
    );
  }
}
