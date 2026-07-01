import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_controller.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_change_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_settings_bottom_sheets.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

part 'profile_settings_page_content.part.dart';
part 'profile_settings_feedback.part.dart';

class ProfileSettingsPage extends ConsumerWidget {
  const ProfileSettingsPage({super.key});

  static const routePath = '/profile/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final state = ref.watch(profileControllerProvider);
    final bottomNavInset = petMagicScrollableBottomInset(context);
    final preferences = ref.watch(appPreferencesControllerProvider);
    final resolvedLocale =
        preferences.locale ?? Localizations.localeOf(context);
    final preferencesController = ref.read(
      appPreferencesControllerProvider.notifier,
    );
    final profileController = ref.read(profileControllerProvider.notifier);
    final router = GoRouter.of(context);

    if (!state.isLoading && !state.isAuthenticated) {
      return ProfileScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomNavInset),
            child: ProtectedAuthGate(
              subtitle: text.authRequiredMessage,
              onSignIn: () => showAuthRequiredSheet(
                context,
                redirectPath: ProfileSettingsPage.routePath,
              ),
            ),
          ),
        ),
      );
    }

    return _ProfileSettingsPageContent(
      state: state,
      bottomNavInset: bottomNavInset,
      resolvedLocale: resolvedLocale,
      themeMode: preferences.themeMode,
      isLight: isLight,
      onBack: () {
        if (router.canPop()) {
          router.pop();
          return;
        }

        router.go(ProfilePage.routePath);
      },
      onOpenAccountInfo: () => context.push(ProfileAccountInfoPage.routePath),
      onOpenLinkedAccounts: () => context.push(
        ProfileSettingsDetailPage.location(
          ProfileSettingsDetailKind.linkedAccounts,
        ),
      ),
      onOpenPassword: () {
        final email = (state.profile?.email ?? state.email).trim();
        if (email.isEmpty) {
          PetMagicToast.show(
            context,
            message: text.profileSettingsUnavailableSubtitle,
            tone: PetMagicToastTone.info,
          );
          return;
        }

        context.push(
          '${PasswordChangePage.routePath}?email=${Uri.encodeComponent(email)}',
        );
      },
      onOpenNotifications: () => context.push(
        ProfileSettingsDetailPage.location(
          ProfileSettingsDetailKind.notifications,
        ),
      ),
      onOpenLanguageSheet: () => showProfileLanguageSheet(
        context: context,
        selectedLocale: resolvedLocale,
        options: profileLanguageSheetOptions,
        onSelect: preferencesController.updateLocale,
      ),
      onOpenThemeSheet: () => showProfileThemeSheet(
        context: context,
        selectedThemeMode: preferences.themeMode,
        onSelect: preferencesController.updateThemeMode,
      ),
      onOpenHelpCenter: () => context.push(
        ProfileSettingsDetailPage.location(
          ProfileSettingsDetailKind.helpCenter,
        ),
      ),
      onOpenSupport: () => context.push(SupportChatPage.routePath),
      onOpenFeedback: () =>
          _handleSettingsFeedbackSubmission(context: context, ref: ref),
      onOpenTerms: () => context.push(
        ProfileSettingsDetailPage.location(ProfileSettingsDetailKind.terms),
      ),
      onOpenPrivacy: () => context.push(
        ProfileSettingsDetailPage.location(ProfileSettingsDetailKind.privacy),
      ),
      onDeleteAccount: () => showProfileDeleteAccountConfirmationSheet(
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
            message: mapProfileFeedbackMessage(nextState.errorMessage!, text),
            tone: PetMagicToastTone.warning,
          );
        },
      ),
    );
  }

  static String _themeModeLabel(AppLocalizations text, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => text.profileSettingsThemeSystem,
      ThemeMode.light => text.profileSettingsThemeLight,
      ThemeMode.dark => text.profileSettingsThemeDark,
    };
  }
}
