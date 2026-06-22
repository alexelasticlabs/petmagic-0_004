import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_controller.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_change_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_settings_bottom_sheets.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

class ProfileSettingsPage extends ConsumerWidget {
  const ProfileSettingsPage({super.key});

  static const routePath = '/profile/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
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
                    onTap: () => context.push(SupportChatPage.routePath),
                  ),
                  ProfileSettingsRow(
                    icon: Icons.feedback_outlined,
                    title: _settingsFeedbackCopy(context).title,
                    subtitle: _settingsFeedbackCopy(context).subtitle,
                    showDivider: false,
                    onTap: () async {
                      final draft = await _showSettingsFeedbackSheet(context);
                      if (draft == null || !context.mounted) {
                        return;
                      }

                      try {
                        await ref
                            .read(templateGenerationRepositoryProvider)
                            .submitFeedback(
                              type: draft.type,
                              category: draft.category,
                              message: draft.message,
                              sourceScreen: 'settings',
                            );
                      } on AppException catch (error) {
                        if (!context.mounted) {
                          return;
                        }

                        PetMagicToast.show(
                          context,
                          message: mapProfileFeedbackMessage(
                            error.message,
                            text,
                          ),
                          tone: PetMagicToastTone.warning,
                        );
                        return;
                      } catch (_) {
                        if (!context.mounted) {
                          return;
                        }

                        PetMagicToast.show(
                          context,
                          message: mapProfileFeedbackMessage(
                            'profile.action_failed',
                            text,
                          ),
                          tone: PetMagicToastTone.warning,
                        );
                        return;
                      }

                      if (!context.mounted) {
                        return;
                      }

                      PetMagicToast.show(
                        context,
                        message: _settingsFeedbackCopy(context).thanks,
                        tone: PetMagicToastTone.success,
                      );
                    },
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
                      isLight
                          ? const Color(0xFFF7EEF0)
                          : const Color(0xFF151A29),
                      isLight
                          ? const Color(0xFFFDF7F8)
                          : const Color(0xFF1A2236),
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

class _SettingsFeedbackCopy {
  const _SettingsFeedbackCopy({
    required this.title,
    required this.subtitle,
    required this.sheetTitle,
    required this.messageLabel,
    required this.messageHint,
    required this.submit,
    required this.thanks,
    required this.options,
  });

  final String title;
  final String subtitle;
  final String sheetTitle;
  final String messageLabel;
  final String messageHint;
  final String submit;
  final String thanks;
  final List<(String, String, String)> options;
}

class _SettingsFeedbackDraft {
  const _SettingsFeedbackDraft({
    required this.type,
    required this.category,
    this.message,
  });

  final String type;
  final String category;
  final String? message;
}

_SettingsFeedbackCopy _settingsFeedbackCopy(BuildContext context) {
  final isRu = Localizations.localeOf(context).languageCode == 'ru';
  if (isRu) {
    return const _SettingsFeedbackCopy(
      title: 'Send feedback',
      subtitle: 'Идея, баг, оплата или общий комментарий',
      sheetTitle: 'Send feedback',
      messageLabel: 'Комментарий',
      messageHint: 'Текст optional',
      submit: 'Отправить',
      thanks: 'Спасибо за feedback',
      options: [
        ('General', 'general', 'Общее'),
        ('FeatureRequest', 'suggestion', 'Пожелание'),
        ('BugReport', 'bug', 'Баг'),
        ('PaymentIssue', 'payment', 'Оплата'),
      ],
    );
  }

  return const _SettingsFeedbackCopy(
    title: 'Send feedback',
    subtitle: 'Idea, bug, payment, or general comment',
    sheetTitle: 'Send feedback',
    messageLabel: 'Comment',
    messageHint: 'Optional',
    submit: 'Send',
    thanks: 'Thanks for the feedback',
    options: [
      ('General', 'general', 'General'),
      ('FeatureRequest', 'suggestion', 'Feature request'),
      ('BugReport', 'bug', 'Bug'),
      ('PaymentIssue', 'payment', 'Payment'),
    ],
  );
}

Future<_SettingsFeedbackDraft?> _showSettingsFeedbackSheet(
  BuildContext context,
) {
  final copy = _settingsFeedbackCopy(context);

  return showModalBottomSheet<_SettingsFeedbackDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _SettingsFeedbackSheet(copy: copy);
    },
  );
}

class _SettingsFeedbackSheet extends StatefulWidget {
  const _SettingsFeedbackSheet({required this.copy});

  final _SettingsFeedbackCopy copy;

  @override
  State<_SettingsFeedbackSheet> createState() => _SettingsFeedbackSheetState();
}

class _SettingsFeedbackSheetState extends State<_SettingsFeedbackSheet> {
  late (String, String, String) _selected = widget.copy.options.first;
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.copy;
    final colors = context.petMagicColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.backgroundBottom,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  copy.sheetTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in copy.options)
                      ChoiceChip(
                        selected: _selected == option,
                        label: Text(option.$3),
                        onSelected: (_) => setState(() => _selected = option),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _messageController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: copy.messageLabel,
                    hintText: copy.messageHint,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () {
                    final trimmedMessage = _messageController.text.trim();
                    Navigator.of(context).pop(
                      _SettingsFeedbackDraft(
                        type: _selected.$1,
                        category: _selected.$2,
                        message: trimmedMessage.isEmpty ? null : trimmedMessage,
                      ),
                    );
                  },
                  child: Text(copy.submit),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
