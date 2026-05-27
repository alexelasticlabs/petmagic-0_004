import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/support/presentation/support_home_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  static const routePath = '/profile';

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isOpeningSubscription = false;

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
    final subscriptionSummary = ref.watch(premiumSubscriptionSummaryProvider);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final bottomNavInset = petMagicScrollableBottomInset(context);

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
                        message: mapProfileFeedbackMessage(
                          state.errorMessage!,
                          text,
                        ),
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
                        walletBalance: walletState.wallet?.balance,
                      ),
                      const SizedBox(height: 12),
                      _WalletHighlightCard(
                        walletState: walletState,
                        onTap: () => context.go(WalletPage.routePath),
                      ),
                      const SizedBox(height: 12),
                      if (!profile.isPremium) ...[
                        _PremiumBannerCard(
                          onTap: () =>
                              _handlePremiumTap(subscriptionSummary.value),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (subscriptionSummary.value?.isPremium == true) ...[
                        _SubscriptionSummaryCard(
                          summary: subscriptionSummary.value!,
                          isOpening: _isOpeningSubscription,
                          onManageTap: () => _handleSubscriptionAction(
                            subscriptionSummary.value,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ProfileGlassCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            ProfileSettingsRow(
                              icon: Icons.privacy_tip_outlined,
                              title: text.profileLegalShortcutTitle,
                              subtitle: legalStatus,
                              iconColor: colors.accent,
                              onTap: () => context.push(
                                ProfileSettingsDetailPage.location(
                                  ProfileSettingsDetailKind.terms,
                                ),
                              ),
                            ),
                            ProfileSettingsRow(
                              icon: Icons.support_agent_rounded,
                              title: text.profileSupportTitle,
                              subtitle: text.profileSupportCompactSubtitle,
                              iconColor: colors.blue,
                              onTap: () =>
                                  context.push(SupportHomePage.routePath),
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

  Future<void> _handlePremiumTap(
    PremiumSubscriptionSummaryView? summary,
  ) async {
    if (summary?.canManageSubscription == true) {
      await _handleSubscriptionAction(summary);
      return;
    }

    if (mounted) {
      context.push(PremiumPage.routePath);
    }
  }

  Future<void> _handleSubscriptionAction(
    PremiumSubscriptionSummaryView? summary,
  ) async {
    if (summary == null || !summary.canManageSubscription) {
      if (mounted) {
        context.push(PremiumPage.routePath);
      }

      return;
    }

    setState(() => _isOpeningSubscription = true);

    try {
      final managementService = ref.read(
        premiumSubscriptionManagementServiceProvider,
      );
      final url = await managementService.createManagementUrl(
        summary.manageSubscriptionAction,
      );
      final uri = Uri.tryParse(url);
      if (uri == null) {
        return;
      }

      final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningSubscription = false);
      }
    }
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.profile, required this.walletBalance});

  final MobileUserProfile profile;
  final int? walletBalance;

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
    final balanceLabel = walletBalance == null
        ? text.profileWalletLoadingHint
        : '${_formatProfileNumber(context, walletBalance!)} PawSpark';

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
  const _PremiumBannerCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.gold.withValues(alpha: 0.28)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.gold.withValues(alpha: 0.18),
                const Color(0xFF8A5A12).withValues(alpha: 0.22),
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
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: colors.gold.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: colors.gold,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.profilePremiumBannerTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        text.profilePremiumSubtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 12.2,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.gold,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: colors.gold.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          text.profilePremiumOpenAction,
                          style: TextStyle(
                            color: colors.backgroundBottom,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: colors.backgroundBottom,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubscriptionSummaryCard extends StatelessWidget {
  const _SubscriptionSummaryCard({
    required this.summary,
    required this.isOpening,
    required this.onManageTap,
  });

  final PremiumSubscriptionSummaryView summary;
  final bool isOpening;
  final VoidCallback onManageTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final format = DateFormat.yMMMd(locale);
    final providerLabel = switch (summary.provider) {
      PremiumSubscriptionProviderView.appStore => text.premiumPaymentApple,
      PremiumSubscriptionProviderView.googlePlay =>
        text.premiumPaymentGooglePlay,
      PremiumSubscriptionProviderView.stripe => text.premiumPaymentStripe,
      PremiumSubscriptionProviderView.unknown => text.premiumPaymentStripe,
    };
    final subtitle = summary.planName?.trim().isNotEmpty == true
        ? summary.planName!
        : providerLabel;
    final nextBillingValue = summary.currentPeriodEndUtc == null
        ? null
        : format.format(summary.currentPeriodEndUtc!.toLocal());

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.gold.withValues(alpha: 0.22)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.gold.withValues(alpha: 0.12),
            colors.surfaceGlass,
            colors.surfaceStrong.withValues(alpha: 0.52),
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: colors.gold.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: colors.gold,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.profileSubscriptionTitle,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 12.2,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _CompactPremiumAction(
                  label: text.premiumManageAction,
                  onTap: isOpening ? null : onManageTap,
                  isLoading: isOpening,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ProfileStatusPill(
                  label: summary.status,
                  leading: Icons.verified_rounded,
                  backgroundColor: colors.gold.withValues(alpha: 0.16),
                  foregroundColor: colors.gold,
                ),
                ProfileStatusPill(
                  label: providerLabel,
                  leading: Icons.credit_card_rounded,
                  backgroundColor: colors.surfaceStrong.withValues(alpha: 0.58),
                  foregroundColor: colors.textStrong,
                ),
              ],
            ),
            if (nextBillingValue != null) ...[
              const SizedBox(height: 12),
              _SubscriptionMetaTile(
                label: text.profileSubscriptionNextBillingLabel,
                value: nextBillingValue,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubscriptionMetaTile extends StatelessWidget {
  const _SubscriptionMetaTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactPremiumAction extends StatelessWidget {
  const _CompactPremiumAction({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.gold,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: colors.gold.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator.adaptive(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.backgroundBottom,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.open_in_new_rounded,
                    color: colors.backgroundBottom,
                    size: 14,
                  ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: colors.backgroundBottom,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
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
