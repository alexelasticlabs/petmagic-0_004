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
