import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/generation_media_kind.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';

String typeLabel(AppLocalizations text, TemplateGenerationResult generation) {
  return isVideoGeneration(generation) ? text.videoLabel : text.imageLabel;
}

String formatGenerationDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.$year, $hour:$minute';
}

String etaLabel(AppLocalizations text, TemplateGenerationResult generation) {
  if (generation.status == TemplateGenerationStatus.queued) {
    final position = generation.queuePosition;
    final waitSeconds = generation.estimatedWaitSeconds;
    if (position != null &&
        position > 0 &&
        waitSeconds != null &&
        waitSeconds > 0) {
      return text.generationStatusEtaEstimated(
        'queue #$position, ${_formatWaitDuration(waitSeconds)}',
      );
    }

    if (waitSeconds != null && waitSeconds > 0) {
      return text.generationStatusEtaEstimated(
        _formatWaitDuration(waitSeconds),
      );
    }

    if (position != null && position > 0) {
      return '${text.generationStatusEtaQueued} #$position';
    }
  }

  final estimated = generation.estimatedDurationLabel;
  if (estimated != null && estimated.isNotEmpty) {
    return text.generationStatusEtaEstimated(estimated);
  }

  if (generation.stage == 'queued') {
    return text.generationStatusEtaQueued;
  }
  if (generation.stage == 'finalizing') {
    return text.generationStatusEtaFinalizing;
  }
  return text.generationStatusEtaDefault;
}

String _formatWaitDuration(int totalSeconds) {
  final minutes = (totalSeconds / 60).ceil();
  if (minutes <= 1) {
    return '1 min';
  }

  return '$minutes min';
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

String statusTitle(AppLocalizations text, TemplateGenerationResult generation) {
  if (generation.isCompleted) {
    return text.generationStatusStatusCompleted;
  }
  if (generation.isFailed) {
    return text.generationStatusStatusFailed;
  }
  return switch (generation.stage) {
    'queued' => text.generationStatusStageQueued,
    'preprocessing' => text.templateFlowStepProcessPhoto,
    'generating' => text.templateFlowStepCreateMagic,
    'finalizing' => text.templateFlowStepFinalTouches,
    _ => text.generationStatusStatusCreatingMagic,
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
  return text.generationStatusTerminalSuccessHint;
}

IconData generationStatusIcon(TemplateGenerationResult generation) {
  if (generation.isCompleted) {
    return Icons.check_circle_rounded;
  }
  if (generation.isFailed) {
    return Icons.error_outline_rounded;
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
  return colors.gold;
}

bool isVideoGeneration(TemplateGenerationResult generation) {
  return isVideoGenerationResult(generation);
}
