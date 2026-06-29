import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/pets/presentation/pet_media_url_normalizer.dart';
import 'package:petmagic_mobile/features/pets/presentation/pet_profile_providers.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_preview_image.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';

part 'pet_generation_launch_sheet_content.part.dart';

typedef PetPhotoPicker = Future<XFile?> Function();
typedef PetPhotoUploader = Future<PetPhoto> Function(XFile photo);
typedef PetGenerationStarter =
    Future<TemplateGenerationResult> Function(PetPhoto photo);

class PetGenerationLaunchResult {
  const PetGenerationLaunchResult._({this.generation, this.changePet = false});

  const PetGenerationLaunchResult.started(TemplateGenerationResult generation)
    : this._(generation: generation);

  const PetGenerationLaunchResult.changePet() : this._(changePet: true);

  final TemplateGenerationResult? generation;
  final bool changePet;
}

Future<PetGenerationLaunchResult?> showPetGenerationLaunchSheet({
  required BuildContext context,
  required TemplateItem template,
  required String petId,
  required TemplateGenerationGate gate,
  required PetPhotoPicker pickPhoto,
  required PetPhotoUploader uploadPhoto,
  required PetGenerationStarter startGeneration,
  String? initialPetPhotoId,
  String? petName,
  bool showChangeAction = false,
}) {
  final colors = context.petMagicColors;
  return showPetMagicModalBottomSheet<PetGenerationLaunchResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.94,
    ),
    builder: (sheetContext, bottomInset) => DecoratedBox(
      decoration: BoxDecoration(
        color: colors.backgroundBottom,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: colors.border.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 32,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: _PetGenerationLaunchSheet(
        template: template,
        petId: petId,
        initialPetPhotoId: initialPetPhotoId,
        petName: petName,
        gate: gate,
        bottomInset: bottomInset,
        showChangeAction: showChangeAction,
        pickPhoto: pickPhoto,
        uploadPhoto: uploadPhoto,
        startGeneration: startGeneration,
      ),
    ),
  );
}

class _PetGenerationLaunchSheet extends ConsumerStatefulWidget {
  const _PetGenerationLaunchSheet({
    required this.template,
    required this.petId,
    required this.gate,
    required this.bottomInset,
    required this.pickPhoto,
    required this.uploadPhoto,
    required this.startGeneration,
    this.initialPetPhotoId,
    this.petName,
    this.showChangeAction = false,
  });

  final TemplateItem template;
  final String petId;
  final String? initialPetPhotoId;
  final String? petName;
  final TemplateGenerationGate gate;
  final double bottomInset;
  final bool showChangeAction;
  final PetPhotoPicker pickPhoto;
  final PetPhotoUploader uploadPhoto;
  final PetGenerationStarter startGeneration;

  @override
  ConsumerState<_PetGenerationLaunchSheet> createState() =>
      _PetGenerationLaunchSheetState();
}

