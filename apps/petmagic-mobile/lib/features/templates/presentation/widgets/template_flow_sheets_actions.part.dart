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
  final screenHeight = Overlay.of(
    context,
    rootOverlay: true,
  ).context.size!.height;
  return showPetMagicModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints.tightFor(height: screenHeight),
    builder: (sheetContext, bottomInset) {
      final contentHeight = (screenHeight - bottomInset)
          .clamp(0.0, screenHeight)
          .toDouble();
      return SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: contentHeight,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(color: colors.backgroundBottom),
                child: SafeArea(
                  top: true,
                  bottom: false,
                  child: _TemplateGenerationConfirmContent(
                    template: template,
                    photo: photo,
                    title: text.templateFlowReadyTitle,
                    subtitle: text.templateFlowCheckDetailsSubtitle,
                    durationHint: text.templateFlowDurationHint,
                    createLabel: text.templateFlowCreateMagicAction,
                    changePhotoLabel: text.templateFlowChangePhotoAction,
                    onCreate: () => Navigator.of(sheetContext).pop(true),
                    onChangePhoto: () => Navigator.of(sheetContext).pop(false),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _TemplateGenerationConfirmContent extends StatelessWidget {
  const _TemplateGenerationConfirmContent({
    required this.template,
    required this.photo,
    required this.title,
    required this.subtitle,
    required this.durationHint,
    required this.createLabel,
    required this.changePhotoLabel,
    required this.onCreate,
    required this.onChangePhoto,
  });

  final TemplateItem template;
  final XFile photo;
  final String title;
  final String subtitle;
  final String durationHint;
  final String createLabel;
  final String changePhotoLabel;
  final VoidCallback onCreate;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _SheetHandle(color: colors.border)),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: onChangePhoto,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                    color: colors.textSoft,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.textStrong,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
              fontSize: 14.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 26),
          _TemplateGenerationConfirmSummary(template: template, photo: photo),
          const SizedBox(height: 14),
          Divider(height: 1, color: colors.border.withValues(alpha: 0.62)),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 20, color: colors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  durationHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textMuted,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.auto_awesome_rounded, size: 19),
            label: Text(createLabel),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              backgroundColor: colors.accent,
              foregroundColor: colors.on(colors.accent),
              elevation: 0,
              shadowColor: Colors.transparent,
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: onChangePhoto, child: Text(changePhotoLabel)),
        ],
      ),
    );
  }
}

class _TemplateGenerationConfirmSummary extends StatelessWidget {
  const _TemplateGenerationConfirmSummary({
    required this.template,
    required this.photo,
  });

  final TemplateItem template;
  final XFile photo;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = (constraints.maxWidth * 0.44)
            .clamp(140.0, 160.0)
            .toDouble();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: previewSize,
                height: previewSize,
                child: Image.file(
                  File(photo.path),
                  fit: BoxFit.cover,
                  cacheWidth: _selectedPetPhotoPreviewCacheWidth,
                  cacheHeight: _selectedPetPhotoPreviewCacheHeight,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: colors.surfaceStrong,
                    child: Icon(
                      Icons.photo_camera_back_rounded,
                      color: colors.textMuted,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _templateDisplayTitle(text, template.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.textStrong,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _templateDisplayDescription(
                      text,
                      template.shortDescription,
                      isVideo: template.isVideo,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                      fontSize: 14.5,
                      height: 1.34,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: colors.accent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${template.tokenCost} ${text.walletBalanceUnit}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
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
        );
      },
    );
  }
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
              onTopUpBalance: () =>
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
