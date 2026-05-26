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

class ProfileAccountInfoPage extends ConsumerWidget {
  const ProfileAccountInfoPage({super.key});

  static const routePath = '/profile/settings/account';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final profile = ref.watch(profileControllerProvider).profile;
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
                              if (profile.roles.isNotEmpty)
                                ProfileStatusPill(label: profile.roles.first),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ProfileGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.profileAccountDetailsSection,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      profile.displayName?.trim().isNotEmpty == true
                          ? profile.displayName!
                          : text.profileAccountDisplayNameMissing,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.email,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.legalAcceptance.isCurrentAccepted
                          ? text.profileLegalAcceptanceCurrent
                          : text.profileLegalAcceptanceRequired,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
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
      final currentDocument = _documentFromAsync(kind, legalDocumentsAsync);
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
              if (currentDocument case final document?)
                ProfileGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _showFullLegalDocumentSheet(
                            context,
                            title,
                            document,
                          ),
                          icon: const Icon(Icons.menu_book_rounded),
                          label: Text(text.profileLegalOpenFullAction),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        document.summary,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 15,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        text.profileLegalCompactHint,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
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
                  ProfileSectionLabel(
                    label: text.profileLegalDocumentInfoSection,
                  ),
                  const SizedBox(height: 8),
                  ProfileGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _changesTitle(locale),
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ..._buildChangesHints(
                          _documentFromValue(kind, value),
                          locale,
                        ).map(
                          (hint) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              hint,
                              style: TextStyle(
                                color: colors.textSoft,
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
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
                  const SizedBox(height: 14),
                  ProfileSectionLabel(label: text.profileLegalDocumentSection),
                  ..._documentFromValue(kind, value).sections
                      .take(4)
                      .map(
                        (section) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ProfileGlassCard(
                            child: _LegalSectionTile(
                              section: section,
                              compactLabel:
                                  text.profileLegalCompactSectionLabel,
                              colors: colors,
                            ),
                          ),
                        ),
                      ),
                  if (_documentFromValue(kind, value).sections.length > 4)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ProfileGlassCard(
                        child: Text(
                          text.profileLegalCompactHint,
                          style: TextStyle(
                            color: colors.textSoft,
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  ProfileSectionLabel(
                    label: text.profileDetailsNextStepSection,
                  ),
                  const SizedBox(height: 8),
                  ProfileGlassCard(
                    child: Text(
                      requiresAcceptance
                          ? text.profileDetailsTermsNext
                          : text.profileLegalCurrentAcceptedHint,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 15,
                        height: 1.5,
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

  String _changesTitle(Locale locale) {
    return locale.languageCode.toLowerCase().startsWith('ru')
        ? 'Что изменилось'
        : 'What changed';
  }

  List<String> _buildChangesHints(MobileLegalDocument document, Locale locale) {
    final headings = document.sections
        .map((section) => section.heading.trim())
        .where((heading) => heading.isNotEmpty)
        .take(3)
        .toList(growable: false);

    if (headings.isEmpty) {
      return [
        locale.languageCode.toLowerCase().startsWith('ru')
            ? '• Обновлено содержание документа.'
            : '• Document content has been updated.',
      ];
    }

    return headings.map((heading) => '• $heading').toList(growable: false);
  }

  Future<void> _showFullLegalDocumentSheet(
    BuildContext context,
    String title,
    MobileLegalDocument document,
  ) {
    final colors = context.petMagicColors;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.9,
            minChildSize: 0.6,
            maxChildSize: 0.95,
            builder: (context, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    document.summary,
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...document.sections.map(
                    (section) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.heading,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...section.paragraphs.map(
                            (paragraph) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                paragraph,
                                style: TextStyle(
                                  color: colors.textSoft,
                                  fontSize: 14,
                                  height: 1.55,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _LegalSectionTile extends StatelessWidget {
  const _LegalSectionTile({
    required this.section,
    required this.compactLabel,
    required this.colors,
  });

  final MobileLegalDocumentSection section;
  final String compactLabel;
  final PetMagicColors colors;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        iconColor: colors.textStrong,
        collapsedIconColor: colors.textMuted,
        title: Text(
          section.heading,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            compactLabel,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        children: [
          const SizedBox(height: 8),
          ...section.paragraphs.map(
            (paragraph) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                paragraph,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 14,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
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