class _PetGenerationLaunchSheetState
    extends ConsumerState<_PetGenerationLaunchSheet> {
  final List<PetPhoto> _uploadedPhotos = <PetPhoto>[];
  String? _selectedPhotoId;
  bool _isUploading = false;
  bool _isStarting = false;
  String? _errorMessage;

  bool get _isBusy => _isUploading || _isStarting;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPetPhotoId?.trim();
    if (initial != null && initial.isNotEmpty) {
      _selectedPhotoId = initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final photosAsync = ref.watch(petPhotosProvider(widget.petId));
    final selectedPhotoForStart = photosAsync.maybeWhen(
      data: (photos) => _selectedPhoto(_mergePhotos(photos)),
      orElse: () => null,
    );
    final startAction = selectedPhotoForStart == null || _isBusy
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
                title: _petLaunchTitle(text, widget.petName),
                subtitle: _petLaunchSubtitle(text),
              ),
              const SizedBox(height: 18),
              _PetLaunchTemplateCard(
                template: widget.template,
                tokenCost: widget.template.tokenCost,
              ),
              const SizedBox(height: 12),
              _PetLaunchPetCard(
                petName: widget.petName,
                balance: widget.gate.balance,
              ),
              const SizedBox(height: 16),
              photosAsync.when(
                data: (photos) => _buildPhotoPicker(
                  context,
                  photos: _mergePhotos(photos),
                  isLoading: false,
                ),
                loading: () => _buildPhotoPicker(
                  context,
                  photos: _uploadedPhotos,
                  isLoading: true,
                ),
                error: (error, stackTrace) => _PetLaunchPhotoLoadError(
                  message: _petLaunchPhotoLoadErrorLabel(text),
                  onRetry: _isBusy
                      ? null
                      : () {
                          setState(() => _errorMessage = null);
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
                          setState(() {
                            _selectedPhotoId = photo.id;
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

  Future<void> _uploadPhoto() async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final picked = await widget.pickPhoto();
      if (!mounted || picked == null) {
        return;
      }

      final uploaded = await widget.uploadPhoto(picked);
      if (!mounted) {
        return;
      }

      setState(() {
        _uploadedPhotos.insert(0, uploaded);
        _selectedPhotoId = uploaded.id;
      });
      ref.invalidate(petPhotosProvider(widget.petId));
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _petLaunchUploadErrorText(
          AppLocalizations.of(context),
          error,
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _start(PetPhoto selectedPhoto) async {
    if (_isBusy) {
      return;
    }

    final text = AppLocalizations.of(context);
    if (selectedPhoto.id.trim().isEmpty ||
        _petPhotoDisplayUrl(selectedPhoto) == null) {
      setState(() => _errorMessage = _petLaunchSelectedPhotoMissingText(text));
      return;
    }

    setState(() {
      _isStarting = true;
      _errorMessage = null;
    });

    try {
      final generation = await widget.startGeneration(selectedPhoto);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(PetGenerationLaunchResult.started(generation));
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _petLaunchStartErrorText(text, error);
      });
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }
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

String _petLaunchTitle(AppLocalizations text, String? petName) {
  final name = petName?.trim();
  if (name != null && name.isNotEmpty) {
    return text.petGenerationLaunchTitleWithName(name);
  }
  return text.petGenerationLaunchTitle;
}

String _petLaunchSubtitle(AppLocalizations text) =>
    text.petGenerationLaunchSubtitle;

String _petLaunchPhotoSectionTitle(AppLocalizations text) =>
    text.petGenerationLaunchPhotoSectionTitle;

String _petLaunchSelectedPhotoLabel(AppLocalizations text) =>
    text.petGenerationLaunchSelectedPhotoLabel;

String _petLaunchUploadPhotoLabel(AppLocalizations text) =>
    text.petGenerationLaunchUploadPhotoAction;

String _petLaunchChoosePhotoLabel(AppLocalizations text) =>
    text.petGenerationLaunchChoosePhotoTitle;

String _petLaunchLoadingPhotosLabel(AppLocalizations text) =>
    text.petGenerationLaunchLoadingPhotos;

String _petLaunchPhotoLoadErrorLabel(AppLocalizations text) =>
    text.petGenerationLaunchPhotoLoadError;

String _petLaunchSelectedPhotoMissingText(AppLocalizations text) =>
    text.petGenerationLaunchSelectedPhotoMissing;

String _petLaunchCloseLabel(AppLocalizations text) => text.closeAction;

String _petLaunchUploadErrorText(AppLocalizations text, Object error) {
  if (error is AppException) {
    final message = error.message;
    if (message.contains('pets.photo_type_not_allowed')) {
      return text.petGenerationLaunchPhotoTypeError;
    }
  }

  return text.petGenerationLaunchUploadError;
}

String _petLaunchStartErrorText(AppLocalizations text, Object error) {
  if (error is AppException) {
    final authMessage = mapCommonAuthFeedbackMessage(text, error.message);
    if (authMessage != null) {
      return authMessage;
    }

    final message = error.message.toLowerCase();
    if (error.statusCode == 402 || message.contains('insufficient')) {
      return text.templateFlowInsufficientBalanceError;
    }
    if (message.contains('unavailable') || message.contains('photo')) {
      return _petLaunchSelectedPhotoMissingText(text);
    }
  }

  return text.petGenerationLaunchStartError;
}

String templatePetTypeLabel(String value, AppLocalizations text) {
  return switch (value) {
    'dog' => text.petsDogType,
    'cat' => text.petsCatType,
    _ => text.petsOtherType,
  };
}
