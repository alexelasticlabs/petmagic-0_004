import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_avatar_cropper_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_settings_detail_header.dart';
import 'package:petmagic_mobile/shared/auth/auth_required_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';
import 'package:petmagic_mobile/shared/profile/profile_surface_widgets.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

part 'profile_account_info_content.part.dart';

enum _AvatarSheetAction { pickFromGallery, remove }

class ProfileAccountInfoPage extends ConsumerStatefulWidget {
  const ProfileAccountInfoPage({super.key});

  static const routePath = '/profile/settings/account';

  @override
  ConsumerState<ProfileAccountInfoPage> createState() =>
      _ProfileAccountInfoPageState();
}

class _ProfileAccountInfoPageState
    extends ConsumerState<ProfileAccountInfoPage> {
  final TextEditingController _displayNameController = TextEditingController();
  bool _isEditingDisplayName = false;

  @override
  void initState() {
    super.initState();
    _syncDisplayNameController(ref.read(profileControllerProvider));
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final state = ref.watch(profileControllerProvider);
    final profile = state.profile;
    final bottomInset = petMagicBottomNavInset(
      context,
      extraSpacing: kPetMagicBottomContentInsetRelaxed,
    );

    if (!state.isLoading && !state.isAuthenticated) {
      return ProfileScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset),
            child: ProtectedAuthGate(
              subtitle: text.authRequiredMessage,
              onSignIn: () => showAuthRequiredSheet(
                context,
                redirectPath: ProfileAccountInfoPage.routePath,
              ),
            ),
          ),
        ),
      );
    }

    ref.listen(profileControllerProvider, (previous, next) {
      if (!mounted) {
        return;
      }

      _syncDisplayNameController(next);

      final previousError = previous?.errorMessage;
      if (next.errorMessage != null && next.errorMessage != previousError) {
        PetMagicToast.show(
          context,
          message: mapProfileFeedbackMessage(next.errorMessage!, text),
          tone: PetMagicToastTone.warning,
        );
      }
    });

    return ProfileScreenBackground(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset),
          children: [
            ProfileSettingsDetailHeader(
              title: text.profileSettingsAccountInfoTitle,
              subtitle: text.profileAccountDetailsSubtitle,
            ),
            const SizedBox(height: 22),
            if (profile == null)
              ProfileGlassCard(
                child: Text(
                  text.profileSettingsUnavailableSubtitle,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else ...[
              _AccountProfileHeroCard(
                profile: profile,
                displayName: _resolvedDisplayName(profile),
                isSaving: state.isSaving,
                onAvatarTap: () => _openAvatarSheet(profile),
              ),
              const SizedBox(height: 14),
              _ProfileEditableNameCard(
                controller: _displayNameController,
                isEditing: _isEditingDisplayName,
                isSaving: state.isSaving,
                currentValue: _resolvedDisplayName(profile),
                onStartEditing: () => _startEditingDisplayName(profile),
                onCancelEditing: () => _cancelEditingDisplayName(profile),
                onSave: () => _saveDisplayName(profile),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _syncDisplayNameController(ProfileState state) {
    if (_isEditingDisplayName) {
      return;
    }

    final displayName = state.profile?.displayName ?? '';
    if (_displayNameController.text == displayName) {
      return;
    }

    _displayNameController.value = _displayNameController.value.copyWith(
      text: displayName,
      selection: TextSelection.collapsed(offset: displayName.length),
      composing: TextRange.empty,
    );
  }

  String _resolvedDisplayName(MobileUserProfile profile) {
    final trimmed = profile.displayName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }

    return profile.email;
  }

  void _startEditingDisplayName(MobileUserProfile profile) {
    _displayNameController
      ..text = profile.displayName ?? ''
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: (profile.displayName ?? '').length),
      );
    setState(() => _isEditingDisplayName = true);
  }

  void _cancelEditingDisplayName(MobileUserProfile profile) {
    _displayNameController.text = profile.displayName ?? '';
    setState(() => _isEditingDisplayName = false);
  }

  Future<void> _saveDisplayName(MobileUserProfile profile) async {
    await ref
        .read(profileControllerProvider.notifier)
        .updateCurrentProfile(displayName: _displayNameController.text.trim());
    if (!mounted) {
      return;
    }

    final nextState = ref.read(profileControllerProvider);
    if (nextState.errorMessage != null) {
      _showActionFeedback(nextState.errorMessage!);
      return;
    }

    _displayNameController.text = nextState.profile?.displayName ?? '';
    setState(() => _isEditingDisplayName = false);
  }

  Future<void> _uploadAvatar() async {
    final controller = ref.read(profileControllerProvider.notifier);
    final selectedFile = await controller.pickAvatarImage();
    if (selectedFile == null || !mounted) {
      return;
    }

    final croppedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            ProfileAvatarCropperPage(sourceImagePath: selectedFile.path),
        fullscreenDialog: true,
      ),
    );
    if (!mounted || croppedPath == null || croppedPath.trim().isEmpty) {
      return;
    }

    await controller.uploadAvatarFromPath(croppedPath);
    if (!mounted) {
      return;
    }

    final nextState = ref.read(profileControllerProvider);
    if (nextState.errorMessage != null) {
      _showActionFeedback(nextState.errorMessage!);
    }
  }

  Future<void> _removeAvatar() async {
    await ref.read(profileControllerProvider.notifier).removeAvatar();
    if (!mounted) {
      return;
    }

    final nextState = ref.read(profileControllerProvider);
    if (nextState.errorMessage != null) {
      _showActionFeedback(nextState.errorMessage!);
    }
  }

  Future<void> _openAvatarSheet(MobileUserProfile profile) async {
    final text = AppLocalizations.of(context);
    final hasAvatar = profile.avatar != null;

    final action = await showModalBottomSheet<_AvatarSheetAction>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = context.petMagicColors;
        final bottomInset = petMagicScrollableBottomInset(ctx);
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.85),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: Text(
                      text.profileAvatarSheetTitle,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_a_photo_outlined),
                    title: Text(text.profileAvatarPickFromGallery),
                    onTap: () => Navigator.of(
                      ctx,
                    ).pop(_AvatarSheetAction.pickFromGallery),
                  ),
                  if (hasAvatar)
                    ListTile(
                      leading: const Icon(Icons.delete_outline_rounded),
                      title: Text(text.profileAvatarRemove),
                      onTap: () =>
                          Navigator.of(ctx).pop(_AvatarSheetAction.remove),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (action == _AvatarSheetAction.pickFromGallery) {
      await _uploadAvatar();
    } else if (action == _AvatarSheetAction.remove) {
      await _removeAvatar();
    }
  }

  void _showActionFeedback(String message) {
    final text = AppLocalizations.of(context);
    PetMagicToast.show(
      context,
      message: mapProfileFeedbackMessage(message, text),
      tone: PetMagicToastTone.warning,
    );
  }
}
