import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';

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
      ref.read(walletControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final walletState = ref.watch(walletControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final bottomNavInset = petMagicBottomNavInset(context);

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
    final legalStatus = profile?.legalAcceptance.isCurrentAccepted == true
        ? text.profileLegalShortcutAccepted
        : text.profileLegalShortcutPending;

    return ProfileScreenBackground(
      child: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : RefreshIndicator.adaptive(
                onRefresh: controller.initialize,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, bottomNavInset),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                text.profileTitle,
                                style: TextStyle(
                                  color: colors.textStrong,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
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
                        wallet: walletState.wallet,
                      ),
                      const SizedBox(height: 12),
                      _WalletHighlightCard(
                        walletState: walletState,
                        onTap: () => context.go(WalletPage.routePath),
                      ),
                      const SizedBox(height: 12),
                      _PremiumBannerCard(
                        isPremium: profile.isPremium,
                        onTap: () => context.push(PremiumPage.routePath),
                      ),
                      const SizedBox(height: 12),
                      _ProfileStatsCard(
                        profile: profile,
                        wallet: walletState.wallet,
                      ),
                      const SizedBox(height: 12),
                      const _ProfileMagicMomentCard(),
                      const SizedBox(height: 12),
                      ProfileGlassCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            ProfileSettingsRow(
                              icon: Icons.privacy_tip_outlined,
                              title: text.profileLegalShortcutTitle,
                              subtitle: legalStatus,
                              iconColor: colors.accent,
                              onTap: () =>
                                  context.push(ProfileSettingsPage.routePath),
                            ),
                            ProfileSettingsRow(
                              icon: Icons.support_agent_rounded,
                              title: text.profileSupportTitle,
                              subtitle: text.profileSupportCompactSubtitle,
                              iconColor: colors.blue,
                              onTap: () =>
                                  context.push(SupportChatPage.routePath),
                            ),
                            ProfileSettingsRow(
                              icon: Icons.settings_outlined,
                              title: text.profileSettingsShortcutTitle,
                              subtitle: text.profileSettingsCompactSubtitle,
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
  const _ProfileHeroCard({required this.profile, required this.wallet});

  final MobileUserProfile profile;
  final WalletStateModel? wallet;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final displayName = profile.displayName?.trim().isNotEmpty == true
        ? profile.displayName!
        : profile.email;
    final membershipLabel = profile.isPremium
        ? text.profilePremiumPlanLabel
        : text.profileFreePlanLabel;
    final emailLabel = profile.emailConfirmed
        ? text.profileEmailVerifiedShort
        : text.profileEmailPendingShort;
    final balanceLabel = wallet == null
        ? text.profileWalletLoadingHint
        : '${_formatProfileNumber(context, wallet!.balance)} PawSpark';

    return ProfileGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProfileAvatarBadge(
                imageUrl: profile.avatar?.url,
                fallbackLabel: displayName,
                size: 72,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ProfileStatusPill(
                          label: membershipLabel,
                          leading: profile.isPremium
                              ? Icons.workspace_premium_rounded
                              : Icons.pets_rounded,
                          backgroundColor:
                              (profile.isPremium ? colors.gold : colors.accent)
                                  .withValues(alpha: 0.14),
                          foregroundColor: profile.isPremium
                              ? colors.gold
                              : colors.accent,
                        ),
                        ProfileStatusPill(
                          label: emailLabel,
                          leading: profile.emailConfirmed
                              ? Icons.verified_rounded
                              : Icons.mark_email_unread_outlined,
                          backgroundColor:
                              (profile.emailConfirmed
                                      ? colors.blue
                                      : colors.textMuted)
                                  .withValues(alpha: 0.14),
                          foregroundColor: profile.emailConfirmed
                              ? colors.blue
                              : colors.textSoft,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            profile.email,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceStrong.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border.withValues(alpha: 0.8)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: colors.accent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    balanceLabel,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletHighlightCard extends StatelessWidget {
  const _WalletHighlightCard({required this.walletState, required this.onTap});

  final WalletState walletState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final wallet = walletState.wallet;
    final weeklyReady =
        wallet?.nextWeeklyGrantAtUtc == null ||
        wallet!.nextWeeklyGrantAtUtc!.isBefore(DateTime.now().toUtc());
    final balanceText = wallet == null
        ? (walletState.isLoading
              ? text.profileWalletLoadingHint
              : text.profileWalletEmptyHint)
        : '${_formatProfileNumber(context, wallet.balance)} PawSpark';
    final rewardLabel = wallet == null
        ? text.profileWalletPreviewLoadingStatus
        : weeklyReady
        ? text.profileWalletPreviewWeeklyReady
        : text.profileWalletPreviewAdCount(wallet.adRewardsRemainingToday);
    final rewardColor = wallet == null
        ? colors.textMuted
        : weeklyReady
        ? colors.gold
        : colors.accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.accent.withValues(alpha: 0.26),
                colors.blue.withValues(alpha: 0.2),
                colors.surfaceGlass,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 24,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.backgroundBottom.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: colors.textStrong,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.profileWalletPreviewEyebrow,
                            style: TextStyle(
                              color: colors.textSoft,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text.profileWalletTitle,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: colors.textMuted,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  balanceText,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 24,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text.profileWalletPreviewSubtitle,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ProfileStatusPill(
                      label: rewardLabel,
                      leading: wallet == null
                          ? Icons.sync_rounded
                          : weeklyReady
                          ? Icons.card_giftcard_rounded
                          : Icons.play_circle_outline_rounded,
                      backgroundColor: rewardColor.withValues(alpha: 0.14),
                      foregroundColor: rewardColor,
                    ),
                    _ProfileActionChip(label: text.profileWalletPreviewAction),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumBannerCard extends StatelessWidget {
  const _PremiumBannerCard({required this.isPremium, required this.onTap});

  final bool isPremium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final title = isPremium
        ? text.profilePremiumBannerActiveTitle
        : text.profilePremiumBannerTitle;
    final actionLabel = isPremium
        ? text.premiumManageAction
        : text.profilePremiumOpenAction;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.gold.withValues(alpha: 0.28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.gold.withValues(alpha: 0.24),
            const Color(0xFF8A5A12).withValues(alpha: 0.28),
            colors.surfaceGlass,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: colors.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _BenefitPill(
                  label: text.profilePremiumBenefitUnlimitedTemplates,
                ),
                _BenefitPill(
                  label: text.profilePremiumBenefitPriorityGeneration,
                ),
                _BenefitPill(label: text.profilePremiumBenefitNoWatermark),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.gold,
                  foregroundColor: colors.backgroundBottom,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStatsCard extends StatelessWidget {
  const _ProfileStatsCard({required this.profile, required this.wallet});

  final MobileUserProfile profile;
  final WalletStateModel? wallet;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final stats = [
      _ProfileStatItem(
        icon: Icons.savings_outlined,
        value: wallet == null
            ? '...'
            : _formatProfileNumber(context, wallet!.balance),
        label: text.profileStatBalanceLabel,
        highlight: colors.accent,
      ),
      _ProfileStatItem(
        icon: Icons.workspace_premium_outlined,
        value: profile.isPremium ? text.premiumLabel : text.freeLabel,
        label: text.profileStatPlanLabel,
        highlight: profile.isPremium ? colors.gold : colors.accent,
      ),
      _ProfileStatItem(
        icon: profile.emailConfirmed
            ? Icons.verified_rounded
            : Icons.mark_email_unread_outlined,
        value: profile.emailConfirmed
            ? text.profileStatReady
            : text.profileStatPending,
        label: text.profileEmailStat,
        highlight: profile.emailConfirmed ? colors.blue : colors.gold,
      ),
      _ProfileStatItem(
        icon: Icons.privacy_tip_outlined,
        value: profile.legalAcceptance.isCurrentAccepted
            ? text.profileStatReady
            : text.profileStatPending,
        label: text.profileStatLegalLabel,
        highlight: profile.legalAcceptance.isCurrentAccepted
            ? colors.accent
            : colors.gold,
      ),
    ];

    return ProfileGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileSectionLabel(label: text.profileStatsSectionTitle),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 10.0;
              final tileWidth = (constraints.maxWidth - spacing) / 2;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final stat in stats)
                    SizedBox(
                      width: tileWidth,
                      child: _ProfileStatPanel(stat: stat),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileStatItem {
  const _ProfileStatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.highlight,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color highlight;
}

class _ProfileStatPanel extends StatelessWidget {
  const _ProfileStatPanel({required this.stat});

  final _ProfileStatItem stat;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colors.surfaceStrong.withValues(alpha: 0.7),
        border: Border.all(color: colors.border.withValues(alpha: 0.85)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: stat.highlight.withValues(alpha: 0.16),
              ),
              child: Icon(stat.icon, color: stat.highlight, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              stat.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stat.label,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 11.8,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMagicMomentCard extends StatelessWidget {
  const _ProfileMagicMomentCard();

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileGlassCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.pets_rounded, color: colors.accent, size: 22),
                Positioned(
                  top: 10,
                  right: 9,
                  child: Icon(Icons.star_rounded, color: colors.gold, size: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.profileMagicMomentTitle,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text.profileMagicMomentSubtitle,
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
    );
  }
}

class _BenefitPill extends StatelessWidget {
  const _BenefitPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.backgroundBottom.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ProfileActionChip extends StatelessWidget {
  const _ProfileActionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.accent.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colors.accent,
                fontSize: 11.8,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.arrow_forward_rounded, color: colors.accent, size: 14),
          ],
        ),
      ),
    );
  }
}

class _HeaderActionIcon extends StatelessWidget {
  const _HeaderActionIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

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
          child: Center(child: Icon(icon, color: colors.textStrong, size: 26)),
        ),
      ),
    );
  }
}

String _formatProfileNumber(BuildContext context, int value) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return NumberFormat.decimalPattern(locale).format(value);
}
