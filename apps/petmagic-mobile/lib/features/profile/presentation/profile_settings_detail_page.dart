import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_avatar_cropper_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_linked_accounts_settings_section.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_notifications_settings_section.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_settings_bottom_sheets.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/legal_document_list_view.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';

part 'profile_account_info_content.part.dart';
part 'profile_settings_detail_generic_content.part.dart';
part 'profile_settings_detail_legal_content.part.dart';

enum ProfileSettingsDetailKind {
  linkedAccounts,
  notifications,
  helpCenter,
  support,
  terms,
  privacy,
  deleteAccount;

  String get slug => switch (this) {
    ProfileSettingsDetailKind.linkedAccounts => 'linked-accounts',
    ProfileSettingsDetailKind.notifications => 'notifications',
    ProfileSettingsDetailKind.helpCenter => 'help-center',
    ProfileSettingsDetailKind.support => 'support',
    ProfileSettingsDetailKind.terms => 'terms',
    ProfileSettingsDetailKind.privacy => 'privacy',
    ProfileSettingsDetailKind.deleteAccount => 'delete-account',
  };

  static ProfileSettingsDetailKind fromSlug(String slug) {
    return ProfileSettingsDetailKind.values.firstWhere(
      (value) => value.slug == slug,
      orElse: () => ProfileSettingsDetailKind.helpCenter,
    );
  }
}

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
            _DetailHeader(
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

class ProfileSettingsDetailPage extends ConsumerWidget {
  const ProfileSettingsDetailPage({required this.kind, super.key});

  static const routePath = '/profile/settings/detail/:kind';

  static String location(ProfileSettingsDetailKind kind) {
    return '/profile/settings/detail/${kind.slug}';
  }

  final ProfileSettingsDetailKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final state = ref.watch(profileControllerProvider);
    final profileController = ref.read(profileControllerProvider.notifier);
    final profile = state.profile;
    final bottomInset = petMagicBottomNavInset(
      context,
      extraSpacing: kPetMagicBottomContentInsetRelaxed,
    );

    if (!state.isLoading &&
        !state.isAuthenticated &&
        _profileSettingsDetailRequiresAuth(kind)) {
      return ProfileScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset),
            child: ProtectedAuthGate(
              subtitle: text.authRequiredMessage,
              onSignIn: () => showAuthRequiredSheet(
                context,
                redirectPath: ProfileSettingsDetailPage.location(kind),
              ),
            ),
          ),
        ),
      );
    }

    final title = switch (kind) {
      ProfileSettingsDetailKind.linkedAccounts =>
        text.profileSettingsLinkedAccountsTitle,
      ProfileSettingsDetailKind.notifications =>
        text.profileSettingsNotificationsTitle,
      ProfileSettingsDetailKind.helpCenter =>
        text.profileSettingsHelpCenterTitle,
      ProfileSettingsDetailKind.support => text.profileSettingsSupportTitle,
      ProfileSettingsDetailKind.terms => text.profileSettingsTermsTitle,
      ProfileSettingsDetailKind.privacy => text.profileSettingsPrivacyTitle,
      ProfileSettingsDetailKind.deleteAccount =>
        text.profileSettingsDeleteAccountTitle,
    };

    final subtitle = switch (kind) {
      ProfileSettingsDetailKind.linkedAccounts =>
        text.profileDetailsLinkedAccountsBody,
      ProfileSettingsDetailKind.notifications =>
        text.profileDetailsNotificationsBody,
      ProfileSettingsDetailKind.helpCenter => text.profileDetailsHelpBody,
      ProfileSettingsDetailKind.support => text.profileSettingsSupportSubtitle,
      ProfileSettingsDetailKind.terms => text.profileDetailsTermsBody,
      ProfileSettingsDetailKind.privacy => text.profileDetailsPrivacyBody,
      ProfileSettingsDetailKind.deleteAccount => text.profileDetailsDeleteBody,
    };

    if (kind == ProfileSettingsDetailKind.terms ||
        kind == ProfileSettingsDetailKind.privacy) {
      final requiresAcceptance =
          profile?.legalAcceptance.requiresAcceptance == true;

      return _ProfileSettingsLegalDetailRoute(
        kind: kind,
        title: title,
        subtitle: subtitle,
        state: state,
        profile: profile,
        bottomInset: bottomInset,
        requiresAcceptance: requiresAcceptance,
      );
    }

    if (kind == ProfileSettingsDetailKind.notifications) {
      return ProfileNotificationsSettingsSection(
        title: title,
        subtitle: subtitle,
        errorMessage: state.errorMessage,
        scope: profile?.userId ?? 'guest',
        fallbackMarketingEmails: profile?.marketingEmailsEnabled ?? false,
        bottomInset: bottomInset,
      );
    }

    if (kind == ProfileSettingsDetailKind.linkedAccounts) {
      return ProfileLinkedAccountsSettingsSection(
        title: title,
        subtitle: subtitle,
        bottomInset: bottomInset,
      );
    }

    final status = switch (kind) {
      ProfileSettingsDetailKind.linkedAccounts =>
        text.profileDetailsLinkedAccountsStatus,
      ProfileSettingsDetailKind.notifications =>
        profile?.marketingEmailsEnabled == true
            ? text.profileDetailsNotificationsStatusEnabled
            : text.profileDetailsNotificationsStatusDisabled,
      ProfileSettingsDetailKind.helpCenter => text.profileDetailsHelpStatus,
      ProfileSettingsDetailKind.support => text.profileSupportCompactSubtitle,
      ProfileSettingsDetailKind.terms => text.profileDetailsTermsStatusAccepted,
      ProfileSettingsDetailKind.privacy => text.profileDetailsPrivacyStatus,
      ProfileSettingsDetailKind.deleteAccount =>
        text.profileDetailsDeleteStatus,
    };

    final nextStep = switch (kind) {
      ProfileSettingsDetailKind.linkedAccounts =>
        text.profileDetailsLinkedAccountsNext,
      ProfileSettingsDetailKind.notifications =>
        text.profileDetailsNotificationsNext,
      ProfileSettingsDetailKind.helpCenter => text.profileDetailsHelpNext,
      ProfileSettingsDetailKind.support => text.supportHomeOpenChatAction,
      ProfileSettingsDetailKind.terms => text.profileDetailsTermsNext,
      ProfileSettingsDetailKind.privacy => text.profileDetailsPrivacyNext,
      ProfileSettingsDetailKind.deleteAccount => text.profileDetailsDeleteNext,
    };

    return _ProfileSettingsStaticDetailContent(
      kind: kind,
      title: title,
      subtitle: subtitle,
      status: status,
      nextStep: nextStep,
      bottomInset: bottomInset,
      onOpenSupport: kind == ProfileSettingsDetailKind.helpCenter
          ? () => context.push(SupportChatPage.routePath)
          : null,
      onDeleteAccount: kind == ProfileSettingsDetailKind.deleteAccount
          ? () async {
              await showProfileDeleteAccountConfirmationSheet(
                context: context,
                onConfirm: () async {
                  await profileController.deleteAccount();

                  if (!context.mounted) {
                    return;
                  }

                  final nextState = ref.read(profileControllerProvider);
                  if (nextState.errorMessage == null) {
                    return;
                  }

                  PetMagicToast.show(
                    context,
                    message: mapProfileFeedbackMessage(
                      nextState.errorMessage!,
                      text,
                    ),
                    tone: PetMagicToastTone.warning,
                  );
                },
              );
            }
          : null,
    );
  }
}

