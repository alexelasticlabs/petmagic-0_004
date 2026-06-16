import 'dart:async';

import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:share_plus/share_plus.dart';

const _petGalleryProviderCacheTtl = Duration(minutes: 1);
const int _petPhotoThumbnailMemCacheWidth = 512;
const int _petAvatarMemCacheWidth = 192;

Duration? _noPetGalleryProviderRetry(int retryCount, Object error) => null;

final petsProvider = FutureProvider.autoDispose<List<PetProfile>>((ref) {
  final cacheLink = ref.keepAlive();
  final cancelToken = CancelToken();
  Timer? cacheTimer;
  ref.onCancel(() {
    cacheTimer = Timer(_petGalleryProviderCacheTtl, cacheLink.close);
  });
  ref.onResume(() => cacheTimer?.cancel());
  ref.onDispose(() {
    cacheTimer?.cancel();
    if (!cancelToken.isCancelled) {
      cancelToken.cancel('pets_provider_disposed');
    }
  });
  return ref
      .watch(templateGenerationRepositoryProvider)
      .fetchPets(cancelToken: cancelToken);
}, retry: _noPetGalleryProviderRetry);

final petPhotosProvider = FutureProvider.autoDispose
    .family<List<PetPhoto>, String>((ref, petId) {
      final cacheLink = ref.keepAlive();
      final cancelToken = CancelToken();
      Timer? cacheTimer;
      ref.onCancel(() {
        cacheTimer = Timer(_petGalleryProviderCacheTtl, cacheLink.close);
      });
      ref.onResume(() => cacheTimer?.cancel());
      ref.onDispose(() {
        cacheTimer?.cancel();
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('pet_photos_provider_disposed');
        }
      });
      return ref
          .watch(templateGenerationRepositoryProvider)
          .fetchPetPhotos(petId, cancelToken: cancelToken);
    }, retry: _noPetGalleryProviderRetry);

final petGenerationsProvider = FutureProvider.autoDispose
    .family<List<TemplateGenerationResult>, String>((ref, petId) {
      final cacheLink = ref.keepAlive();
      final cancelToken = CancelToken();
      Timer? cacheTimer;
      ref.onCancel(() {
        cacheTimer = Timer(_petGalleryProviderCacheTtl, cacheLink.close);
      });
      ref.onResume(() => cacheTimer?.cancel());
      ref.onDispose(() {
        cacheTimer?.cancel();
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('pet_generations_provider_disposed');
        }
      });
      return ref
          .watch(templateGenerationRepositoryProvider)
          .fetchPetGenerations(petId, cancelToken: cancelToken);
    }, retry: _noPetGalleryProviderRetry);

class MyPetsPage extends ConsumerWidget {
  const MyPetsPage({super.key});

  static const routePath = '/profile/pets';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.petMagicColors;
    final launchState = ref.watch(appLaunchControllerProvider);
    final text = AppLocalizations.of(context);
    final bottomInset = petMagicScrollableBottomInset(context);

    if (launchState.isLoading || !launchState.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('My pets')),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.backgroundTop, colors.backgroundBottom],
            ),
          ),
          child: launchState.isLoading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: ProtectedAuthGate(
                    subtitle: text.authRequiredMessage,
                    onSignIn: () {
                      unawaited(
                        showAuthRequiredSheet(
                          context,
                          redirectPath: MyPetsPage.routePath,
                        ),
                      );
                    },
                  ),
                ),
        ),
      );
    }

    final pets = ref.watch(petsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My pets')),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.backgroundTop, colors.backgroundBottom],
          ),
        ),
        child: pets.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (error, _) => _StateView(
            title: 'Could not load pets',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(petsProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _StateView(
                title: 'Добавьте первого питомца',
                actionLabel: 'Add pet',
                onAction: () => _showPetForm(context, ref),
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: () => _refreshPets(ref),
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final pet = items[index];
                  return _PetCard(
                    pet: pet,
                    onTap: () => context.push(PetDetailsPage.location(pet.id)),
                    onGenerate: () =>
                        context.go(_templatesWithPetLocation(pet.id)),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPetForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add pet'),
      ),
    );
  }
}

class PetDetailsPage extends ConsumerStatefulWidget {
  const PetDetailsPage({required this.petId, super.key});

