part of 'template_flow_sheets.dart';

double? _progressValue(TemplateGenerationResult? generation, bool isFailed) {
  if (isFailed) {
    return 1;
  }
  if (generation == null) {
    return 0.18;
  }

  return switch (generation.stage) {
    'submitting_preprocess' || 'preprocess_provider_queued' => 0.44,
    'preprocess_provider_processing' => 0.52,
    'video_provider_queued' => 0.64,
    'video_provider_processing' => 0.74,
    _ => _progressValueForStatus(generation),
  };
}

double _progressValueForStatus(TemplateGenerationResult generation) {
  return switch (generation.status) {
    TemplateGenerationStatus.queued => 0.28,
    TemplateGenerationStatus.uploading => 0.36,
    TemplateGenerationStatus.submittingToProvider => 0.40,
    TemplateGenerationStatus.providerQueued => 0.44,
    TemplateGenerationStatus.preprocessing => 0.52,
    TemplateGenerationStatus.processing =>
      generation.motionGenerationCompletedAtUtc != null
          ? 0.82
          : generation.preprocessingCompletedAtUtc != null
          ? 0.64
          : 0.48,
    TemplateGenerationStatus.providerProcessing => 0.68,
    TemplateGenerationStatus.generating => 0.74,
    TemplateGenerationStatus.finalizing => 0.9,
    TemplateGenerationStatus.importingMedia => 0.92,
    TemplateGenerationStatus.cancellationRequested => 0.95,
    TemplateGenerationStatus.completed => 1,
    TemplateGenerationStatus.cancelled => 1,
    TemplateGenerationStatus.failed => 1,
  };
}

String _generationErrorText(AppLocalizations text, String raw) {
  final authMessage = mapCommonAuthFeedbackMessage(text, raw);
  if (authMessage != null) {
    return authMessage;
  }

  return switch (normalizeTemplateErrorKey(raw)) {
    'templates.premium_required' => text.templateFlowPremiumRequiredError,
    'templates.insufficient_balance' =>
      text.templateFlowInsufficientBalanceError,
    'templates.generation_already_started' =>
      text.templateFlowActiveGenerationLimitError,
    'templates.generation_wait_too_long' => text.templateFlowServerError,
    'templates.template_unavailable' =>
      text.templateFlowTemplateUnavailableError,
    'templates.template_changed' => text.templateFlowTemplateChangedError,
    'templates.network_unavailable' ||
    'templates.connection_timeout' => text.templateFlowNetworkError,
    'templates.server_unavailable' ||
    'templates.server_timeout' => text.templateFlowServerError,
    _ => text.templateFlowStartFailedError,
  };
}

String _formatLocalizedWaitDuration(AppLocalizations text, int totalSeconds) {
  final minutes = (totalSeconds / 60).ceil().clamp(1, 24 * 60);
  return text.generationStatusWaitMinutes(minutes);
}

String _templateHeroTitle(AppLocalizations text, {required bool isVideo}) {
  return isVideo
      ? text.templateDetailHeroVideoTitle
      : text.templateDetailHeroImageTitle;
}

String _templateDisplayTitle(AppLocalizations text, String rawTitle) {
  final normalized = rawTitle.trim();
  if (normalized.isEmpty || _isTechnicalTemplateText(normalized)) {
    return text.templateDetailFallbackTitle;
  }

  return normalized;
}

String _templateDisplayDescription(
  AppLocalizations text,
  String rawDescription, {
  required bool isVideo,
}) {
  final normalized = rawDescription.trim();
  if (normalized.isEmpty || _isTechnicalTemplateText(normalized)) {
    return isVideo
        ? text.templateDetailFallbackDescriptionVideo
        : text.templateDetailFallbackDescriptionImage;
  }

  return normalized;
}

String _templateDisplayCategory(AppLocalizations text, String rawCategory) {
  final normalized = rawCategory.trim();
  if (normalized.isEmpty) {
    return text.templateDetailCategoryTemplate;
  }

  final lower = normalized.toLowerCase();
  if (lower == 'portrait') {
    return text.templateDetailCategoryPortrait;
  }
  if (lower == 'video') {
    return text.templateDetailCategoryVideo;
  }

  return normalized;
}

String _templateDisplayRequirement(AppLocalizations text, String raw) {
  final normalized = raw.trim();
  final lower = normalized.toLowerCase();
  if (lower == 'one pet in the photo') {
    return text.templateDetailRequirementOnePet;
  }
  if (lower == 'clear face') {
    return text.templateDetailRequirementClearFace;
  }
  if (lower == 'good lighting') {
    return text.templateDetailRequirementGoodLighting;
  }
  if (lower == 'full body visible') {
    return text.templateDetailRequirementFullBodyVisible;
  }
  if (lower == 'pet facing camera') {
    return text.templateDetailRequirementFacingCamera;
  }
  if (lower == 'no cropped head or legs') {
    return text.templateDetailRequirementNoCroppedHeadOrLegs;
  }

  return normalized;
}

String _templateQualityWarning(AppLocalizations text) {
  return text.templateDetailQualityWarning;
}

String _templateUploadActionLabel(
  AppLocalizations text, {
  required bool isVideo,
}) {
  return isVideo
      ? text.templateDetailUploadPhotoForVideoAction
      : text.templateFlowUploadPetPhotoAction;
}

String _templatePreviewMissingTitle(AppLocalizations text) {
  return text.templateDetailPreviewMissingTitle;
}

String _templatePreviewMissingSubtitle(
  AppLocalizations text, {
  required bool isVideo,
}) {
  return isVideo
      ? text.templateDetailPreviewMissingSubtitleVideo
      : text.templateDetailPreviewMissingSubtitleImage;
}

String _templateEstimatedDuration(
  AppLocalizations text, {
  required bool isVideo,
}) {
  return isVideo ? text.templateDetailVideoEta : text.templateDetailImageEta;
}

bool _isTechnicalTemplateText(String text) {
  final lower = text.toLowerCase();
  return lower.contains('placeholder') ||
      lower.contains('admin') ||
      lower.contains('public catalog') ||
      lower.contains('catalog flows') ||
      lower.contains('template card');
}
