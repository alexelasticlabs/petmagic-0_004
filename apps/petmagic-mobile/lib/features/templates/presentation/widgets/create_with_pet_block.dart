import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/features/pets/application/pets_contract.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/pet_generation_launch_sheet.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';

class CreateWithPetBlockSlot extends ConsumerWidget {
  const CreateWithPetBlockSlot({
    super.key,
    required this.selectedPetId,
    required this.selectedPetPhotoId,
  });

  final String? selectedPetId;
  final String? selectedPetPhotoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final launchState = ref.watch(appLaunchControllerProvider);
    if (launchState.isLoading || !launchState.isAuthenticated) {
      return const SizedBox.shrink();
    }

    return _CreateWithPetBlock(
      pets: ref.watch(petsProvider),
      selectedPetId: selectedPetId,
      selectedPetPhotoId: selectedPetPhotoId,
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
                      color: colors.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text.petsAddAction,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.accent,
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
        return Row(
          children: [
            Expanded(
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
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () =>
                  context.appNavigator.push(const PetsDestination()),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(92, 46),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(text.profilePetsTitle),
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
    final colors = context.petMagicColors;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 52,
        padding: const EdgeInsets.fromLTRB(7, 6, 10, 6),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colors.accent.withValues(alpha: 0.86)
                : colors.border.withValues(alpha: 0.62),
          ),
        ),
        child: Row(
          children: [
            PetShortcutAvatar(avatarUrl: pet.avatarUrl, size: 38),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      templatePetTypeLabel(pet.type, text),
                      pet.breed,
                    ].whereType<String>().join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

const int _petShortcutAvatarCacheWidth = 64;

class PetShortcutAvatar extends StatelessWidget {
  const PetShortcutAvatar({
    super.key,
    this.avatarUrl,
    this.icon,
    this.size = 26,
  });

  final String? avatarUrl;
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final iconData = icon ?? Icons.pets_rounded;
    final url = normalizePetMediaUrl(avatarUrl);

    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          cacheKey: persistentSafeProfileAvatarUrl(url),
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: _petShortcutAvatarCacheWidth,
          maxWidthDiskCache: _petShortcutAvatarCacheWidth,
          filterQuality: FilterQuality.medium,
          errorWidget: (_, _, _) =>
              _PetShortcutIcon(iconData: iconData, size: size),
        ),
      );
    }

    return _PetShortcutIcon(
      iconData: iconData,
      color: colors.accent,
      size: size,
    );
  }
}

class _PetShortcutIcon extends StatelessWidget {
  const _PetShortcutIcon({required this.iconData, this.color, this.size = 26});

  final IconData iconData;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        size: size <= 28 ? 15 : 20,
        color: color ?? colors.textStrong,
      ),
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
      final preferredHeight = 216.0 + (pets.length * 80);
      final sheetHeight = preferredHeight > maxHeight
          ? maxHeight
          : preferredHeight;

      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceGlass,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.border.withValues(alpha: 0.88)),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.42),
                  blurRadius: 26,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: SizedBox(
              height: sheetHeight,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
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
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: pets.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final pet = pets[index];
                          return _PetPickerOption(
                            pet: pet,
                            isSelected: pet.id == selectedPetId,
                            onTap: () => Navigator.of(sheetContext).pop(pet),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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

class _PetPickerOption extends StatelessWidget {
  const _PetPickerOption({
    required this.pet,
    required this.isSelected,
    required this.onTap,
  });

  final PetProfile pet;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: pet.name,
      child: AnimatedContainer(
        key: ValueKey<String>('pet-picker-option:${pet.id}'),
        duration: AppTheme.motionFast,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accentSoft.withValues(alpha: 0.34)
              : colors.surfaceStrong.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? colors.accent.withValues(alpha: 0.78)
                : colors.border.withValues(alpha: 0.72),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  PetShortcutAvatar(avatarUrl: pet.avatarUrl, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          pet.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            templatePetTypeLabel(pet.type, text),
                            pet.breed,
                          ].whereType<String>().join(' • '),
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
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: AppTheme.motionFast,
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isSelected ? colors.accent : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? colors.accent : colors.textMuted,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: PetMagicPalettes.onColor(colors.accent),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
