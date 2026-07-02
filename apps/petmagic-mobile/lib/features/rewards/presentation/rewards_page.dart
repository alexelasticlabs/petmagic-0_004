import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/legal_acceptance_gate_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/rewards/presentation/mappers/rewards_error_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:petmagic_mobile/shared/widgets/premium_banner_style.dart';
import 'package:petmagic_mobile/shared/widgets/premium_shimmer_button.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_haptics.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:share_plus/share_plus.dart';

part 'rewards_page_referral_cards.dart';
part 'rewards_page_referral_share.part.dart';
part 'rewards_page_friend_code_card.part.dart';
part 'rewards_page_premium_upsell.part.dart';
part 'rewards_page_shared_widgets.dart';
part 'rewards_page_shell_widgets.dart';
part 'rewards_page_support.part.dart';

class RewardsPage extends ConsumerStatefulWidget {
  const RewardsPage({super.key});

  static const routePath = '/rewards';

  @override
  ConsumerState<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends ConsumerState<RewardsPage>
    with WidgetsBindingObserver {
  Future<void> _showReferralHowItWorksSheet(int bonusSpark) =>
      _showRewardsReferralHowItWorksSheet(context, bonusSpark);

  Future<void> _showHistorySheet(List<WalletLedgerItem> items) =>
      _showRewardsHistorySheet(context, items);
  ProviderSubscription<AppLaunchState>? _launchSubscription;
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _launchSubscription = ref.listenManual<AppLaunchState>(
      appLaunchControllerProvider,
      (_, next) => _handleLaunchState(next),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _launchSubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleLaunchState(AppLaunchState launchState) {
    if (launchState.isAuthenticated && !_wasAuthenticated) {
      _wasAuthenticated = true;
      _scheduleInitialLoadIfNeeded();
      return;
    }

    _wasAuthenticated = launchState.isAuthenticated;
  }

  bool _hasHydratedRewardsSnapshot(WalletState state) {
    return state.hasCompletedFullLoad &&
        state.wallet != null &&
        state.rewards != null;
  }

  void _scheduleInitialLoadIfNeeded() {
    final snapshot = ref.read(walletControllerProvider);
    if (_hasHydratedRewardsSnapshot(snapshot)) {
      return;
    }

    Future.microtask(() {
      if (!mounted) {
        return;
      }
      if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
        return;
      }

      final current = ref.read(walletControllerProvider);
      if (_hasHydratedRewardsSnapshot(current)) {
        return;
      }

      ref.read(walletControllerProvider.notifier).load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !ref.read(appLaunchControllerProvider).isAuthenticated) {
      return;
    }

    final walletState = ref.read(walletControllerProvider);
    final hasInternet = ref.read(networkStatusControllerProvider).hasInternet;
    if (!hasInternet) {
      return;
    }

    final unavailableKind =
        walletState.wallet == null && !walletState.isInitialLoading
        ? classifyAppUnavailable(
            raw: walletState.errorMessage,
            hasInternet: hasInternet,
          )
        : null;
    if (unavailableKind == null) {
      return;
    }

    unawaited(ref.read(walletControllerProvider.notifier).load(refresh: true));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletControllerProvider);
    final controller = ref.read(walletControllerProvider.notifier);
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select((launch) => launch.isAuthenticated),
    );
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final hasShell =
        context.findAncestorWidgetOfExactType<PetMagicShell>() != null;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomNavInset = hasShell
        ? petMagicScrollableBottomInset(context)
        : MediaQuery.viewPaddingOf(context).bottom +
              kPetMagicBottomContentInsetCompact;
    final rewards = state.rewards;
    final isPremiumUser = state.wallet?.isPremium == true;
    final unavailableKind = state.wallet == null && !state.isInitialLoading
        ? classifyAppUnavailable(
            raw: state.errorMessage,
            hasInternet: hasInternet,
          )
        : null;
    final rewardsSummary = rewards == null
        ? null
        : _RewardsSummaryView(
            referralCode: rewards.referralCode,
            referralBonusSpark: rewards.referralBonusSpark,
            referralStatus: rewards.referralStatus,
            referrerCode: rewards.referrerCode,
            totalReferralBonusEarned: rewards.totalReferralBonusEarned,
            referredUsersCount: rewards.referredUsersCount,
            pendingReferredUsersCount: rewards.pendingReferredUsersCount,
            rewardedReferredUsersCount: rewards.rewardedReferredUsersCount,
          );
    final warningMessage = rewardsWarningMessage(text, state.errorMessage);
    final legalAcceptanceRequired = isLegalAcceptanceRequiredError(
      state.errorMessage,
    );

    if (!isAuthenticated) {
      return _RewardsBackdrop(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomNavInset + keyboardInset),
            child: ProtectedAuthGate(
              subtitle: text.authRequiredMessage,
              onSignIn: () => showAuthRequiredSheet(
                context,
                redirectPath: RewardsPage.routePath,
              ),
            ),
          ),
        ),
      );
    }

    if (state.wallet == null &&
        !state.isInitialLoading &&
        legalAcceptanceRequired) {
      return _RewardsBackdrop(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              bottomNavInset + keyboardInset,
            ),
            child: _RewardsLegalGateCard(
              message:
                  mapCommonAuthFeedbackMessage(
                    text,
                    state.errorMessage,
                    preferAuthRequiredMessage: true,
                  ) ??
                  text.profileLegalAcceptanceRequired,
              onOpenLegalGate: () =>
                  context.go(LegalAcceptanceGatePage.routePath),
            ),
          ),
        ),
      );
    }

    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.hasInternet != false || !next.hasInternet) {
        return;
      }

      final walletState = ref.read(walletControllerProvider);
      final currentUnavailableKind =
          walletState.wallet == null && !walletState.isInitialLoading
          ? classifyAppUnavailable(
              raw: walletState.errorMessage,
              hasInternet: next.hasInternet,
            )
          : null;
      if (currentUnavailableKind == null) {
        return;
      }

      unawaited(controller.load(refresh: true));
    });

    return _RewardsBackdrop(
      child: SafeArea(
        child: state.isInitialLoading
            ? Center(
                child: CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                ),
              )
            : unavailableKind != null
            ? PetMagicUnavailableView(
                kind: unavailableKind,
                onRetry: () => unawaited(controller.load(refresh: true)),
                padding: EdgeInsets.fromLTRB(
                  28,
                  36,
                  28,
                  bottomNavInset + keyboardInset,
                ),
              )
            : RefreshIndicator.adaptive(
                onRefresh: () async {
                  await PetMagicHaptics.medium();
                  await controller.load(refresh: true);
                },
                color: colors.accent,
                backgroundColor: colors.surfaceStrong,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    bottomNavInset + keyboardInset + 8,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _RewardsHero(
                      balance: state.wallet?.balance,
                      onHistoryTap: () => _showHistorySheet(state.ledger),
                    ),
                    const SizedBox(height: 16),
                    _AdRewardCard(
                      wallet: state.wallet,
                      isClaimingAd: state.isClaimingAd,
                      onClaimAd: controller.claimAdReward,
                    ),
                    if (warningMessage != null) ...[
                      const SizedBox(height: 16),
                      _WarningBanner(
                        message: warningMessage,
                        tone: colors.gold,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _PromoCodeCard(
                      isSubmitting: state.isRedeeming,
                      onSubmit: controller.applyRedeemCode,
                    ),
                    const SizedBox(height: 16),
                    if (isAuthenticated && !isPremiumUser) ...[
                      _RewardsPremiumUpsellCard(
                        onOpenPremium: () =>
                            context.push(PremiumPage.routePath),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _ReferralCard(rewards: rewardsSummary),
                    const SizedBox(height: 14),
                    _ReferralInfoNote(
                      rewards: rewardsSummary,
                      onHowItWorksTap: () => _showReferralHowItWorksSheet(
                        rewardsSummary?.referralBonusSpark ?? 15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FriendCodeCard(
                      rewards: rewardsSummary,
                      isSubmitting: state.isApplyingReferral,
                      onSubmit: controller.applyReferralCode,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
