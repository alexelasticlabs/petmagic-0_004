import 'package:petmagic_mobile/features/templates/data/generation_gallery_file_storage.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_media_record.dart';

/// Applies local tombstones while deleting only sandboxed generation media.
class GenerationGalleryDeletionCoordinator {
  const GenerationGalleryDeletionCoordinator({
    required GenerationGalleryFileStorage fileStorage,
    required Future<List<GenerationGalleryMediaRecord>> Function() readEntries,
    required Future<void> Function(List<GenerationGalleryMediaRecord> entries)
    writeEntries,
    required void Function(String downloadKey) cancelDownload,
    required DateTime Function() clock,
  }) : _fileStorage = fileStorage,
       _readEntries = readEntries,
       _writeEntries = writeEntries,
       _cancelDownload = cancelDownload,
       _clock = clock;

  final GenerationGalleryFileStorage _fileStorage;
  final Future<List<GenerationGalleryMediaRecord>> Function() _readEntries;
  final Future<void> Function(List<GenerationGalleryMediaRecord> entries)
  _writeEntries;
  final void Function(String downloadKey) _cancelDownload;
  final DateTime Function() _clock;

  Future<void> markDeleted(
    String generationId, {
    required String? userId,
    required Future<String?> Function() resolveAccountScope,
  }) async {
    final entries = await _readEntries();
    var changed = false;
    final updated = <GenerationGalleryMediaRecord>[];
    for (final entry in entries) {
      if (entry.generationId != generationId) {
        updated.add(entry);
        continue;
      }
      changed = true;
      _cancelDownload(galleryDownloadKey(entry.accountScope, generationId));
      await _fileStorage.deleteGenerationDirectory(
        entry.accountScope,
        generationId,
      );
      updated.add(
        entry.copyWith(
          isDeletedLocally: true,
          previewLocalPath: null,
          outputLocalPath: null,
          isDownloadComplete: false,
          lastSyncedAtUtc: _clock().toUtc(),
          version: entry.version + 1,
          pendingServerDelete: true,
        ),
      );
    }

    if (!changed) {
      final accountScope = await resolveAccountScope();
      if (accountScope == null) {
        return;
      }
      final nowUtc = _clock().toUtc();
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
          pendingServerDelete: true,
        ),
      );
      changed = true;
    }
    if (changed) {
      await _writeEntries(updated);
    }
  }
}
