import 'package:flutter/material.dart';

// Stable presentation mapping exposed by the generation application contract.
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/generation_media_kind.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';

String typeLabel(AppLocalizations text, TemplateGenerationResult generation) {
  return isVideoGeneration(generation) ? text.videoLabel : text.imageLabel;
}

String formatGenerationDateTime(DateTime value, Locale locale) {
  return DateFormat.yMMMd(
    locale.toLanguageTag(),
  ).add_Hm().format(value.toLocal());
}

String etaLabel(AppLocalizations text, TemplateGenerationResult generation) {
  if (generation.isWaitingInQueue) {
    final position = generation.queuePosition;
    final waitSeconds = generation.estimatedWaitSeconds;
    if (position != null &&
        position > 0 &&
        waitSeconds != null &&
        waitSeconds > 0) {
      return text.generationStatusEtaEstimated(
        text.generationStatusQueuePositionWithWait(
          position,
          _formatWaitDuration(text, waitSeconds),
        ),
      );
    }

    if (waitSeconds != null && waitSeconds > 0) {
      return text.generationStatusEtaEstimated(
        _formatWaitDuration(text, waitSeconds),
      );
    }

    if (position != null && position > 0) {
      return text.generationStatusQueuePosition(position);
    }
  }

  if (generation.stage == 'queued') {
    return text.generationStatusEtaQueued;
  }
  if (generation.status == TemplateGenerationStatus.providerQueued ||
      generation.status == TemplateGenerationStatus.submittingToProvider) {
    return text.generationStatusEtaStartsSoon;
  }
  if (generation.stage == 'finalizing') {
    return text.generationStatusEtaFinalizing;
  }
  if (generation.status == TemplateGenerationStatus.importingMedia) {
    return text.generationStatusEtaFinalizing;
  }
  return text.generationStatusEtaDefault;
}

String _formatWaitDuration(AppLocalizations text, int totalSeconds) {
  final minutes = (totalSeconds / 60).ceil().clamp(1, 24 * 60);
  return text.generationStatusWaitMinutes(minutes);
}

String failureReasonMessage(
  AppLocalizations text,
  TemplateGenerationResult generation,
) {
  final code = (generation.failureCode ?? '').toLowerCase();
  final message = (generation.failureMessage ?? '').toLowerCase();
  final combined = '$code $message';

  if (combined.contains('photo') ||
      combined.contains('face') ||
      combined.contains('pet') ||
      combined.contains('quality')) {
    return text.generationStatusFailurePhotoHint;
  }

  return text.generationStatusFailureTechnicalHint;
}

bool isPhotoFailure(TemplateGenerationResult generation) {
  final combined =
      '${generation.failureCode ?? ''} ${generation.failureMessage ?? ''}'
          .toLowerCase();
  return combined.contains('photo') ||
      combined.contains('face') ||
      combined.contains('pet') ||
      combined.contains('quality');
}

String galleryMediaStateMessage(
  AppLocalizations text,
  TemplateGenerationResult generation,
) {
  return switch (generation.galleryMedia.state) {
    GalleryMediaState.pending ||
    GalleryMediaState.processing => text.generationStatusMediaPreparingMessage,
    GalleryMediaState.previewReadyOnly =>
      text.generationStatusMediaPreviewOnlyMessage,
    GalleryMediaState.watermarkPreparing =>
      text.generationStatusMediaWatermarkPreparingMessage,
    GalleryMediaState.expired => text.generationStatusMediaExpiredMessage,
    GalleryMediaState.storageUnavailable =>
      text.generationStatusMediaUnavailableMessage,
    GalleryMediaState.failed => text.generationStatusMediaFailedMessage,
    GalleryMediaState.hidden => text.generationStatusMediaHiddenMessage,
    GalleryMediaState.resultReady => '',
  };
}

IconData galleryMediaStateIcon(TemplateGenerationResult generation) {
  return switch (generation.galleryMedia.state) {
    GalleryMediaState.pending ||
    GalleryMediaState.processing ||
    GalleryMediaState.watermarkPreparing => Icons.hourglass_empty_rounded,
    GalleryMediaState.previewReadyOnly => Icons.image_outlined,
    GalleryMediaState.expired => Icons.event_busy_rounded,
    GalleryMediaState.storageUnavailable => Icons.cloud_off_rounded,
    GalleryMediaState.failed => Icons.error_outline_rounded,
    GalleryMediaState.hidden => Icons.visibility_off_outlined,
    GalleryMediaState.resultReady => Icons.check_circle_rounded,
  };
}

String statusTitle(AppLocalizations text, TemplateGenerationResult generation) {
  if (generation.isCompleted) {
    return text.generationStatusStatusCompleted;
  }
  if (generation.isFailed) {
    return text.generationStatusStatusFailed;
  }
  if (generation.isCancelled) {
    return text.generationStatusStatusCancelled;
  }
  return switch (generation.stage) {
    'queued' => text.generationStatusStageQueued,
    'preprocessing' => text.templateFlowStepProcessPhoto,
    'generating' => text.templateFlowStepCreateMagic,
    'finalizing' => text.templateFlowStepFinalTouches,
    'cancelling' => text.generationStatusStatusCreatingMagic,
    _ => switch (generation.status) {
      TemplateGenerationStatus.queued => text.generationStatusStageQueued,
      TemplateGenerationStatus.uploading => text.templateFlowStepProcessPhoto,
      TemplateGenerationStatus.submittingToProvider =>
        text.generationStatusEtaStartsSoon,
      TemplateGenerationStatus.providerQueued =>
        text.generationStatusStageQueued,
      TemplateGenerationStatus.preprocessing =>
        text.templateFlowStepProcessPhoto,
      TemplateGenerationStatus.processing ||
      TemplateGenerationStatus.providerProcessing ||
      TemplateGenerationStatus.generating => text.templateFlowStepCreateMagic,
      TemplateGenerationStatus.finalizing ||
      TemplateGenerationStatus.importingMedia =>
        text.templateFlowStepFinalTouches,
      TemplateGenerationStatus.cancellationRequested =>
        text.generationStatusStatusCreatingMagic,
      _ => text.generationStatusStatusCreatingMagic,
    },
  };
}

String terminalHint(
  AppLocalizations text,
  TemplateGenerationResult generation,
) {
  if (generation.isFailed) {
    return generation.refundedAtUtc != null
        ? text.generationStatusTerminalRefundedHint
        : text.generationStatusTerminalFailureHint;
  }
  if (generation.isCancelled) {
    return text.generationStatusTerminalCancelledHint;
  }
  return text.generationStatusTerminalSuccessHint;
}

IconData generationStatusIcon(TemplateGenerationResult generation) {
  if (generation.isCompleted) {
    return Icons.check_circle_rounded;
  }
  if (generation.isFailed) {
    return Icons.error_outline_rounded;
  }
  if (generation.isCancelled) {
    return Icons.cancel_rounded;
  }
  return Icons.auto_awesome_rounded;
}

Color generationStatusColor(
  PetMagicColors colors,
  TemplateGenerationResult generation,
) {
  if (generation.isFailed) {
    return colors.danger;
  }
  if (generation.isCompleted) {
    return colors.accent;
  }
  if (generation.isCancelled) {
    return colors.textMuted;
  }
  return colors.gold;
}

bool isVideoGeneration(TemplateGenerationResult generation) {
  return isVideoGenerationResult(generation);
}

// Presentation mapping for generation status.
