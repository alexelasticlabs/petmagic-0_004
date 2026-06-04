import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_avatar_cropper_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_linked_accounts_settings_section.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_notifications_settings_section.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_settings_bottom_sheets.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';

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
    if (!_isEditingDisplayName) {
      _displayNameController.text = profile?.displayName ?? '';
    }
    final bottomInset = petMagicBottomNavInset(
      context,
      extraSpacing: kPetMagicBottomContentInsetRelaxed,
    );

    ref.listen(profileControllerProvider, (previous, next) {
      if (!mounted) {
        return;
      }

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

class _AccountProfileHeroCard extends StatelessWidget {
  const _AccountProfileHeroCard({
    required this.profile,
    required this.displayName,
    required this.isSaving,
    required this.onAvatarTap,
  });

  final MobileUserProfile profile;
  final String displayName;
  final bool isSaving;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // gradient accent strip
          Container(
            width: double.infinity,
            height: 5,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                colors: [
                  colors.accent.withValues(alpha: 0.7),
                  colors.blue.withValues(alpha: 0.5),
                  colors.purple.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
          // tappable avatar
          Stack(
            alignment: Alignment.center,
            children: [
              ProfileAvatarBadge(
                imageUrl: profile.avatar?.url,
                fallbackLabel: displayName,
                size: 120,
                showEditOverlay: !isSaving,
                onTap: isSaving ? null : onAvatarTap,
              ),
              if (isSaving)
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colors.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text.profileAvatarTapToChange,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 16),
          // display name
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 5),
          // email
          Text(
            profile.email,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          // status pills
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ProfileStatusPill(
                label: profile.isPremium ? text.premiumLabel : text.freeLabel,
                leading: profile.isPremium
                    ? null
                    : Icons.person_outline_rounded,
                leadingWidget: profile.isPremium
                    ? const PremiumCrownIcon(size: 13)
                    : null,
                backgroundColor: profile.isPremium
                    ? const Color(0xFFFFC107).withValues(alpha: 0.18)
                    : null,
                foregroundColor: profile.isPremium
                    ? const Color(0xFFF59E0B)
                    : null,
              ),
              ProfileStatusPill(
                label: profile.emailConfirmed
                    ? text.profileEmailVerifiedShort
                    : text.profileEmailPendingShort,
                leading: profile.emailConfirmed
                    ? Icons.verified_rounded
                    : Icons.mail_outline_rounded,
                foregroundColor: profile.emailConfirmed
                    ? colors.accent
                    : colors.textMuted,
              ),
              if (profile.roles.isNotEmpty)
                ProfileStatusPill(
                  label: profile.roles.first,
                  leading: Icons.shield_outlined,
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ProfileEditableNameCard extends StatelessWidget {
  const _ProfileEditableNameCard({
    required this.controller,
    required this.isEditing,
    required this.isSaving,
    required this.currentValue,
    required this.onStartEditing,
    required this.onCancelEditing,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool isEditing;
  final bool isSaving;
  final String currentValue;
  final VoidCallback onStartEditing;
  final VoidCallback onCancelEditing;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final material = MaterialLocalizations.of(context);

    return ProfileGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.accentSoft.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.badge_outlined, color: colors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text.profileAccountDisplayNameLabel,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!isEditing)
                IconButton(
                  onPressed: isSaving ? null : onStartEditing,
                  tooltip: text.profileAccountDisplayNameLabel,
                  icon: const Icon(Icons.edit_rounded),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isEditing) ...[
            TextField(
              controller: controller,
              textInputAction: TextInputAction.done,
              maxLength: 120,
              decoration: InputDecoration(
                counterText: '',
                hintText: text.profileAccountDisplayNameLabel,
              ),
              onSubmitted: (_) => onSave(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : onCancelEditing,
                    child: Text(material.cancelButtonLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: isSaving ? null : onSave,
                    child: Text(
                      isSaving
                          ? text.profileLoadingAction
                          : material.saveButtonLabel,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              currentValue,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
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
    final colors = context.petMagicColors;
    final state = ref.watch(profileControllerProvider);
    final profileController = ref.read(profileControllerProvider.notifier);
    final profile = state.profile;
    final bottomInset = petMagicBottomNavInset(
      context,
      extraSpacing: kPetMagicBottomContentInsetRelaxed,
    );

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
      ProfileSettingsDetailKind.support => text.profileDetailsSupportBody,
      ProfileSettingsDetailKind.terms => text.profileDetailsTermsBody,
      ProfileSettingsDetailKind.privacy => text.profileDetailsPrivacyBody,
      ProfileSettingsDetailKind.deleteAccount => text.profileDetailsDeleteBody,
    };

    if (kind == ProfileSettingsDetailKind.terms ||
        kind == ProfileSettingsDetailKind.privacy) {
      final locale = Localizations.localeOf(context);
      final localeTag = locale.toLanguageTag();
      final legalDocumentsAsync = ref.watch(
        currentLegalDocumentsProvider(localeTag),
      );
      final requiresAcceptance =
          profile?.legalAcceptance.requiresAcceptance == true;

      return ProfileScreenBackground(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset),
            children: [
              _DetailHeader(title: title, subtitle: subtitle),
              const SizedBox(height: 22),
              if (state.errorMessage != null) ...[
                ProfileGlassCard(
                  child: Text(
                    mapProfileFeedbackMessage(state.errorMessage!, text),
                    style: TextStyle(
                      color: colors.danger,
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              ProfileSectionLabel(
                label: text.profileDetailsCurrentStatusSection,
              ),
              ProfileGlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _InfoRow(
                      label: text.profileAccountConsentLabel,
                      value: profile?.legalAcceptance.isCurrentAccepted == true
                          ? text.profileLegalAcceptanceCurrent
                          : text.profileLegalAcceptanceRequired,
                    ),
                    _InfoRow(
                      label: text.profileLegalVersionLabel,
                      value:
                          _documentFromAsync(
                            kind,
                            legalDocumentsAsync,
                          )?.version ??
                          '...',
                    ),
                    _InfoRow(
                      label: text.profileLegalPublishedLabel,
                      value: _formatDate(
                        _documentFromAsync(
                          kind,
                          legalDocumentsAsync,
                        )?.publishedAtUtc,
                        locale,
                      ),
                    ),
                    _InfoRow(
                      label: text.profileLegalAcceptedVersionLabel,
                      value: kind == ProfileSettingsDetailKind.terms
                          ? (profile
                                    ?.legalAcceptance
                                    .termsOfUseAcceptedVersion ??
                                '—')
                          : (profile
                                    ?.legalAcceptance
                                    .privacyPolicyAcceptedVersion ??
                                '—'),
                    ),
                    _InfoRow(
                      label: text.profileLegalAcceptedAtLabel,
                      value: _formatDate(
                        kind == ProfileSettingsDetailKind.terms
                            ? profile?.legalAcceptance.termsOfUseAcceptedAtUtc
                            : profile
                                  ?.legalAcceptance
                                  .privacyPolicyAcceptedAtUtc,
                        locale,
                      ),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const SizedBox(height: 18),
              ...switch (legalDocumentsAsync) {
                AsyncLoading() => [
                  ProfileGlassCard(
                    child: Text(
                      text.profileLegalLoading,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                AsyncError() => [
                  ProfileGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.profileLegalUnavailable,
                          style: TextStyle(
                            color: colors.danger,
                            fontSize: 15,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => ref.invalidate(
                            currentLegalDocumentsProvider(localeTag),
                          ),
                          child: Text(text.retryAction),
                        ),
                      ],
                    ),
                  ),
                ],
                AsyncData(:final value) => [
                  ProfileGlassCard(
                    child: profile != null && requiresAcceptance
                        ? SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: state.isSaving
                                  ? null
                                  : () => ref
                                        .read(
                                          profileControllerProvider.notifier,
                                        )
                                        .acceptCurrentLegalDocuments(value),
                              child: Text(
                                state.isSaving
                                    ? text.profileLoadingAction
                                    : text.profileLegalAcceptAction,
                              ),
                            ),
                          )
                        : Text(
                            profile == null
                                ? text.profileLegalAcceptanceGuestHint
                                : text.profileLegalCurrentAcceptedHint,
                            style: TextStyle(
                              color: colors.textSoft,
                              fontSize: 14,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ],
              },
            ],
          ),
        ),
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
      ProfileSettingsDetailKind.support => text.profileDetailsSupportStatus,
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
      ProfileSettingsDetailKind.support => text.profileDetailsSupportNext,
      ProfileSettingsDetailKind.terms => text.profileDetailsTermsNext,
      ProfileSettingsDetailKind.privacy => text.profileDetailsPrivacyNext,
      ProfileSettingsDetailKind.deleteAccount => text.profileDetailsDeleteNext,
    };

    return ProfileScreenBackground(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset),
          children: [
            _DetailHeader(title: title, subtitle: subtitle),
            const SizedBox(height: 22),
            ProfileSectionLabel(label: text.profileDetailsCurrentStatusSection),
            ProfileGlassCard(
              child: Text(
                status,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 16,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 18),
            ProfileSectionLabel(label: text.profileDetailsNextStepSection),
            ProfileGlassCard(
              child: Text(
                nextStep,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (kind == ProfileSettingsDetailKind.deleteAccount) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.danger,
                    foregroundColor: colors.backgroundBottom,
                    shadowColor: colors.danger.withValues(alpha: 0.35),
                  ),
                  onPressed: () async {
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
                  },
                  child: Text(text.profileSettingsDeleteAccountTitle),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  MobileLegalDocument? _documentFromAsync(
    ProfileSettingsDetailKind kind,
    AsyncValue<MobileLegalDocuments> value,
  ) {
    return switch (value) {
      AsyncData(:final value) => _documentFromValue(kind, value),
      _ => null,
    };
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