  static const routePath = '/profile/pets/:petId';

  static String location(String petId) =>
      '/profile/pets/${Uri.encodeComponent(petId)}';

  final String petId;

  @override
  ConsumerState<PetDetailsPage> createState() => _PetDetailsPageState();
}

class _PetDetailsPageState extends ConsumerState<PetDetailsPage> {
  bool _isAddingPhoto = false;
  CancelToken? _addPhotoCancelToken;

  @override
  void didUpdateWidget(covariant PetDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petId == widget.petId) {
      return;
    }

    final cancelToken = _addPhotoCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('pet_photo_upload_pet_changed');
    }
    _addPhotoCancelToken = null;
    if (_isAddingPhoto) {
      setState(() => _isAddingPhoto = false);
    }
  }

  void _addPhoto(String petId, {String? currentAvatarUrl}) {
    if (_isAddingPhoto) {
      return;
    }

    final cancelToken = CancelToken();
    _addPhotoCancelToken = cancelToken;
    setState(() => _isAddingPhoto = true);
    unawaited(() async {
      try {
        await _pickAndUploadPhoto(
          context,
          ref,
          petId,
          currentAvatarUrl: currentAvatarUrl,
          cancelToken: cancelToken,
        );
      } on Object catch (error) {
        if (_isPetPhotoRequestCancelled(error, cancelToken)) {
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_petPhotoUploadErrorMessage(error))),
          );
        }
      } finally {
        final isActiveUpload = identical(_addPhotoCancelToken, cancelToken);
        if (isActiveUpload) {
          _addPhotoCancelToken = null;
        }
        if (mounted && isActiveUpload) {
          setState(() => _isAddingPhoto = false);
        }
      }
    }());
  }

  @override
  void dispose() {
    final cancelToken = _addPhotoCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('pet_photo_upload_disposed');
    }
    _addPhotoCancelToken = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final launchState = ref.watch(appLaunchControllerProvider);
    final text = AppLocalizations.of(context);
    final bottomInset = petMagicScrollableBottomInset(context);

    if (launchState.isLoading || !launchState.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pet details')),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.backgroundTop, colors.backgroundBottom],
            ),
          ),
          child: launchState.isLoading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: ProtectedAuthGate(
                    subtitle: text.authRequiredMessage,
                    onSignIn: () {
                      unawaited(
                        showAuthRequiredSheet(
                          context,
                          redirectPath: PetDetailsPage.location(widget.petId),
                        ),
                      );
                    },
                  ),
                ),
        ),
      );
    }

    final pets = ref.watch(petsProvider);
    final photos = ref.watch(petPhotosProvider(widget.petId));
    final generations = ref.watch(petGenerationsProvider(widget.petId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pet details'),
        actions: [
          IconButton(
            tooltip: 'Delete pet',
            onPressed: () => _deletePet(context, ref, widget.petId),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.backgroundTop, colors.backgroundBottom],
          ),
        ),
        child: pets.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (_, _) => _StateView(
            title: 'Could not load pet',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(petsProvider),
          ),
          data: (items) {
            final pet = _findPet(items, widget.petId);
            if (pet == null) {
              return const _StateView(title: 'Pet not found');
            }

            return RefreshIndicator.adaptive(
              onRefresh: () => _refreshPetDetails(ref, widget.petId),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _PetHeader(
                        pet: pet,
                        onEdit: () => _showPetForm(context, ref, pet: pet),
                        onGenerate: () =>
                            context.go(_templatesWithPetLocation(pet.id)),
                        onAddPhoto: () =>
                            _addPhoto(pet.id, currentAvatarUrl: pet.avatarUrl),
                        isAddingPhoto: _isAddingPhoto,
                      ),
                    ),
                  ),
                  _SectionTitleSliver(title: 'Photos', topPadding: 16),
                  ...photos.when(
                    loading: () => const <Widget>[_PhotoGridSkeletonSliver()],
                    error: (_, _) => <Widget>[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: _InlineError(
                            label: 'Could not load photos',
                            onRetry: () =>
                                ref.invalidate(petPhotosProvider(widget.petId)),
                          ),
                        ),
                      ),
                    ],
                    data: (items) => <Widget>[
                      _PhotoGrid(
                        petId: pet.id,
                        currentAvatarUrl: pet.avatarUrl,
                        photos: items,
                      ),
                    ],
                  ),
                  _SectionTitleSliver(
                    title: 'Generation history',
                    topPadding: 18,
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
                    sliver: SliverToBoxAdapter(
                      child: generations.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => _InlineError(
                          label: 'Could not load history',
                          onRetry: () => ref.invalidate(
                            petGenerationsProvider(widget.petId),
                          ),
                        ),
                        data: (items) => _GenerationList(generations: items),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({
    required this.pet,
    required this.onTap,
    required this.onGenerate,
  });

  final PetProfile pet;
  final VoidCallback onTap;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _PetAvatar(url: pet.avatarUrl, name: pet.name, size: 64),
                  const SizedBox(width: 12),
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
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          '${_typeLabel(pet.type)}${pet.breed == null ? '' : ' • ${pet.breed}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${pet.photosCount} photos • ${pet.generationsCount} generations',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: pet.photosCount > 0 ? onGenerate : null,
                child: Text(
                  'Create with ${pet.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetHeader extends StatelessWidget {
  const _PetHeader({
    required this.pet,
    required this.onEdit,
    required this.onGenerate,
    required this.onAddPhoto,
    required this.isAddingPhoto,
  });

  final PetProfile pet;
  final VoidCallback onEdit;
  final VoidCallback onGenerate;
  final VoidCallback onAddPhoto;
  final bool isAddingPhoto;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PetAvatar(url: pet.avatarUrl, name: pet.name, size: 84),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${_typeLabel(pet.type)}${pet.breed == null ? '' : ' • ${pet.breed}'}',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: pet.photosCount > 0 ? onGenerate : null,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text('Generate with ${pet.name}'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Add photos',
                  onPressed: isAddingPhoto ? null : onAddPhoto,
                  icon: isAddingPhoto
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.add_a_photo_outlined),
                ),
              ],
            ),
            if (pet.photosCount == 0) ...[
              const SizedBox(height: 8),
              Text('Добавьте фото ${pet.name}, чтобы начать'),
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
  });

  final String petId;
  final String? currentAvatarUrl;
  final List<PetPhoto> photos;

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
    _photoActionCancelTokens[photo.id] = cancelToken;
    setState(() => _busyPhotoIds.add(photo.id));
    try {
      await action(cancelToken);
    } on Object catch (error) {
      if (_isPetPhotoRequestCancelled(error, cancelToken)) {
        return;
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not update photo')));
    } finally {
      final isActiveAction = identical(
        _photoActionCancelTokens[photo.id],
        cancelToken,
      );
      if (mounted && isActiveAction) {
        setState(() => _busyPhotoIds.remove(photo.id));
      }
      if (isActiveAction) {
        _photoActionCancelTokens.remove(photo.id);
      }
    }
  }

  @override
  void dispose() {
    for (final cancelToken in _photoActionCancelTokens.values) {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('pet_photo_action_disposed');
      }
    }
    _photoActionCancelTokens.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return const SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
        sliver: SliverToBoxAdapter(child: Text('No photos yet.')),
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
                : () => context.go(
                    _templatesWithPetLocation(
                      widget.petId,
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
    required this.onSetAvatar,
    required this.onSetFavorite,
    required this.onUseForGeneration,
    required this.onDelete,
  });

  final PetPhoto photo;
  final bool isBusy;
  final VoidCallback onSetAvatar;
  final VoidCallback onSetFavorite;
  final VoidCallback? onUseForGeneration;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final imageUrl = _petPhotoDisplayUrl(photo);

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
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: _petPhotoThumbnailMemCacheWidth,
                        maxWidthDiskCache: _petPhotoThumbnailMemCacheWidth,
                        placeholder: (_, _) => const _PetPhotoImageSkeleton(),
                        errorWidget: (_, _, _) =>
                            const _PetPhotoImageFallback(),
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
                        tooltip: 'Set as avatar',
                        icon: Icons.account_circle_outlined,
                        onPressed: isBusy ? null : onSetAvatar,
                      ),
                      _PetPhotoActionButton(
                        tooltip: 'Mark favorite',
                        icon: photo.isFavorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        onPressed: isBusy ? null : onSetFavorite,
                      ),
                      _PetPhotoActionButton(
                        tooltip: 'Use for generation',
                        icon: Icons.auto_awesome_rounded,
                        onPressed: onUseForGeneration,
                      ),
                      _PetPhotoActionButton(
                        tooltip: 'Delete photo',
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
                  const _PetPhotoBadge(
                    label: 'Avatar',
                    icon: Icons.account_circle_rounded,
                  ),
                if (photo.isFavorite)
                  const _PetPhotoBadge(
                    label: 'Favorite',
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
      color: colors.surfaceStrong,
      child: Icon(Icons.broken_image_outlined, color: colors.textMuted),
    );
  }
}

