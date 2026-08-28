import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';

part 'petmagic_action_sheet_items.part.dart';

enum PetMagicActionSheetResult { gallery, camera, myPets }

enum PetMagicActionSheetStep { main, uploadSource }

Future<PetMagicActionSheetResult?> showPetMagicActionSheet(
  BuildContext context,
) {
  final screenHeight = Overlay.of(
    context,
    rootOverlay: true,
  ).context.size!.height;

  return showPetMagicModalBottomSheet<PetMagicActionSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.55),
    constraints: BoxConstraints.tightFor(height: screenHeight),
    builder: (sheetContext, bottomInset) => PetMagicActionSheet(
      bottomInset: bottomInset,
      screenHeight: screenHeight,
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
    this.screenHeight,
  });

  final VoidCallback onPickFromGallery;
  final VoidCallback onOpenCamera;
  final VoidCallback onSelectExistingPet;
  final double bottomInset;
  final double? screenHeight;

  @override
  State<PetMagicActionSheet> createState() => _PetMagicActionSheetState();
}

class _PetMagicActionSheetState extends State<PetMagicActionSheet> {
  PetMagicActionSheetStep _step = PetMagicActionSheetStep.main;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final screenHeight =
        widget.screenHeight ?? MediaQuery.sizeOf(context).height;
    final contentHeight = (screenHeight - widget.bottomInset)
        .clamp(0.0, screenHeight)
        .toDouble();

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
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: widget.bottomInset),
          child: SizedBox(
            height: contentHeight,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              child: _buildSheetSurface(context, colors: colors),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetSurface(
    BuildContext context, {
    required PetMagicColors colors,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PetMagicActionSheetHandle(),
              const SizedBox(height: 14),
              _PetMagicActionSheetHeader(
                title: _step == PetMagicActionSheetStep.main
                    ? AppLocalizations.of(context).petsActionSheetAddPhotoTitle
                    : AppLocalizations.of(context).petsActionSheetSourceTitle,
                onBack: _step == PetMagicActionSheetStep.uploadSource
                    ? () => setState(() {
                        _step = PetMagicActionSheetStep.main;
                      })
                    : null,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: colors.border.withValues(alpha: 0.62)),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
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
          icon: Icons.file_upload_outlined,
          title: text.petsActionSheetUploadDeviceTitle,
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
          title: text.petsActionSheetChoosePetTitle,
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
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              color: context.petMagicColors.border.withValues(alpha: 0.62),
            ),
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
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: colors.border.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _PetMagicActionSheetHeader extends StatelessWidget {
  const _PetMagicActionSheetHeader({
    required this.title,
    required this.onClose,
    this.onBack,
  });

  final String title;
  final VoidCallback onClose;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: colors.textSoft,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.textStrong,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 24),
            color: colors.textSoft,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
        ],
      ),
    );
  }
}
