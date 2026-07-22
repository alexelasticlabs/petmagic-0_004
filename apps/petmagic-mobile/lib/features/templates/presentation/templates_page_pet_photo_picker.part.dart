part of 'templates_page.dart';

extension _TemplatesPagePetPhotoPicker on _TemplatesPageState {
  Future<XFile?> _pickPetPhoto(PetMagicActionSheetResult sourceAction) async {
    final source = switch (sourceAction) {
      PetMagicActionSheetResult.camera => ImageSource.camera,
      PetMagicActionSheetResult.gallery => ImageSource.gallery,
      PetMagicActionSheetResult.myPets => null,
    };
    if (source == null) {
      return null;
    }

    return _runPetPhotoPickerSession(() async {
      final permissionFeedback = await ref
          .read(mediaPermissionFeedbackCoordinatorProvider)
          .request(
            context,
            source == ImageSource.camera
                ? MediaPermissionFlow.cameraPhoto
                : MediaPermissionFlow.galleryPhoto,
          );
      if (!mounted || !permissionFeedback.granted) {
        if (mounted) {
          ref
              .read(mediaPermissionFeedbackCoordinatorProvider)
              .show(context, permissionFeedback);
        }
        return null;
      }

      return _imagePicker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 1800,
      );
    });
  }

  Future<XFile?> _pickPetGalleryPhoto() async {
    return _runPetPhotoPickerSession(() async {
      final permissionFeedback = await ref
          .read(mediaPermissionFeedbackCoordinatorProvider)
          .request(context, MediaPermissionFlow.galleryPhoto);
      if (!mounted || !permissionFeedback.granted) {
        if (mounted) {
          ref
              .read(mediaPermissionFeedbackCoordinatorProvider)
              .show(context, permissionFeedback);
        }
        return null;
      }

      return _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 1800,
      );
    });
  }

  Future<T?> _runPetPhotoPickerSession<T>(Future<T?> Function() action) async {
    if (_isPetPhotoPickerActive) {
      return null;
    }

    _isPetPhotoPickerActive = true;
    try {
      return await action();
    } finally {
      _isPetPhotoPickerActive = false;
    }
  }
}

Future<PetProfile?> _showPetPickerSheet(
  BuildContext context,
  List<PetProfile> pets,
) {
  final text = AppLocalizations.of(context);
  final colors = context.petMagicColors;
  return showPetMagicModalBottomSheet<PetProfile>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext, bottomInset) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceStrong,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border.withValues(alpha: 0.8)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: Material(
              type: MaterialType.transparency,
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
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
                  const SizedBox(height: 6),
                  for (final pet in pets)
                    ListTile(
                      leading: PetShortcutAvatar(avatarUrl: pet.avatarUrl),
                      title: Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        [
                          templatePetTypeLabel(pet.type, text),
                          pet.breed,
                        ].whereType<String>().join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textSoft),
                      ),
                      onTap: () => Navigator.of(sheetContext).pop(pet),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

TemplateItem? _findTemplateById(Iterable<TemplateItem> items, String id) {
  final normalizedId = id.trim();
  if (normalizedId.isEmpty) {
    return null;
  }

  for (final item in items) {
    if (item.templateId == normalizedId) {
      return item;
    }
  }

  return null;
}