class _GenerationList extends StatelessWidget {
  const _GenerationList({required this.generations});

  final List<TemplateGenerationResult> generations;

  @override
  Widget build(BuildContext context) {
    if (generations.isEmpty) {
      return const Text('No generations yet.');
    }

    return Column(
      children: [
        for (final generation in generations.take(12))
          _PetGenerationHistoryTile(generation: generation),
      ],
    );
  }
}

class _PetGenerationHistoryTile extends StatelessWidget {
  const _PetGenerationHistoryTile({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final safeOutputUrl = parseSafeGenerationMediaUri(
      generation.outputUrl,
    )?.toString();

    return Card(
      child: ListTile(
        title: Text(generation.templateTitle ?? generation.templateId),
        subtitle: Text(
          '${generation.templateType ?? 'Template'} • ${generation.status.name} • ${_formatDate(generation.createdAtUtc)}',
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Open',
              onPressed: () => context.push(
                GenerationStatusPage.routeFor(generation.generationId),
              ),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
            IconButton(
              tooltip: 'Share',
              onPressed: safeOutputUrl == null
                  ? null
                  : () => SharePlus.instance.share(
                      ShareParams(text: safeOutputUrl),
                    ),
              icon: const Icon(Icons.ios_share_rounded),
            ),
            IconButton(
              tooltip: 'Use as input',
              onPressed: () => context.go(
                _templatesWithPetLocation(
                  generation.petId ?? '',
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

class _PetAvatar extends StatelessWidget {
  const _PetAvatar({required this.url, required this.name, required this.size});

  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _normalizePetMediaUrl(url);
    if (imageUrl == null) {
      return CircleAvatar(
        radius: size / 2,
        child: Text(name.isEmpty ? '?' : name.characters.first),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
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
  const _StateView({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets_rounded, size: 48),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.label, required this.onRetry});

  final String label;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

Future<void> _showPetForm(
  BuildContext context,
  WidgetRef ref, {
  PetProfile? pet,
}) async {
  final nameController = TextEditingController(text: pet?.name ?? '');
  final breedController = TextEditingController(text: pet?.breed ?? '');
  var type = pet?.type ?? 'dog';
  XFile? photo;
  var step = 0;
  final picker = ImagePicker();

  Future<void> save(BuildContext sheetContext) async {
    final name = nameController.text.trim();
    if (name.isEmpty || name.length > 40) {
      return;
    }

    final repository = ref.read(templateGenerationRepositoryProvider);
    final saved = pet == null
        ? await repository.createPet(
            name: name,
            type: type,
            breed: breedController.text.trim().isEmpty
                ? null
                : breedController.text.trim(),
          )
        : await repository.updatePet(
            petId: pet.id,
            name: name,
            type: type,
            breed: breedController.text.trim().isEmpty
                ? null
                : breedController.text.trim(),
          );
    final selectedPhoto = photo;
    if (selectedPhoto != null) {
      await repository.uploadPetPhoto(petId: saved.id, photo: selectedPhoto);
    }
    ref.invalidate(petsProvider);
    ref.invalidate(petPhotosProvider(saved.id));
    if (sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              pet == null ? 'Add pet' : 'Edit pet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (pet == null)
              Stepper(
                currentStep: step,
                type: StepperType.vertical,
                margin: EdgeInsets.zero,
                onStepTapped: (value) => setState(() => step = value),
                controlsBuilder: (context, details) {
                  final isLast = step == 2;
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        FilledButton(
                          onPressed: () async {
                            if (step == 0 &&
                                nameController.text.trim().isEmpty) {
                              return;
                            }

                            if (!isLast) {
                              setState(() => step += 1);
                              return;
                            }

                            await save(context);
                          },
                          child: Text(isLast ? 'Save' : 'Next'),
                        ),
                        if (step > 0) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setState(() => step -= 1),
                            child: const Text('Back'),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                steps: [
                  Step(
                    title: const Text('Name'),
                    isActive: step >= 0,
                    content: TextField(
                      controller: nameController,
                      maxLength: 40,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                  ),
                  Step(
                    title: const Text('Type and breed'),
                    isActive: step >= 1,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'dog', label: Text('Dog')),
                            ButtonSegment(value: 'cat', label: Text('Cat')),
                            ButtonSegment(value: 'other', label: Text('Other')),
                          ],
                          selected: {type},
                          onSelectionChanged: (value) =>
                              setState(() => type = value.first),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: breedController,
                          maxLength: 60,
                          decoration: const InputDecoration(labelText: 'Breed'),
                        ),
                      ],
                    ),
                  ),
                  Step(
                    title: const Text('Photo'),
                    isActive: step >= 2,
                    content: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 2048,
                            imageQuality: 92,
                          );
                          if (picked != null) {
                            setState(() => photo = picked);
                          }
                        },
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: Text(
                          photo == null
                              ? 'Choose first photo'
                              : 'Photo selected',
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              TextField(
                controller: nameController,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'dog', label: Text('Dog')),
                  ButtonSegment(value: 'cat', label: Text('Cat')),
                  ButtonSegment(value: 'other', label: Text('Other')),
                ],
                selected: {type},
                onSelectionChanged: (value) =>
                    setState(() => type = value.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: breedController,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Breed'),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => save(context),
                child: const Text('Save'),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  nameController.dispose();
  breedController.dispose();
}

Future<void> _pickAndUploadPhoto(
  BuildContext context,
  WidgetRef ref,
  String petId, {
  String? currentAvatarUrl,
  required CancelToken cancelToken,
}) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 2048,
    imageQuality: 92,
  );
  if (picked == null || cancelToken.isCancelled) {
    return;
  }

  final uploadedPhoto = await ref
      .read(templateGenerationRepositoryProvider)
      .uploadPetPhoto(petId: petId, photo: picked, cancelToken: cancelToken);
  if (cancelToken.isCancelled) {
    return;
  }
  await _evictPetMediaUrl(currentAvatarUrl);
  await _evictPetPhotoMedia(uploadedPhoto);
  if (cancelToken.isCancelled) {
    return;
  }
  ref.invalidate(petsProvider);
  ref.invalidate(petPhotosProvider(petId));
}

Future<void> _setAvatar(
  WidgetRef ref,
  String petId,
  PetPhoto photo, {
  String? currentAvatarUrl,
  required CancelToken cancelToken,
}) async {
  final updatedPhoto = await ref
      .read(templateGenerationRepositoryProvider)
      .setPetPhotoAsAvatar(
        petId: petId,
        photoId: photo.id,
        cancelToken: cancelToken,
      );
  if (cancelToken.isCancelled) {
    return;
  }
  await _evictPetMediaUrl(currentAvatarUrl);
  await _evictPetPhotoMedia(photo);
  await _evictPetPhotoMedia(updatedPhoto);
  if (cancelToken.isCancelled) {
    return;
  }
  ref.invalidate(petsProvider);
  ref.invalidate(petPhotosProvider(petId));
}

Future<void> _setFavorite(
  WidgetRef ref,
  String petId,
  PetPhoto photo, {
  required CancelToken cancelToken,
}) async {
  await ref
      .read(templateGenerationRepositoryProvider)
      .setPetPhotoFavorite(
        petId: petId,
        photoId: photo.id,
        isFavorite: !photo.isFavorite,
        cancelToken: cancelToken,
      );
  if (cancelToken.isCancelled) {
    return;
  }
  ref.invalidate(petPhotosProvider(petId));
}

Future<void> _deletePhoto(
  WidgetRef ref,
  String petId,
  PetPhoto photo, {
  String? currentAvatarUrl,
  required CancelToken cancelToken,
}) async {
  await ref
      .read(templateGenerationRepositoryProvider)
      .deletePetPhoto(
        petId: petId,
        photoId: photo.id,
        cancelToken: cancelToken,
      );
  if (cancelToken.isCancelled) {
    return;
  }
  await _evictPetMediaUrl(currentAvatarUrl);
  await _evictPetPhotoMedia(photo);
  if (cancelToken.isCancelled) {
    return;
  }
  ref.invalidate(petsProvider);
  ref.invalidate(petPhotosProvider(petId));
}

bool _isPetPhotoRequestCancelled(Object error, CancelToken cancelToken) {
  return cancelToken.isCancelled ||
      (error is DioException && CancelToken.isCancel(error));
}

String _petPhotoUploadErrorMessage(Object error) {
  if (error is AppException &&
      error.message.trim() == 'pets.photo_type_not_allowed') {
    return 'This photo type is not supported';
  }

  return 'Could not upload photo';
}

Future<void> _deletePet(
  BuildContext context,
  WidgetRef ref,
  String petId,
) async {
  await ref.read(templateGenerationRepositoryProvider).deletePet(petId);
  ref.invalidate(petsProvider);
  if (context.mounted) {
    context.pop();
  }
}

String _typeLabel(String value) {
  return switch (value) {
    'dog' => 'Dog',
    'cat' => 'Cat',
    _ => 'Other',
  };
}

String _formatDate(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

Future<void> _refreshPets(WidgetRef ref) {
  ref.invalidate(petsProvider);
  return _ignoreRefreshFailure(ref.read(petsProvider.future));
}

Future<void> _refreshPetDetails(WidgetRef ref, String petId) {
  ref.invalidate(petsProvider);
  ref.invalidate(petPhotosProvider(petId));
  ref.invalidate(petGenerationsProvider(petId));
  return Future.wait<void>([
    _ignoreRefreshFailure(ref.read(petsProvider.future)),
    _ignoreRefreshFailure(ref.read(petPhotosProvider(petId).future)),
    _ignoreRefreshFailure(ref.read(petGenerationsProvider(petId).future)),
  ]);
}

Future<void> _ignoreRefreshFailure<T>(Future<T> future) async {
  try {
    await future;
  } on Object {
    // Provider state renders the refresh error; keep the pull gesture finite.
  }
}

String _templatesWithPetLocation(String petId, {String? petPhotoId}) {
  final normalizedPetId = petId.trim();
  if (normalizedPetId.isEmpty) {
    return TemplatesPage.routePath;
  }

  return Uri(
    path: TemplatesPage.routePath,
    queryParameters: {
      'petId': normalizedPetId,
      if (petPhotoId != null && petPhotoId.isNotEmpty) 'petPhotoId': petPhotoId,
    },
  ).toString();
}

String? _petPhotoDisplayUrl(PetPhoto photo) {
  return _normalizePetMediaUrl(photo.thumbnailUrl);
}

Future<void> _evictPetPhotoMedia(PetPhoto photo) async {
  await Future.wait([
    _evictPetMediaUrl(photo.thumbnailUrl),
    _evictPetMediaUrl(photo.url),
  ]);
}

Future<void> _evictPetMediaUrl(String? rawUrl) async {
  final imageUrl = _normalizePetMediaUrl(rawUrl);
  if (imageUrl == null) {
    return;
  }

  try {
    await CachedNetworkImage.evictFromCache(imageUrl);
  } on Object {
    // Provider invalidation still refreshes metadata; image-cache eviction is best-effort.
  }
}

String? _normalizePetMediaUrl(String? rawUrl) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final sanitized = Uri.encodeFull(trimmed.replaceAll('\\', '/'));
  final parsed = Uri.tryParse(sanitized);
  final candidate = parsed?.hasScheme == true
      ? parsed.toString()
      : Uri.tryParse(AppConfig.apiBaseUrl)
            ?.resolve(sanitized.startsWith('/') ? sanitized : '/$sanitized')
            .toString();
  if (candidate == null) {
    return null;
  }

  return parseSafeProfileAvatarUri(candidate)?.toString();
}

PetProfile? _findPet(List<PetProfile> pets, String petId) {
  for (final pet in pets) {
    if (pet.id == petId) {
      return pet;
    }
  }

  return null;
}
