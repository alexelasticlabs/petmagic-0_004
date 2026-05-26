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
    builder: (sheetContext, bottomInset) => Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.96,
        minChildSize: 0.72,
        maxChildSize: 0.98,
        expand: false,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colors.backgroundBottom,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(color: colors.border.withValues(alpha: 0.72)),
            ),
            child: _TemplateDetailContent(
              template: template,
              scrollController: scrollController,
            ),
          );
        },
      ),
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
              const SizedBox(height: 18),
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
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(photo.path),
                      width: 88,
                      height: 112,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ConfirmMeta(
                          label: text.templateFlowTemplateLabel,
                          value: template.title,
                        ),
                        _ConfirmMeta(
                          label: text.templateFlowCostLabel,
                          value: '${template.tokenCost} PawSpark',
                        ),
                        _ConfirmMeta(
                          label: text.templateFlowBalanceLabel,
                          value: '${gate.balance} PawSpark',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceStrong.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.55),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colors.gold,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          text.templateFlowDurationHint,
                          style: Theme.of(context).textTheme.bodySmall
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
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(text.templateFlowCreateMagicAction),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
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

class _TemplateDetailContent extends StatelessWidget {
  const _TemplateDetailContent({
    required this.template,
    required this.scrollController,
  });

  final TemplateItem template;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final duration = template.referenceVideoDurationSeconds;

