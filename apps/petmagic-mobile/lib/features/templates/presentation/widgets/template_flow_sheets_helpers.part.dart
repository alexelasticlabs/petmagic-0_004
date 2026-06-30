part of 'template_flow_sheets.dart';

double? _progressValue(TemplateGenerationResult? generation, bool isFailed) {
  if (isFailed) {
    return 1;
  }
  if (generation == null) {
    return 0.18;
  }
  return switch (generation.status) {
    TemplateGenerationStatus.queued => 0.28,
    TemplateGenerationStatus.uploading => 0.36,
    TemplateGenerationStatus.preprocessing => 0.52,
    TemplateGenerationStatus.processing =>
      generation.motionGenerationCompletedAtUtc != null
          ? 0.82
          : generation.preprocessingCompletedAtUtc != null
          ? 0.64
          : 0.48,
    TemplateGenerationStatus.generating => 0.74,
    TemplateGenerationStatus.finalizing => 0.9,
    TemplateGenerationStatus.completed => 1,
    TemplateGenerationStatus.failed => 1,
  };
}

String _generationErrorText(AppLocalizations text, String raw) {
  final authMessage = mapCommonAuthFeedbackMessage(text, raw);
  if (authMessage != null) {
    return authMessage;
  }

  if (raw == 'templates.insufficient_balance') {
    return text.templateFlowInsufficientBalanceError;
  }

  if (raw.contains('templates.network_unavailable')) {
    return text.templateFlowNetworkError;
  }

  if (raw.contains('templates.server_unavailable')) {
    return text.templateFlowServerError;
  }

  if (raw.contains('templates.generation_failed')) {
    return text.templateFlowStartFailedError;
  }

  return text.templateFlowStartFailedError;
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
