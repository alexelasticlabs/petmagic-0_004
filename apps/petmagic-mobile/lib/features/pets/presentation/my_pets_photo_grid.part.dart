part of 'my_pets_page.dart';

class _PhotoGridSkeletonSliver extends StatelessWidget {
  const _PhotoGridSkeletonSliver();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      sliver: SliverGrid.builder(
        itemCount: 4,
        gridDelegate: _petPhotoGridDelegate,
        itemBuilder: (context, index) => const _PetPhotoSkeletonCard(),
      ),
    );
  }
}

class _PhotoGrid extends ConsumerStatefulWidget {
  const _PhotoGrid({
    required this.petId,
    required this.currentAvatarUrl,
    required this.photos,
    required this.text,
  });

  final String petId;
  final String? currentAvatarUrl;
  final List<PetPhoto> photos;
  final AppLocalizations text;

  @override
  ConsumerState<_PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends ConsumerState<_PhotoGrid> {
  final Set<String> _busyPhotoIds = <String>{};
  final Map<String, RequestCancellation> _photoActionCancelTokens =
      <String, RequestCancellation>{};

  @override
  void didUpdateWidget(covariant _PhotoGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petId == widget.petId) {
      return;
    }

    for (final cancelToken in _photoActionCancelTokens.values) {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('pet_photo_grid_pet_changed');
      }
    }
    _photoActionCancelTokens.clear();
    _busyPhotoIds.clear();
  }

  Future<void> _runPhotoAction(
    PetPhoto photo,
    Future<void> Function(RequestCancellation cancellation) action,
  ) async {
    if (_busyPhotoIds.contains(photo.id)) {
      return;
    }

    final cancelToken = RequestCancellation();
    setState(() {
      _busyPhotoIds.add(photo.id);
      _photoActionCancelTokens[photo.id] = cancelToken;
    });

    try {
      await action(cancelToken);
    } on Object catch (error) {
      if (_isPetPhotoRequestCancelled(error, cancelToken)) {
        return;
      }
      if (!mounted) {
        return;
      }
      final text = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_petPhotoUploadErrorMessage(text, error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyPhotoIds.remove(photo.id);
          _photoActionCancelTokens.remove(photo.id);
        });
      } else {
        _photoActionCancelTokens.remove(photo.id);
      }
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('pet_photo_grid_action_finished');
      }
    }
  }

  @override
  void dispose() {
    for (final cancelToken in _photoActionCancelTokens.values) {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('pet_photo_grid_disposed');
      }
    }
    _photoActionCancelTokens.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        sliver: SliverToBoxAdapter(
          child: _PetSectionEmpty(label: widget.text.petsNoPhotosTitle),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      sliver: SliverGrid.builder(
        gridDelegate: _petPhotoGridDelegate,
        itemCount: widget.photos.length,
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          final isBusy = _busyPhotoIds.contains(photo.id);
          return _PetPhotoCard(
            photo: photo,
            isBusy: isBusy,
            text: widget.text,
            onSetAvatar: () => _runPhotoAction(
              photo,
              (cancelToken) => _setAvatar(
                ref,
                widget.petId,
                photo,
                currentAvatarUrl: widget.currentAvatarUrl,
                cancelToken: cancelToken,
              ),
            ),
            onSetFavorite: () => _runPhotoAction(
              photo,
              (cancelToken) => _setFavorite(
                ref,
                widget.petId,
                photo,
                cancelToken: cancelToken,
              ),
            ),
            onUseForGeneration: isBusy
                ? null
                : () => context.appNavigator.go(
                    TemplatesDestination(
                      petId: widget.petId,
                      petPhotoId: photo.id,
                    ),
                  ),
            onDelete: () => _runPhotoAction(
              photo,
              (cancelToken) => _deletePhoto(
                ref,
                widget.petId,
                photo,
                currentAvatarUrl: widget.currentAvatarUrl,
                cancelToken: cancelToken,
              ),
            ),
          );
        },
      ),
    );
  }
}

const _petPhotoGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: 10,
  mainAxisSpacing: 10,
  childAspectRatio: 0.78,
);

class _PetPhotoCard extends StatelessWidget {
  const _PetPhotoCard({
    required this.photo,
    required this.isBusy,
    required this.text,
    required this.onSetAvatar,
    required this.onSetFavorite,
    required this.onUseForGeneration,
    required this.onDelete,
  });

