part of 'template_generation_models.dart';

enum TemplateGenerationStatus {
  queued,
  uploading,
  processing,
  preprocessing,
  generating,
  finalizing,
  submittingToProvider,
  providerQueued,
  providerProcessing,
  importingMedia,
  cancellationRequested,
  completed,
  failed,
  cancelled,
}

enum GalleryMediaState {
  pending,
  processing,
  resultReady,
  previewReadyOnly,
  watermarkPreparing,
  expired,
  storageUnavailable,
  failed,
  hidden,
}

GalleryMediaState galleryMediaStateFromApi(String? value) {
  return switch ((value ?? '').trim().toLowerCase()) {
    'resultready' ||
    'result_ready' ||
    'result-ready' => GalleryMediaState.resultReady,
    'previewreadyonly' ||
    'preview_ready_only' ||
    'preview-ready-only' => GalleryMediaState.previewReadyOnly,
    'watermarkpreparing' ||
    'watermark_preparing' ||
    'watermark-preparing' => GalleryMediaState.watermarkPreparing,
    'expired' => GalleryMediaState.expired,
    'storageunavailable' ||
    'storage_unavailable' ||
    'storage-unavailable' => GalleryMediaState.storageUnavailable,
    'failed' => GalleryMediaState.failed,
    'hidden' => GalleryMediaState.hidden,
    'processing' => GalleryMediaState.processing,
    _ => GalleryMediaState.pending,
  };
}

class GalleryMedia {
  const GalleryMedia({
    this.state = GalleryMediaState.pending,
    this.mediaType = 'image',
    this.previewUrl,
    this.resultUrl,
    this.resultExpiresAtUtc,
    this.durationSeconds,
    this.hasWatermark = false,
    this.canRemoveWatermark = false,
    this.isWatermarkRemoved = false,
    this.canDownload = false,
    this.canShare = false,
    this.reasonCode,
    this.userMessageKey,
    this.retryAfterSeconds,
  });

  final GalleryMediaState state;
  final String mediaType;
  final String? previewUrl;
  final String? resultUrl;
  final DateTime? resultExpiresAtUtc;
  final double? durationSeconds;
  final bool hasWatermark;
  final bool canRemoveWatermark;
  final bool isWatermarkRemoved;
  final bool canDownload;
  final bool canShare;
  final String? reasonCode;
  final String? userMessageKey;
  final int? retryAfterSeconds;

  bool get hasActionableResult =>
      state == GalleryMediaState.resultReady && resultUrl != null;

  bool get needsExplanation =>
      state == GalleryMediaState.previewReadyOnly ||
      state == GalleryMediaState.watermarkPreparing ||
      state == GalleryMediaState.expired ||
      state == GalleryMediaState.storageUnavailable ||
      state == GalleryMediaState.failed ||
      state == GalleryMediaState.hidden;
}

TemplateGenerationStatus templateGenerationStatusFromApi(String value) {
  return switch (value.trim().toLowerCase()) {
    '1' => TemplateGenerationStatus.queued,
    '2' => TemplateGenerationStatus.processing,
    '3' => TemplateGenerationStatus.completed,
    '4' => TemplateGenerationStatus.failed,
    '5' => TemplateGenerationStatus.cancelled,
    '6' => TemplateGenerationStatus.processing,
    '7' => TemplateGenerationStatus.submittingToProvider,
    '8' => TemplateGenerationStatus.providerQueued,
    '9' => TemplateGenerationStatus.providerProcessing,
    '10' => TemplateGenerationStatus.importingMedia,
    '11' => TemplateGenerationStatus.cancellationRequested,
    'uploading' => TemplateGenerationStatus.uploading,
    'processing' => TemplateGenerationStatus.processing,
    'preprocessing' => TemplateGenerationStatus.preprocessing,
    'generating' => TemplateGenerationStatus.generating,
    'finalizing' => TemplateGenerationStatus.finalizing,
    'submittingtoprovider' ||
    'submitting_to_provider' ||
    'submitting-to-provider' => TemplateGenerationStatus.submittingToProvider,
    'providerqueued' ||
    'provider_queued' ||
    'provider-queued' => TemplateGenerationStatus.providerQueued,
    'providerprocessing' ||
    'provider_processing' ||
    'provider-processing' => TemplateGenerationStatus.providerProcessing,
    'importingmedia' ||
    'importing_media' ||
    'importing-media' => TemplateGenerationStatus.importingMedia,
    'cancellationrequested' ||
    'cancellation_requested' ||
    'cancellation-requested' => TemplateGenerationStatus.cancellationRequested,
    'completed' => TemplateGenerationStatus.completed,
    'succeeded' => TemplateGenerationStatus.completed,
    'failed' => TemplateGenerationStatus.failed,
    'cancelled' || 'canceled' => TemplateGenerationStatus.cancelled,
    _ => TemplateGenerationStatus.queued,
  };
}
