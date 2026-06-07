import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/premium_banner_style.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/shared/widgets/premium_shimmer_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
part 'template_flow_sheets_content.part.dart';

enum TemplateDetailAction { upload }

enum PetPhotoSourceAction { gallery, camera }

enum TemplateBlockedAction { wallet, premium, chooseAnother }

const _kInsufficientBalanceMascotAsset =
    'assets/rewards/powspark-empty-cat.png';
const int _selectedPetPhotoPreviewCacheWidth = 288;
const int _selectedPetPhotoPreviewCacheHeight = 354;

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
                            cacheWidth: _selectedPetPhotoPreviewCacheWidth,
                            cacheHeight: _selectedPetPhotoPreviewCacheHeight,
                            filterQuality: FilterQuality.medium,
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

class _InsufficientBalanceBanner extends StatelessWidget {
  const _InsufficientBalanceBanner({
    required this.templateCost,
    required this.balance,
    required this.showPremiumCta,
    required this.onClose,
    required this.onOpenPremium,
    required this.onBuyPowSpark,
    required this.onLater,
  });

  final int templateCost;
  final int balance;
  final bool showPremiumCta;
  final VoidCallback onClose;
  final VoidCallback onOpenPremium;
  final VoidCallback onBuyPowSpark;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isRu =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final rightInset = compact ? 146.0 : 200.0;
        final mascotHeight = compact ? 252.0 : 300.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(
                0xFFE0A91E,
              ).withValues(alpha: isLight ? 0.78 : 0.9),
              width: 1.15,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: PremiumBannerStyle.gradient(isLight),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 8,
                top: 6,
                child: IconButton(
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    color: isLight
                        ? const Color(0xFF514325)
                        : const Color(0xFFE1DED4),
                  ),
                ),
              ),
              Positioned(
                right: -8,
                bottom: -2,
                child: IgnorePointer(
                  child: Image.asset(
                    _kInsufficientBalanceMascotAsset,
                    height: mascotHeight,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 18, rightInset, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(
                              0xFF140D01,
                            ).withValues(alpha: isLight ? 0.16 : 0.36),
                            border: Border.all(
                              color: const Color(
                                0xFFE0A91E,
                              ).withValues(alpha: 0.76),
                            ),
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFFEAB13A),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isRu ? 'PowSpark закончились' : 'No PowSpark left',
                            style: TextStyle(
                              color: isLight
                                  ? const Color(0xFF1E1608)
                                  : const Color(0xFFEDE7D8),
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isRu
                          ? 'Вы можете купить PowSpark разово\nили оформить Premium и получать\n40 PowSpark каждую неделю.'
                          : 'You can buy PowSpark once\nor get Premium and receive\n40 PowSpark every week.',
                      style: TextStyle(
                        color: isLight
                            ? const Color(0xFF3B3324)
                            : const Color(0xFFE3DFD2),
                        fontSize: 12.4,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      text.templateFlowInsufficientBalanceMessage(
                        templateCost,
                        balance,
                      ),
                      style: TextStyle(
                        color: isLight
                            ? const Color(0xFF2F2719)
                            : const Color(0xFFD7DFEF),
                        fontSize: 11.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (showPremiumCta) ...[
                      PremiumShimmerButton(
                        label: text.profilePremiumOpenAction,
                        onTap: onOpenPremium,
                        height: 40,
                      ),
                      const SizedBox(height: 9),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton(
                        onPressed: onBuyPowSpark,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF0EA76A),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            text.templateFlowTopUpBalanceAction,
                            style: const TextStyle(
                              color: Color(0xFF0EA76A),
                              fontSize: 12.8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton(
                        onPressed: onLater,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isLight
                                ? const Color(0xFFBCB29B)
                                : const Color(0xFF2A3651),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            text.templateFlowChooseAnotherTemplateAction,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isLight
                                  ? const Color(0xFF3C3324)
                                  : const Color(0xFFC6CEDD),
                              fontSize: 12.6,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TemplateGoldShimmerButton extends StatefulWidget {
  const _TemplateGoldShimmerButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_TemplateGoldShimmerButton> createState() =>
      _TemplateGoldShimmerButtonState();
}

class _TemplateGoldShimmerButtonState extends State<_TemplateGoldShimmerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE0A91E).withValues(alpha: 0.34),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = _controller.value;
                  final shimmerStart = -1.6 + (t * 2.8);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF4C64D), Color(0xFFEAB13A)],
                          ),
                        ),
                        child: child,
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(shimmerStart, -1),
                                end: Alignment(shimmerStart + 0.9, 1),
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.68),
                                  Colors.transparent,
                                ],
                                stops: const [0.23, 0.5, 0.77],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        color: Color(0xFF261903),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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

  return text.templateFlowStartFailedError;
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
