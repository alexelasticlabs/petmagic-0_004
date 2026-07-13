import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:petmagic_mobile/shared/files/file_name_sanitizer.dart';
import 'package:petmagic_mobile/shared/files/media_signature.dart';

typedef GalleryRootDirectoryResolver = Future<Directory> Function();

/// Owns sandboxed generation-gallery filesystem operations.
class GenerationGalleryFileStorage {
  const GenerationGalleryFileStorage({
    required GalleryRootDirectoryResolver rootDirectoryResolver,
    required String scopeRoot,
  }) : _rootDirectoryResolver = rootDirectoryResolver,
       _scopeRoot = scopeRoot;

  final GalleryRootDirectoryResolver _rootDirectoryResolver;
  final String _scopeRoot;

  static Future<void> deleteStaleFilesForPrefix(
    Directory targetDirectory,
    String prefix,
    File retainedFile,
  ) async {
    try {
      if (!await targetDirectory.exists()) {
        return;
      }
      final retainedPath = retainedFile.path;
      await for (final entity in targetDirectory.list()) {
        if (entity is! File || entity.path == retainedPath) {
          continue;
        }
        final fileName = _basename(entity.path);
        if (_matchesPrefix(fileName, prefix)) {
          await entity.delete();
        }
      }
    } on Object {
      // Local cache cleanup is best effort.
    }
  }

  static Future<void> deleteFilesForPrefix(
    Directory targetDirectory,
    String prefix,
  ) async {
    try {
      if (!await targetDirectory.exists()) {
        return;
      }
      await for (final entity in targetDirectory.list()) {
        if (entity is File && _matchesPrefix(_basename(entity.path), prefix)) {
          await entity.delete();
        }
      }
    } on Object {
      // Local cache cleanup is best effort.
    }
  }

