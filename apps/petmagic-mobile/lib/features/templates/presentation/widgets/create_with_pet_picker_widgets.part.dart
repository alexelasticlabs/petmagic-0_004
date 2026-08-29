part of 'create_with_pet_block.dart';

class _PetPickerList extends StatelessWidget {
  const _PetPickerList({
    required this.pets,
    required this.selectedPetId,
    required this.onPick,
    this.shrinkWrap = false,
  });

  final List<PetProfile> pets;
  final String? selectedPetId;
  final ValueChanged<PetProfile> onPick;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: pets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final pet = pets[index];
        return _PetPickerOption(
          pet: pet,
          isSelected: pet.id == selectedPetId,
          onTap: () => onPick(pet),
        );
      },
    );
  }
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
