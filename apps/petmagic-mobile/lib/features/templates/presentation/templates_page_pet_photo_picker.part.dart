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
