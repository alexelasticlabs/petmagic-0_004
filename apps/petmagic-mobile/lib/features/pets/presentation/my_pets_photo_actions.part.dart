part of 'my_pets_page.dart';

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

Future<void> _pickAndUploadPhoto(
  BuildContext context,
  WidgetRef ref,
  String petId, {
  String? currentAvatarUrl,
  required CancelToken cancelToken,
}) async {
  final permissionFeedbackCoordinator = ref.read(
    mediaPermissionFeedbackCoordinatorProvider,
  );
  final permissionFeedback = await permissionFeedbackCoordinator.request(
    context,
    MediaPermissionFlow.galleryPhoto,
  );
  if (!context.mounted) {
    return;
  }
  if (!permissionFeedback.granted) {
    permissionFeedbackCoordinator.show(context, permissionFeedback);
    return;
  }

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
  await _refreshPetProfileMedia(ref, petId);
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
  await _refreshPetProfileMedia(ref, petId);
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
  await _ignoreRefreshFailure(ref.read(petPhotosProvider(petId).future));
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
  await _refreshPetProfileMedia(ref, petId);
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
  await _refreshPets(ref);
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

Future<void> _refreshPetProfileMedia(WidgetRef ref, String petId) {
  ref.invalidate(petsProvider);
  ref.invalidate(petPhotosProvider(petId));
  return Future.wait<void>([
    _ignoreRefreshFailure(ref.read(petsProvider.future)),
    _ignoreRefreshFailure(ref.read(petPhotosProvider(petId).future)),
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
    final normalizedThumbnail = normalizePetMediaUrl(thumbnailUrl);
    if (normalizedThumbnail != null) {
      return normalizedThumbnail;
    }
  }

  return normalizePetMediaUrl(photo.url);
}

String? _petPhotoOriginalDisplayUrl(PetPhoto photo) {
  return normalizePetMediaUrl(photo.url);
}

Future<void> _evictPetPhotoMedia(PetPhoto photo) async {
  await Future.wait([
    _evictPetMediaUrl(photo.thumbnailUrl),
    _evictPetMediaUrl(photo.url),
  ]);
}

Future<void> _evictPetMediaUrl(String? rawUrl) async {
  final imageUrl = normalizePetMediaUrl(rawUrl);
  if (imageUrl == null) {
    return;
  }

  try {
    await CachedNetworkImage.evictFromCache(imageUrl);
  } on Object {
    // Provider invalidation still refreshes metadata; image-cache eviction is best-effort.
  }
}

PetProfile? _findPet(List<PetProfile> pets, String petId) {
  for (final pet in pets) {
    if (pet.id == petId) {
      return pet;
    }
  }

  return null;
}
