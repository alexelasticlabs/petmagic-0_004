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
    barrierColor: const Color(0x8C000000),
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
    final surfaceBorderColor = const Color(0x1FFF9FDF);

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
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF172433), Color(0xFF101820)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: surfaceBorderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0x3300F2A6),
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
    return Center(
      child: Container(
        width: 46,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
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
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
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

class PetMagicActionSheetItem extends StatefulWidget {
  const PetMagicActionSheetItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.semanticLabel,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<PetMagicActionSheetItem> createState() =>
      _PetMagicActionSheetItemState();
}

class _PetMagicActionSheetItemState extends State<PetMagicActionSheetItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final enabled = widget.enabled;
    final reduceMotion = PetMotion.reduceMotion(context);
    final duration = PetMotion.effectiveDuration(context, PetMotion.fast);
    final cardBorderRadius = BorderRadius.circular(24);

    final baseFill = Colors.white.withValues(alpha: enabled ? 0.05 : 0.03);
    final pressedFill = Colors.white.withValues(alpha: enabled ? 0.1 : 0.03);
    final borderColor = Colors.white.withValues(alpha: enabled ? 0.08 : 0.04);
    final chevronColor = Colors.white.withValues(alpha: enabled ? 0.68 : 0.3);
    final secondaryFill = enabled
        ? (_pressed
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.035))
        : Colors.white.withValues(alpha: 0.016);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _pressed && enabled && !reduceMotion ? 0.978 : 1,
        duration: duration,
        curve: PetMotion.emphasized,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: cardBorderRadius,
            onTap: enabled
                ? () {
                    PetMagicHaptics.light();
                    widget.onTap();
                  }
                : null,
            onHighlightChanged: (value) {
              if (_pressed == value) {
                return;
              }

              setState(() {
                _pressed = value;
              });
            },
            child: AnimatedContainer(
              duration: duration,
              curve: PetMotion.emphasized,
              constraints: const BoxConstraints(minHeight: 96),
              decoration: BoxDecoration(
                borderRadius: cardBorderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [(_pressed ? pressedFill : baseFill), secondaryFill],
                ),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: enabled ? 0.18 : 0.1),
                    blurRadius: 18,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: enabled ? 1 : 0.5,
                      child: PetMagicActionIconContainer(
                        icon: widget.icon,
                        highlighted: _pressed && enabled,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: colors.textStrong.withValues(
                                    alpha: enabled ? 1 : 0.5,
                                  ),
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: const Color(
                                    0xFFA6ADB4,
                                  ).withValues(alpha: enabled ? 1 : 0.5),
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: chevronColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PetMagicActionIconContainer extends StatelessWidget {
  const PetMagicActionIconContainer({
    super.key,
    required this.icon,
    this.highlighted = false,
  });

  final IconData icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PetMotion.effectiveDuration(context, PetMotion.fast),
      curve: PetMotion.emphasized,
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00F2A6), Color(0xFF00C97A)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF00F2A6,
            ).withValues(alpha: highlighted ? 0.28 : 0.16),
            blurRadius: highlighted ? 22 : 14,
            spreadRadius: highlighted ? 2 : 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, size: 30, color: Colors.white),
    );
  }
}