  final PetPhoto photo;
  final bool isBusy;
  final AppLocalizations text;
  final VoidCallback onSetAvatar;
  final VoidCallback onSetFavorite;
  final VoidCallback? onUseForGeneration;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final imageUrl = _petPhotoDisplayUrl(photo);
    final fallbackImageUrl = _petPhotoOriginalDisplayUrl(photo);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: imageUrl == null
                    ? const _PetPhotoImageFallback()
                    : _PetPhotoNetworkImage(
                        imageUrl: imageUrl,
                        fallbackImageUrl: fallbackImageUrl == imageUrl
                            ? null
                            : fallbackImageUrl,
                      ),
              ),
              SizedBox(
                height: 48,
                child: Material(
                  color: colors.surface,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _PetPhotoActionButton(
                        tooltip: text.petsSetAvatarTooltip,
                        icon: Icons.account_circle_outlined,
                        onPressed: isBusy ? null : onSetAvatar,
                      ),
                      _PetPhotoActionButton(
                        tooltip: text.petsMarkFavoriteTooltip,
                        icon: photo.isFavorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        onPressed: isBusy ? null : onSetFavorite,
                      ),
                      _PetPhotoActionButton(
                        tooltip: text.petsUseForGenerationTooltip,
                        icon: Icons.auto_awesome_rounded,
                        onPressed: onUseForGeneration,
                      ),
                      _PetPhotoActionButton(
                        tooltip: text.petsDeletePhotoTooltip,
                        icon: Icons.delete_outline_rounded,
                        onPressed: isBusy ? null : onDelete,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                if (photo.isAvatar)
                  _PetPhotoBadge(
                    label: text.petsAvatarBadge,
                    icon: Icons.account_circle_rounded,
                  ),
                if (photo.isFavorite)
                  _PetPhotoBadge(
                    label: text.petsFavoriteBadge,
                    icon: Icons.star_rounded,
                  ),
              ],
            ),
          ),
          if (isBusy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.22),
                child: const Center(
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PetPhotoNetworkImage extends StatelessWidget {
  const _PetPhotoNetworkImage({required this.imageUrl, this.fallbackImageUrl});

  final String imageUrl;
  final String? fallbackImageUrl;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: persistentSafeMediaCacheKeyUrl(imageUrl),
      fit: BoxFit.cover,
      memCacheWidth: _petPhotoThumbnailMemCacheWidth,
      maxWidthDiskCache: _petPhotoThumbnailMemCacheWidth,
      placeholder: (_, _) => const _PetPhotoImageSkeleton(),
      errorWidget: (_, _, _) {
        final fallback = fallbackImageUrl;
        if (fallback == null || fallback.isEmpty) {
          return const _PetPhotoImageFallback();
        }

        return CachedNetworkImage(
          imageUrl: fallback,
          cacheKey: persistentSafeMediaCacheKeyUrl(fallback),
          fit: BoxFit.cover,
          memCacheWidth: _petPhotoThumbnailMemCacheWidth,
          maxWidthDiskCache: _petPhotoThumbnailMemCacheWidth,
          placeholder: (_, _) => const _PetPhotoImageSkeleton(),
          errorWidget: (_, _, _) => const _PetPhotoImageFallback(),
        );
      },
    );
  }
}

class _PetPhotoActionButton extends StatelessWidget {
  const _PetPhotoActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(icon, size: 21),
    );
  }
}

class _PetPhotoBadge extends StatelessWidget {
  const _PetPhotoBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetPhotoSkeletonCard extends StatelessWidget {
  const _PetPhotoSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(child: _PetPhotoImageSkeleton()),
          ColoredBox(color: colors.surface, child: const SizedBox(height: 48)),
        ],
      ),
    );
  }
}

class _PetPhotoImageSkeleton extends StatelessWidget {
  const _PetPhotoImageSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return ColoredBox(
      color: colors.surfaceStrong.withValues(alpha: 0.74),
      child: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator.adaptive(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
          ),
        ),
      ),
    );
  }
}

class _PetPhotoImageFallback extends StatelessWidget {
  const _PetPhotoImageFallback();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return ColoredBox(
      color: colors.surfaceStrong.withValues(alpha: 0.88),
      child: Center(
        child: Icon(
          Icons.pets_rounded,
          color: colors.textMuted.withValues(alpha: 0.35),
          size: 32,
        ),
      ),
    );
  }
}
