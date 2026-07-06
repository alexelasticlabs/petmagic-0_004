part of 'pet_generation_launch_sheet.dart';

const int _petLaunchSelectedPhotoPreviewCacheWidth = 760;
const int _petLaunchPhotoThumbnailCacheWidth = 180;

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
                  cacheKey: persistentSafeGenerationMediaUrl(imageUrl),
                  fit: BoxFit.cover,
                  memCacheWidth: _petLaunchSelectedPhotoPreviewCacheWidth,
                  maxWidthDiskCache: _petLaunchSelectedPhotoPreviewCacheWidth,
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
                  cacheKey: persistentSafeGenerationMediaUrl(imageUrl),
                  fit: BoxFit.cover,
                  memCacheWidth: _petLaunchPhotoThumbnailCacheWidth,
                  maxWidthDiskCache: _petLaunchPhotoThumbnailCacheWidth,
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
