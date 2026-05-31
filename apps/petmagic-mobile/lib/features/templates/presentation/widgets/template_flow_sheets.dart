import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
part 'template_flow_sheets_content.part.dart';

enum TemplateDetailAction { upload }

enum PetPhotoSourceAction { gallery, camera }

enum TemplateBlockedAction { wallet, premium, chooseAnother }

Future<TemplateDetailAction?> showTemplateDetailSheet(
  BuildContext context,
  TemplateItem template,
) {
  final colors = context.petMagicColors;
  return showPetMagicModalBottomSheet<TemplateDetailAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext, bottomInset) => DraggableScrollableSheet(
      initialChildSize: 0.96,
      minChildSize: 0.72,
      maxChildSize: 0.98,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.backgroundBottom,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: colors.border.withValues(alpha: 0.72)),
          ),
          child: TemplateDetailContent(
            template: template,
            scrollController: scrollController,
          ),
        );
      },
    ),
  );
}

Future<PetPhotoSourceAction?> showPetPhotoSourceSheet(BuildContext context) {
  final text = AppLocalizations.of(context);
  final colors = context.petMagicColors;
  return showPetMagicModalBottomSheet<PetPhotoSourceAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext, bottomInset) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceStrong,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border.withValues(alpha: 0.8)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              _SheetHandle(color: colors.border),
              const SizedBox(height: 6),
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: colors.accent,
                ),
                title: Text(
                  text.templateFlowPhotoSourceGallery,
                  style: TextStyle(color: colors.textStrong),
                ),
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop(PetPhotoSourceAction.gallery),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_camera_outlined,
                  color: colors.accent,
                ),
                title: Text(
                  text.templateFlowPhotoSourceCamera,
                  style: TextStyle(color: colors.textStrong),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(PetPhotoSourceAction.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<bool?> showTemplateGenerationConfirmSheet({
  required BuildContext context,
  required TemplateItem template,
  required XFile photo,
  required TemplateGenerationGate gate,
}) {
  final text = AppLocalizations.of(context);
  final colors = context.petMagicColors;
  return showPetMagicModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext, bottomInset) => Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.backgroundBottom,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _SheetHandle(color: colors.border)),
              const SizedBox(height: 20),
              Text(
                text.templateFlowReadyTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                text.templateFlowCheckDetailsSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceGlass,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.6),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 96,
                        height: 118,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colors.border.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.file(
                            File(photo.path),
                            width: 96,
                            height: 118,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              text.templateFlowTemplateLabel,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colors.textMuted,
                                    letterSpacing: 0.3,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              template.title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: colors.textStrong,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Divider(
                              height: 1,
                              color: colors.border.withValues(alpha: 0.55),
                            ),
                            const SizedBox(height: 12),
                            _ConfirmMetaRow(
                              label: text.templateFlowCostLabel,
                              value: '${template.tokenCost}',
                              valueColor: colors.gold,
                            ),
                            const SizedBox(height: 8),
                            _ConfirmMetaRow(
                              label: text.templateFlowBalanceLabel,
                              value: '${gate.balance}',
                              valueColor: colors.accent,
                              showCheck: gate.isAllowed,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.gold.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.gold.withValues(alpha: 0.22),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        color: colors.gold,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          text.templateFlowDurationHint,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colors.textSoft, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                icon: const Icon(Icons.auto_awesome_rounded, size: 19),
                label: Text(text.templateFlowCreateMagicAction),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(text.templateFlowChangePhotoAction),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<TemplateBlockedAction?> showTemplateBlockedSheet({
  required BuildContext context,
  required TemplateItem template,
  required TemplateGenerationGate gate,
}) {
  final text = AppLocalizations.of(context);
  final colors = context.petMagicColors;
  final isPremiumBlock =
      gate.kind == TemplateGenerationGateKind.premiumRequired;
  final title = isPremiumBlock
      ? text.templateFlowPremiumTemplateTitle
      : text.templateFlowInsufficientBalanceTitle;
  final message = isPremiumBlock
      ? text.templateFlowPremiumTemplateMessage
      : text.templateFlowInsufficientBalanceMessage(
          template.tokenCost,
          gate.balance,
        );
  final primaryLabel = isPremiumBlock
      ? text.premiumContinueAction
      : text.templateFlowTopUpBalanceAction;
  final primaryAction = isPremiumBlock
      ? TemplateBlockedAction.premium
      : TemplateBlockedAction.wallet;

  return showPetMagicModalBottomSheet<TemplateBlockedAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext, bottomInset) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceStrong,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border.withValues(alpha: 0.8)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: _SheetHandle(color: colors.border)),
                const SizedBox(height: 18),
                Icon(
                  isPremiumBlock
                      ? Icons.workspace_premium_rounded
                      : Icons.account_balance_wallet_rounded,
                  color: isPremiumBlock ? colors.gold : colors.accent,
                  size: 34,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSoft,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(primaryAction),
                  child: Text(primaryLabel),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(
                    sheetContext,
                  ).pop(TemplateBlockedAction.chooseAnother),
                  child: Text(text.templateFlowChooseAnotherTemplateAction),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> showTemplateGenerationProgressSheet({
  required BuildContext context,
  required TemplateItem template,
}) {
  final colors = context.petMagicColors;
  return showPetMagicModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext, bottomInset) => Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.backgroundBottom,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.92,
          child: _TemplateGenerationProgressContent(template: template),
        ),
      ),
    ),
  );
}

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
    TemplateGenerationStatus.succeeded => 1,
    TemplateGenerationStatus.completed => 1,
    TemplateGenerationStatus.failed => 1,
  };
}

