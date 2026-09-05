part of 'pet_generation_launch_sheet.dart';

extension _PetGenerationLaunchSheetView on _PetGenerationLaunchSheetState {
  Widget _buildLaunchSheet(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final pets = ref.watch(petsProvider).asData?.value ?? const <PetProfile>[];
    PetProfile? pet;
    for (final candidate in pets) {
      if (candidate.id == widget.petId) {
        pet = candidate;
        break;
      }
    }
    final petName = pet?.name ?? widget.petName;
    final photosAsync = ref.watch(petPhotosProvider(widget.petId));
    final selectedPhotoForStart = photosAsync.maybeWhen(
      data: (photos) => _selectedPhoto(_mergePhotos(photos)),
      orElse: () => null,
    );
    final selectedPhotoId = selectedPhotoForStart?.id.trim();
    final selectedPhotoPreviewFailed =
        selectedPhotoId != null &&
        selectedPhotoId.isNotEmpty &&
        selectedPhotoId == _failedPreviewPhotoId;
    final startAction =
        selectedPhotoForStart == null ||
            _petPhotoDisplayUrl(selectedPhotoForStart) == null ||
            selectedPhotoPreviewFailed ||
            _isBusy
        ? null
        : () => _start(selectedPhotoForStart);
    final bottomBarHeight = widget.showChangeAction ? 130.0 : 78.0;

    return SafeArea(
      top: false,
      child: Stack(
        children: [
          Positioned(
            right: 28,
            top: 42,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: colors.accent.withValues(alpha: 0.30),
              size: 22,
            ),
          ),
          Positioned(
            left: 24,
            top: 126,
            child: Icon(
              Icons.star_rounded,
              color: colors.gold.withValues(alpha: 0.20),
              size: 16,
            ),
          ),
          ListView(
            padding: EdgeInsets.fromLTRB(
              18,
              10,
              18,
              widget.bottomInset + bottomBarHeight + 20,
            ),
            shrinkWrap: true,
            children: [
              Row(
                children: [
                  const Spacer(),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: _petLaunchCloseLabel(text),
                    onPressed: _isBusy
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: colors.textSoft),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _PetLaunchHeader(
                title: _petLaunchTitle(text, petName),
                subtitle: _petLaunchSubtitle(text),
              ),
              const SizedBox(height: 18),
              _PetLaunchTemplateCard(
                template: widget.template,
                tokenCost: widget.template.tokenCost,
              ),
              const SizedBox(height: 12),
              _PetLaunchPetCard(
                petName: petName,
                avatarUrl:
                    pet?.avatarUrl ??
                    (selectedPhotoForStart == null
                        ? null
                        : _petPhotoDisplayUrl(selectedPhotoForStart)),
                balance: widget.gate.balance,
              ),
              const SizedBox(height: 16),
              photosAsync.when(
                data: (photos) => _buildPhotoPicker(
                  context,
                  photos: _mergePhotos(photos),
                  isLoading: false,
                  onPreviewLoadFailed: _markPreviewLoadFailed,
                ),
                loading: () => _buildPhotoPicker(
                  context,
                  photos: _uploadedPhotos,
                  isLoading: true,
                  onPreviewLoadFailed: _markPreviewLoadFailed,
                ),
                error: (error, stackTrace) => _PetLaunchPhotoLoadError(
                  message: _petLaunchPhotoLoadErrorLabel(text),
                  onRetry: _isBusy
                      ? null
                      : () {
                          _applyLaunchState(() => _errorMessage = null);
                          ref.invalidate(petPhotosProvider(widget.petId));
                        },
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _PetLaunchInlineError(message: _errorMessage!),
              ],
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _PetLaunchBottomBar(
              bottomInset: widget.bottomInset,
              showChangeAction: widget.showChangeAction,
              isStarting: _isStarting,
              startLabel: text.templateFlowCreateMagicAction,
              changeLabel: text.petsChangeAction,
              onStart: startAction,
              onChangePet: _isBusy
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop(const PetGenerationLaunchResult.changePet()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPicker(
    BuildContext context, {
    required List<PetPhoto> photos,
    required bool isLoading,
    required ValueChanged<PetPhoto> onPreviewLoadFailed,
  }) {
    final text = AppLocalizations.of(context);
    final selected = _selectedPhoto(photos);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _petLaunchPhotoSectionTitle(text),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.petMagicColors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _isBusy ? null : _uploadPhoto,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_rounded, size: 18),
              label: Text(_petLaunchUploadPhotoLabel(text)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _PetLaunchSelectedPhotoPreview(
          photo: selected,
          isLoading: isLoading,
          onUpload: _isBusy ? null : _uploadPhoto,
          onImageLoadFailed: onPreviewLoadFailed,
        ),
        const SizedBox(height: 12),
        if (photos.isNotEmpty)
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                if (index == photos.length) {
                  return _PetLaunchUploadTile(
                    isLoading: _isUploading,
                    onTap: _isBusy ? null : _uploadPhoto,
                  );
                }
                final photo = photos[index];
                final isSelected = selected?.id == photo.id;
                return _PetLaunchPhotoThumbnail(
                  photo: photo,
                  isSelected: isSelected,
                  onTap: _isBusy
                      ? null
                      : () {
                          _applyLaunchState(() {
                            _selectedPhotoId = photo.id;
                            _failedPreviewPhotoId = null;
                            _errorMessage = null;
                          });
                        },
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemCount: photos.length + 1,
            ),
          )
        else
          _PetLaunchNoPhotosHint(
            isLoading: isLoading || _isUploading,
            onUpload: _isBusy ? null : _uploadPhoto,
          ),
      ],
    );
  }

  List<PetPhoto> _mergePhotos(List<PetPhoto> fetchedPhotos) {
    final result = <PetPhoto>[];
    final seen = <String>{};
    for (final photo in [..._uploadedPhotos, ...fetchedPhotos]) {
      final id = photo.id.trim();
      if (id.isEmpty || !seen.add(id)) {
        continue;
      }
      result.add(photo);
    }
    return result;
  }

  PetPhoto? _selectedPhoto(List<PetPhoto> photos) {
    if (photos.isEmpty) {
      return null;
    }

    final selectedId = _selectedPhotoId?.trim();
    if (selectedId != null && selectedId.isNotEmpty) {
      for (final photo in photos) {
        if (photo.id == selectedId) {
          return photo;
        }
      }
    }

    for (final photo in photos) {
      if (photo.isAvatar) {
        return photo;
      }
    }
    for (final photo in photos) {
      if (photo.isFavorite) {
        return photo;
      }
    }
    return photos.first;
  }
}
