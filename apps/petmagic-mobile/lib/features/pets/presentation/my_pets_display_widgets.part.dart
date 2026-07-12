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
                        '${_typeLabel(pet.type, text)}${pet.breed == null ? '' : ' • ${pet.breed}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textSoft, fontSize: 13),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${text.petsStatsPhotos(pet.photosCount)} • ${text.petsStatsGenerations(pet.generationsCount)}',
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
              '${_typeLabel(pet.type, text)}${pet.breed == null ? '' : ' • ${pet.breed}'}',
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
  final Map<String, CancelToken> _photoActionCancelTokens =
      <String, CancelToken>{};

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
    Future<void> Function(CancelToken cancelToken) action,
  ) async {
    if (_busyPhotoIds.contains(photo.id)) {
      return;
    }

    final cancelToken = CancelToken();
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

class _GenerationList extends StatelessWidget {
  const _GenerationList({required this.generations, required this.text});

  final List<TemplateGenerationResult> generations;
  final AppLocalizations text;

  @override
  Widget build(BuildContext context) {
    if (generations.isEmpty) {
      return _PetSectionEmpty(label: text.petsNoGenerationsTitle);
    }

    return Column(
      children: [
        for (final generation in generations.take(12))
          _PetGenerationHistoryTile(generation: generation, text: text),
      ],
    );
  }
}

class _PetGenerationHistoryTile extends StatelessWidget {
  const _PetGenerationHistoryTile({
    required this.generation,
    required this.text,
  });

  final TemplateGenerationResult generation;
  final AppLocalizations text;

  @override
  Widget build(BuildContext context) {
    final safeOutputUrl = parseSafeGenerationMediaUri(
      generation.outputUrl,
    )?.toString();
    final shareSafeUrl = safeOutputUrl == null
        ? null
        : persistentSafeGenerationMediaUrl(safeOutputUrl);

    return Card(
      child: ListTile(
        title: Text(generation.templateTitle ?? generation.templateId),
        subtitle: Text(
          '${generation.templateType ?? text.petsTemplateFallback} • ${_petGenerationStatusTitle(text, generation)} • ${_formatDate(context, generation.createdAtUtc)}',
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: text.petsOpenGenerationTooltip,
              onPressed: () => context.appNavigator.push(
                GenerationDestination(generation.generationId),
              ),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
            IconButton(
              tooltip: text.petsShareGenerationTooltip,
              onPressed: shareSafeUrl == null || shareSafeUrl.isEmpty
                  ? null
                  : () => SharePlus.instance.share(
                      ShareParams(text: shareSafeUrl),
                    ),
              icon: const Icon(Icons.ios_share_rounded),
            ),
            IconButton(
              tooltip: text.petsUseGenerationAsInputTooltip,
              onPressed: () => context.appNavigator.go(
                TemplatesDestination(
                  petId: generation.petId,
                  petPhotoId: generation.petPhotoId,
                ),
              ),
              icon: const Icon(Icons.auto_fix_high_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

String _petGenerationStatusTitle(
  AppLocalizations text,
  TemplateGenerationResult generation,
) {
  if (generation.isCompleted) return text.generationStatusStatusCompleted;
  if (generation.isFailed) return text.generationStatusStatusFailed;
  if (generation.isCancelled) return text.generationStatusStatusCancelled;

  return switch (generation.stage) {
    'queued' => text.generationStatusStageQueued,
    'preprocessing' => text.templateFlowStepProcessPhoto,
    'generating' => text.templateFlowStepCreateMagic,
    'finalizing' => text.templateFlowStepFinalTouches,
    _ => text.generationStatusStatusCreatingMagic,
  };
}

class _PetAvatar extends StatelessWidget {
  const _PetAvatar({required this.url, required this.name, required this.size});

  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = normalizePetMediaUrl(url);
    if (imageUrl == null) {
      return CircleAvatar(
        radius: size / 2,
        child: Text(name.isEmpty ? '?' : name.characters.first),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        cacheKey: persistentSafeProfileAvatarUrl(imageUrl),
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: _petAvatarMemCacheWidth,
        maxWidthDiskCache: _petAvatarMemCacheWidth,
        placeholder: (_, _) => CircleAvatar(
          radius: size / 2,
          child: const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, _, _) => CircleAvatar(
          radius: size / 2,
          child: const Icon(Icons.pets_rounded),
        ),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.26),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.pets_rounded,
                size: 32,
                color: colors.accent.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 7),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PetSectionEmpty extends StatelessWidget {
  const _PetSectionEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 18,
            color: colors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.label,
    required this.retryLabel,
    required this.onRetry,
  });

  final String label;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        TextButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
    );
  }
}
