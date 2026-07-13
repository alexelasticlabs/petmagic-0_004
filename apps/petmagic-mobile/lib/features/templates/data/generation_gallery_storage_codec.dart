import 'dart:convert';

import 'package:petmagic_mobile/features/templates/data/generation_gallery_file_storage.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_media_record.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';

/// Encodes gallery records and restores only paths inside their account scope.
class GenerationGalleryStorageCodec {
  const GenerationGalleryStorageCodec({
    required GalleryRootDirectoryResolver rootDirectoryResolver,
    required GenerationGalleryFileStorage fileStorage,
  }) : _rootDirectoryResolver = rootDirectoryResolver,
       _fileStorage = fileStorage;

  final GalleryRootDirectoryResolver _rootDirectoryResolver;
  final GenerationGalleryFileStorage _fileStorage;

  Future<String> encode(List<GenerationGalleryMediaRecord> entries) async {
    final root = await _rootDirectoryResolver();
    return jsonEncode(
      entries
          .map(
            (entry) => entry.toJson(
              localPathMapper: (path) =>
                  GenerationGalleryFileStorage.persistedLocalPath(root, path),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<List<GenerationGalleryMediaRecord>> sanitizeLocalPaths(
    String accountScope,
    List<GenerationGalleryMediaRecord> entries,
  ) async {
    final sanitized = <GenerationGalleryMediaRecord>[];
    for (final entry in entries) {
      final previewLocalPath = await _fileStorage.trustedLocalPath(
        accountScope,
        entry.generationId,
        entry.previewLocalPath,
      );
      final outputLocalPath = await _fileStorage.trustedLocalPath(
        accountScope,
        entry.generationId,
        entry.outputLocalPath,
      );
      final localPathsChanged =
          previewLocalPath != entry.previewLocalPath ||
          outputLocalPath != entry.outputLocalPath;
      final localPathsRejected =
          (entry.previewLocalPath?.trim().isNotEmpty ?? false) &&
              previewLocalPath == null ||
          (entry.outputLocalPath?.trim().isNotEmpty ?? false) &&
              outputLocalPath == null;
      sanitized.add(
        localPathsChanged
            ? entry.copyWith(
                previewLocalPath: previewLocalPath,
                outputLocalPath: outputLocalPath,
                isDownloadComplete: localPathsRejected
                    ? false
                    : entry.isDownloadComplete,
                localBytes: localPathsRejected ? 0 : entry.localBytes,
              )
            : entry,
      );
    }
    return sanitized;
  }

  static bool safeMediaUriEquals(String left, String right) {
    final leftSafe = persistentSafeGenerationMediaUrl(left);
    final rightSafe = persistentSafeGenerationMediaUrl(right);
    return leftSafe != null && rightSafe != null && leftSafe == rightSafe;
  }

  static bool safeNullableMediaUriEquals(String? left, String? right) {
    if (left == null && right == null) {
      return true;
    }
    if (left == null || right == null) {
      return false;
    }
    return safeMediaUriEquals(left, right);
  }
}
