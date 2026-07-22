import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/application/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_settings_detail_header.dart';
import 'package:petmagic_mobile/shared/auth/auth_required_sheet.dart';
import 'package:petmagic_mobile/shared/profile/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_linked_accounts_settings_section.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_notifications_settings_section.dart';
import 'package:petmagic_mobile/shared/settings/app_settings_bottom_sheets.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/legal_document_list_view.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

export 'profile_account_info_page.dart';

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
          ? () => context.appNavigator.push(const SupportChatDestination())
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
