import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  static const routePath = '/profile';

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) {
        return;
      }

      ref.read(profileControllerProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    if (!state.isLoading && !state.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go(AuthEntryPage.routePath);
        }
      });

      return const SizedBox.expand(
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final profile = state.profile;

    return ProfileScreenBackground(
      child: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : RefreshIndicator.adaptive(
                onRefresh: controller.initialize,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 104),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                text.profileTitle,
                                style: TextStyle(
                                  color: colors.textStrong,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                text.profileDashboardSubtitle,
                                style: TextStyle(
                                  color: colors.textSoft,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _HeaderActionIcon(
                          icon: Icons.notifications_none_rounded,
                          badgeColor: colors.accent,
                        ),
                        const SizedBox(width: 10),
                        _HeaderActionIcon(
                          icon: Icons.settings_outlined,
                          onTap: () =>
                              context.push(ProfileSettingsPage.routePath),
                        ),
                      ],
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 18),
                      ProfileMessageCard(
                        message: state.errorMessage!,
                        tone: colors.danger,
                      ),
                    ],
                    if (state.successMessage == 'logout') ...[
                      const SizedBox(height: 18),
                      ProfileMessageCard(
                        message: text.profileSignedOut,
                        tone: colors.accent,
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (profile != null) ...[
                      _ProfileHeroCard(
                        profile: profile,
                        isSaving: state.isSaving,
                        onUploadAvatar: state.isSaving
                            ? null
                            : controller.uploadAvatar,
                        onOpenSettings: () =>
                            context.push(ProfileSettingsPage.routePath),
                      ),
                      const SizedBox(height: 16),
                      _ProfilePetsRow(onTap: () {}),
                      const SizedBox(height: 16),
                      ProfileGlassCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            ProfileSettingsRow(
                              icon: Icons.workspace_premium_outlined,
                              title: text.profilePremiumTitle,
                              subtitle: text.profilePremiumSubtitle,
                              iconColor: colors.gold,
                            ),
                            ProfileSettingsRow(
                              icon: Icons.mail_outline_rounded,
                              title: text.profileCommunicationsTitle,
                              subtitle: profile.marketingEmailsEnabled
                                  ? text.profileCommunicationsEnabled
                                  : text.profileCommunicationsDisabled,
                              trailingText: profile.marketingEmailsEnabled
                                  ? text.profilePreferenceEnabled
                                  : text.profilePreferenceOff,
                            ),
                            ProfileSettingsRow(
                              icon: Icons.privacy_tip_outlined,
                              title: text.profilePrivacyTitle,
                              subtitle: profile.termsOfUseAccepted
                                  ? text.profileTermsAccepted
                                  : text.profileTermsPending,
                              trailingText: profile.termsOfUseAccepted
                                  ? text.profilePreferenceEnabled
                                  : text.profilePreferenceOff,
                            ),
                            ProfileSettingsRow(
                              icon: Icons.support_agent_rounded,
                              title: text.profileSupportTitle,
                              subtitle: text.profileSupportSubtitle,
                              iconColor: colors.blue,
                              onTap: () => context.push(SupportChatPage.routePath),
                            ),
                            ProfileSettingsRow(
                              icon: Icons.settings_outlined,
                              title: text.profileSettingsShortcutTitle,
                              subtitle: text.profileSettingsShortcutSubtitle,
                              showDivider: false,
                              onTap: () =>
                                  context.push(ProfileSettingsPage.routePath),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: state.isSaving ? null : controller.logout,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: colors.danger,
                          side: BorderSide(
                            color: colors.danger.withValues(alpha: 0.3),
                          ),
                          backgroundColor: colors.danger.withValues(
                            alpha: 0.08,
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded),
                        label: Text(text.profileSignOutAction),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.profile,
    required this.isSaving,
    required this.onUploadAvatar,
    required this.onOpenSettings,
  });

  final MobileUserProfile profile;
  final bool isSaving;
  final VoidCallback? onUploadAvatar;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final displayName = profile.displayName?.trim().isNotEmpty == true
        ? profile.displayName!
        : profile.email;

    return ProfileGlassCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileAvatarBadge(
                imageUrl: profile.avatar?.url,
                fallbackLabel: displayName,
                size: 80,
                bottomBadge: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onUploadAvatar,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.backgroundBottom,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isSaving
                            ? Icons.hourglass_top_rounded
                            : Icons.camera_alt_rounded,
                        color: colors.backgroundBottom,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onOpenSettings,
                          icon: Icon(
                            Icons.edit_rounded,
                            color: colors.accent,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.email,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 13,
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
                          leading: profile.isPremium
                              ? Icons.workspace_premium_rounded
                              : Icons.favorite_outline_rounded,
                          backgroundColor: profile.isPremium
                              ? colors.gold.withValues(alpha: 0.18)
                              : colors.accentSoft,
                          foregroundColor: profile.isPremium
                              ? colors.gold
                              : colors.accent,
                        ),
                        ProfileStatusPill(
                          label: profile.emailConfirmed
                              ? text.profileEmailConfirmed
                              : text.profileEmailPending,
                          leading: profile.emailConfirmed
                              ? Icons.verified_rounded
                              : Icons.mark_email_unread_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surfaceStrong.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.border.withValues(alpha: 0.75)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent.withValues(alpha: 0.14),
                  ),
                  child: Icon(
                    Icons.tips_and_updates_outlined,
                    color: colors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.profileAccountCenterTitle,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        text.profileAccountCenterSubtitle,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textMuted,
                  size: 24,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePetsRow extends StatelessWidget {
  const _ProfilePetsRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileGlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent.withValues(alpha: 0.14),
                ),
                child: Icon(Icons.pets_rounded, color: colors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.profilePetsTitle,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text.profilePetsSubtitle,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ...List.generate(
                3,
                (index) => Transform.translate(
                  offset: Offset(index == 0 ? 0 : -10.0 * index, 0),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surfaceStrong,
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(
                      [
                        Icons.pets_rounded,
                        Icons.cruelty_free_outlined,
                        Icons.favorite_rounded,
                      ][index],
                      color: [colors.accent, colors.gold, colors.blue][index],
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textMuted,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderActionIcon extends StatelessWidget {
  const _HeaderActionIcon({required this.icon, this.onTap, this.badgeColor});

  final IconData icon;
  final VoidCallback? onTap;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(child: Icon(icon, color: colors.textStrong, size: 26)),
              if (badgeColor != null)
                Positioned(
                  top: 8,
                  right: 4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
