part of 'my_pets_page.dart';

class _PetAuthGate extends StatelessWidget {
  const _PetAuthGate({required this.redirectPath});

  final String redirectPath;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return ProtectedAuthGate(
      title: text.petsAuthRequiredTitle,
      subtitle: text.petsAuthRequiredMessage,
      onSignIn: () =>
          context.appNavigator.go(AuthDestination(redirectPath: redirectPath)),
      onSignUp: () => context.appNavigator.go(
        RegisterDestination(redirectPath: redirectPath),
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({
    required this.pet,
    required this.text,
    required this.onTap,
    required this.onGenerate,
  });

  final PetProfile pet;
  final AppLocalizations text;
  final VoidCallback onTap;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.72),
              width: 1.05,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                _PetAvatar(url: pet.avatarUrl, name: pet.name, size: 68),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_typeLabel(pet.type, text)}${pet.breed == null ? '' : ' â€¢ ${pet.breed}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textSoft, fontSize: 13),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${text.petsStatsPhotos(pet.photosCount)} â€¢ ${text.petsStatsGenerations(pet.generationsCount)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PetHeader extends StatelessWidget {
  const _PetHeader({
    required this.pet,
    required this.text,
    required this.onEdit,
    required this.onGenerate,
    required this.onAddPhoto,
    required this.isAddingPhoto,
  });

  final PetProfile pet;
  final AppLocalizations text;
  final VoidCallback onEdit;
  final VoidCallback onGenerate;
  final VoidCallback onAddPhoto;
  final bool isAddingPhoto;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.border.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: _PetAvatar(
                      url: pet.avatarUrl,
                      name: pet.name,
                      size: 146,
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 8,
                    child: IconButton.filled(
                      tooltip: text.petsAddPhotosTooltip,
                      onPressed: isAddingPhoto ? null : onAddPhoto,
                      icon: isAddingPhoto
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.photo_camera_outlined, size: 19),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              pet.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.textStrong,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${_typeLabel(pet.type, text)}${pet.breed == null ? '' : ' â€¢ ${pet.breed}'}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textSoft),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: pet.photosCount > 0 ? onGenerate : null,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(
                text.petsGenerateWithName(pet.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(text.petsEditTitle),
            ),
            if (pet.photosCount == 0) ...[
              const SizedBox(height: 10),
              Text(
                text.petsAddPhotoPrompt(pet.name),
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSoft),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitleSliver extends StatelessWidget {
  const _SectionTitleSliver({required this.title, required this.topPadding});

  final String title;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
