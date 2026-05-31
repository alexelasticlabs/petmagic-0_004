import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_controller.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_change_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_settings_bottom_sheets.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';

class ProfileSettingsPage extends ConsumerWidget {
  const ProfileSettingsPage({super.key});

  static const routePath = '/profile/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
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

    return ProfileScreenBackground(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(18, 16, 18, bottomNavInset),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (router.canPop()) {
                      router.pop();
                      return;
                    }

                    router.go(ProfilePage.routePath);
                  },
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
                        text.profileSettingsTitle,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        text.profileSettingsSubtitle,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ProfileSectionLabel(label: text.profileSettingsAccountSection),
            ProfileGlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ProfileSettingsRow(
                    icon: Icons.person_outline_rounded,
                    title: text.profileSettingsAccountInfoTitle,
                    subtitle: text.profileAccountDetailsSubtitle,
                    onTap: () => context.push(ProfileAccountInfoPage.routePath),
                  ),
                  ProfileSettingsRow(
                    icon: Icons.link_rounded,
                    title: text.profileSettingsLinkedAccountsTitle,
                    subtitle: text.profileSettingsLinkedAccountsSubtitle,
                    onTap: () => context.push(
                      ProfileSettingsDetailPage.location(
                        ProfileSettingsDetailKind.linkedAccounts,
                      ),
                    ),
                  ),
                  ProfileSettingsRow(
                    icon: Icons.lock_outline_rounded,
                    title: text.profileSettingsPasswordTitle,
                    subtitle: text.profileSettingsPasswordSubtitle,
                    showDivider: false,
                    onTap: () {
                      final email = (state.profile?.email ?? state.email)
                          .trim();
                      if (email.isEmpty) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                text.profileSettingsUnavailableSubtitle,
                              ),
                            ),
                          );
                        return;
                      }

                      context.push(
                        '${PasswordChangePage.routePath}?email=${Uri.encodeComponent(email)}',
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ProfileSectionLabel(
              label: text.profileSettingsNotificationsSection,
            ),
            ProfileGlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ProfileSettingsRow(
                    icon: Icons.notifications_none_rounded,
                    title: text.profileSettingsNotificationsTitle,
                    subtitle: text.profileSettingsNotificationsSubtitle,
                    onTap: () => context.push(
                      ProfileSettingsDetailPage.location(
                        ProfileSettingsDetailKind.notifications,
                      ),
                    ),
                    trailingText: state.profile?.marketingEmailsEnabled == true
                        ? text.profilePreferenceEnabled
                        : text.profilePreferenceOff,
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ProfileSectionLabel(label: text.profileSettingsPreferencesSection),
            ProfileGlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ProfileSettingsRow(
                    icon: Icons.language_rounded,
                    title: text.profileSettingsLanguageTitle,
                    subtitle: _languageLabel(text, resolvedLocale),
                    onTap: () async {
                      await showProfileLanguageSheet(
                        context: context,
                        selectedLocale: resolvedLocale,
                        options: _languageOptions(),
                        onSelect: preferencesController.updateLocale,
                      );
                    },
                  ),
                  ProfileSettingsRow(
                    icon: Icons.dark_mode_outlined,
                    title: text.profileSettingsThemeTitle,
                    subtitle: _themeModeLabel(text, preferences.themeMode),
                    showDivider: false,
                    onTap: () async {
                      await showProfileThemeSheet(
                        context: context,
                        selectedThemeMode: preferences.themeMode,
                        onSelect: preferencesController.updateThemeMode,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ProfileSectionLabel(label: text.profileSettingsSupportSection),
            ProfileGlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ProfileSettingsRow(
                    icon: Icons.help_outline_rounded,
                    title: text.profileSettingsHelpCenterTitle,
                    subtitle: text.profileSettingsHelpCenterSubtitle,
                    onTap: () => context.push(
                      ProfileSettingsDetailPage.location(
                        ProfileSettingsDetailKind.helpCenter,
                      ),
                    ),
                  ),
                  ProfileSettingsRow(
                    icon: Icons.support_agent_rounded,
                    title: text.profileSettingsSupportTitle,
                    subtitle: text.profileSettingsSupportSubtitle,
                    showDivider: false,
                    onTap: () => context.push(SupportChatPage.routePath),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ProfileSectionLabel(label: text.profileSettingsAboutSection),
            ProfileGlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ProfileSettingsRow(
                    icon: Icons.description_outlined,
                    title: text.profileSettingsTermsTitle,
                    subtitle: text.profileSettingsTermsSubtitle,
                    onTap: () => context.push(
                      ProfileSettingsDetailPage.location(
                        ProfileSettingsDetailKind.terms,
                      ),
                    ),
                  ),
                  ProfileSettingsRow(
                    icon: Icons.verified_user_outlined,
                    title: text.profileSettingsPrivacyTitle,
                    subtitle: text.profileSettingsPrivacySubtitle,
                    showDivider: false,
                    onTap: () => context.push(
                      ProfileSettingsDetailPage.location(
                        ProfileSettingsDetailKind.privacy,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        text.profileSettingsVersionLabel('1.2.0'),
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ProfileSectionLabel(label: text.profileSettingsDangerSection),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.danger.withValues(alpha: 0.2),
                      colors.surfaceGlass,
                    ],
                  ),
                  border: Border.all(
                    color: colors.danger.withValues(alpha: 0.45),
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colors.danger.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ProfileSettingsRow(
                  icon: Icons.delete_outline_rounded,
                  title: text.profileSettingsDeleteAccountTitle,
                  subtitle: text.profileSettingsDeleteAccountSubtitle,
                  iconColor: colors.danger,
                  isDestructive: true,
                  showDivider: false,
                  onTap: () async {
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<ProfileLanguageSheetOption> _languageOptions() {
    return const [
      ProfileLanguageSheetOption(locale: Locale('ru'), nativeLabel: 'Русский'),
      ProfileLanguageSheetOption(locale: Locale('en'), nativeLabel: 'English'),
      ProfileLanguageSheetOption(locale: Locale('de'), nativeLabel: 'Deutsch'),
      ProfileLanguageSheetOption(locale: Locale('es'), nativeLabel: 'Español'),
      ProfileLanguageSheetOption(locale: Locale('fr'), nativeLabel: 'Français'),
      ProfileLanguageSheetOption(locale: Locale('it'), nativeLabel: 'Italiano'),
      ProfileLanguageSheetOption(locale: Locale('pl'), nativeLabel: 'Polski'),
    ];
  }

  static String _languageLabel(AppLocalizations text, Locale locale) {
    return switch (locale.languageCode) {
      'ru' => 'Русский',
      'en' => 'English',
      'de' => 'Deutsch',
      'es' => 'Español',
      'fr' => 'Français',
      'it' => 'Italiano',
      'pl' => 'Polski',
      _ => 'English',
    };
  }

  static String _themeModeLabel(AppLocalizations text, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => text.profileSettingsThemeSystem,
      ThemeMode.light => text.profileSettingsThemeLight,
      ThemeMode.dark => text.profileSettingsThemeDark,
    };
  }
}
