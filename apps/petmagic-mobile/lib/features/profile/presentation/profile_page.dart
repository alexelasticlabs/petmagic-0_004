import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/pets/presentation/my_pets_page.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/premium/presentation/subscription_management_page.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/features/gamification/presentation/gamification_providers.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/gamification_summary_card.dart';
import 'package:petmagic_mobile/features/gamification/presentation/achievements_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/motion_entrance.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:petmagic_mobile/shared/widgets/premium_shimmer_button.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';

const _profilePremiumDogAsset = 'assets/rewards/profile-premium-dog.png';
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  static const routePath = '/profile';

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with WidgetsBindingObserver {
  bool _isOpeningSubscription = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (!mounted) {
        return;
      }

      ref.invalidate(premiumSubscriptionSummaryProvider);
      ref.read(profileControllerProvider.notifier).initialize();
      ref.read(walletControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    final profileState = ref.read(profileControllerProvider);
    final hasInternet = ref.read(networkStatusControllerProvider).hasInternet;
    final unavailableKind =
        !profileState.isLoading && profileState.profile == null
        ? classifyAppUnavailable(
            raw: profileState.errorMessage,
            hasInternet: hasInternet,
          )
        : null;
    if (unavailableKind == null) {
      return;
    }

    unawaited(ref.read(profileControllerProvider.notifier).initialize());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      profileControllerProvider.select(
        (state) => (
          isLoading: state.isLoading,
          isAuthenticated: state.isAuthenticated,
          isSaving: state.isSaving,
          profile: state.profile,
        ),
      ),
    );
    final wallet = ref.watch(
      walletControllerProvider.select((walletState) => walletState.wallet),
    );
    final walletIsLoading = ref.watch(
      walletControllerProvider.select((walletState) => walletState.isLoading),
    );
    final controller = ref.read(profileControllerProvider.notifier);
    final subscriptionSummary = ref.watch(
      premiumSubscriptionSummaryProvider.select((summary) => summary.value),
    );
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final bottomNavInset = petMagicScrollableBottomInset(context);
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final unavailableKind = !state.isLoading && state.profile == null
        ? classifyAppUnavailable(
            raw: ref.watch(
              profileControllerProvider.select((state) => state.errorMessage),
            ),
            hasInternet: hasInternet,
          )
        : null;

    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.hasInternet != false || !next.hasInternet) {
        return;
      }

      final profileState = ref.read(profileControllerProvider);
      final currentUnavailableKind =
          !profileState.isLoading && profileState.profile == null
          ? classifyAppUnavailable(
              raw: profileState.errorMessage,
              hasInternet: next.hasInternet,
            )
          : null;
      if (currentUnavailableKind == null) {
        return;
      }

      unawaited(controller.initialize());
    });

    if (!state.isLoading && !state.isAuthenticated && unavailableKind == null) {
      return ProfileScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomNavInset),
            child: ProtectedAuthGate(
              subtitle: text.authRequiredMessage,
              onSignIn: () => showAuthRequiredSheet(
                context,
                redirectPath: ProfilePage.routePath,
              ),
            ),
          ),
        ),
      );
    }

    if (unavailableKind != null) {
      return ProfileScreenBackground(
        child: SafeArea(
          child: PetMagicUnavailableView(
            kind: unavailableKind,
            onRetry: () => unawaited(controller.initialize()),
            padding: EdgeInsets.fromLTRB(28, 36, 28, bottomNavInset),
          ),
        ),
      );
    }

    final profile = state.profile;
    final summaryPremium = subscriptionSummary?.isPremium;
    final shouldShowSubscriptionCard = summaryPremium == true;
    final shouldShowPremiumCta =
        summaryPremium == false ||
        (summaryPremium == null && profile?.isPremium != true);
    final legalStatus = profile?.legalAcceptance.isCurrentAccepted == true
        ? text.profileLegalShortcutAccepted
        : text.profileLegalShortcutPending;

    ref.listen(profileControllerProvider, (previous, next) {
      if (!mounted) {
        return;
      }

      final previousError = previous?.errorMessage;
      if (next.errorMessage != null && next.errorMessage != previousError) {
        PetMagicToast.show(
          context,
          message: mapProfileFeedbackMessage(next.errorMessage!, text),
          tone: PetMagicToastTone.warning,
        );
      }

      final previousSuccess = previous?.successMessage;
      if (next.successMessage != null &&
          next.successMessage != previousSuccess) {
        final message = next.successMessage == 'logout'
            ? text.profileSignedOut
            : mapProfileFeedbackMessage(next.successMessage!, text);
        PetMagicToast.show(
          context,
          message: message,
          tone: PetMagicToastTone.success,
        );
      }
    });

    return ProfileScreenBackground(
      child: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : RefreshIndicator.adaptive(
                onRefresh: () async {
                  ref.invalidate(premiumSubscriptionSummaryProvider);
                  await controller.initialize();
                },
                child: ListView(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, bottomNavInset),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    MotionEntrance(
                      delay: const Duration(milliseconds: 20),
                      child: Row(
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
                    ),
                    const SizedBox(height: 18),
                    if (profile != null) ...[
                      MotionEntrance(
                        delay: const Duration(milliseconds: 100),
                        child: _ProfileHeroCard(profile: profile),
                      ),
                      const SizedBox(height: 12),
                      MotionEntrance(
                        delay: const Duration(milliseconds: 150),
                        child: _WalletHighlightCard(
                          wallet: wallet,
                          isWalletLoading: walletIsLoading,
                          onTap: () => context.push(WalletPage.routePath),
                        ),
                      ),
                      const SizedBox(height: 12),
                      MotionEntrance(
                        delay: const Duration(milliseconds: 170),
                        child: _GamificationHighlightsWrapper(),
                      ),
                      const SizedBox(height: 12),
                      if (shouldShowPremiumCta) ...[
                        MotionEntrance(
                          delay: const Duration(milliseconds: 200),
                          child: _PremiumBannerCard(
                            onTap: () => _handlePremiumTap(subscriptionSummary),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (shouldShowSubscriptionCard) ...[
                        MotionEntrance(
                          delay: const Duration(milliseconds: 240),
                          child: _SubscriptionSummaryCard(
                            summary: subscriptionSummary!,
                            isOpening: _isOpeningSubscription,
                            onManageTap: () =>
                                _handleSubscriptionAction(subscriptionSummary),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      MotionEntrance(
                        delay: const Duration(milliseconds: 280),
                        child: ProfileGlassCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              ProfileSettingsRow(
                                icon: Icons.pets_rounded,
                                title: text.profilePetsTitle,
                                subtitle: text.profilePetsSubtitle,
                                iconColor: colors.accent,
                                onTap: () => context.push(MyPetsPage.routePath),
                              ),
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
                      ),
                      const SizedBox(height: 16),
                      MotionEntrance(
                        delay: const Duration(milliseconds: 320),
                        child: OutlinedButton.icon(
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
    if (_isOpeningSubscription) {
      return;
    }

    if (summary == null || !summary.canManageSubscription) {
      if (mounted) {
        context.push(PremiumPage.routePath);
      }

      return;
    }

    setState(() => _isOpeningSubscription = true);
    await context.push(SubscriptionManagementPage.routePath);
    if (!mounted) {
      return;
    }

    ref.invalidate(premiumSubscriptionSummaryProvider);
    await ref.read(profileControllerProvider.notifier).initialize();
    if (mounted) {
      setState(() => _isOpeningSubscription = false);
    }
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.profile});

  final MobileUserProfile profile;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final displayName = profile.displayName?.trim().isNotEmpty == true
        ? profile.displayName!
        : profile.email;
    final membershipLabel = profile.isPremium
        ? text.profilePremiumPlanLabel
        : text.profileFreePlanLabel;
    final emailLabel = profile.emailConfirmed
        ? text.profileEmailVerifiedShort
        : text.profileEmailPendingShort;

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
                              ? null
                              : Icons.pets_rounded,
                          leadingWidget: profile.isPremium
                              ? const PremiumCrownIcon(size: 14)
                              : null,
                          backgroundColor:
                              (profile.isPremium ? colors.gold : colors.accent)
                                  .withValues(alpha: isLight ? 0.26 : 0.2),
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
                                  .withValues(alpha: isLight ? 0.26 : 0.2),
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
        ],
      ),
    );
  }
}

class _WalletHighlightCard extends StatelessWidget {
  const _WalletHighlightCard({
    required this.wallet,
    required this.isWalletLoading,
    required this.onTap,
  });

  final WalletStateModel? wallet;
  final bool isWalletLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final walletValue = wallet;
    final nextWeeklyGrantAtUtc = walletValue?.nextWeeklyGrantAtUtc;
    final weeklyReady =
        nextWeeklyGrantAtUtc == null ||
        nextWeeklyGrantAtUtc.isBefore(DateTime.now().toUtc());
    final balanceText = walletValue == null
        ? (isWalletLoading
              ? text.profileWalletLoadingHint
              : text.profileWalletEmptyHint)
        : '${_formatProfileNumber(context, walletValue.balance)} PawSpark';
    final rewardLabel = walletValue == null
        ? text.profileWalletPreviewLoadingStatus
        : weeklyReady
        ? text.profileWalletPreviewWeeklyReady
        : text.profileWalletPreviewAdCount(walletValue.adRewardsRemainingToday);
    const cardAccent = Color(0xFF00F2A6);
    final rewardColor = walletValue == null
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
          child: PetMagicAccentCard(
            accentColor: cardAccent,
            borderOpacity: isLight ? 0.2 : 0.28,
            glowOpacity: isLight ? 0.1 : 0.15,
            glowAlignment: const Alignment(-0.94, -0.16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(
                          alpha: isLight ? 0.04 : 0.16,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cardAccent.withValues(alpha: 0.24),
                        ),
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
                              color: colors.textSoft.withValues(alpha: 0.78),
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
                      color: colors.textSoft,
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
                    color: colors.textSoft.withValues(alpha: 0.82),
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = context.petMagicColors;
    const accent = Color(0xFFFFC107);

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            child: PetMagicAccentCard(
              accentColor: accent,
              borderRadius: BorderRadius.circular(20),
              padding: EdgeInsets.zero,
              borderOpacity: isLight ? 0.2 : 0.28,
              glowOpacity: isLight ? 0.1 : 0.15,
              glowAlignment: const Alignment(-0.92, -0.9),
              child: SizedBox(
                height: 168,
                child: Stack(
                  children: [
                    Positioned(
                      top: 14,
                      left: 16,
                      child: IgnorePointer(
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                accent.withValues(alpha: isLight ? 0.12 : 0.18),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: isLight ? 0.82 : 0.94,
                          child: Image.asset(
                            _profilePremiumDogAsset,
                            height: 136,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 140, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.24),
                              ),
                              color: accent.withValues(
                                alpha: isLight ? 0.1 : 0.14,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const PremiumCrownIcon(size: 12),
                                const SizedBox(width: 5),
                                Text(
                                  text.premiumLabel,
                                  style: const TextStyle(
                                    color: Color(0xFFFFD666),
                                    fontSize: 10.4,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            text.premiumUpsellHeadline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            text.premiumUpsellSubtitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSoft.withValues(alpha: 0.86),
                              fontSize: 11.2,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          PremiumShimmerButton(
                            label: text.profilePremiumOpenAction,
                            onTap: onTap,
                            height: 42,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                  child: const PremiumCrownIcon(size: 21),
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

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 126),
      child: Material(
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.backgroundBottom,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final chipBg = isLight
        ? const Color(0xFFDCF6EA)
        : colors.accent.withValues(alpha: 0.12);
    final chipBorder = isLight
        ? const Color(0xFF8FD6B8)
        : colors.accent.withValues(alpha: 0.24);
    final chipText = isLight ? const Color(0xFF0A7A4D) : colors.accent;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: chipText,
                fontSize: 11.8,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.arrow_forward_rounded, color: chipText, size: 14),
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

class _GamificationHighlightsWrapper extends ConsumerWidget {
  const _GamificationHighlightsWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(gamificationSummaryProvider);
    final achievementsAsync = ref.watch(achievementsProvider);
    final achievements = achievementsAsync.asData?.value;

    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) => GamificationHighlightsCard(
        summary: summary,
        unlockedAchievementsCount: achievements
            ?.where((achievement) => achievement.isUnlocked)
            .length,
        totalAchievementsCount: achievements?.length,
        onStreakTap: () => context.push(AchievementsPage.routePath),
        onAchievementsTap: () => context.push(AchievementsPage.routePath),
        onPetTap: () => context.push(MyPetsPage.routePath),
      ),
    );
  }
}
