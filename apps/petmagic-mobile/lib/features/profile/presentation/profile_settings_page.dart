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
    final bottomNavInset = petMagicBottomNavInset(context);
    final preferences = ref.watch(appPreferencesControllerProvider);
    final preferencesController = ref.read(
      appPreferencesControllerProvider.notifier,
    );

    return ProfileScreenBackground(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(18, 16, 18, bottomNavInset),
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
                    subtitle: state.profile == null
                        ? text.profileSettingsUnavailableSubtitle
                        : state.profile!.email,
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
            const SizedBox(height: 18),
            ProfileSectionLabel(label: text.profileSettingsPreferencesSection),
            ProfileGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingsChoiceGroup(
                    icon: Icons.language_rounded,
                    title: text.profileSettingsLanguageTitle,
                    subtitle: text.profileSettingsLanguageSubtitle,
                    children: [
                      _SettingsChoiceButton(
                        icon: Icons.translate_rounded,
                        label: 'RU',
                        caption: text.profileSettingsLanguageRussian,
                        isSelected: _matchesLocale(
                          preferences.locale,
                          const Locale('ru'),
                        ),
                        onTap: () => preferencesController.updateLocale(
                          const Locale('ru'),
                        ),
                      ),
                      _SettingsChoiceButton(
                        icon: Icons.language_rounded,
                        label: 'EN',
                        caption: text.profileSettingsLanguageEnglish,
                        isSelected: _matchesLocale(
                          preferences.locale,
                          const Locale('en'),
                        ),
                        onTap: () => preferencesController.updateLocale(
                          const Locale('en'),
                        ),
                      ),
                      _SettingsChoiceButton(
                        icon: Icons.public_rounded,
                        label: 'US',
                        caption: text.profileSettingsLanguageEnglishUs,
                        isSelected: _matchesLocale(
                          preferences.locale,
                          const Locale('en', 'US'),
                        ),
                        onTap: () => preferencesController.updateLocale(
                          const Locale('en', 'US'),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(
                      height: 1,
                      color: colors.border.withValues(alpha: 0.7),
                    ),
                  ),
                  _SettingsChoiceGroup(
                    icon: Icons.dark_mode_outlined,
                    title: text.profileSettingsThemeTitle,
                    subtitle: text.profileSettingsThemeSubtitle,
                    children: [
                      _SettingsChoiceButton(
                        icon: Icons.brightness_auto_rounded,
                        label: text.profileSettingsThemeSystem,
                        isSelected: preferences.themeMode == ThemeMode.system,
                        onTap: () => preferencesController.updateThemeMode(
                          ThemeMode.system,
                        ),
                      ),
                      _SettingsChoiceButton(
                        icon: Icons.light_mode_rounded,
                        label: text.profileSettingsThemeLight,
                        isSelected: preferences.themeMode == ThemeMode.light,
                        onTap: () => preferencesController.updateThemeMode(
                          ThemeMode.light,
                        ),
                      ),
                      _SettingsChoiceButton(
                        icon: Icons.dark_mode_rounded,
                        label: text.profileSettingsThemeDark,
                        isSelected: preferences.themeMode == ThemeMode.dark,
                        onTap: () => preferencesController.updateThemeMode(
                          ThemeMode.dark,
                        ),
                      ),
                    ],
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

  static bool _matchesLocale(Locale? currentLocale, Locale candidate) {
    final effectiveLocale = currentLocale ?? candidate;

    return effectiveLocale.languageCode == candidate.languageCode &&
        (effectiveLocale.countryCode ?? '') == (candidate.countryCode ?? '');
  }
}

class _SettingsChoiceGroup extends StatelessWidget {
  const _SettingsChoiceGroup({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colors.accent, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                children[index],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsChoiceButton extends StatelessWidget {
  const _SettingsChoiceButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.caption,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.accent.withValues(alpha: 0.16)
                : colors.surfaceStrong.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? colors.accent.withValues(alpha: 0.55)
                  : colors.border.withValues(alpha: 0.75),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? colors.accent : colors.textMuted,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 12.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
