import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/pets/presentation/pet_media_url_normalizer.dart';
import 'package:petmagic_mobile/features/pets/presentation/pet_profile_providers.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/pet_generation_launch_sheet.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';

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
              onTap: () => context.push('/profile/pets'),
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
                  final pickedPet = await _showPetPickerSheet(context, items);
                  if (!context.mounted || pickedPet == null) {
                    return;
                  }

                  context.go(
                    _templatesPetShortcutLocation(
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
              onPressed: () => context.push('/profile/pets'),
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

String _templatesPetShortcutLocation({
  required String petId,
  required String? selectedPetId,
  required String? selectedPetPhotoId,
}) {
  final keepSelectedPhoto =
      selectedPetId == petId &&
      selectedPetPhotoId != null &&
      selectedPetPhotoId.isNotEmpty;
  return Uri(
    path: TemplatesPage.routePath,
    queryParameters: {
      'petId': petId,
      if (keepSelectedPhoto) 'petPhotoId': selectedPetPhotoId,
    },
  ).toString();
}

Future<PetProfile?> _showPetPickerSheet(
  BuildContext context,
  List<PetProfile> pets,
) {
  final text = AppLocalizations.of(context);
  final colors = context.petMagicColors;
  return showPetMagicModalBottomSheet<PetProfile>(
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: Material(
              type: MaterialType.transparency,
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final pet in pets)
                    ListTile(
                      leading: PetShortcutAvatar(avatarUrl: pet.avatarUrl),
                      title: Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        [
                          templatePetTypeLabel(pet.type, text),
                          pet.breed,
                        ].whereType<String>().join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textSoft),
                      ),
                      onTap: () => Navigator.of(sheetContext).pop(pet),
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
