part of 'pet_generation_launch_sheet.dart';

class _PetLaunchHeader extends StatelessWidget {
  const _PetLaunchHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.accent.withValues(alpha: 0.96),
                colors.accent.withValues(alpha: 0.52),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.24),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.textStrong,
            fontWeight: FontWeight.w900,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textSoft,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PetLaunchTemplateCard extends StatelessWidget {
  const _PetLaunchTemplateCard({
    required this.template,
    required this.tokenCost,
  });

  final TemplateItem template;
  final int tokenCost;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceGlass.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.62)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                width: 82,
                height: 98,
                child: _PetLaunchTemplatePreview(template: template),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.templateFlowTemplateLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PetLaunchChip(
                        icon: Icons.movie_creation_rounded,
                        label: template.isVideo ? 'Video' : 'Image',
                      ),
                      _PetLaunchPawSparkChip(label: '$tokenCost PawSpark'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetLaunchTemplatePreview extends StatelessWidget {
  const _PetLaunchTemplatePreview({required this.template});

  final TemplateItem template;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final thumbnailUrl = template.thumbnailUrl?.trim();
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return TemplatePreviewImage(
        imageUrl: thumbnailUrl,
        cacheWidth: 180,
        fit: BoxFit.cover,
        placeholder: _PetLaunchMagicFallback(iconSize: 28),
        errorBuilder: (_) => _PetLaunchMagicFallback(iconSize: 28),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surfaceStrong),
      child: _PetLaunchMagicFallback(iconSize: 28),
    );
  }
}

class _PetLaunchPetCard extends StatelessWidget {
  const _PetLaunchPetCard({required this.petName, required this.balance});

  final String? petName;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final name = petName?.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.accent.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.pets_rounded, color: colors.accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name == null || name.isEmpty
                    ? text.petsGenerateWithPet
                    : text.petsGenerateWithName(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _PetLaunchPawSparkChip(label: '$balance'),
          ],
        ),
      ),
    );
  }
}

class _PetLaunchSelectedPhotoPreview extends StatelessWidget {
  const _PetLaunchSelectedPhotoPreview({
    required this.photo,
    required this.isLoading,
    required this.onUpload,
  });

  final PetPhoto? photo;
  final bool isLoading;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final imageUrl = photo == null ? null : _petPhotoDisplayUrl(photo!);
    return AspectRatio(
      aspectRatio: 1.46,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceStrong.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.border.withValues(alpha: 0.70)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 760,
                  filterQuality: FilterQuality.medium,
                  placeholder: (_, _) => _PetLaunchMagicFallback(iconSize: 34),
                  errorWidget: (_, _, _) =>
                      _PetLaunchNoPhotoPreview(onUpload: onUpload),
                )
              else if (isLoading)
                _PetLaunchLoadingPhotoPreview()
              else
                _PetLaunchNoPhotoPreview(onUpload: onUpload),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.42),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 13,
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: colors.accent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _petLaunchSelectedPhotoLabel(text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetLaunchPhotoThumbnail extends StatelessWidget {
  const _PetLaunchPhotoThumbnail({
    required this.photo,
    required this.isSelected,
    required this.onTap,
  });

  final PetPhoto photo;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final imageUrl = _petPhotoDisplayUrl(photo);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 72,
        height: 72,
        padding: EdgeInsets.all(isSelected ? 3 : 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? colors.accent
                : colors.border.withValues(alpha: 0.72),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: imageUrl == null
              ? _PetLaunchMagicFallback(iconSize: 20)
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 180,
                  filterQuality: FilterQuality.medium,
                  placeholder: (_, _) => _PetLaunchMagicFallback(iconSize: 20),
                  errorWidget: (_, _, _) =>
                      _PetLaunchMagicFallback(iconSize: 20),
                ),
        ),
      ),
    );
  }
}

class _PetLaunchUploadTile extends StatelessWidget {
  const _PetLaunchUploadTile({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: colors.surfaceGlass.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.accent.withValues(alpha: 0.34)),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: colors.accent,
                  ),
                )
              : Icon(
                  Icons.add_photo_alternate_rounded,
                  color: colors.accent,
                  size: 25,
                ),
        ),
      ),
    );
  }
}

class _PetLaunchNoPhotosHint extends StatelessWidget {
  const _PetLaunchNoPhotosHint({
    required this.isLoading,
    required this.onUpload,
  });

  final bool isLoading;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.gold.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.photo_camera_back_rounded, color: colors.gold, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isLoading
                    ? _petLaunchLoadingPhotosLabel(text)
                    : text.petsNoPhotoStartMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSoft,
                  height: 1.32,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: isLoading ? null : onUpload,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Text(text.petsUploadAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetLaunchNoPhotoPreview extends StatelessWidget {
  const _PetLaunchNoPhotoPreview({required this.onUpload});

  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surfaceStrong, colors.accent.withValues(alpha: 0.16)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_photo_alternate_rounded,
              color: colors.accent,
              size: 38,
            ),
            const SizedBox(height: 10),
            Text(
              _petLaunchChoosePhotoLabel(text),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.textStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              label: Text(text.petsUploadAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetLaunchLoadingPhotoPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surfaceStrong),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colors.accent),
            const SizedBox(height: 12),
            Text(
              _petLaunchLoadingPhotosLabel(text),
              style: TextStyle(
                color: colors.textSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetLaunchPhotoLoadError extends StatelessWidget {
  const _PetLaunchPhotoLoadError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.danger.withValues(alpha: 0.26)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: colors.danger, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSoft,
                  height: 1.32,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).petsRetryAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetLaunchInlineError extends StatelessWidget {
  const _PetLaunchInlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.danger.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: colors.danger, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textStrong,
                  height: 1.28,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetLaunchBottomBar extends StatelessWidget {
  const _PetLaunchBottomBar({
    required this.bottomInset,
    required this.showChangeAction,
    required this.isStarting,
    required this.startLabel,
    required this.changeLabel,
    required this.onStart,
    required this.onChangePet,
  });

  final double bottomInset;
  final bool showChangeAction;
  final bool isStarting;
  final String startLabel;
  final String changeLabel;
  final VoidCallback? onStart;
  final VoidCallback? onChangePet;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.backgroundBottom.withValues(alpha: 0.0),
            colors.backgroundBottom,
            colors.backgroundBottom,
          ],
          stops: const [0, 0.34, 1],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, bottomInset + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PetLaunchStartButton(
              label: startLabel,
              isLoading: isStarting,
              onPressed: onStart,
            ),
            if (showChangeAction) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onChangePet,
                icon: const Icon(Icons.pets_rounded, size: 18),
                label: Text(changeLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PetLaunchStartButton extends StatelessWidget {
  const _PetLaunchStartButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: colors.textStrong,
                ),
              )
            : const Icon(Icons.auto_awesome_rounded, size: 20),
        label: Text(label),
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _PetLaunchChip extends StatelessWidget {
  const _PetLaunchChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.58)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.accent, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textSoft,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetLaunchPawSparkChip extends StatelessWidget {
  const _PetLaunchPawSparkChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.accent.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PawSparkIcon(size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetLaunchMagicFallback extends StatelessWidget {
  const _PetLaunchMagicFallback({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accent.withValues(alpha: 0.22),
            colors.surfaceStrong.withValues(alpha: 0.74),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome_rounded,
          color: colors.accent.withValues(alpha: 0.86),
          size: iconSize,
        ),
      ),
    );
  }
}
