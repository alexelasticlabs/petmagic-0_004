import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:share_plus/share_plus.dart';

final petsProvider = FutureProvider.autoDispose<List<PetProfile>>((ref) {
  return ref.watch(templateGenerationRepositoryProvider).fetchPets();
});

final petPhotosProvider = FutureProvider.autoDispose
    .family<List<PetPhoto>, String>((ref, petId) {
      return ref
          .watch(templateGenerationRepositoryProvider)
          .fetchPetPhotos(petId);
    });

final petGenerationsProvider = FutureProvider.autoDispose
    .family<List<TemplateGenerationResult>, String>((ref, petId) {
      return ref
          .watch(templateGenerationRepositoryProvider)
          .fetchPetGenerations(petId);
    });

class MyPetsPage extends ConsumerWidget {
  const MyPetsPage({super.key});

  static const routePath = '/profile/pets';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.petMagicColors;
    final pets = ref.watch(petsProvider);
    final bottomInset = petMagicScrollableBottomInset(context);

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
              onRefresh: () async => ref.invalidate(petsProvider),
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

class PetDetailsPage extends ConsumerWidget {
  const PetDetailsPage({required this.petId, super.key});

  static const routePath = '/profile/pets/:petId';

  static String location(String petId) => '/profile/pets/$petId';

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petsProvider);
    final photos = ref.watch(petPhotosProvider(petId));
    final generations = ref.watch(petGenerationsProvider(petId));
    final colors = context.petMagicColors;
    final bottomInset = petMagicScrollableBottomInset(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pet details'),
        actions: [
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _deletePet(context, ref, petId),
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
            final pet = _findPet(items, petId);
            if (pet == null) {
              return const _StateView(title: 'Pet not found');
            }

            return RefreshIndicator.adaptive(
              onRefresh: () async {
                ref.invalidate(petsProvider);
                ref.invalidate(petPhotosProvider(petId));
                ref.invalidate(petGenerationsProvider(petId));
              },
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
                children: [
                  _PetHeader(
                    pet: pet,
                    onEdit: () => _showPetForm(context, ref, pet: pet),
                    onGenerate: () =>
                        context.go(_templatesWithPetLocation(pet.id)),
                    onAddPhoto: () => _pickAndUploadPhoto(context, ref, pet.id),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Photos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  photos.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => _InlineError(
                      label: 'Could not load photos',
                      onRetry: () => ref.invalidate(petPhotosProvider(petId)),
                    ),
                    data: (items) => _PhotoGrid(petId: pet.id, photos: items),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Generation history',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  generations.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => _InlineError(
                      label: 'Could not load history',
                      onRetry: () =>
                          ref.invalidate(petGenerationsProvider(petId)),
                    ),
                    data: (items) => _GenerationList(generations: items),
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
  });

  final PetProfile pet;
  final VoidCallback onEdit;
  final VoidCallback onGenerate;
  final VoidCallback onAddPhoto;

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
                  onPressed: onAddPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
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

class _PhotoGrid extends ConsumerWidget {
  const _PhotoGrid({required this.petId, required this.photos});

  final String petId;
  final List<PetPhoto> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (photos.isEmpty) {
      return const Text('No photos yet.');
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Image.network(
                  photo.thumbnailUrl ?? photo.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (photo.isAvatar) const Chip(label: Text('Avatar')),
                    if (photo.isFavorite) const Chip(label: Text('Favorite')),
                    IconButton.filledTonal(
                      tooltip: 'Set as avatar',
                      onPressed: () => _setAvatar(ref, petId, photo.id),
                      icon: const Icon(Icons.account_circle_outlined),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Mark favorite',
                      onPressed: () => _setFavorite(ref, petId, photo),
                      icon: Icon(
                        photo.isFavorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Use for generation',
                      onPressed: () => context.go(
                        '${TemplatesPage.routePath}?petId=${Uri.encodeComponent(petId)}&petPhotoId=${Uri.encodeComponent(photo.id)}',
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Delete',
                      onPressed: () => _deletePhoto(ref, petId, photo.id),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
          Card(
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
                      '${GenerationStatusPage.routePrefix}/${generation.generationId}',
                    ),
                    icon: const Icon(Icons.open_in_new_rounded),
                  ),
                  IconButton(
                    tooltip: 'Share',
                    onPressed: generation.outputUrl == null
                        ? null
                        : () => SharePlus.instance.share(
                            ShareParams(text: generation.outputUrl!),
                          ),
                    icon: const Icon(Icons.ios_share_rounded),
                  ),
                  IconButton(
                    tooltip: 'Use as input',
                    onPressed: () => context.go(TemplatesPage.routePath),
                    icon: const Icon(Icons.auto_fix_high_outlined),
                  ),
                ],
              ),
            ),
          ),
      ],
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
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        child: Text(name.isEmpty ? '?' : name.characters.first),
      );
    }

    return ClipOval(
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => CircleAvatar(
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
  String petId,
) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 2048,
    imageQuality: 92,
  );
  if (picked == null) {
    return;
  }

  await ref
      .read(templateGenerationRepositoryProvider)
      .uploadPetPhoto(petId: petId, photo: picked);
  ref.invalidate(petsProvider);
  ref.invalidate(petPhotosProvider(petId));
}

Future<void> _setAvatar(WidgetRef ref, String petId, String photoId) async {
  await ref
      .read(templateGenerationRepositoryProvider)
      .setPetPhotoAsAvatar(petId: petId, photoId: photoId);
  ref.invalidate(petsProvider);
  ref.invalidate(petPhotosProvider(petId));
}

Future<void> _setFavorite(WidgetRef ref, String petId, PetPhoto photo) async {
  await ref
      .read(templateGenerationRepositoryProvider)
      .setPetPhotoFavorite(
        petId: petId,
        photoId: photo.id,
        isFavorite: !photo.isFavorite,
      );
  ref.invalidate(petPhotosProvider(petId));
}

Future<void> _deletePhoto(WidgetRef ref, String petId, String photoId) async {
  await ref
      .read(templateGenerationRepositoryProvider)
      .deletePetPhoto(petId: petId, photoId: photoId);
  ref.invalidate(petsProvider);
  ref.invalidate(petPhotosProvider(petId));
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

String _templatesWithPetLocation(String petId) {
  return Uri(
    path: TemplatesPage.routePath,
    queryParameters: {'petId': petId},
  ).toString();
}

PetProfile? _findPet(List<PetProfile> pets, String petId) {
  for (final pet in pets) {
    if (pet.id == petId) {
      return pet;
    }
  }

  return null;
}