String _generationErrorText(AppLocalizations text, String raw) {
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

  return raw;
}

bool _isRussian(Locale locale) => locale.languageCode.toLowerCase() == 'ru';

String _templateHeroTitle(Locale locale, {required bool isVideo}) {
  if (_isRussian(locale)) {
    return isVideo
        ? '🐾 Оживите любимца в памятном ролике'
        : '✨ Превратите питомца в милый портрет';
  }

  return isVideo
      ? '🐾 Turn your pet into a memorable video'
      : '✨ Turn your pet into an adorable portrait';
}

String _templateDisplayTitle(Locale locale, String rawTitle) {
  final normalized = rawTitle.trim();
  if (normalized.isEmpty || _isTechnicalTemplateText(normalized)) {
    return _isRussian(locale) ? 'Портрет питомца' : 'Pet portrait';
  }

  return normalized;
}

String _templateDisplayDescription(
  Locale locale,
  String rawDescription, {
  required bool isVideo,
}) {
  final normalized = rawDescription.trim();
  if (normalized.isEmpty || _isTechnicalTemplateText(normalized)) {
    if (_isRussian(locale)) {
      return isVideo
          ? 'Создайте короткое эмоциональное видео с вашим питомцем и поделитесь им с близкими.'
          : 'Создайте тёплое памятное фото вашего любимца в стиле PetMagic.';
    }

    return isVideo
        ? 'Create a short emotional video with your pet and share it with your loved ones.'
        : 'Create a warm memorable portrait of your pet in PetMagic style.';
  }

  return normalized;
}

String _templateDisplayCategory(Locale locale, String rawCategory) {
  final normalized = rawCategory.trim();
  if (normalized.isEmpty) {
    return _isRussian(locale) ? 'Шаблон' : 'Template';
  }

  if (_isRussian(locale)) {
    final lower = normalized.toLowerCase();
    if (lower == 'portrait') return 'Портрет';
    if (lower == 'video') return 'Видео';
  }

  return normalized;
}

String _templateDisplayRequirement(Locale locale, String raw) {
  final normalized = raw.trim();
  if (!_isRussian(locale)) {
    return normalized;
  }

  final lower = normalized.toLowerCase();
  if (lower == 'one pet in the photo') return 'Один питомец в кадре';
  if (lower == 'clear face') return 'Хорошо видно морду';
  if (lower == 'good lighting') return 'Хорошее освещение';
  if (lower == 'full body visible') return 'Питомец полностью в кадре';
  if (lower == 'pet facing camera') return 'Питомец смотрит в камеру';
  if (lower == 'no cropped head or legs') {
    return 'Голова и лапы не обрезаны';
  }

  return normalized;
}

String _templateBestResultTitle(Locale locale) {
  return _isRussian(locale)
      ? 'Для лучшего результата:'
      : 'For the best result:';
}

String _templateQualityWarning(Locale locale) {
  return _isRussian(locale)
      ? 'Результат зависит от качества фотографии.'
      : 'Result quality depends on your photo quality.';
}

String _templateUploadActionLabel(Locale locale, {required bool isVideo}) {
  if (_isRussian(locale)) {
    return isVideo
        ? 'Загрузить фото питомца для видео'
        : 'Загрузить фото питомца';
  }

  return isVideo ? 'Upload pet photo for video' : 'Upload a pet photo';
}

String _templatePreviewMissingTitle(Locale locale) {
  return _isRussian(locale)
      ? '📷 Превью скоро появится'
      : '🐾 Preview coming soon';
}

String _templatePreviewMissingSubtitle(Locale locale, {required bool isVideo}) {
  if (_isRussian(locale)) {
    return isVideo
        ? 'Этот шаблон уже доступен для генерации. Загрузите фото питомца и попробуйте.'
        : 'Шаблон уже доступен для генерации. Загрузите фото питомца и попробуйте.';
  }

  return isVideo
      ? 'This template is already available. Upload your pet photo and try it now.'
      : 'This template is already available for generation. Upload your pet photo and try it.';
}

bool _isTechnicalTemplateText(String text) {
  final lower = text.toLowerCase();
  return lower.contains('placeholder') ||
      lower.contains('admin') ||
      lower.contains('public catalog') ||
      lower.contains('catalog flows') ||
      lower.contains('template card');
}