    return CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: colors.textStrong,
                    ),
                    const Spacer(),
                    if (template.isPremium)
                      _Pill(
                        icon: Icons.workspace_premium_rounded,
                        label: 'Premium',
                        color: colors.gold,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: 1.3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: _TemplateNetworkMedia(template: template),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  template.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.textStrong,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  template.shortDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSoft,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      leading: const PawSparkIcon(size: 15),
                      label: '${template.tokenCost} PawSpark',
                      color: colors.gold,
                    ),
                    _Pill(
                      icon: template.isVideo
                          ? Icons.videocam_rounded
                          : Icons.image_rounded,
                      label: template.isVideo
                          ? text.videoLabel
                          : text.imageLabel,
                      color: colors.accent,
                    ),
                    _Pill(
                      icon: Icons.category_rounded,
                      label: template.category,
                      color: colors.blue,
                    ),
                    if (template.isVideo && duration != null)
                      _Pill(
                        icon: Icons.timer_rounded,
                        label: formatDuration(duration),
                        color: colors.purple,
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  text.templateFlowBestPhotoTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                for (final requirement
                    in template.effectivePetPhotoRequirements.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RequirementRow(label: requirement),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(TemplateDetailAction.upload),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(text.templateFlowUploadPetPhotoAction),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TemplateGenerationProgressContent extends ConsumerWidget {
  const _TemplateGenerationProgressContent({required this.template});

  final TemplateItem template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.petMagicColors;
    final state = ref.watch(templateGenerationControllerProvider);
    final generation = state.generation;
    final isCompleted = generation?.isCompleted == true;
    final isFailed = generation?.isFailed == true || state.errorMessage != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: isCompleted || isFailed
                  ? () => Navigator.of(context).pop()
                  : null,
              icon: const Icon(Icons.close_rounded),
              color: colors.textStrong,
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: isCompleted
                  ? _GenerationResultView(
                      template: template,
                      generation: generation!,
                    )
                  : _GenerationWorkingView(
                      template: template,
                      generation: generation,
                      isFailed: isFailed,
                      errorMessage:
                          state.errorMessage ?? generation?.failureMessage,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenerationWorkingView extends ConsumerWidget {
  const _GenerationWorkingView({
    required this.template,
    required this.generation,
    required this.isFailed,
    this.errorMessage,
  });

  final TemplateItem template;
  final TemplateGenerationResult? generation;
  final bool isFailed;
  final String? errorMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final progress = _progressValue(generation, isFailed);
    final isBalanceError = errorMessage == 'templates.insufficient_balance';

    return Column(
      key: const ValueKey('generation-working'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isFailed
              ? text.templateFlowCreateFailedTitle
              : text.magicLoadingPreparing,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.textStrong,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isFailed
              ? isBalanceError
                    ? text.templateFlowCreateFailedBalanceHint
                    : text.templateFlowCreateFailedRetryHint
              : text.templateFlowCreateHint,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 34),
        SizedBox(
          width: 138,
          height: 138,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: isFailed ? 1 : progress,
                strokeWidth: 7,
                color: isFailed ? colors.danger : colors.accent,
                backgroundColor: colors.border.withValues(alpha: 0.6),
              ),
              Center(
                child: Text(
                  isFailed ? '!' : '${((progress ?? 0.35) * 100).round()}%',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _ProgressStep(
          label: text.templateFlowStepProcessPhoto,
          done: generation != null,
        ),
        _ProgressStep(
          label: text.templateFlowStepAnalyzePet,
          done:
              generation?.startedAtUtc != null ||
              generation?.preprocessingCompletedAtUtc != null,
        ),
        _ProgressStep(
          label: text.templateFlowStepCreateMagic,
          done:
              generation?.motionGenerationCompletedAtUtc != null ||
              generation?.isCompleted == true,
        ),
        _ProgressStep(
          label: text.templateFlowStepFinalTouches,
          done: generation?.isCompleted == true,
        ),
        const SizedBox(height: 22),
        if (isFailed) ...[
          if (errorMessage != null && errorMessage!.isNotEmpty)
            Text(
              _generationErrorText(text, errorMessage!),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                height: 1.35,
              ),
            ),
          const SizedBox(height: 14),
          if (isBalanceError)
            FilledButton.icon(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.go(WalletPage.routePath);
              },
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: Text(text.templateFlowTopUpBalanceAction),
            )
          else
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(templateGenerationControllerProvider.notifier)
                  .startGeneration(template),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(text.retryAction),
            ),
        ] else
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceStrong.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border.withValues(alpha: 0.55)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: colors.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text.templateFlowResultReadySubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSoft,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GenerationResultView extends StatelessWidget {
  const _GenerationResultView({
    required this.template,
    required this.generation,
  });

  final TemplateItem template;
  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final outputUrl = generation.outputUrl ?? '';

    return Column(
      key: const ValueKey('generation-result'),
      children: [
        Text(
          text.templateFlowResultReadyTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.textStrong,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text.templateFlowResultReadySubtitle,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: outputUrl.isEmpty
                ? _EmptyMediaBox(label: text.templateFlowResultUnavailable)
                : template.isVideo
                ? _NetworkVideoPreview(url: outputUrl)
                : CachedNetworkImage(
                    imageUrl: outputUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) =>
                        _EmptyMediaBox(label: text.templateFlowLoadingResult),
                    errorWidget: (context, url, error) => _EmptyMediaBox(
                      label: text.templateFlowResultLoadFailed,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: outputUrl.isEmpty
                    ? null
                    : () => SharePlus.instance.share(
                        ShareParams(text: '${template.title}\n$outputUrl'),
                      ),
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(text.supportChatShareAction),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(text.templateFlowCreateMoreAction),
        ),
      ],
    );
  }
}

class _TemplateNetworkMedia extends StatelessWidget {
  const _TemplateNetworkMedia({required this.template});

  final TemplateItem template;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final asset = template.previewAsset;
    if (asset == null || asset.url.isEmpty) {
      return _EmptyMediaBox(label: text.templateFlowPreviewFallback);
    }

    if (template.isVideo && isVideoPreview(asset)) {
      return _NetworkVideoPreview(url: asset.url);
    }

    return CachedNetworkImage(
      imageUrl: asset.url,
      fit: BoxFit.cover,
      placeholder: (context, url) =>
          _EmptyMediaBox(label: text.templateFlowLoadingPreview),
      errorWidget: (context, url, error) =>
          _EmptyMediaBox(label: text.templateFlowPreviewUnavailable),
    );
  }
}

class _NetworkVideoPreview extends StatefulWidget {
  const _NetworkVideoPreview({required this.url});

  final String url;

  @override
  State<_NetworkVideoPreview> createState() => _NetworkVideoPreviewState();
}

class _NetworkVideoPreviewState extends State<_NetworkVideoPreview> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _NetworkVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _controller = null;
      _initialize();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    controller.setVolume(0);
    controller.setLooping(true);
    try {
      await controller.initialize();
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }
      await controller.play();
      setState(() {});
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() => _controller = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _EmptyMediaBox(label: text.templateFlowLoadingVideo);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: IconButton.filledTonal(
              onPressed: () async {
                if (controller.value.isPlaying) {
                  await controller.pause();
                } else {
                  await controller.play();
                }
                if (mounted) {
                  setState(() {});
                }
              },
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfirmMeta extends StatelessWidget {
  const _ConfirmMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Row(
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          color: colors.accent,
          size: 18,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textSoft,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: done ? colors.accent : colors.textMuted,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: done ? colors.textSoft : colors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    this.icon,
    this.leading,
    required this.label,
    required this.color,
  });

  final IconData? icon;
  final Widget? leading;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null)
              leading!
            else if (icon != null)
              Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _EmptyMediaBox extends StatelessWidget {
  const _EmptyMediaBox({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return ColoredBox(
      color: colors.surfaceStrong,
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
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
