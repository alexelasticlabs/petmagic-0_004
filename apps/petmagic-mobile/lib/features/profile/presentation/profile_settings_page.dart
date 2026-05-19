import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_controller.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_reset_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';

class ProfileSettingsPage extends ConsumerWidget {
  const ProfileSettingsPage({super.key});

  static const routePath = '/profile/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final state = ref.watch(profileControllerProvider);
    final preferences = ref.watch(appPreferencesControllerProvider);
    final preferencesController = ref.read(
      appPreferencesControllerProvider.notifier,
    );

    return ProfileScreenBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            Row(
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
                        text.profileSettingsTitle,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 31,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        text.profileSettingsSubtitle,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            ProfileSectionLabel(label: text.profileSettingsAccountSection),
            ProfileGlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ProfileSettingsRow(
                    icon: Icons.person_outline_rounded,
                    title: text.profileSettingsAccountInfoTitle,
                    subtitle: state.profile == null
                        ? text.profileSettingsUnavailableSubtitle
                        : '${state.profile!.displayName?.trim().isNotEmpty == true ? state.profile!.displayName : state.profile!.email} • ${state.profile!.email}',
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
                      context.push(
                        '${PasswordResetPage.routePath}?email=${Uri.encodeComponent(state.profile?.email ?? state.email)}',
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
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
                    trailing: IgnorePointer(
                      child: Switch.adaptive(
                        value: state.profile?.marketingEmailsEnabled ?? false,
                        onChanged: (_) {},
                      ),
                    ),
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            ProfileSectionLabel(label: text.profileSettingsPreferencesSection),
            ProfileGlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ProfileSettingsRow(
                    icon: Icons.language_rounded,
                    title: text.profileSettingsLanguageTitle,
                    subtitle: text.profileSettingsLanguageSubtitle,
                    trailingText: _languageLabel(context, preferences.locale),
                    onTap: () => _showLocalePicker(
                      context,
                      preferences.locale,
                      preferencesController,
                    ),
                  ),
                  ProfileSettingsRow(
                    icon: Icons.dark_mode_outlined,
                    title: text.profileSettingsThemeTitle,
                    subtitle: text.profileSettingsThemeSubtitle,
                    trailingText: _themeModeLabel(
                      context,
                      preferences.themeMode,
                    ),
                    showDivider: false,
                    onTap: () => _showThemeModePicker(
                      context,
                      preferences.themeMode,
                      preferencesController,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
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
                    onTap: () => context.push(
                      ProfileSettingsDetailPage.location(
                        ProfileSettingsDetailKind.support,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
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
            const SizedBox(height: 22),
            ProfileSectionLabel(label: text.profileSettingsDangerSection),
            ProfileGlassCard(
              padding: EdgeInsets.zero,
              child: ProfileSettingsRow(
                icon: Icons.delete_outline_rounded,
                title: text.profileSettingsDeleteAccountTitle,
                subtitle: text.profileSettingsDeleteAccountSubtitle,
                iconColor: colors.danger,
                isDestructive: true,
                showDivider: false,
                onTap: () => context.push(
                  ProfileSettingsDetailPage.location(
                    ProfileSettingsDetailKind.deleteAccount,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _themeModeLabel(BuildContext context, ThemeMode mode) {
    final text = AppLocalizations.of(context);

    return switch (mode) {
      ThemeMode.system => text.profileSettingsThemeSystem,
      ThemeMode.light => text.profileSettingsThemeLight,
      ThemeMode.dark => text.profileSettingsThemeDark,
    };
  }

  String _languageLabel(BuildContext context, Locale? locale) {
    final text = AppLocalizations.of(context);
    final effectiveLocale = locale ?? Localizations.localeOf(context);

    if (effectiveLocale.languageCode == 'ru') {
      return text.profileSettingsLanguageRussian;
    }

    if (effectiveLocale.languageCode == 'en' &&
        effectiveLocale.countryCode == 'US') {
      return text.profileSettingsLanguageEnglishUs;
    }

    return text.profileSettingsLanguageEnglish;
  }

  Future<void> _showThemeModePicker(
    BuildContext context,
    ThemeMode currentMode,
    AppPreferencesController controller,
  ) async {
    final text = AppLocalizations.of(context);
    final selectedMode = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(text.profileSettingsThemeSystem),
                trailing: currentMode == ThemeMode.system
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(context).pop(ThemeMode.system),
              ),
              ListTile(
                title: Text(text.profileSettingsThemeLight),
                trailing: currentMode == ThemeMode.light
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(context).pop(ThemeMode.light),
              ),
              ListTile(
                title: Text(text.profileSettingsThemeDark),
                trailing: currentMode == ThemeMode.dark
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(context).pop(ThemeMode.dark),
              ),
            ],
          ),
        );
      },
    );

    if (selectedMode != null) {
      await controller.updateThemeMode(selectedMode);
    }
  }

  Future<void> _showLocalePicker(
    BuildContext context,
    Locale? currentLocale,
    AppPreferencesController controller,
  ) async {
    final text = AppLocalizations.of(context);
    final selectedLocale = await showModalBottomSheet<Locale>(
      context: context,
      builder: (context) {
        final current = currentLocale ?? Localizations.localeOf(context);

        Widget buildLocaleTile(Locale locale, String label) {
          final isSelected =
              locale.languageCode == current.languageCode &&
              (locale.countryCode ?? '') == (current.countryCode ?? '');

          return ListTile(
            title: Text(label),
            trailing: isSelected ? const Icon(Icons.check_rounded) : null,
            onTap: () => Navigator.of(context).pop(locale),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildLocaleTile(
                const Locale('ru'),
                text.profileSettingsLanguageRussian,
              ),
              buildLocaleTile(
                const Locale('en'),
                text.profileSettingsLanguageEnglish,
              ),
              buildLocaleTile(
                const Locale('en', 'US'),
                text.profileSettingsLanguageEnglishUs,
              ),
            ],
          ),
        );
      },
    );

    if (selectedLocale != null) {
      await controller.updateLocale(selectedLocale);
    }
  }
}
