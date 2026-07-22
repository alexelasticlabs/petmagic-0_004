import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_haptics.dart';

part 'petmagic_action_sheet_items.part.dart';

enum PetMagicActionSheetResult { gallery, camera, myPets }

enum PetMagicActionSheetStep { main, uploadSource }

Future<PetMagicActionSheetResult?> showPetMagicActionSheet(
  BuildContext context,
) {
  return showPetMagicModalBottomSheet<PetMagicActionSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.55),
    builder: (sheetContext, bottomInset) => PetMagicActionSheet(
      bottomInset: bottomInset,
      onPickFromGallery: () =>
          Navigator.of(sheetContext).pop(PetMagicActionSheetResult.gallery),
      onOpenCamera: () =>
          Navigator.of(sheetContext).pop(PetMagicActionSheetResult.camera),
      onSelectExistingPet: () =>
          Navigator.of(sheetContext).pop(PetMagicActionSheetResult.myPets),
    ),
  );
}

class PetMagicActionSheet extends StatefulWidget {
  const PetMagicActionSheet({
    super.key,
    required this.onPickFromGallery,
    required this.onOpenCamera,
    required this.onSelectExistingPet,
    this.bottomInset = 0,
  });

  final VoidCallback onPickFromGallery;
  final VoidCallback onOpenCamera;
  final VoidCallback onSelectExistingPet;
  final double bottomInset;

  @override
  State<PetMagicActionSheet> createState() => _PetMagicActionSheetState();
}

class _PetMagicActionSheetState extends State<PetMagicActionSheet> {
  PetMagicActionSheetStep _step = PetMagicActionSheetStep.main;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = PetMotion.reduceMotion(context);
    final disableGlass =
        defaultTargetPlatform == TargetPlatform.android ||
        PerformanceGuard.shouldDisableGlassEffects(context);
    final colors = context.petMagicColors;
    final bottomPadding = math.max(widget.bottomInset, 12.0);
    final surfaceBorderColor = colors.border.withValues(alpha: 0.72);

    return PopScope<void>(
      canPop: _step == PetMagicActionSheetStep.main,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _step == PetMagicActionSheetStep.main) {
          return;
        }

        setState(() {
          _step = PetMagicActionSheetStep.main;
        });
      },
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPadding),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: disableGlass
                    ? _buildSheetSurface(
                        context,
                        colors: colors,
                        reduceMotion: reduceMotion,
                        surfaceBorderColor: surfaceBorderColor,
                      )
                    : BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: _buildSheetSurface(
                          context,
                          colors: colors,
                          reduceMotion: reduceMotion,
                          surfaceBorderColor: surfaceBorderColor,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetSurface(
    BuildContext context, {
    required PetMagicColors colors,
    required bool reduceMotion,
    required Color surfaceBorderColor,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.surfaceGlass, colors.surface],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: surfaceBorderColor),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.12),
            blurRadius: 36,
            spreadRadius: 2,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.34),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: AnimatedSize(
          duration: PetMotion.effectiveDuration(context, PetMotion.medium),
          curve: PetMotion.emphasized,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PetMagicActionSheetHandle(),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: PetMotion.effectiveDuration(
                  context,
                  const Duration(milliseconds: 220),
                ),
                switchInCurve: PetMotion.emphasized,
                switchOutCurve: Curves.easeInOutCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ...previousChildren,
                      ...switch (currentChild) {
                        final Widget child => [child],
                        null => const <Widget>[],
                      },
                    ],
                  );
                },
                transitionBuilder: (child, animation) {
                  final slideTween = Tween<Offset>(
                    begin: reduceMotion
                        ? Offset.zero
                        : const Offset(0.05, 0.04),
                    end: Offset.zero,
                  );
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: slideTween.animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<PetMagicActionSheetStep>(_step),
                  child: _buildStep(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    final text = AppLocalizations.of(context);
    final items = switch (_step) {
      PetMagicActionSheetStep.main => [
        PetMagicActionSheetItem(
          icon: Icons.upload_rounded,
          title: text.petsUploadAction,
          subtitle: text.petsActionSheetUploadSubtitle,
          semanticLabel: text.petsActionSheetUploadSemantic,
          onTap: () {
            setState(() {
              _step = PetMagicActionSheetStep.uploadSource;
            });
          },
        ),
        PetMagicActionSheetItem(
          icon: Icons.pets_rounded,
          title: text.petsChooseFromMyPetsAction,
          subtitle: text.petsActionSheetMyPetsSubtitle,
          semanticLabel: text.petsActionSheetMyPetsSemantic,
          onTap: widget.onSelectExistingPet,
        ),
      ],
      PetMagicActionSheetStep.uploadSource => [
        PetMagicActionSheetItem(
          icon: Icons.photo_library_outlined,
          title: text.templateFlowPhotoSourceGallery,
          subtitle: text.petsActionSheetGallerySubtitle,
          semanticLabel: text.petsActionSheetGallerySemantic,
          onTap: widget.onPickFromGallery,
        ),
        PetMagicActionSheetItem(
          icon: Icons.photo_camera_outlined,
          title: text.templateFlowPhotoSourceCamera,
          subtitle: text.petsActionSheetCameraSubtitle,
          semanticLabel: text.petsActionSheetCameraSemantic,
          onTap: widget.onOpenCamera,
        ),
      ],
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_step == PetMagicActionSheetStep.uploadSource)
          _PetMagicActionSheetStepHeader(
            title: text.petsActionSheetSourceTitle,
            onBack: () {
              setState(() {
                _step = PetMagicActionSheetStep.main;
              });
            },
          ),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          items[i],
        ],
      ],
    );
  }
}

class _PetMagicActionSheetHandle extends StatelessWidget {
  const _PetMagicActionSheetHandle();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Center(
      child: Container(
        width: 46,
        height: 5,
        decoration: BoxDecoration(
          color: colors.border.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _PetMagicActionSheetStepHeader extends StatelessWidget {
  const _PetMagicActionSheetStepHeader({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: Colors.transparent,
                child: InkResponse(
                  onTap: onBack,
                  radius: 22,
                  containedInkWell: true,
                  highlightShape: BoxShape.circle,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surfaceStrong.withValues(alpha: 0.58),
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: colors.textStrong,
                    ),
                  ),
                ),
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colors.textStrong,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
