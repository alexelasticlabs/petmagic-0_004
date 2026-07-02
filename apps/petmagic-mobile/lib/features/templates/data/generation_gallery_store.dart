import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/domain/generation_media_kind.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/shared/files/device_file_saver.dart';
import 'package:petmagic_mobile/shared/files/file_name_sanitizer.dart';
import 'package:petmagic_mobile/shared/files/media_signature.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'template_generation_repository.dart';

part 'generation_gallery_store_entries.part.dart';
part 'generation_gallery_store_record.part.dart';
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

final generationGalleryStoreProvider = Provider<GenerationGalleryStore>((ref) {
  return GenerationGalleryStore(
    dio: ref.watch(dioProvider),
    preferences: ref.watch(templateGenerationSharedPreferencesProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    rootDirectoryResolver: ref.watch(
      generationGalleryRootDirectoryResolverProvider,
    ),
  );
});

class GenerationGalleryStore {
  GenerationGalleryStore({
    required Dio dio,
    required SharedPreferencesAsync preferences,
    required AuthSessionStorage sessionStorage,
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
  }) : _dio = dio,
       _preferences = preferences,
       _sessionStorage = sessionStorage,
       _rootDirectoryResolver = rootDirectoryResolver,
       _maxBackgroundMaterializationsPerSession =
           maxBackgroundMaterializationsPerSession,
       _maxBackgroundVideoOutputsPerSession =
           maxBackgroundVideoOutputsPerSession,
       _maxBackgroundBytesPerSession = maxBackgroundBytesPerSession,
       _maxBackgroundFileBytes = maxBackgroundFileBytes,
       _maxGalleryCacheBytesPerScope = maxGalleryCacheBytesPerScope,
       _maxMaterializationRetryCount = maxMaterializationRetryCount,
       _materializationRetryBaseBackoff = materializationRetryBaseBackoff,
       _clock = clock ?? DateTime.now;

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

  final Dio _dio;
  final SharedPreferencesAsync _preferences;
  final AuthSessionStorage _sessionStorage;
  final GenerationGalleryRootDirectoryResolver _rootDirectoryResolver;
  final int _maxBackgroundMaterializationsPerSession;
  final int _maxBackgroundVideoOutputsPerSession;
  final int _maxBackgroundBytesPerSession;
  final int _maxBackgroundFileBytes;
  final int _maxGalleryCacheBytesPerScope;
  final int _maxMaterializationRetryCount;
  final Duration _materializationRetryBaseBackoff;
  final DateTime Function() _clock;
  final Map<String, CancelToken> _downloadCancelTokens = {};
  final Map<String, Future<GenerationGalleryMediaRecord?>> _inFlightDownloads =
      {};
  int _backgroundMaterializationsThisSession = 0;
  int _backgroundVideoOutputsThisSession = 0;
  int _backgroundBytesThisSession = 0;

  Future<String?> readCurrentAccountScope() async {
    final session = await _sessionStorage.read();
    return _galleryResolveAccountScope(session?.user.userId);
  }

  Future<List<GenerationGalleryMediaRecord>> loadLocalReadyItems() async {
    final entries = await _galleryReadEntries(this);
    return entries
        .where((entry) => !entry.isDeletedLocally)
        .toList(growable: false);
  }

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

  Future<Set<String>> loadDeletedGenerationIds() async {
    final entries = await _galleryReadEntries(this);
    return entries
        .where((entry) => entry.isDeletedLocally)
        .map((entry) => entry.generationId)
        .toSet();
  }

  Future<List<String>> loadPendingServerDeleteIds() async {
    final entries = await _galleryReadEntries(this);
    return entries
        .where((entry) => entry.isDeletedLocally && entry.pendingServerDelete)
        .map((entry) => entry.generationId)
        .toList(growable: false);
  }

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

  Future<void> removeRecord(String generationId) async {
    final entries = await _galleryReadEntries(this);
    final target = entries
        .where((entry) => entry.generationId == generationId)
        .toList(growable: false);
    for (final entry in target) {
      await _galleryDeleteGenerationDirectory(
        this,
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

  Future<GenerationGalleryMediaRecord> upsertReadyItem(
    TemplateGenerationResult generation,
  ) {
    return _galleryUpsertReadyItem(this, generation);
  }

  Future<void> markDeletedLocally(String generationId, {String? userId}) {
    return _galleryMarkDeletedLocally(this, generationId, userId: userId);
  }

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

  Future<void> cancelActiveDownloads() {
    return _galleryCancelActiveDownloads(this);
  }

  Future<void> purgeCurrentAccountScope() {
    return _galleryPurgeCurrentAccountScope(this);
  }

  Future<void> purgeAllScopes() {
    return _galleryPurgeAllScopes(this);
  }

  Future<void> cleanupCurrentAccountArtifacts() {
    return _galleryCleanupCurrentAccountArtifacts(this);
  }
}
