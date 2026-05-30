import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_linked_accounts_settings_section.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_notifications_settings_section.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_settings_bottom_sheets.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';

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
              // Hero-карточка профиля
              ProfileGlassCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ProfileAvatarBadge(
                          imageUrl: profile.avatar?.url,
                          fallbackLabel:
                              profile.displayName?.trim().isNotEmpty == true
                              ? profile.displayName!
                              : profile.email,
                          size: 72,
                        ),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: profile.isPremium
                                  ? const Color(0xFFFFC107)
                                  : colors.surfaceStrong,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.border,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              profile.isPremium
                                  ? Icons.workspace_premium_rounded
                                  : Icons.person_outline_rounded,
                              size: 13,
                              color: profile.isPremium
                                  ? Colors.white
                                  : colors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _isEditingDisplayName
                                    ? TextField(
                                        controller: _displayNameController,
                                        textInputAction: TextInputAction.done,
                                        maxLength: 120,
                                        decoration: InputDecoration(
                                          counterText: '',
                                          hintText: text
                                              .profileAccountDisplayNameLabel,
                                        ),
                                        onSubmitted: (_) async {
                                          await ref
                                              .read(
                                                profileControllerProvider
                                                    .notifier,
                                              )
                                              .updateCurrentProfile(
                                                displayName:
                                                    _displayNameController.text,
                                              );
                                          if (!mounted) {
                                            return;
                                          }
                                          setState(
                                            () => _isEditingDisplayName = false,
                                          );
                                        },
                                      )
                                    : Text(
                                        profile.displayName
                                                    ?.trim()
                                                    .isNotEmpty ==
                                                true
                                            ? profile.displayName!
                                            : profile.email,
                                        style: TextStyle(
                                          color: colors.textStrong,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          height: 1.2,
                                        ),
                                      ),
                              ),
                              if (_isEditingDisplayName) ...[
                                IconButton(
                                  tooltip: MaterialLocalizations.of(
                                    context,
                                  ).cancelButtonLabel,
                                  onPressed: state.isSaving
                                      ? null
                                      : () => setState(
                                          () => _isEditingDisplayName = false,
                                        ),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                  ),
                                ),
                                IconButton(
                                  tooltip: MaterialLocalizations.of(
                                    context,
                                  ).saveButtonLabel,
                                  onPressed: state.isSaving
                                      ? null
                                      : () async {
                                          await ref
                                              .read(
                                                profileControllerProvider
                                                    .notifier,
                                              )
                                              .updateCurrentProfile(
                                                displayName:
                                                    _displayNameController.text,
                                              );
                                          if (!mounted) {
                                            return;
                                          }
                                          setState(
                                            () => _isEditingDisplayName = false,
                                          );
                                        },
                                  icon: const Icon(
                                    Icons.check_rounded,
                                    size: 20,
                                  ),
                                ),
                              ] else
                                IconButton(
                                  tooltip: text.profileAccountDisplayNameLabel,
                                  onPressed: state.isSaving
                                      ? null
                                      : () => setState(() {
                                          _displayNameController.text =
                                              profile.displayName ?? '';
                                          _isEditingDisplayName = true;
                                        }),
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                          if (profile.displayName?.trim().isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.alternate_email_rounded,
                                  size: 13,
                                  color: colors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    profile.email,
                                    style: TextStyle(
                                      color: colors.textSoft,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ProfileStatusPill(
                                label: profile.isPremium
                                    ? text.premiumLabel
                                    : text.freeLabel,
                                leading: profile.isPremium
                                    ? Icons.workspace_premium_rounded
                                    : Icons.person_outline_rounded,
                                backgroundColor: profile.isPremium
                                    ? const Color(
                                        0xFFFFC107,
                                      ).withValues(alpha: 0.18)
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
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: state.isSaving
                                    ? null
                                    : () async {
                                        await ref
                                            .read(
                                              profileControllerProvider
                                                  .notifier,
                                            )
                                            .uploadAvatar();
                                        if (!context.mounted) {
                                          return;
                                        }

                                        final nextState = ref.read(
                                          profileControllerProvider,
                                        );
                                        if (nextState.errorMessage == null) {
                                          return;
                                        }

                                        ScaffoldMessenger.of(context)
                                          ..hideCurrentSnackBar()
                                          ..showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                mapProfileFeedbackMessage(
                                                  nextState.errorMessage!,
                                                  text,
                                                ),
                                              ),
                                            ),
                                          );
                                      },
                                icon: const Icon(Icons.upload_rounded),
                                label: Text(text.profileAvatarUpload),
                              ),
                              if (profile.avatar != null)
                                OutlinedButton.icon(
                                  onPressed: state.isSaving
                                      ? null
                                      : () async {
                                          await ref
                                              .read(
                                                profileControllerProvider
                                                    .notifier,
                                              )
                                              .removeAvatar();
                                          if (!context.mounted) {
                                            return;
                                          }

                                          final nextState = ref.read(
                                            profileControllerProvider,
                                          );
                                          if (nextState.errorMessage == null) {
                                            return;
                                          }

                                          ScaffoldMessenger.of(context)
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  mapProfileFeedbackMessage(
                                                    nextState.errorMessage!,
                                                    text,
                                                  ),
                                                ),
                                              ),
                                            );
                                        },
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  label: Text(text.profileAvatarRemove),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ProfileSectionLabel(label: text.profileAccountDetailsSection),
              ProfileGlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _AccountInfoRow(
                      icon: Icons.badge_outlined,
                      label: text.profileAccountDisplayNameLabel,
                      value: profile.displayName?.trim().isNotEmpty == true
                          ? profile.displayName!
                          : text.profileAccountDisplayNameMissing,
                      valueFaded:
                          profile.displayName?.trim().isNotEmpty != true,
                    ),
                    _AccountInfoRow(
                      icon: Icons.alternate_email_rounded,
                      label: text.profileEmailLabel,
                      value: profile.email,
                    ),
                    _AccountInfoRow(
                      icon: profile.isPremium
                          ? Icons.workspace_premium_rounded
                          : Icons.person_outline_rounded,
                      label: text.profileAccountMembershipLabel,
                      value: profile.isPremium
                          ? text.premiumLabel
                          : text.freeLabel,
                      valueColor: profile.isPremium
                          ? const Color(0xFFF59E0B)
                          : null,
                    ),
                    _AccountInfoRow(
                      icon: profile.emailConfirmed
                          ? Icons.mark_email_read_outlined
                          : Icons.mail_outline_rounded,
                      label: text.profileEmailStat,
                      value: profile.emailConfirmed
                          ? text.profileEmailConfirmed
                          : text.profileEmailPending,
                      valueColor: profile.emailConfirmed
                          ? colors.accent
                          : colors.danger,
                    ),
                    _AccountInfoRow(
                      icon: profile.avatar != null
                          ? Icons.image_rounded
                          : Icons.image_not_supported_outlined,
                      label: text.profileAccountAvatarLabel,
                      value: profile.avatar != null
                          ? text.profileAccountAvatarUploaded
                          : text.profileAccountAvatarMissing,
                      valueFaded: profile.avatar == null,
                    ),
                    _AccountInfoRow(
                      icon: profile.legalAcceptance.isCurrentAccepted
                          ? Icons.verified_user_outlined
                          : Icons.gavel_rounded,
                      label: text.profileAccountConsentLabel,
                      value: profile.legalAcceptance.isCurrentAccepted
                          ? text.profileLegalAcceptanceCurrent
                          : text.profileLegalAcceptanceRequired,
                      valueColor: profile.legalAcceptance.isCurrentAccepted
                          ? colors.accent
                          : colors.danger,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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

                        final messenger = ScaffoldMessenger.of(context);
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                mapProfileFeedbackMessage(
                                  nextState.errorMessage!,
                                  text,
                                ),
                              ),
                            ),
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

class _AccountInfoRow extends StatelessWidget {
  const _AccountInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueFaded = false,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool valueFaded;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final resolvedValueColor =
        valueColor ?? (valueFaded ? colors.textMuted : colors.textStrong);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(color: colors.border.withValues(alpha: 0.7)),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.accentSoft.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: colors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 3,
              child: Text(
                value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: TextStyle(
                  color: resolvedValueColor,
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
