import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';

String subtitleForFilter(
  AppLocalizations text,
  GenerationHistoryFilter filter,
) {
  return switch (filter) {
    GenerationHistoryFilter.all => text.generationStatusSubtitleAll,
    GenerationHistoryFilter.active => text.generationStatusSubtitleActive,
    GenerationHistoryFilter.ready => text.generationStatusSubtitleReady,
    GenerationHistoryFilter.failed => text.generationStatusSubtitleFailed,
  };
}

String typeLabel(AppLocalizations text, TemplateGenerationResult generation) {
  return isVideoGeneration(generation) ? text.videoLabel : text.imageLabel;
}

String stageStatusLabel(
  AppLocalizations text,
  TemplateGenerationResult generation,
) {
  if (generation.effectiveProgressPercent >= 95) {
    return text.generationStatusEtaFinalizing;
  }

  return switch (generation.stage) {
    'queued' => text.generationStatusStageQueued,
    'uploading' => text.templateFlowStepProcessPhoto,
    'preprocessing' => text.templateFlowStepProcessPhoto,
    'processing' => text.templateFlowStepCreateMagic,
    'generating' => text.templateFlowStepCreateMagic,
    'finalizing' => text.templateFlowStepFinalTouches,
    _ => text.templateFlowStepCreateMagic,
  };
}

String estimatedTimeLabel(
  AppLocalizations text,
  TemplateGenerationResult generation,
) {
  if (generation.stage == 'queued') {
    return text.generationStatusEtaStartsSoon;
  }
  if ((generation.estimatedDurationLabel ?? '').isNotEmpty) {
    return text.generationStatusEtaEstimated(
      generation.estimatedDurationLabel!,
    );
  }
  return text.generationStatusEtaNotifyHint;
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

String formattedDate(AppLocalizations text, DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final dayDiff = today.difference(date).inDays;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  if (dayDiff == 0) {
    return text.generationStatusDateToday('$hour:$minute');
  }
  if (dayDiff == 1) {
    return text.generationStatusDateYesterday('$hour:$minute');
  }
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year;
  return '$day.$month.$year, $hour:$minute';
}

IconData statusIcon(TemplateGenerationResult generation) {
  if (generation.isCompleted) {
    return Icons.check_circle_rounded;
  }
  if (generation.isFailed) {
    return Icons.error_outline_rounded;
  }
  return Icons.auto_awesome_rounded;
}

Color statusColor(PetMagicColors colors, TemplateGenerationResult generation) {
  if (generation.isFailed) {
    return colors.danger;
  }
  if (generation.isCompleted) {
    return colors.accent;
  }
  return colors.gold;
}

String? previewUrl(TemplateGenerationResult generation) {
  if (generation.isCompleted &&
      generation.outputUrl != null &&
      generation.outputUrl!.isNotEmpty) {
    return generation.outputUrl;
  }
  if (generation.sourceImageAsset?.url != null &&
      generation.sourceImageAsset!.url.isNotEmpty) {
    return generation.sourceImageAsset!.url;
  }
  if (generation.normalizedImageUrl != null &&
      generation.normalizedImageUrl!.isNotEmpty) {
    return generation.normalizedImageUrl;
  }
  return null;
}

bool isVideoGeneration(TemplateGenerationResult generation) {
  final type = generation.templateType?.toLowerCase() ?? '';
  return type.contains('video') ||
      generation.outputVideoDurationSeconds != null;
}
