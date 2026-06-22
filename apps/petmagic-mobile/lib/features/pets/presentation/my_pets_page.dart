import 'dart:async';
import 'dart:io';

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
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
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
        appBar: AppBar(title: Text(text.profilePetsTitle)),
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
                  child: _PetAuthGate(redirectPath: MyPetsPage.routePath),
                ),
        ),
      );
    }

    final pets = ref.watch(petsProvider);
    final petsLoadRequiresSignIn = _isUnauthorizedError(pets.asError?.error);

    return Scaffold(
      appBar: AppBar(title: Text(text.profilePetsTitle)),
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
          error: (error, _) {
            if (_isUnauthorizedError(error)) {
              return Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: _PetAuthGate(redirectPath: MyPetsPage.routePath),
              );
            }

            return _StateView(
              title: text.petsLoadErrorTitle,
              actionLabel: text.petsRetryAction,
              onAction: () => ref.invalidate(petsProvider),
            );
          },
          data: (items) {
            if (items.isEmpty) {
              return _StateView(
                title: text.petsEmptyTitle,
                subtitle: text.petsEmptySubtitle,
                actionLabel: text.petsAddAction,
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
                    text: text,
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
      floatingActionButton: petsLoadRequiresSignIn
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showPetForm(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(text.petsAddAction),
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
          final text = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_petPhotoUploadErrorMessage(text, error))),
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
        appBar: AppBar(title: Text(text.petsDetailsTitle)),
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
                  child: _PetAuthGate(
                    redirectPath: PetDetailsPage.location(widget.petId),
                  ),
                ),
        ),
      );
    }

    final pets = ref.watch(petsProvider);
    final petsLoadRequiresSignIn = _isUnauthorizedError(pets.asError?.error);

    if (petsLoadRequiresSignIn) {
      return Scaffold(
        appBar: AppBar(title: Text(text.petsDetailsTitle)),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.backgroundTop, colors.backgroundBottom],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: _PetAuthGate(
              redirectPath: PetDetailsPage.location(widget.petId),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(text.petsDetailsTitle),
        actions: [
          IconButton(
            tooltip: text.petsDeleteTooltip,
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
            title: text.petsLoadPetErrorTitle,
            actionLabel: text.petsRetryAction,
            onAction: () => ref.invalidate(petsProvider),
          ),
          data: (items) {
            final pet = _findPet(items, widget.petId);
            if (pet == null) {
              return _StateView(title: text.petsNotFoundTitle);
            }

            final photos = ref.watch(petPhotosProvider(widget.petId));
            final generations = ref.watch(petGenerationsProvider(widget.petId));

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
                        text: text,
                        onEdit: () => _showPetForm(context, ref, pet: pet),
                        onGenerate: () =>
                            context.go(_templatesWithPetLocation(pet.id)),
                        onAddPhoto: () =>
                            _addPhoto(pet.id, currentAvatarUrl: pet.avatarUrl),
                        isAddingPhoto: _isAddingPhoto,
                      ),
                    ),
                  ),
                  _SectionTitleSliver(
                    title: text.petsPhotosTitle,
                    topPadding: 16,
                  ),
                  ...photos.when(
                    loading: () => const <Widget>[_PhotoGridSkeletonSliver()],
                    error: (_, _) => <Widget>[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: _InlineError(
                            label: text.petsLoadPhotosErrorTitle,
                            retryLabel: text.petsRetryAction,
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
                        text: text,
                      ),
                    ],
                  ),
                  _SectionTitleSliver(
                    title: text.petsHistoryTitle,
                    topPadding: 18,
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
                    sliver: SliverToBoxAdapter(
                      child: generations.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => _InlineError(
                          label: text.petsLoadHistoryErrorTitle,
                          retryLabel: text.petsRetryAction,
                          onRetry: () => ref.invalidate(
                            petGenerationsProvider(widget.petId),
                          ),
                        ),
                        data: (items) =>
                            _GenerationList(generations: items, text: text),
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

class _PetAuthGate extends StatelessWidget {
  const _PetAuthGate({required this.redirectPath});

  final String redirectPath;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return ProtectedAuthGate(
      title: text.petsAuthRequiredTitle,
      subtitle: text.petsAuthRequiredMessage,
      onSignIn: () => context.go(
        '${AuthEntryPage.routePath}?redirect=${Uri.encodeQueryComponent(redirectPath)}',
      ),
      onSignUp: () => context.go(RegisterEntryPage.routePath),
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
              color: colors.accent.withValues(alpha: 0.62),
              width: 1.15,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
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
                          const SizedBox(height: 3),
                          Text(
                            '${_typeLabel(pet.type, text)}${pet.breed == null ? '' : ' • ${pet.breed}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colors.textSoft),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 5,
                            children: [
                              _PetMetricChip(
                                label: text.petsStatsPhotos(pet.photosCount),
                              ),
                              _PetMetricChip(
                                label: text.petsStatsGenerations(
                                  pet.generationsCount,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.textSoft,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: pet.photosCount > 0 ? onGenerate : null,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                    label: Text(
                      text.petsCreateWithName(pet.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PetMetricChip extends StatelessWidget {
  const _PetMetricChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.48)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.textSoft,
            fontWeight: FontWeight.w800,
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
      ).showSnackBar(SnackBar(content: Text(widget.text.petsPhotoUpdateError)));
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
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        sliver: SliverToBoxAdapter(child: Text(widget.text.petsNoPhotosTitle)),
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
  const _GenerationList({required this.generations, required this.text});

  final List<TemplateGenerationResult> generations;
  final AppLocalizations text;

  @override
  Widget build(BuildContext context) {
    if (generations.isEmpty) {
      return Text(text.petsNoGenerationsTitle);
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

    return Card(
      child: ListTile(
        title: Text(generation.templateTitle ?? generation.templateId),
        subtitle: Text(
          '${generation.templateType ?? text.petsTemplateFallback} • ${generation.status.name} • ${_formatDate(generation.createdAtUtc)}',
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: text.petsOpenGenerationTooltip,
              onPressed: () => context.push(
                GenerationStatusPage.routeFor(generation.generationId),
              ),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
            IconButton(
              tooltip: text.petsShareGenerationTooltip,
              onPressed: safeOutputUrl == null
                  ? null
                  : () => SharePlus.instance.share(
                      ShareParams(text: safeOutputUrl),
                    ),
              icon: const Icon(Icons.ios_share_rounded),
            ),
            IconButton(
              tooltip: text.petsUseGenerationAsInputTooltip,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets_rounded, size: 48),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center),
            ],
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

Future<void> _showPetForm(
  BuildContext context,
  WidgetRef _, {
  PetProfile? pet,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PetFormSheet(pet: pet),
  );
}

class _PetFormSheet extends ConsumerStatefulWidget {
  const _PetFormSheet({this.pet});

  final PetProfile? pet;

  @override
  ConsumerState<_PetFormSheet> createState() => _PetFormSheetState();
}

class _PetFormSheetState extends ConsumerState<_PetFormSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.pet?.name ?? '',
  );
  late final TextEditingController _breedController = TextEditingController(
    text: widget.pet?.breed ?? '',
  );
  late String _type = widget.pet?.type ?? 'dog';
  final _picker = ImagePicker();
  XFile? _photo;
  var _step = 0;
  var _isSaving = false;
  var _showNameError = false;

  bool get _isEditing => widget.pet != null;
  bool get _isNameValid => _nameController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (_isSaving || name.isEmpty || name.length > 40) {
      setState(() => _showNameError = true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repository = ref.read(templateGenerationRepositoryProvider);
      final breed = _breedController.text.trim();
      final pet = widget.pet;
      final saved = pet == null
          ? await repository.createPet(
              name: name,
              type: _type,
              breed: breed.isEmpty ? null : breed,
            )
          : await repository.updatePet(
              petId: pet.id,
              name: name,
              type: _type,
              breed: breed.isEmpty ? null : breed,
            );
      if (!mounted) {
        return;
      }

      final selectedPhoto = _photo;
      if (selectedPhoto != null) {
        final uploadedPhoto = await repository.uploadPetPhoto(
          petId: saved.id,
          photo: selectedPhoto,
        );
        if (!uploadedPhoto.isAvatar && uploadedPhoto.id.isNotEmpty) {
          await repository.setPetPhotoAsAvatar(
            petId: saved.id,
            photoId: uploadedPhoto.id,
          );
        }
        if (!mounted) {
          return;
        }
      }

      ref.invalidate(petsProvider);
      ref.invalidate(petPhotosProvider(saved.id));
      await Future.wait([
        _ignoreRefreshFailure(ref.read(petsProvider.future)),
        _ignoreRefreshFailure(ref.read(petPhotosProvider(saved.id).future)),
      ]);
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 92,
    );
    if (!mounted || picked == null) {
      return;
    }

    setState(() => _photo = picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceStrong,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border.withValues(alpha: 0.72)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: 14),
                _PetFormProgress(currentStep: _isEditing ? 2 : _step),
                const SizedBox(height: 22),
                Text(
                  _isEditing ? text.petsEditTitle : text.petsAddTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (!_isEditing)
                  _buildCreateStepper(text)
                else
                  _buildEditForm(text),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateStepper(AppLocalizations text) {
    final isLast = _step == 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: switch (_step) {
            0 => _PetNameStep(
              key: const ValueKey('pet-name-step'),
              controller: _nameController,
              enabled: !_isSaving,
              showError: _showNameError && !_isNameValid,
              text: text,
              onChanged: (_) {
                if (_showNameError && _isNameValid) {
                  setState(() => _showNameError = false);
                }
              },
            ),
            1 => _PetTypeStep(
              key: const ValueKey('pet-type-step'),
              type: _type,
              breedController: _breedController,
              enabled: !_isSaving,
              text: text,
              onTypeChanged: (value) => setState(() => _type = value),
            ),
            _ => _PetPhotoStep(
              key: const ValueKey('pet-photo-step'),
              photo: _photo,
              enabled: !_isSaving,
              text: text,
              onPickPhoto: _pickPhoto,
            ),
          },
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            if (_step > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () => setState(() => _step -= 1),
                  child: Text(text.petsBackAction),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (_step == 0)
              Expanded(
                child: _PetFormPrimaryButton(
                  label: isLast ? text.petsDoneAction : text.petsNextAction,
                  isSaving: _isSaving,
                  onPressed: () async {
                    if (!_isNameValid) {
                      setState(() => _showNameError = true);
                      return;
                    }
                    setState(() => _step += 1);
                  },
                ),
              )
            else
              SizedBox(
                width: 132,
                child: _PetFormPrimaryButton(
                  label: isLast ? text.petsDoneAction : text.petsNextAction,
                  isSaving: _isSaving,
                  onPressed: () async {
                    if (!isLast) {
                      setState(() => _step += 1);
                      return;
                    }

                    await _save();
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditForm(AppLocalizations text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PetNameStep(
          controller: _nameController,
          enabled: !_isSaving,
          showError: _showNameError && !_isNameValid,
          text: text,
          onChanged: (_) {
            if (_showNameError && _isNameValid) {
              setState(() => _showNameError = false);
            }
          },
        ),
        const SizedBox(height: 18),
        _PetTypeStep(
          type: _type,
          breedController: _breedController,
          enabled: !_isSaving,
          text: text,
          onTypeChanged: (value) => setState(() => _type = value),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(text.petsSaveAction),
        ),
      ],
    );
  }
}

class _PetFormProgress extends StatelessWidget {
  const _PetFormProgress({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Row(
      children: [
        for (var index = 0; index < 3; index++) ...[
          _PetProgressDot(index: index, currentStep: currentStep),
          if (index < 2)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: index < currentStep
                    ? colors.accent.withValues(alpha: 0.78)
                    : colors.border.withValues(alpha: 0.62),
              ),
            ),
        ],
      ],
    );
  }
}

class _PetFormPrimaryButton extends StatelessWidget {
  const _PetFormPrimaryButton({
    required this.label,
    required this.isSaving,
    required this.onPressed,
  });

  final String label;
  final bool isSaving;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isSaving ? null : () => unawaited(onPressed()),
      child: isSaving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

class _PetProgressDot extends StatelessWidget {
  const _PetProgressDot({required this.index, required this.currentStep});

  final int index;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isDone = index < currentStep;
    final isActive = index == currentStep;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? colors.accent : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDone || isActive
              ? colors.accent
              : colors.border.withValues(alpha: 0.82),
          width: 1.4,
        ),
      ),
      child: isDone
          ? Icon(Icons.check_rounded, size: 17, color: colors.accent)
          : Text(
              '${index + 1}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isActive ? Colors.black : colors.textMuted,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}

class _PetNameStep extends StatelessWidget {
  const _PetNameStep({
    super.key,
    required this.controller,
    required this.enabled,
    required this.showError,
    required this.text,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool showError;
  final AppLocalizations text;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PetStepHeading(
          title: text.petsNameStepTitle,
          subtitle: text.petsNameStepSubtitle,
        ),
        const SizedBox(height: 18),
        TextField(
          controller: controller,
          maxLength: 40,
          enabled: enabled,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: text.petsNameHint,
            errorText: showError ? text.petsNameRequiredError : null,
            counterStyle: TextStyle(color: colors.textMuted),
          ),
        ),
        Text(
          text.petsNameExample,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textMuted,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _PetTypeStep extends StatelessWidget {
  const _PetTypeStep({
    super.key,
    required this.type,
    required this.breedController,
    required this.enabled,
    required this.text,
    required this.onTypeChanged,
  });

  final String type;
  final TextEditingController breedController;
  final bool enabled;
  final AppLocalizations text;
  final ValueChanged<String> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PetStepHeading(
          title: text.petsTypeBreedTitle,
          subtitle: text.petsTypeBreedStepSubtitle,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _PetTypeChip(
                label: text.petsDogType,
                icon: Icons.pets_rounded,
                selected: type == 'dog',
                onTap: enabled ? () => onTypeChanged('dog') : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PetTypeChip(
                label: text.petsCatType,
                icon: Icons.cruelty_free_outlined,
                selected: type == 'cat',
                onTap: enabled ? () => onTypeChanged('cat') : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PetTypeChip(
                label: text.petsOtherType,
                icon: Icons.inventory_2_outlined,
                selected: type == 'other',
                onTap: enabled ? () => onTypeChanged('other') : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: breedController,
          maxLength: 60,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: text.petsBreedLabel,
            hintText: text.petsBreedHint,
          ),
        ),
      ],
    );
  }
}

class _PetTypeChip extends StatelessWidget {
  const _PetTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.18)
              : colors.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? colors.accent
                : colors.border.withValues(alpha: 0.7),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? colors.accent : colors.textSoft,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? colors.accent : colors.textSoft,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetPhotoStep extends StatelessWidget {
  const _PetPhotoStep({
    super.key,
    required this.photo,
    required this.enabled,
    required this.text,
    required this.onPickPhoto,
  });

  final XFile? photo;
  final bool enabled;
  final AppLocalizations text;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final selectedPhoto = photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PetStepHeading(
          title: text.petsPhotoStepTitle,
          subtitle: text.petsPhotoStepSubtitle,
        ),
        const SizedBox(height: 18),
        Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: enabled ? onPickPhoto : null,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surface.withValues(alpha: 0.86),
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.62),
                  width: 1.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: selectedPhoto == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          color: colors.accent,
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          text.petsAddPhotoAction,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colors.accent,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          text.petsPhotoFormatHint,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.textMuted, height: 1.15),
                        ),
                      ],
                    )
                  : Image.file(File(selectedPhoto.path), fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          selectedPhoto == null
              ? text.petsAddPhotoLaterHint
              : text.petsPhotoSelectedLabel,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textMuted,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _PetStepHeading extends StatelessWidget {
  const _PetStepHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.textStrong,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textSoft, height: 1.32),
        ),
      ],
    );
  }
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

  final repository = ref.read(templateGenerationRepositoryProvider);
  var uploadedPhoto = await repository.uploadPetPhoto(
    petId: petId,
    photo: picked,
    cancelToken: cancelToken,
  );
  if (cancelToken.isCancelled) {
    return;
  }
  if ((currentAvatarUrl == null || currentAvatarUrl.trim().isEmpty) &&
      !uploadedPhoto.isAvatar &&
      uploadedPhoto.id.isNotEmpty) {
    uploadedPhoto = await repository.setPetPhotoAsAvatar(
      petId: petId,
      photoId: uploadedPhoto.id,
      cancelToken: cancelToken,
    );
    if (cancelToken.isCancelled) {
      return;
    }
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

bool _isUnauthorizedError(Object? error) {
  return error is AppException && error.statusCode == 401;
}

String _petPhotoUploadErrorMessage(AppLocalizations text, Object error) {
  if (error is AppException &&
      error.message.trim() == 'pets.photo_type_not_allowed') {
    return text.petsUnsupportedPhotoTypeError;
  }

  return text.petsPhotoUploadError;
}

Future<void> _deletePet(
  BuildContext context,
  WidgetRef ref,
  String petId,
) async {
  final text = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(text.petsDeleteConfirmTitle),
      content: Text(text.petsDeleteConfirmMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(text.petsCancelAction),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(text.petsDeleteConfirmAction),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }

  await ref.read(templateGenerationRepositoryProvider).deletePet(petId);
  ref.invalidate(petsProvider);
  if (context.mounted) {
    context.pop();
  }
}

String _typeLabel(String value, AppLocalizations text) {
  return switch (value) {
    'dog' => text.petsDogType,
    'cat' => text.petsCatType,
    _ => text.petsOtherType,
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
  final thumbnailUrl = photo.thumbnailUrl?.trim();
  if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
    final normalizedThumbnail = _normalizePetMediaUrl(thumbnailUrl);
    if (normalizedThumbnail != null) {
      return normalizedThumbnail;
    }
  }

  return _normalizePetMediaUrl(photo.url);
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
