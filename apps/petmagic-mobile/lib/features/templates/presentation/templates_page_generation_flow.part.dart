part of 'templates_page.dart';

extension _TemplatesPageGenerationFlow on _TemplatesPageState {
  Future<void> _startTemplateUploadFlow(
    TemplateItem template, {
    TemplateOfTheDayItem? templateOfTheDay,
  }) async {
    final petId = _routeQueryParameter(context, 'petId');
    final petPhotoId = _routeQueryParameter(context, 'petPhotoId');
    if (petId != null && petId.isNotEmpty) {
      await _startTemplateFromPetFlow(
        template,
        petId,
        petPhotoId: petPhotoId,
        templateOfTheDay: templateOfTheDay,
      );
      return;
    }

    while (mounted) {
      if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
        await showAuthRequiredSheet(
          context,
          redirectPath: _templatesPageLocation(context),
        );
        return;
      }

      final inputChoice = await showPetMagicActionSheet(context);
      if (!mounted || inputChoice == null) {
        return;
      }

      switch (inputChoice) {
        case PetMagicActionSheetResult.myPets:
          await _startFromMyPetsChoice(
            template,
            templateOfTheDay: templateOfTheDay,
          );
          return;
        case PetMagicActionSheetResult.gallery:
        case PetMagicActionSheetResult.camera:
          break;
      }

      final photo = await _pickPetPhoto(inputChoice);
      if (!mounted || photo == null) {
        return;
      }

      final generationController = ref.read(
        templateGenerationControllerProvider.notifier,
      );
      generationController.selectPhoto(photo);

      final gate = await generationController.checkGate(template);
      if (!mounted) {
        return;
      }

      if (!gate.isAllowed) {
        final hasPremiumAccess =
            ref.read(walletControllerProvider).wallet?.isPremium ?? false;
        final blockerAction = await showTemplateBlockedSheet(
          context: context,
          template: template,
          gate: gate,
          hasPremiumAccess: hasPremiumAccess,
        );
        if (!mounted || blockerAction == null) {
          return;
        }

        switch (blockerAction) {
          case TemplateBlockedAction.wallet:
            context.push(WalletPage.routePath);
          case TemplateBlockedAction.premium:
            context.push(PremiumPage.routePath);
          case TemplateBlockedAction.chooseAnother:
            break;
        }
        return;
      }

      final confirmed = await showTemplateGenerationConfirmSheet(
        context: context,
        template: template,
        photo: photo,
        gate: gate,
      );
      if (!mounted) {
        return;
      }

      if (confirmed == false) {
        continue;
      }

      if (confirmed != true) {
        return;
      }

      final router = GoRouter.of(context);
      final text = AppLocalizations.of(context);
      final generation = await generationController.startGeneration(template);
      if (!mounted) {
        return;
      }

      if (generation == null) {
        final errorMessage = ref
            .read(templateGenerationControllerProvider)
            .errorMessage;
        if (_isAuthRequiredError(errorMessage)) {
          await showAuthRequiredSheet(
            context,
            redirectPath: _templatesPageLocation(context),
          );
          return;
        }

        final featured = templateOfTheDay;
        if (featured != null) {
          unawaited(
            _recordTemplateOfTheDayAnalytics(
              featured,
              'generation_failed',
              extraMetadata: <String, Object?>{
                if (errorMessage != null && errorMessage.isNotEmpty)
                  'error': errorMessage,
              },
            ),
          );
        }

        PetMagicToast.show(
          context,
          message: errorMessage == null || errorMessage.isEmpty
              ? text.templateFlowStartFailedError
              : _generationStartErrorText(text, errorMessage),
          tone: PetMagicToastTone.warning,
        );
        return;
      }

      final featured = templateOfTheDay;
      if (featured != null) {
        unawaited(
          _recordTemplateOfTheDayAnalytics(
            featured,
            'generation_started',
            generationId: generation.generationId,
          ),
        );
      }

      router.push(
        GenerationStatusPage.routeFor(generation.generationId),
        extra: featured,
      );
      return;
    }
  }

  Future<void> _startTemplateFromPetFlow(
    TemplateItem template,
    String petId, {
    String? petPhotoId,
    String? petName,
    bool showChangeAction = false,
    TemplateOfTheDayItem? templateOfTheDay,
  }) async {
    final text = AppLocalizations.of(context);
    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
      await showAuthRequiredSheet(
        context,
        redirectPath: _templatesPageLocation(
          context,
          petId: petId,
          petPhotoId: petPhotoId,
        ),
        title: text.petsAuthRequiredTitle,
        message: text.petsAuthRequiredMessage,
        showSignUp: true,
      );
      return;
    }

    final generationController = ref.read(
      templateGenerationControllerProvider.notifier,
    );
    final gate = await generationController.checkGate(template);
    if (!mounted) {
      return;
    }

    if (!gate.isAllowed) {
      final hasPremiumAccess =
          ref.read(walletControllerProvider).wallet?.isPremium ?? false;
      final blockerAction = await showTemplateBlockedSheet(
        context: context,
        template: template,
        gate: gate,
        hasPremiumAccess: hasPremiumAccess,
      );
      if (!mounted || blockerAction == null) {
        return;
      }

      switch (blockerAction) {
        case TemplateBlockedAction.wallet:
          context.push(WalletPage.routePath);
        case TemplateBlockedAction.premium:
          context.push(PremiumPage.routePath);
        case TemplateBlockedAction.chooseAnother:
          break;
      }
      return;
    }

    final action = await showPetGenerationLaunchSheet(
      context: context,
      template: template,
      petId: petId,
      initialPetPhotoId: petPhotoId,
      petName: petName,
      gate: gate,
      showChangeAction: showChangeAction,
      pickPhoto: _pickPetGalleryPhoto,
      uploadPhoto: (photo) => ref
          .read(templateGenerationRepositoryProvider)
          .uploadPetPhoto(petId: petId, photo: photo),
      startGeneration: (selectedPhoto) async {
        return ref
            .read(templateGenerationRepositoryProvider)
            .startGenerationFromPet(
              petId: petId,
              petPhotoId: selectedPhoto.id,
              templateId: template.templateId,
            );
      },
    );
    if (!mounted || action == null) {
      return;
    }

    if (action.changePet) {
      context.push('/profile/pets');
      return;
    }

    final generation = action.generation;
    if (generation == null) {
      return;
    }

    await ref
        .read(templateGenerationRepositoryProvider)
        .rememberActiveGeneration(generationId: generation.generationId);
    ref.invalidate(walletControllerProvider);
    if (!mounted) {
      return;
    }

    final featured = templateOfTheDay;
    if (featured != null) {
      unawaited(
        _recordTemplateOfTheDayAnalytics(
          featured,
          'generation_started',
          generationId: generation.generationId,
        ),
      );
    }

    context.go(
      GenerationStatusPage.routeFor(generation.generationId),
      extra: featured,
    );
  }

  Future<void> _startFromMyPetsChoice(
    TemplateItem template, {
    TemplateOfTheDayItem? templateOfTheDay,
  }) async {
    try {
      final pets = await ref.read(petsProvider.future);
      if (!mounted) {
        return;
      }

      if (pets.isEmpty) {
        final text = AppLocalizations.of(context);
        PetMagicToast.show(
          context,
          message: text.petsFirstPetToast,
          tone: PetMagicToastTone.info,
        );
        context.push('/profile/pets');
        return;
      }

      final selectedPet = pets.length == 1
          ? pets.first
          : await _showPetPickerSheet(context, pets);
      if (!mounted || selectedPet == null) {
        return;
      }

      await _startTemplateFromPetFlow(
        template,
        selectedPet.id,
        petName: selectedPet.name,
        showChangeAction: pets.length == 1,
        templateOfTheDay: templateOfTheDay,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.GenerationFlow',
        operation: 'load_my_pets_before_generation',
        message: 'Could not load pets before starting template generation flow',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }

      PetMagicToast.show(
        context,
        message: AppLocalizations.of(context).petsCouldNotLoadToast,
        tone: PetMagicToastTone.warning,
      );
    }
  }

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

String? _routeQueryParameter(BuildContext context, String key) {
  try {
    final value = GoRouterState.of(context).uri.queryParameters[key];
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  } catch (error, stackTrace) {
    AppLogger.warn(
      feature: 'Templates.GenerationFlow',
      operation: 'read_route_query_parameter',
      message: 'Could not read templates route query parameter',
      context: {'key': key},
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

String _templatesPageLocation(
  BuildContext context, {
  String? petId,
  String? petPhotoId,
}) {
  return TemplatesPage.location(
    petId:
        petId ?? _routeQueryParameter(context, TemplatesPage.petIdQueryParam),
    petPhotoId:
        petPhotoId ??
        _routeQueryParameter(context, TemplatesPage.petPhotoIdQueryParam),
  );
}
