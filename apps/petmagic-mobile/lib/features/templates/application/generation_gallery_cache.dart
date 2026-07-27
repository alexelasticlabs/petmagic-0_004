import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';

final generationGalleryStoreProvider = Provider<GenerationGalleryCache>((ref) {
  return const _NoopGenerationGalleryCache();
});

abstract interface class GenerationGalleryMediaRecordView {
  String get generationId;
  String get accountScope;
  String get userId;
  String get status;
  String? get templateTitle;
  String? get templateType;
  DateTime get updatedAtUtc;
  String? get previewRemoteUrl;
  String? get outputRemoteUrl;
  String? get previewLocalPath;
  String? get outputLocalPath;
  bool get isDeletedLocally;
  bool get isDownloadComplete;
  DateTime get lastSyncedAtUtc;
  int get version;
  bool get pendingServerDelete;
  int get localBytes;
}

abstract interface class GenerationGalleryCache {
  Future<String?> readCurrentAccountScope();
  Future<List<GenerationGalleryMediaRecordView>> loadLocalReadyItems();
  Future<GenerationGalleryMediaRecordView?> readLocalRecord(
    String generationId,
  );
  Future<Set<String>> loadDeletedGenerationIds();
  Future<List<String>> loadPendingServerDeleteIds();
  Future<void> clearPendingServerDelete(String generationId);
  Future<void> removeRecord(String generationId);
  Future<GenerationGalleryMediaRecordView> upsertReadyItem(
    TemplateGenerationResult generation,
  );
  Future<void> markDeletedLocally(String generationId, {String? userId});
  Future<GenerationGalleryMediaRecordView?> materializeGenerationMedia(
    TemplateGenerationResult generation, {
    bool background = false,
  });
  Future<void> cancelActiveDownloads();
  Future<void> clearCurrentAccountDownloads();
  Future<void> purgeCurrentAccountScope();
  Future<void> purgeAllScopes();
  Future<void> cleanupCurrentAccountArtifacts();
}

/// Safe null object for isolated widgets that do not persist gallery media.
/// The production composition root always overrides this provider.
final class _NoopGenerationGalleryCache implements GenerationGalleryCache {
  const _NoopGenerationGalleryCache();

  @override
  Future<void> cancelActiveDownloads() async {}

  @override
  Future<void> clearCurrentAccountDownloads() async {}

  @override
  Future<void> cleanupCurrentAccountArtifacts() async {}

  @override
  Future<void> clearPendingServerDelete(String generationId) async {}

  @override
  Future<Set<String>> loadDeletedGenerationIds() async => const {};

  @override
  Future<List<GenerationGalleryMediaRecordView>> loadLocalReadyItems() async =>
      const [];

  @override
  Future<List<String>> loadPendingServerDeleteIds() async => const [];

  @override
  Future<void> markDeletedLocally(
    String generationId, {
    String? userId,
  }) async {}

  @override
  Future<GenerationGalleryMediaRecordView?> materializeGenerationMedia(
    TemplateGenerationResult generation, {
    bool background = false,
  }) async => null;

  @override
  Future<void> purgeAllScopes() async {}

  @override
  Future<void> purgeCurrentAccountScope() async {}

  @override
  Future<String?> readCurrentAccountScope() async => null;

  @override
  Future<GenerationGalleryMediaRecordView?> readLocalRecord(
    String generationId,
  ) async => null;

  @override
  Future<void> removeRecord(String generationId) async {}

  @override
  Future<GenerationGalleryMediaRecordView> upsertReadyItem(
    TemplateGenerationResult generation,
  ) async => _NoopGenerationGalleryRecord(generation);
}

final class _NoopGenerationGalleryRecord
    implements GenerationGalleryMediaRecordView {
  const _NoopGenerationGalleryRecord(this.generation);

  final TemplateGenerationResult generation;

  @override
  String get generationId => generation.generationId;
  @override
  String get accountScope => 'none';
  @override
  String get userId => generation.userId;
  @override
  String get status => generation.status.name;
  @override
  String? get templateTitle => generation.templateTitle;
  @override
  String? get templateType => generation.templateType;
  @override
  DateTime get updatedAtUtc => generation.updatedAtUtc;
  @override
  String? get previewRemoteUrl => generation.resultPreviewUrl;
  @override
  String? get outputRemoteUrl => generation.outputUrl;
  @override
  String? get previewLocalPath => null;
  @override
  String? get outputLocalPath => null;
  @override
  bool get isDeletedLocally => false;
  @override
  bool get isDownloadComplete => false;
  @override
  DateTime get lastSyncedAtUtc => generation.updatedAtUtc;
  @override
  int get version => 1;
  @override
  bool get pendingServerDelete => false;
  @override
  int get localBytes => 0;
}