  static Future<bool> hasUsableFile(File file) async {
    try {
      if (!await file.exists()) {
        return false;
      }
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file || stat.size <= 0) {
        return false;
      }
      final header = await file.openRead(0, 16).toList();
      return hasSupportedMediaSignature([for (final chunk in header) ...chunk]);
    } on Object {
      return false;
    }
  }

  static Future<int> fileSize(File file) async {
    try {
      if (!await file.exists()) {
        return 0;
      }
      final stat = await file.stat();
      return stat.type == FileSystemEntityType.file ? stat.size : 0;
    } on Object {
      return 0;
    }
  }

  static Future<int> calculateLocalBytes(Iterable<String?> paths) async {
    var total = 0;
    final seen = <String>{};
    for (final path in paths) {
      final normalized = path?.trim();
      if (normalized == null || normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      total += await fileSize(File(normalized));
    }
    return total;
  }

  static bool isValidLocalFile(String? path, {bool allowMissing = false}) {
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
        return hasSupportedMediaSignature(handle.readSync(16));
      } finally {
        handle.closeSync();
      }
    } on Object {
      return false;
    }
  }

  static String? persistedLocalPath(Directory root, String? path) {
    final normalized = path?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final normalizedPath = _normalizedAbsolutePath(normalized);
    final normalizedRoot = _normalizedAbsoluteDirectoryPath(root);
    if (!normalizedPath.startsWith(normalizedRoot)) {
      return normalized;
    }
    if (normalizedPath.length <= normalizedRoot.length) {
      return null;
    }
    final absoluteOriginal = File(
      normalized,
    ).absolute.uri.normalizePath().toFilePath(windows: Platform.isWindows);
    return absoluteOriginal
        .substring(normalizedRoot.length)
        .split(RegExp(r'[\\/]'))
        .where((segment) => segment.isNotEmpty)
        .join('/');
  }

  Future<Directory> ensureGenerationDirectory(
    String accountScope,
    String generationId,
  ) async {
    final directory = await generationDirectory(accountScope, generationId);
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> deleteGenerationDirectory(
    String accountScope,
    String generationId,
  ) async {
    final directory = await generationDirectory(accountScope, generationId);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<Directory> generationDirectory(
    String accountScope,
    String generationId,
  ) async {
    final root = await _rootDirectoryResolver();
    return Directory(
      '${root.path}${Platform.pathSeparator}'
      '$_scopeRoot${Platform.pathSeparator}'
      '${_scopeStorageSegment(accountScope)}${Platform.pathSeparator}'
      '${_safePathSegment(generationId, fallback: 'generation')}',
    );
  }

  Future<String?> trustedLocalPath(
    String accountScope,
    String generationId,
    String? path,
  ) async {
    final normalized = path?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final expectedDirectory = await generationDirectory(
      accountScope,
      generationId,
    );
    final resolved = await resolvePersistedLocalPath(normalized);
    return _isPathInsideDirectory(resolved, expectedDirectory)
        ? resolved
        : null;
  }

  Future<String> resolvePersistedLocalPath(String path) async {
    if (File(path).isAbsolute) {
      return path;
    }
    final segments = path
        .split(RegExp(r'[\\/]'))
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty ||
        segments.any((segment) => segment == '.' || segment == '..')) {
      return path;
    }
    final root = await _rootDirectoryResolver();
    return ([root.path, ...segments]).join(Platform.pathSeparator);
  }

  Future<void> deleteScopeDirectory(String accountScope) async {
    final root = await _rootDirectoryResolver();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}'
      '$_scopeRoot${Platform.pathSeparator}${_scopeStorageSegment(accountScope)}',
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> deleteRootDirectory() async {
    final root = await _rootDirectoryResolver();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}$_scopeRoot',
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> cleanupScopeArtifactsForKnownIds(
    String accountScope,
    Set<String> knownGenerationIds, {
    required Set<String> activeGenerationIds,
  }) async {
    final root = await _rootDirectoryResolver();
    final scopeDirectory = Directory(
      '${root.path}${Platform.pathSeparator}'
      '$_scopeRoot${Platform.pathSeparator}${_scopeStorageSegment(accountScope)}',
    );
    if (!await scopeDirectory.exists()) {
      return;
    }
    final knownIds = knownGenerationIds
        .map((id) => _safePathSegment(id, fallback: 'generation'))
        .toSet();
    final activeIds = activeGenerationIds
        .map((id) => _safePathSegment(id, fallback: 'generation'))
        .toSet();
    await for (final entity in scopeDirectory.list()) {
      if (entity is! Directory) {
        continue;
      }
      final generationId = entity.uri.pathSegments.lastWhere(
        (segment) => segment.isNotEmpty,
        orElse: () => '',
      );
      if (generationId.isEmpty || activeIds.contains(generationId)) {
        continue;
      }
      if (!knownIds.contains(generationId)) {
        await entity.delete(recursive: true);
      } else {
        await cleanupGenerationArtifacts(entity);
      }
    }
  }

  Future<void> deleteLocalPath(
    String accountScope,
    String generationId,
    String? path,
  ) async {
    final normalized = await trustedLocalPath(accountScope, generationId, path);
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    try {
      final file = File(normalized);
      if (await file.exists()) {
        await file.delete();
      }
      final partFile = File('$normalized.part');
      if (await partFile.exists()) {
        await partFile.delete();
      }
    } on Object {
      // Stale cache artifacts will be retried during a later cleanup.
    }
  }

  static Future<void> cleanupGenerationArtifacts(
    Directory generationDirectory,
  ) async {
    try {
      if (!await generationDirectory.exists()) {
        return;
      }
      await for (final entity in generationDirectory.list()) {
        if (entity is File && entity.path.endsWith('.part')) {
          await entity.delete();
        }
      }
    } on Object {
      // Materialization can recreate safe files after best-effort cleanup.
    }
  }

  static bool _matchesPrefix(String fileName, String prefix) {
    return fileName.startsWith('$prefix.') || fileName.startsWith('${prefix}_');
  }

  static bool _isPathInsideDirectory(String path, Directory directory) {
    return _normalizedAbsolutePath(
      path,
    ).startsWith(_normalizedAbsoluteDirectoryPath(directory));
  }

  static String _normalizedAbsoluteDirectoryPath(Directory directory) {
    final normalized = _normalizedAbsolutePath(directory.path);
    return normalized.endsWith(Platform.pathSeparator)
        ? normalized
        : '$normalized${Platform.pathSeparator}';
  }

  static String _normalizedAbsolutePath(String path) {
    final normalized = File(
      path,
    ).absolute.uri.normalizePath().toFilePath(windows: Platform.isWindows);
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  static String _scopeStorageSegment(String accountScope) {
    final normalized = accountScope.trim().toLowerCase();
    return 'scope_${sha256.convert(utf8.encode(normalized))}';
  }

  static String _safePathSegment(String value, {required String fallback}) {
    final trimmed = value.trim();
    final sanitized = sanitizeFileName(trimmed, fallback: fallback);
    final isSpecialDirectory = sanitized == '.' || sanitized == '..';
    if (!isSpecialDirectory && sanitized == trimmed && sanitized.length <= 80) {
      return sanitized;
    }
    final base = isSpecialDirectory ? fallback : sanitized;
    final boundedBase = base.length <= 80 ? base : base.substring(0, 80);
    return '${boundedBase}_${_stableStamp(trimmed)}';
  }

  static String _stableStamp(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash = (hash ^ codeUnit) & 0xffffffff;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String _basename(String path) {
    final parts = path.split(Platform.pathSeparator);
    return parts.isEmpty ? path : parts.last;
  }
}
