part of 'my_pets_page.dart';

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
  var _isPickingPhoto = false;
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
    final text = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (_isSaving || name.isEmpty || name.length > 40) {
      setState(() => _showNameError = true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repository = ref.read(petRepositoryProvider);
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
          photo: LocalMediaFile(
            path: selectedPhoto.path,
            name: selectedPhoto.name,
            mimeType: selectedPhoto.mimeType,
          ),
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
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Pets.Form',
        operation: 'save_pet',
        message: 'Pet form submission failed',
        context: {'isEditing': _isEditing, 'hasPhoto': _photo != null},
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        PetMagicToast.show(
          context,
          message: text.profileActionFailed,
          tone: PetMagicToastTone.warning,
        );
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickPhoto() async {
    if (_isPickingPhoto) {
      return;
    }

    setState(() => _isPickingPhoto = true);
    try {
      final permissionFeedback = await ref
          .read(mediaPermissionFeedbackCoordinatorProvider)
          .request(context, MediaPermissionFlow.galleryPhoto);
      if (!mounted || !permissionFeedback.granted) {
        if (mounted) {
          ref
              .read(mediaPermissionFeedbackCoordinatorProvider)
              .show(context, permissionFeedback);
        }
        return;
      }

      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        imageQuality: 92,
      );
      if (!mounted || picked == null) {
        return;
      }

      setState(() => _photo = picked);
    } finally {
      if (mounted) {
        setState(() => _isPickingPhoto = false);
      } else {
        _isPickingPhoto = false;
      }
    }
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
                PetFormProgress(currentStep: _isEditing ? 2 : _step),
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
            0 => PetNameStep(
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
            1 => PetTypeStep(
              key: const ValueKey('pet-type-step'),
              type: _type,
              breedController: _breedController,
              enabled: !_isSaving,
              text: text,
              onTypeChanged: (value) => setState(() => _type = value),
            ),
            _ => PetPhotoStep(
              key: const ValueKey('pet-photo-step'),
              photo: _photo,
              enabled: !_isSaving && !_isPickingPhoto,
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
                child: PetFormPrimaryButton(
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
                child: PetFormPrimaryButton(
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
        PetNameStep(
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
        PetTypeStep(
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