class _ProfileSettingsLegalDetailRoute extends ConsumerStatefulWidget {
  const _ProfileSettingsLegalDetailRoute({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.profile,
    required this.bottomInset,
    required this.requiresAcceptance,
  });

  final ProfileSettingsDetailKind kind;
  final String title;
  final String subtitle;
  final ProfileState state;
  final MobileUserProfile? profile;
  final double bottomInset;
  final bool requiresAcceptance;

  @override
  ConsumerState<_ProfileSettingsLegalDetailRoute> createState() =>
      _ProfileSettingsLegalDetailRouteState();
}

class _ProfileSettingsLegalDetailRouteState
    extends ConsumerState<_ProfileSettingsLegalDetailRoute> {
  MobileLegalDocuments? _cachedDocuments;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final localeTag = locale.toLanguageTag();
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final legalDocumentsProvider = currentLegalDocumentsProvider(localeTag);
    final legalDocumentsAsync = hasInternet
        ? ref.watch(legalDocumentsProvider)
        : null;
    final documents =
        switch (legalDocumentsAsync) {
          AsyncData(:final value) => value,
          _ => null,
        } ??
        _cachedDocuments;

    if (hasInternet) {
      ref.listen<AsyncValue<MobileLegalDocuments>>(legalDocumentsProvider, (
        previous,
        next,
      ) {
        next.whenData((value) {
          if (!mounted) {
            return;
          }

          setState(() {
            _cachedDocuments = value;
          });
        });
      });
    }

    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.hasInternet != false ||
          !next.hasInternet ||
          documents != null) {
        return;
      }

      ref.invalidate(legalDocumentsProvider);
    });

    return _ProfileSettingsLegalDetailContent(
      kind: widget.kind,
      title: widget.title,
      subtitle: widget.subtitle,
      state: widget.state,
      profile: widget.profile,
      bottomInset: widget.bottomInset,
      locale: locale,
      localeTag: localeTag,
      legalDocumentsAsync: legalDocumentsAsync,
      documents: documents,
      hasInternet: hasInternet,
      requiresAcceptance: widget.requiresAcceptance,
    );
  }
}

bool _profileSettingsDetailRequiresAuth(ProfileSettingsDetailKind kind) {
  return switch (kind) {
    ProfileSettingsDetailKind.linkedAccounts ||
    ProfileSettingsDetailKind.notifications ||
    ProfileSettingsDetailKind.deleteAccount => true,
    ProfileSettingsDetailKind.helpCenter ||
    ProfileSettingsDetailKind.support ||
    ProfileSettingsDetailKind.terms ||
    ProfileSettingsDetailKind.privacy => false,
  };
}

MobileLegalDocument? _documentFromValueOrNull(
  ProfileSettingsDetailKind kind,
  MobileLegalDocuments? value,
) {
  if (value == null) {
    return null;
  }

  return _documentFromValue(kind, value);
}

MobileLegalDocument _documentFromValue(
  ProfileSettingsDetailKind kind,
  MobileLegalDocuments value,
) {
  return kind == ProfileSettingsDetailKind.terms
      ? value.termsOfUse
      : value.privacyPolicy;
}

String _formatDate(DateTime? value, Locale locale) {
  if (value == null) {
    return '—';
  }

  return DateFormat.yMMMd(
    locale.toLanguageTag(),
  ).add_Hm().format(value.toLocal());
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Row(
      children: [
        IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textStrong,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: colors.border.withValues(alpha: 0.75),
                ),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
