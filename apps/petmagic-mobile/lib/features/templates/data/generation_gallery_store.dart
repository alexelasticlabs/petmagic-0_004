import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/shared/files/device_file_saver.dart';
import 'package:petmagic_mobile/shared/files/file_name_sanitizer.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'template_generation_repository.dart';

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
  }) : _dio = dio,
       _preferences = preferences,
       _sessionStorage = sessionStorage,
       _rootDirectoryResolver = rootDirectoryResolver;

  static const _entriesKeyPrefix = 'generation_gallery_entries_v1:';
  static const _generationScopeRoot = 'generation_gallery';
  static const _maxEntriesPerScope = 120;

  final Dio _dio;
  final SharedPreferencesAsync _preferences;
  final AuthSessionStorage _sessionStorage;
  final GenerationGalleryRootDirectoryResolver _rootDirectoryResolver;
  final Map<String, CancelToken> _downloadCancelTokens = {};
  final Map<String, Future<GenerationGalleryMediaRecord?>> _inFlightDownloads =
      {};

  Future<String?> readCurrentAccountScope() async {
    final session = await _sessionStorage.read();
    return _resolveAccountScope(session?.user.userId);
  }

  Future<List<GenerationGalleryMediaRecord>> loadLocalReadyItems() async {
    final entries = await _readEntries();
    return entries
        .where((entry) => !entry.isDeletedLocally)
        .toList(growable: false);
  }

  Future<GenerationGalleryMediaRecord?> readLocalRecord(
    String generationId,
  ) async {
    final entries = await _readEntries();
    for (final entry in entries) {
      if (entry.generationId == generationId) {
        return entry;
      }
    }
    return null;
  }

  Future<Set<String>> loadDeletedGenerationIds() async {
    final entries = await _readEntries();
    return entries
        .where((entry) => entry.isDeletedLocally)
        .map((entry) => entry.generationId)
        .toSet();
  }

  Future<List<String>> loadPendingServerDeleteIds() async {
    final entries = await _readEntries();
    return entries
        .where((entry) => entry.isDeletedLocally && entry.pendingServerDelete)
        .map((entry) => entry.generationId)
        .toList(growable: false);
  }

  Future<void> clearPendingServerDelete(String generationId) async {
    final entries = await _readEntries();
    final updated = [
      for (final entry in entries)
        if (entry.generationId == generationId)
          entry.copyWith(pendingServerDelete: false)
        else
          entry,
    ];
    await _writeEntries(updated);
  }

  Future<void> removeRecord(String generationId) async {
    final entries = await _readEntries();
    final target = entries
        .where((entry) => entry.generationId == generationId)
        .toList(growable: false);
    for (final entry in target) {
      await _deleteGenerationDirectory(entry.accountScope, generationId);
    }
    final updated = [
      for (final entry in entries)
        if (entry.generationId != generationId) entry,
    ];
    await _writeEntries(updated);
    final updatedScopes = updated.map((entry) => entry.accountScope).toSet();
    for (final scope in target.map((entry) => entry.accountScope).toSet()) {
      if (!updatedScopes.contains(scope)) {
        await _writeEntriesForScope(scope, const []);
      }
    }
  }

  Future<GenerationGalleryMediaRecord> upsertReadyItem(
    TemplateGenerationResult generation,
  ) async {
    return _upsertReadyItem(generation);
  }

  Future<GenerationGalleryMediaRecord> _upsertReadyItem(
    TemplateGenerationResult generation, {
    String? accountScopeOverride,
  }) async {
    final accountScope =
        accountScopeOverride ??
        _resolveAccountScope(generation.userId) ??
        await readCurrentAccountScope();
    if (accountScope == null || !generation.isCompleted) {
      throw StateError('Cannot persist gallery media without account scope.');
    }

    final entries = await _readEntriesForScope(accountScope);
    final existing = _findEntry(entries, generation.generationId);
    final next = GenerationGalleryMediaRecord(
      generationId: generation.generationId,
      accountScope: accountScope,
      userId: generation.userId,
      status: generation.status.name,
      templateTitle: generation.templateTitle,
      templateType: generation.templateType,
      updatedAtUtc: generation.updatedAtUtc.toUtc(),
      previewRemoteUrl: _previewUrl(generation),
      outputRemoteUrl: _cleanUrl(generation.outputUrl),
      previewLocalPath: existing?.previewLocalPath,
      outputLocalPath: existing?.outputLocalPath,
      isDeletedLocally: existing?.isDeletedLocally ?? false,
      isDownloadComplete: existing?.isDownloadComplete ?? false,
      lastSyncedAtUtc: DateTime.now().toUtc(),
      version: (existing?.version ?? 0) + 1,
      pendingServerDelete: existing?.pendingServerDelete ?? false,
    );
    final updated = _replaceEntry(entries, next);
    await _writeEntriesForScope(accountScope, updated);
    return next;
  }

  Future<void> markDeletedLocally(String generationId, {String? userId}) async {
    final entries = await _readEntries();
    var changed = false;
    final updated = <GenerationGalleryMediaRecord>[];
    for (final entry in entries) {
      if (entry.generationId != generationId) {
        updated.add(entry);
        continue;
      }

      changed = true;
      _cancelDownload(_downloadKey(entry.accountScope, generationId));
      await _deleteGenerationDirectory(entry.accountScope, generationId);
      updated.add(
        entry.copyWith(
          isDeletedLocally: true,
          previewLocalPath: null,
          outputLocalPath: null,
          isDownloadComplete: false,
          lastSyncedAtUtc: DateTime.now().toUtc(),
          version: entry.version + 1,
          pendingServerDelete: true,
        ),
      );
    }

    if (!changed) {
      final accountScope =
          _resolveAccountScope(userId) ?? await readCurrentAccountScope();
      if (accountScope == null) {
        return;
      }

      final nowUtc = DateTime.now().toUtc();
      updated.add(
        GenerationGalleryMediaRecord(
          generationId: generationId,
          accountScope: accountScope,
          userId: userId ?? accountScope,
          status: 'deleted',
          updatedAtUtc: nowUtc,
          lastSyncedAtUtc: nowUtc,
          version: 1,
          isDeletedLocally: true,
          isDownloadComplete: false,
          pendingServerDelete: true,
        ),
      );
      changed = true;
    }

    if (changed) {
      await _writeEntries(updated);
    }
  }

  Future<GenerationGalleryMediaRecord?> materializeGenerationMedia(
    TemplateGenerationResult generation,
  ) async {
    if (!generation.isCompleted) {
      return null;
    }

    final accountScope =
        _resolveAccountScope(generation.userId) ??
        await readCurrentAccountScope();
    final downloadKey = _downloadKey(
      accountScope ?? '',
      generation.generationId,
    );
    final existing = _inFlightDownloads[downloadKey];
    if (existing != null) {
      return existing;
    }

    final future = _materializeGenerationMediaInternal(
      generation,
      accountScopeOverride: accountScope,
      downloadKey: downloadKey,
    );
    _inFlightDownloads[downloadKey] = future;
    try {
      return await future;
    } finally {
      _inFlightDownloads.remove(downloadKey);
      _downloadCancelTokens.remove(downloadKey);
    }
  }

  Future<void> cancelActiveDownloads() async {
    final downloadKeys = _downloadCancelTokens.keys.toList(growable: false);
    for (final downloadKey in downloadKeys) {
      _cancelDownload(downloadKey);
    }
  }

  Future<void> purgeCurrentAccountScope() async {
    final accountScope = await readCurrentAccountScope();
    if (accountScope == null) {
      await purgeAllScopes();
      return;
    }

    await _purgeScope(accountScope);
  }

  Future<void> purgeAllScopes() async {
    await cancelActiveDownloads();
    final scopes = await _readKnownAccountScopes();
    for (final scope in scopes) {
      await _preferences.remove(_entriesKeyForScope(scope));
      await _deleteScopeDirectory(scope);
    }
  }

  Future<void> cleanupCurrentAccountArtifacts() async {
    final accountScope = await readCurrentAccountScope();
    if (accountScope == null) {
      return;
    }

    await _cleanupScopeArtifacts(accountScope);
  }

  Future<GenerationGalleryMediaRecord?> _materializeGenerationMediaInternal(
    TemplateGenerationResult generation, {
    required String? accountScopeOverride,
    required String downloadKey,
  }) async {
    final baseEntry = await _upsertReadyItem(
      generation,
      accountScopeOverride: accountScopeOverride,
    );
    if (baseEntry.isDeletedLocally) {
      return baseEntry;
    }

    final generationDirectory = await _ensureGenerationDirectory(
      baseEntry.accountScope,
      generation.generationId,
    );
    await _cleanupGenerationArtifacts(generationDirectory);

    final cancelToken = CancelToken();
    _downloadCancelTokens[downloadKey] = cancelToken;

    var previewLocalPath = baseEntry.previewLocalPath;
    var outputLocalPath = baseEntry.outputLocalPath;
    var isDownloadComplete = true;

    try {
      final previewUrl = baseEntry.previewRemoteUrl;
      if (previewUrl != null) {
        final previewFile = await _materializeRemoteFile(
          remoteUrl: previewUrl,
          targetDirectory: generationDirectory,
          prefix: 'preview',
          fallbackExtension: 'jpg',
          cancelToken: cancelToken,
        );
        previewLocalPath = previewFile?.path;
        if (previewFile == null) {
          isDownloadComplete = false;
        }
      }

      final outputUrl = baseEntry.outputRemoteUrl;
      if (outputUrl != null) {
        final outputFile = await _materializeRemoteFile(
          remoteUrl: outputUrl,
          targetDirectory: generationDirectory,
          prefix: 'result',
          fallbackExtension: _isLikelyVideoUrl(outputUrl) ? 'mp4' : 'jpg',
          cancelToken: cancelToken,
        );
        outputLocalPath = outputFile?.path;
        if (outputFile == null) {
          isDownloadComplete = false;
        }
      } else {
        isDownloadComplete = false;
      }
    } on DioException catch (error) {
      if (!CancelToken.isCancel(error)) {
        _logStoreFailure(
          'materialize_generation_media',
          error,
          StackTrace.current,
        );
      }
      isDownloadComplete = false;
    } on Object catch (error, stackTrace) {
      _logStoreFailure('materialize_generation_media', error, stackTrace);
      isDownloadComplete = false;
    }

    final refreshed = await _updateEntry(
      baseEntry.accountScope,
      generation.generationId,
      (entry) => entry.copyWith(
        previewLocalPath: previewLocalPath,
        outputLocalPath: outputLocalPath,
        isDownloadComplete:
            isDownloadComplete &&
            _isValidLocalFile(previewLocalPath, allowMissing: true) &&
            _isValidLocalFile(outputLocalPath),
        lastSyncedAtUtc: DateTime.now().toUtc(),
        version: entry.version + 1,
      ),
    );
    return refreshed;
  }

  Future<File?> _materializeRemoteFile({
    required String remoteUrl,
    required Directory targetDirectory,
    required String prefix,
    required String fallbackExtension,
    required CancelToken cancelToken,
  }) async {
    final safeUri = parseSafeGenerationMediaUri(remoteUrl);
    if (safeUri == null) {
      return null;
    }

    final extension = extensionFromUrl(safeUri.toString()).trim().isEmpty
        ? fallbackExtension
        : extensionFromUrl(safeUri.toString());
    final urlStamp = _stableUrlStamp(safeUri.toString());
    final fileName = sanitizeFileName(
      '${prefix}_$urlStamp.$extension',
      fallback: '${prefix}_$urlStamp.$fallbackExtension',
    );
    final targetFile = File(
      '${targetDirectory.path}${Platform.pathSeparator}$fileName',
    );
    if (await _hasUsableFile(targetFile)) {
      await _deleteStaleFilesForPrefix(targetDirectory, prefix, targetFile);
      return targetFile;
    }

    final tempFile = File('${targetFile.path}.part');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    await _dio.downloadUri(
      safeUri,
      tempFile.path,
      cancelToken: cancelToken,
      deleteOnError: true,
      options: Options(responseType: ResponseType.bytes),
    );

    if (!await _hasUsableFile(tempFile)) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      return null;
    }

    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempFile.rename(targetFile.path);
    await _deleteStaleFilesForPrefix(targetDirectory, prefix, targetFile);
    return targetFile;
  }

  Future<void> _deleteStaleFilesForPrefix(
    Directory targetDirectory,
    String prefix,
    File retainedFile,
  ) async {
    if (!await targetDirectory.exists()) {
      return;
    }

    final retainedPath = retainedFile.path;
    await for (final entity in targetDirectory.list()) {
      if (entity is! File || entity.path == retainedPath) {
        continue;
      }

      final fileName = _basename(entity.path);
      final isLegacyFile = fileName.startsWith('$prefix.');
      final isStampedFile = fileName.startsWith('${prefix}_');
      if (!isLegacyFile && !isStampedFile) {
        continue;
      }

      await entity.delete();
    }
  }

  Future<bool> _hasUsableFile(File file) async {
    try {
      if (!await file.exists()) {
        return false;
      }
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file || stat.size <= 0) {
        return false;
      }
      final header = await file.openRead(0, 16).toList();
      return _hasSupportedMediaSignature([
        for (final chunk in header) ...chunk,
      ]);
    } on Object {
      return false;
    }
  }

  bool _isValidLocalFile(String? path, {bool allowMissing = false}) {
    final normalized = path?.trim();
    if (normalized == null || normalized.isEmpty) {
      return allowMissing;
    }
    try {
      final file = File(normalized);
      if (!file.existsSync() || file.lengthSync() <= 0) {
        return false;
      }
      final handle = file.openSync();
      try {
        final header = handle.readSync(16);
        return _hasSupportedMediaSignature(header);
      } finally {
        handle.closeSync();
      }
    } on Object {
      return false;
    }
  }

  bool _hasSupportedMediaSignature(List<int> header) {
    if (_startsWith(header, const [0xFF, 0xD8, 0xFF])) {
      return true;
    }
    if (_startsWith(header, const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ])) {
      return true;
    }
    if (header.length >= 12 &&
        _asciiEquals(header, 0, 'RIFF') &&
        _asciiEquals(header, 8, 'WEBP')) {
      return true;
    }
    if (_asciiEquals(header, 0, 'GIF8')) {
      return true;
    }
    if (header.length >= 12 && _asciiEquals(header, 4, 'ftyp')) {
      return true;
    }
    return false;
  }

  bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) {
      return false;
    }
    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) {
        return false;
      }
    }
    return true;
  }

  bool _asciiEquals(List<int> bytes, int offset, String value) {
    if (bytes.length < offset + value.length) {
      return false;
    }
    for (var index = 0; index < value.length; index++) {
      if (bytes[offset + index] != value.codeUnitAt(index)) {
        return false;
      }
    }
    return true;
  }

  Future<List<GenerationGalleryMediaRecord>> _readEntries() async {
    final accountScope = await readCurrentAccountScope();
    if (accountScope == null) {
      return const [];
    }
    return _readEntriesForScope(accountScope);
  }

  Future<List<GenerationGalleryMediaRecord>> _readEntriesForScope(
    String accountScope,
  ) async {
    try {
      final raw = await _preferences.getString(
        _entriesKeyForScope(accountScope),
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
      _logStoreFailure('read_entries', error, stackTrace);
      return const [];
    }
  }

  Future<void> _writeEntries(List<GenerationGalleryMediaRecord> entries) async {
    final grouped = <String, List<GenerationGalleryMediaRecord>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.accountScope, () => []).add(entry);
    }

    for (final item in grouped.entries) {
      await _writeEntriesForScope(item.key, item.value);
    }
  }

  Future<void> _writeEntriesForScope(
    String accountScope,
    List<GenerationGalleryMediaRecord> entries,
  ) async {
    try {
      final prunedEntries = await _pruneEntriesForScope(accountScope, entries);
      await _preferences.setString(
        _entriesKeyForScope(accountScope),
        jsonEncode(
          prunedEntries.map((entry) => entry.toJson()).toList(growable: false),
        ),
      );
    } on Object catch (error, stackTrace) {
      _logStoreFailure('write_entries', error, stackTrace);
    }
  }

  Future<List<GenerationGalleryMediaRecord>> _pruneEntriesForScope(
    String accountScope,
    List<GenerationGalleryMediaRecord> entries,
  ) async {
    if (entries.length <= _maxEntriesPerScope) {
      return entries;
    }

    final ordered = List<GenerationGalleryMediaRecord>.from(entries)
      ..sort((left, right) {
        final bySyncedAt = right.lastSyncedAtUtc.compareTo(
          left.lastSyncedAtUtc,
        );
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
      if (retained.length >= _maxEntriesPerScope) {
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
        await _deleteGenerationDirectory(accountScope, entry.generationId);
      }
    }

    retained.sort(
      (left, right) => right.updatedAtUtc.compareTo(left.updatedAtUtc),
    );
    return retained;
  }

  Future<GenerationGalleryMediaRecord?> _updateEntry(
    String accountScope,
    String generationId,
    GenerationGalleryMediaRecord Function(GenerationGalleryMediaRecord entry)
    mutate,
  ) async {
    final entries = await _readEntriesForScope(accountScope);
    GenerationGalleryMediaRecord? next;
    final updated = [
      for (final entry in entries)
        if (entry.generationId == generationId) next = mutate(entry) else entry,
    ].cast<GenerationGalleryMediaRecord>();
    if (next != null) {
      await _writeEntriesForScope(accountScope, updated);
    }
    return next;
  }

  List<GenerationGalleryMediaRecord> _replaceEntry(
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

  GenerationGalleryMediaRecord? _findEntry(
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

  String _entriesKeyForScope(String accountScope) {
    return '$_entriesKeyPrefix$accountScope';
  }

  Future<Set<String>> _readKnownAccountScopes() async {
    try {
      final keys = await _preferences.getKeys();
      return keys
          .where((key) => key.startsWith(_entriesKeyPrefix))
          .map((key) => key.substring(_entriesKeyPrefix.length))
          .where((scope) => scope.trim().isNotEmpty)
          .toSet();
    } on Object catch (error, stackTrace) {
      _logStoreFailure('read_known_account_scopes', error, stackTrace);
      final entries = await _readEntries();
      return entries.map((entry) => entry.accountScope).toSet();
    }
  }

  String? _resolveAccountScope(String? rawUserId) {
    final value = rawUserId?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<Directory> _ensureGenerationDirectory(
    String accountScope,
    String generationId,
  ) async {
    final root = await _rootDirectoryResolver();
    final scopeSegment = _safePathSegment(accountScope, fallback: 'account');
    final generationSegment = _safePathSegment(
      generationId,
      fallback: 'generation',
    );
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}'
      '$_generationScopeRoot${Platform.pathSeparator}'
      '$scopeSegment${Platform.pathSeparator}$generationSegment',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> _deleteGenerationDirectory(
    String accountScope,
    String generationId,
  ) async {
    final root = await _rootDirectoryResolver();
    final scopeSegment = _safePathSegment(accountScope, fallback: 'account');
    final generationSegment = _safePathSegment(
      generationId,
      fallback: 'generation',
    );
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}'
      '$_generationScopeRoot${Platform.pathSeparator}'
      '$scopeSegment${Platform.pathSeparator}$generationSegment',
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> _deleteScopeDirectory(String accountScope) async {
    final root = await _rootDirectoryResolver();
    final scopeSegment = _safePathSegment(accountScope, fallback: 'account');
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}'
      '$_generationScopeRoot${Platform.pathSeparator}$scopeSegment',
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> _purgeScope(String accountScope) async {
    await cancelActiveDownloads();
    await _preferences.remove(_entriesKeyForScope(accountScope));
    await _deleteScopeDirectory(accountScope);
  }

  Future<void> _cleanupScopeArtifacts(String accountScope) async {
    final root = await _rootDirectoryResolver();
    final scopeDirectory = Directory(
      '${root.path}${Platform.pathSeparator}'
      '$_generationScopeRoot${Platform.pathSeparator}'
      '${_safePathSegment(accountScope, fallback: 'account')}',
    );
    if (!await scopeDirectory.exists()) {
      return;
    }

    final entries = await _readEntriesForScope(accountScope);
    final knownIds = entries
        .map(
          (entry) =>
              _safePathSegment(entry.generationId, fallback: 'generation'),
        )
        .toSet();
    await for (final entity in scopeDirectory.list()) {
      if (entity is! Directory) {
        continue;
      }

      final generationId = entity.uri.pathSegments.isEmpty
          ? ''
          : entity.uri.pathSegments.lastWhere(
              (segment) => segment.isNotEmpty,
              orElse: () => '',
            );
      if (generationId.isEmpty) {
        continue;
      }

      if (!knownIds.contains(generationId)) {
        await entity.delete(recursive: true);
        continue;
      }

      await _cleanupGenerationArtifacts(entity);
    }
  }

  Future<void> _cleanupGenerationArtifacts(
    Directory generationDirectory,
  ) async {
    if (!await generationDirectory.exists()) {
      return;
    }

    await for (final entity in generationDirectory.list()) {
      if (entity is File && entity.path.endsWith('.part')) {
        await entity.delete();
      }
    }
  }

  void _cancelDownload(String generationId) {
    final token = _downloadCancelTokens.remove(generationId);
    if (token != null && !token.isCancelled) {
      token.cancel('gallery_cleanup');
    }
  }

  void _logStoreFailure(String stage, Object error, StackTrace stackTrace) {
    AppLogger.warn(
      feature: 'Templates.GenerationGalleryStore',
      operation: stage,
      message: 'Generation gallery store operation failed',
      context: {'stage': stage},
      error: error,
      stackTrace: stackTrace,
    );
  }
}

const Object _copyWithUnset = Object();

class GenerationGalleryMediaRecord {
  const GenerationGalleryMediaRecord({
    required this.generationId,
    required this.accountScope,
    required this.userId,
    required this.status,
    required this.updatedAtUtc,
    required this.lastSyncedAtUtc,
    required this.version,
    this.templateTitle,
    this.templateType,
    this.previewRemoteUrl,
    this.outputRemoteUrl,
    this.previewLocalPath,
    this.outputLocalPath,
    this.isDeletedLocally = false,
    this.isDownloadComplete = false,
    this.pendingServerDelete = false,
  });

  final String generationId;
  final String accountScope;
  final String userId;
  final String status;
  final String? templateTitle;
  final String? templateType;
  final DateTime updatedAtUtc;
  final String? previewRemoteUrl;
  final String? outputRemoteUrl;
  final String? previewLocalPath;
  final String? outputLocalPath;
  final bool isDeletedLocally;
  final bool isDownloadComplete;
  final DateTime lastSyncedAtUtc;
  final int version;
  final bool pendingServerDelete;

  GenerationGalleryMediaRecord copyWith({
    Object? previewLocalPath = _copyWithUnset,
    Object? outputLocalPath = _copyWithUnset,
    bool? isDeletedLocally,
    bool? isDownloadComplete,
    DateTime? lastSyncedAtUtc,
    int? version,
    bool? pendingServerDelete,
  }) {
    return GenerationGalleryMediaRecord(
      generationId: generationId,
      accountScope: accountScope,
      userId: userId,
      status: status,
      updatedAtUtc: updatedAtUtc,
      lastSyncedAtUtc: lastSyncedAtUtc ?? this.lastSyncedAtUtc,
      version: version ?? this.version,
      templateTitle: templateTitle,
      templateType: templateType,
      previewRemoteUrl: previewRemoteUrl,
      outputRemoteUrl: outputRemoteUrl,
      previewLocalPath: identical(previewLocalPath, _copyWithUnset)
          ? this.previewLocalPath
          : previewLocalPath as String?,
      outputLocalPath: identical(outputLocalPath, _copyWithUnset)
          ? this.outputLocalPath
          : outputLocalPath as String?,
      isDeletedLocally: isDeletedLocally ?? this.isDeletedLocally,
      isDownloadComplete: isDownloadComplete ?? this.isDownloadComplete,
      pendingServerDelete: pendingServerDelete ?? this.pendingServerDelete,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'generationId': generationId,
      'accountScope': accountScope,
      'userId': userId,
      'status': status,
      'templateTitle': templateTitle,
      'templateType': templateType,
      'updatedAtUtc': updatedAtUtc.toIso8601String(),
      'previewRemoteUrl': previewRemoteUrl,
      'outputRemoteUrl': outputRemoteUrl,
      'previewLocalPath': previewLocalPath,
      'outputLocalPath': outputLocalPath,
      'isDeletedLocally': isDeletedLocally,
      'isDownloadComplete': isDownloadComplete,
      'lastSyncedAtUtc': lastSyncedAtUtc.toIso8601String(),
      'version': version,
      'pendingServerDelete': pendingServerDelete,
    };
  }

  factory GenerationGalleryMediaRecord.fromJson(Map<String, dynamic> json) {
    return GenerationGalleryMediaRecord(
      generationId: json['generationId'] as String? ?? '',
      accountScope: json['accountScope'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      status: json['status'] as String? ?? '',
      templateTitle: json['templateTitle'] as String?,
      templateType: json['templateType'] as String?,
      updatedAtUtc:
          DateTime.tryParse(json['updatedAtUtc'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      previewRemoteUrl: json['previewRemoteUrl'] as String?,
      outputRemoteUrl: json['outputRemoteUrl'] as String?,
      previewLocalPath: json['previewLocalPath'] as String?,
      outputLocalPath: json['outputLocalPath'] as String?,
      isDeletedLocally: json['isDeletedLocally'] as bool? ?? false,
      isDownloadComplete: json['isDownloadComplete'] as bool? ?? false,
      lastSyncedAtUtc:
          DateTime.tryParse(
            json['lastSyncedAtUtc'] as String? ?? '',
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      version: (json['version'] as num?)?.toInt() ?? 0,
      pendingServerDelete: json['pendingServerDelete'] as bool? ?? false,
    );
  }
}

String? _previewUrl(TemplateGenerationResult generation) {
  final output = _cleanUrl(generation.outputUrl);
  final source = _cleanUrl(generation.sourceImageAsset?.url);
  final normalized = _cleanUrl(generation.normalizedImageUrl);
  final generationIsVideo = _isVideoGeneration(generation);

  if (generationIsVideo) {
    if (source != null) {
      return source;
    }
    if (normalized != null) {
      return normalized;
    }
    return output != null && !_isLikelyVideoUrl(output) ? output : null;
  }

  if (output != null && !_isLikelyVideoUrl(output)) {
    return output;
  }
  if (source != null) {
    return source;
  }
  if (normalized != null) {
    return normalized;
  }
  return null;
}

bool _isVideoGeneration(TemplateGenerationResult generation) {
  final type = generation.templateType?.toLowerCase() ?? '';
  return type.contains('video') ||
      generation.outputVideoDurationSeconds != null ||
      _isLikelyVideoUrl(generation.outputUrl);
}

String? _cleanUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

bool _isLikelyVideoUrl(String? rawUrl) {
  final url = _cleanUrl(rawUrl);
  if (url == null) {
    return false;
  }

  final normalized = url.toLowerCase();
  final uri = Uri.tryParse(normalized);
  final path = (uri?.path ?? normalized).toLowerCase();
  final query = (uri?.query ?? '').toLowerCase();

  return path.endsWith('.mp4') ||
      path.endsWith('.webm') ||
      path.endsWith('.mov') ||
      path.endsWith('.m4v') ||
      normalized.contains('.mp4?') ||
      normalized.contains('.webm?') ||
      normalized.contains('.mov?') ||
      normalized.contains('.m4v?') ||
      query.contains('format=mp4') ||
      query.contains('ext=mp4') ||
      query.contains('contenttype=video');
}

String _stableUrlStamp(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash = (hash ^ codeUnit) & 0xffffffff;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String _safePathSegment(String value, {required String fallback}) {
  final trimmed = value.trim();
  final sanitized = sanitizeFileName(trimmed, fallback: fallback);
  final isSpecialDirectory = sanitized == '.' || sanitized == '..';
  if (!isSpecialDirectory && sanitized == trimmed) {
    return sanitized;
  }

  final base = isSpecialDirectory ? fallback : sanitized;
  final boundedBase = base.length <= 80 ? base : base.substring(0, 80);
  return '${boundedBase}_${_stableUrlStamp(trimmed)}';
}

String _downloadKey(String accountScope, String generationId) {
  return '$accountScope\u{1F}$generationId';
}

String _basename(String path) {
  final parts = path.split(Platform.pathSeparator);
  return parts.isEmpty ? path : parts.last;
}
