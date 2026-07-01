import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/generation_media_kind.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

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

  if (generation.status == TemplateGenerationStatus.submittingToProvider ||
      generation.status == TemplateGenerationStatus.providerQueued) {
    return text.generationStatusStageQueued;
  }
  if (generation.status == TemplateGenerationStatus.providerProcessing) {
    return text.templateFlowStepCreateMagic;
  }
  if (generation.status == TemplateGenerationStatus.importingMedia) {
    return text.templateFlowStepFinalTouches;
  }

  return switch (generation.stage) {
    'queued' => text.generationStatusStageQueued,
    'submittingToProvider' ||
    'providerQueued' => text.generationStatusStageQueued,
    'uploading' => text.templateFlowStepProcessPhoto,
    'preprocessing' => text.templateFlowStepProcessPhoto,
    'processing' => text.templateFlowStepCreateMagic,
    'providerProcessing' => text.templateFlowStepCreateMagic,
    'generating' => text.templateFlowStepCreateMagic,
    'finalizing' || 'importingMedia' => text.templateFlowStepFinalTouches,
    _ => text.templateFlowStepCreateMagic,
  };
}

String estimatedTimeLabel(
  AppLocalizations text,
  TemplateGenerationResult generation,
) {
  if (generation.stage == 'queued' || generation.isWaitingInQueue) {
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

String formattedDate(AppLocalizations text, DateTime value, Locale locale) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final dayDiff = today.difference(date).inDays;
  final time = DateFormat.Hm(locale.toLanguageTag()).format(local);

  if (dayDiff == 0) {
    return text.generationStatusDateToday(time);
  }
  if (dayDiff == 1) {
    return text.generationStatusDateYesterday(time);
  }
  return DateFormat.yMMMd(locale.toLanguageTag()).add_Hm().format(local);
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
  final resultPreview = _safeMediaUrl(generation.resultPreviewUrl);
  final output = _safeMediaUrl(generation.outputUrl);
  final source = _safeMediaUrl(generation.sourceImageAsset?.url);
  final normalized = _safeMediaUrl(generation.normalizedImageUrl);
  final generationIsVideo = isVideoGeneration(generation);

  if (resultPreview != null && !isLikelyGenerationVideoUrl(resultPreview)) {
    return resultPreview;
  }

  if (generationIsVideo) {
    if (source != null) {
      return source;
    }
    if (normalized != null) {
      return normalized;
    }
    return output != null && isLikelyGenerationImageUrl(output) ? output : null;
  }

  if (output != null && !isLikelyGenerationVideoUrl(output)) {
    return output;
  }
  if (source != null) {
    return source;
  }
  if (normalized != null) {
    return normalized;
  }
  return null;
}

bool isVideoGeneration(TemplateGenerationResult generation) {
  return isVideoGenerationResult(generation);
}

bool canRenderImagePreview(String? url) {
  final normalized = _safeMediaUrl(url);
  return normalized != null && !isLikelyGenerationVideoUrl(normalized);
}

String? _safeMediaUrl(String? raw) {
  return parseSafeGenerationMediaUri(raw)?.toString();
}
