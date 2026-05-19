import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';

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

class ProfileAccountInfoPage extends ConsumerWidget {
  const ProfileAccountInfoPage({super.key});

  static const routePath = '/profile/settings/account';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final profile = ref.watch(profileControllerProvider).profile;

    return ProfileScreenBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
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
              ProfileGlassCard(
                child: Row(
                  children: [
                    ProfileAvatarBadge(
                      imageUrl: profile.avatar?.url,
                      fallbackLabel:
                          profile.displayName?.trim().isNotEmpty == true
                          ? profile.displayName!
                          : profile.email,
                      size: 88,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName?.trim().isNotEmpty == true
                                ? profile.displayName!
                                : profile.email,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.email,
                            style: TextStyle(
                              color: colors.textSoft,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ProfileStatusPill(
                                label: profile.isPremium
                                    ? text.premiumLabel
                                    : text.freeLabel,
                              ),
                              ProfileStatusPill(
                                label: profile.emailConfirmed
                                    ? text.profileEmailConfirmed
                                    : text.profileEmailPending,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ProfileSectionLabel(label: text.profileAccountDetailsSection),
              ProfileGlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _InfoRow(
                      label: text.profileAccountUserIdLabel,
                      value: profile.userId,
                    ),
                    _InfoRow(
                      label: text.profileEmailLabel,
                      value: profile.email,
                    ),
                    _InfoRow(
                      label: text.profileAccountDisplayNameLabel,
                      value: profile.displayName?.trim().isNotEmpty == true
                          ? profile.displayName!
                          : text.profileAccountDisplayNameMissing,
                    ),
                    _InfoRow(
                      label: text.profileAccountRolesLabel,
                      value: profile.roles.isEmpty
                          ? text.profileAccountRolesMissing
                          : profile.roles.join(', '),
                    ),
                    _InfoRow(
                      label: text.profileAccountMembershipLabel,
                      value: profile.isPremium
                          ? text.premiumLabel
                          : text.freeLabel,
                    ),
                    _InfoRow(
                      label: text.profileAccountConsentLabel,
                      value: profile.termsOfUseAccepted
                          ? text.profilePreferenceEnabled
                          : text.profilePreferenceOff,
                    ),
                    _InfoRow(
                      label: text.profileAccountMarketingLabel,
                      value: profile.marketingEmailsEnabled
                          ? text.profilePreferenceEnabled
                          : text.profilePreferenceOff,
                    ),
                    _InfoRow(
                      label: text.profileAccountAvatarLabel,
                      value: profile.avatar == null
                          ? text.profileAccountAvatarMissing
                          : text.profileAccountAvatarUploaded,
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
    final profile = ref.watch(profileControllerProvider).profile;

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

    final status = switch (kind) {
      ProfileSettingsDetailKind.linkedAccounts =>
        text.profileDetailsLinkedAccountsStatus,
      ProfileSettingsDetailKind.notifications =>
        profile?.marketingEmailsEnabled == true
            ? text.profileDetailsNotificationsStatusEnabled
            : text.profileDetailsNotificationsStatusDisabled,
      ProfileSettingsDetailKind.helpCenter => text.profileDetailsHelpStatus,
      ProfileSettingsDetailKind.support => text.profileDetailsSupportStatus,
      ProfileSettingsDetailKind.terms =>
        profile?.termsOfUseAccepted == true
            ? text.profileDetailsTermsStatusAccepted
            : text.profileDetailsTermsStatusPending,
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
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
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
          ],
        ),
      ),
    );
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
