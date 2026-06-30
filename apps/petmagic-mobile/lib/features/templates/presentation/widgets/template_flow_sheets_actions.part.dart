part of 'template_flow_sheets.dart';

Future<TemplateDetailAction?> showTemplateDetailSheet(
  BuildContext context,
  TemplateItem template, {
  bool isPremiumLocked = false,
  VoidCallback? onUnlockPremium,
}) {
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
            isPremiumLocked: isPremiumLocked,
            onUnlockPremium: onUnlockPremium,
          ),
        );
      },
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
                        clipBehavior: Clip.antiAlias,
                        child: Image.file(
                          File(photo.path),
                          fit: BoxFit.cover,
                          cacheWidth: _selectedPetPhotoPreviewCacheWidth,
                          cacheHeight: _selectedPetPhotoPreviewCacheHeight,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) {
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.surfaceGlass,
                              ),
                              child: Icon(
                                Icons.photo_camera_back_rounded,
                                color: colors.textMuted,
                                size: 32,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _templateDisplayTitle(text, template.title),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: colors.textStrong,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _templateDisplayDescription(
                                text,
                                template.shortDescription,
                                isVideo: template.isVideo,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colors.textMuted,
                                    height: 1.35,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  color: colors.accent,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${text.templateFlowCostLabel}: '
                                    '${template.tokenCost} ${text.walletBalanceUnit}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: colors.textSoft,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
  bool hasPremiumAccess = false,
}) {
  final text = AppLocalizations.of(context);
  final colors = context.petMagicColors;
  final isPremiumBlock =
      gate.kind == TemplateGenerationGateKind.premiumRequired;

  if (!isPremiumBlock) {
    return showPetMagicModalBottomSheet<TemplateBlockedAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext, bottomInset) => SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
          shrinkWrap: true,
          children: [
            _InsufficientBalanceBanner(
              templateCost: template.tokenCost,
              balance: gate.balance,
              showPremiumCta: !hasPremiumAccess,
              onClose: () => Navigator.of(
                sheetContext,
              ).pop(TemplateBlockedAction.chooseAnother),
              onOpenPremium: () =>
                  Navigator.of(sheetContext).pop(TemplateBlockedAction.premium),
              onBuyPowSpark: () =>
                  Navigator.of(sheetContext).pop(TemplateBlockedAction.wallet),
              onLater: () => Navigator.of(
                sheetContext,
              ).pop(TemplateBlockedAction.chooseAnother),
            ),
          ],
        ),
      ),
    );
  }

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
                isPremiumBlock
                    ? const PremiumCrownIcon(size: 34)
                    : Icon(
                        Icons.account_balance_wallet_rounded,
                        color: colors.accent,
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
