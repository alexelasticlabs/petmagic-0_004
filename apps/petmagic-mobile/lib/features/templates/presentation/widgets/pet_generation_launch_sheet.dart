import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/pets/application/pets_contract.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/application/template_error_key_mapper.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_preview_image.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'pet_shortcut_avatar.dart';

part 'pet_generation_launch_sheet_media.part.dart';
part 'pet_generation_launch_sheet_content.part.dart';
part 'pet_generation_launch_sheet_view.part.dart';

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
  String? _failedPreviewPhotoId;

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
  Widget build(BuildContext context) => _buildLaunchSheet(context);

  void _applyLaunchState(VoidCallback action) => setState(action);

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
        _failedPreviewPhotoId = null;
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

  void _markPreviewLoadFailed(PetPhoto photo) {
    final photoId = photo.id.trim();
    if (photoId.isEmpty || _failedPreviewPhotoId == photoId) {
      return;
    }

    setState(() => _failedPreviewPhotoId = photoId);
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
    if (_normalizePetLaunchErrorKey(error.message) ==
        'pets.photo_type_not_allowed') {
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

    final key =
        _normalizePetLaunchErrorKey(error.message) ??
        normalizeTemplateErrorKey(error.message);
    if (key == 'templates.premium_required') {
      return text.templateFlowPremiumRequiredError;
    }
    if (error.statusCode == 402 ||
        key == 'templates.insufficient_balance' ||
        key == 'economy.insufficient_balance') {
      return text.templateFlowInsufficientBalanceError;
    }
    if (key == 'pets.photo_not_found' || key == 'pets.photo_required') {
      return _petLaunchSelectedPhotoMissingText(text);
    }
    if (key == 'templates.generation_already_started') {
      return text.templateFlowActiveGenerationLimitError;
    }
    if (key == 'templates.server_unavailable' ||
        key == 'templates.server_timeout' ||
        key == 'templates.generation_wait_too_long') {
      return text.templateFlowServerError;
    }
  }

  return text.petGenerationLaunchStartError;
}

String? _normalizePetLaunchErrorKey(String? raw) {
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final lower = normalized.toLowerCase();
  const safeKeys = <String>[
    'pets.photo_type_not_allowed',
    'pets.photo_not_found',
    'pets.photo_required',
    'templates.insufficient_balance',
    'economy.insufficient_balance',
  ];
  for (final key in safeKeys) {
    if (lower == key || lower.contains(key)) {
      return key;
    }
  }

  return null;
}

String templatePetTypeLabel(String value, AppLocalizations text) {
  return switch (value) {
    'dog' => text.petsDogType,
    'cat' => text.petsCatType,
    _ => text.petsOtherType,
  };
}
