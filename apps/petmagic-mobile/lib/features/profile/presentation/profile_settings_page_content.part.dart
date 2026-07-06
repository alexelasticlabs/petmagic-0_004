part of 'profile_settings_page.dart';

class _ProfileSettingsPageContent extends StatelessWidget {
  const _ProfileSettingsPageContent({
    required this.state,
    required this.bottomNavInset,
    required this.resolvedLocale,
    required this.themeMode,
    required this.isLight,
    required this.onBack,
    required this.onOpenAccountInfo,
    required this.onOpenLinkedAccounts,
    required this.onOpenPassword,
    required this.onOpenNotifications,
    required this.onOpenLanguageSheet,
    required this.onOpenThemeSheet,
    required this.onOpenHelpCenter,
    required this.onOpenSupport,
    required this.onOpenFeedback,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
    required this.onDeleteAccount,
  });

  final ProfileState state;
  final double bottomNavInset;
  final Locale resolvedLocale;
  final ThemeMode themeMode;
  final bool isLight;
  final VoidCallback onBack;
  final VoidCallback onOpenAccountInfo;
  final VoidCallback onOpenLinkedAccounts;
  final VoidCallback onOpenPassword;
  final VoidCallback onOpenNotifications;
  final Future<void> Function() onOpenLanguageSheet;
  final Future<void> Function() onOpenThemeSheet;
  final VoidCallback onOpenHelpCenter;
  final VoidCallback onOpenSupport;
  final Future<void> Function() onOpenFeedback;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;
  final Future<void> Function() onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileScreenBackground(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(18, 16, 18, bottomNavInset),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onBack,
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
                    onTap: onOpenAccountInfo,
                  ),
                  ProfileSettingsRow(
                    icon: Icons.link_rounded,
                    title: text.profileSettingsLinkedAccountsTitle,
                    subtitle: text.profileSettingsLinkedAccountsSubtitle,
                    onTap: onOpenLinkedAccounts,
                  ),
                  ProfileSettingsRow(
                    icon: Icons.lock_outline_rounded,
                    title: text.profileSettingsPasswordTitle,
                    subtitle: text.profileSettingsPasswordSubtitle,
                    showDivider: false,
                    onTap: onOpenPassword,
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
                    onTap: onOpenNotifications,
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
                    subtitle: profileLanguageLabel(text, resolvedLocale),
                    onTap: onOpenLanguageSheet,
                  ),
                  ProfileSettingsRow(
                    icon: Icons.dark_mode_outlined,
                    title: text.profileSettingsThemeTitle,
                    subtitle: ProfileSettingsPage._themeModeLabel(
                      text,
                      themeMode,
                    ),
                    showDivider: false,
                    onTap: onOpenThemeSheet,
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
                    onTap: onOpenHelpCenter,
                  ),
                  ProfileSettingsRow(
                    icon: Icons.support_agent_rounded,
                    title: text.profileSettingsSupportTitle,
                    subtitle: text.profileSettingsSupportSubtitle,
                    onTap: onOpenSupport,
                  ),
                  ProfileSettingsRow(
                    icon: Icons.feedback_outlined,
                    title: _settingsFeedbackCopy(context).title,
                    subtitle: _settingsFeedbackCopy(context).subtitle,
                    showDivider: false,
                    onTap: onOpenFeedback,
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
                    onTap: onOpenTerms,
                  ),
                  ProfileSettingsRow(
                    icon: Icons.verified_user_outlined,
                    title: text.profileSettingsPrivacyTitle,
                    subtitle: text.profileSettingsPrivacySubtitle,
                    showDivider: false,
                    onTap: onOpenPrivacy,
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
                      Color.alphaBlend(
                        colors.danger.withValues(alpha: isLight ? 0.08 : 0.18),
                        colors.surface,
                      ),
                      Color.alphaBlend(
                        colors.danger.withValues(alpha: isLight ? 0.04 : 0.14),
                        colors.surfaceStrong,
                      ),
                    ],
                  ),
                  border: Border.all(
                    color: colors.danger.withValues(
                      alpha: isLight ? 0.42 : 0.36,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colors.danger.withValues(
                        alpha: isLight ? 0.10 : 0.12,
                      ),
                      blurRadius: isLight ? 10 : 14,
                      offset: Offset(0, isLight ? 4 : 6),
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
                  onTap: onDeleteAccount,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
