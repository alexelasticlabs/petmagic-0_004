import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/features/pets/application/pets_contract.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/pet_generation_launch_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';

import 'pet_shortcut_avatar.dart';
import 'pet_creation_identity.dart';

part 'create_with_pet_picker_widgets.part.dart';

class CreateWithPetBlockSlot extends ConsumerWidget {
  const CreateWithPetBlockSlot({
    super.key,
    required this.selectedPetId,
    required this.selectedPetPhotoId,
    this.padding = EdgeInsets.zero,
  });

  final String? selectedPetId;
  final String? selectedPetPhotoId;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final launchState = ref.watch(appLaunchControllerProvider);
    if (launchState.isLoading || !launchState.isAuthenticated) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: padding,
      child: _CreateWithPetBlock(
        pets: ref.watch(petsProvider),
        selectedPetId: selectedPetId,
        selectedPetPhotoId: selectedPetPhotoId,
      ),
    );
  }
}

class _CreateWithPetBlock extends StatelessWidget {
  const _CreateWithPetBlock({
    required this.pets,
    required this.selectedPetId,
    required this.selectedPetPhotoId,
  });

  final AsyncValue<List<PetProfile>> pets;
  final String? selectedPetId;
  final String? selectedPetPhotoId;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return pets.when(
      loading: () => DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceStrong.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border.withValues(alpha: 0.66)),
        ),
        child: const SizedBox(
          height: 52,
          child: Center(
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceStrong.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border.withValues(alpha: 0.66)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.appNavigator.push(const PetsDestination()),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: colors.accentInk,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text.petsAddAction,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.accentInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final selectedPet = items.firstWhere(
          (pet) => pet.id == selectedPetId,
          orElse: () => items.first,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              child: _SelectedPetHomeButton(
                pet: selectedPet,
                isSelected: selectedPetId == selectedPet.id,
                onPressed: () async {
                  final pickedPet = await showTemplatePetPickerSheet(
                    context,
                    items,
                    selectedPetId: selectedPet.id,
                  );
                  if (!context.mounted || pickedPet == null) {
                    return;
                  }

                  context.appNavigator.go(
                    _templatesPetShortcutDestination(
                      petId: pickedPet.id,
                      selectedPetId: selectedPetId,
                      selectedPetPhotoId: selectedPetPhotoId,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () =>
                    context.appNavigator.push(const PetsDestination()),
                style: TextButton.styleFrom(
                  foregroundColor: colors.textSoft,
                  minimumSize: const Size(92, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(text.profilePetsTitle),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SelectedPetHomeButton extends StatelessWidget {
  const _SelectedPetHomeButton({
    required this.pet,
    required this.isSelected,
    required this.onPressed,
  });

  final PetProfile pet;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return PetCreationIdentity(
      name: pet.name,
      caption: isSelected
          ? text.petsGenerateWithPet
          : text.petsChooseFromMyPetsAction,
      avatarUrl: pet.avatarUrl,
      selected: isSelected,
      onPressed: onPressed,
    );
  }
}

TemplatesDestination _templatesPetShortcutDestination({
  required String petId,
  required String? selectedPetId,
  required String? selectedPetPhotoId,
}) {
  final keepSelectedPhoto =
      selectedPetId == petId &&
      selectedPetPhotoId != null &&
      selectedPetPhotoId.isNotEmpty;
  return TemplatesDestination(
    petId: petId,
    petPhotoId: keepSelectedPhoto ? selectedPetPhotoId : null,
  );
}

Future<PetProfile?> showTemplatePetPickerSheet(
  BuildContext context,
  List<PetProfile> pets, {
  String? selectedPetId,
}) {
  final text = AppLocalizations.of(context);
  final colors = context.petMagicColors;
  return showPetMagicModalBottomSheet<PetProfile>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext, bottomInset) {
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.72;
      final useScrollableList = 216 + (pets.length * 80) > maxHeight;

      return SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceGlass,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.88),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.42),
                    blurRadius: 26,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.border.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: colors.accentSoft.withValues(alpha: 0.34),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.pets_rounded,
                              color: colors.accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  text.profilePetsTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textStrong,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  text.petsActionSheetMyPetsSubtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textSoft,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (useScrollableList)
                      Flexible(
                        child: _PetPickerList(
                          pets: pets,
                          selectedPetId: selectedPetId,
                          onPick: (pet) => Navigator.of(sheetContext).pop(pet),
                        ),
                      )
                    else
                      _PetPickerList(
                        pets: pets,
                        selectedPetId: selectedPetId,
                        onPick: (pet) => Navigator.of(sheetContext).pop(pet),
                        shrinkWrap: true,
                      ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        8,
                        12,
                        12 + MediaQuery.viewPaddingOf(sheetContext).bottom,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            context.appNavigator.push(const PetsDestination());
                          },
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: Text(text.profilePetsTitle),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
