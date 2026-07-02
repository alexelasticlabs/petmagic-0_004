import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/pets/presentation/my_pets_page.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_subscription_status_presenter.dart';
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
import 'package:petmagic_mobile/features/gamification/presentation/achievements_page_state.dart';
import 'package:petmagic_mobile/features/gamification/presentation/gamification_providers.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/gamification_summary_card.dart';
import 'package:petmagic_mobile/features/gamification/presentation/achievements_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/android_loopback_backend_hint.dart';
import 'package:petmagic_mobile/shared/widgets/motion_entrance.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:petmagic_mobile/shared/widgets/premium_shimmer_button.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';

part 'profile_page_cards.part.dart';
part 'profile_page_premium.part.dart';
part 'profile_page_subscription_summary.part.dart';
part 'profile_page_gamification.part.dart';

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
  ProviderSubscription<AppLaunchState>? _launchSubscription;
  bool _hasHandledLaunchState = false;
  bool _wasAuthenticated = false;
  bool _isProfileReloadScheduled = false;
  bool _shouldInvalidatePremiumSummaryAfterReload = false;
  Future<void>? _profileReloadInFlight;

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

  void _preloadWalletIfNeeded() {
    final profileState = ref.read(profileControllerProvider);
    final walletState = ref.read(walletControllerProvider);
    if (!profileState.isAuthenticated ||
        profileState.profile == null ||
        !ref.read(appLaunchControllerProvider).isAuthenticated ||
        !ref.read(networkStatusControllerProvider).hasInternet) {
      return;
    }

    if (!_shouldPreloadWalletSnapshot(walletState)) {
      return;
    }

    unawaited(ref.read(walletControllerProvider.notifier).load());
  }

  bool _shouldPreloadWalletSnapshot(WalletState walletState) {
    if (walletState.isLoading || walletState.isRefreshing) {
      return false;
    }

    return !walletState.hasCompletedFullLoad;
  }

  bool _shouldSkipDeferredProfileReload() {
    if (ref.read(appLaunchControllerProvider).isAuthenticated) {
      return false;
    }

    final profileState = ref.read(profileControllerProvider);
    return !profileState.isLoading && !profileState.isAuthenticated;
  }

  @override
  void dispose() {
    _launchSubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleLaunchState(AppLaunchState launchState) {
    final shouldReload =
        !_hasHandledLaunchState ||
        _wasAuthenticated != launchState.isAuthenticated;
    _hasHandledLaunchState = true;
    _wasAuthenticated = launchState.isAuthenticated;
    if (!shouldReload) {
      return;
    }

    _scheduleProfileReload();
  }

  void _scheduleProfileReload() {
    if (_isProfileReloadScheduled) {
      return;
    }

    _isProfileReloadScheduled = true;
    Future.microtask(() async {
      _isProfileReloadScheduled = false;
      if (!mounted || _shouldSkipDeferredProfileReload()) {
        return;
      }

      await _reloadProfile(invalidatePremiumSummary: true);
    });
  }

  Future<void> _reloadProfile({bool invalidatePremiumSummary = false}) async {
    if (invalidatePremiumSummary) {
      _shouldInvalidatePremiumSummaryAfterReload = true;
    }

    final inFlight = _profileReloadInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final operation = () async {
      try {
        await ref.read(profileControllerProvider.notifier).initialize();
        if (!mounted) {
          return;
        }

        final profileState = ref.read(profileControllerProvider);
        if (_shouldInvalidatePremiumSummaryAfterReload &&
            profileState.isAuthenticated &&
            profileState.profile != null) {
          ref.invalidate(premiumSubscriptionSummaryProvider);
        }

        _preloadWalletIfNeeded();
      } finally {
        _shouldInvalidatePremiumSummaryAfterReload = false;
      }
    }();

    _profileReloadInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_profileReloadInFlight, operation)) {
        _profileReloadInFlight = null;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    final profileState = ref.read(profileControllerProvider);
    final walletState = ref.read(walletControllerProvider);
    final hasInternet = ref.read(networkStatusControllerProvider).hasInternet;
    if (!hasInternet) {
      return;
    }

    if (profileState.isAuthenticated &&
        profileState.profile != null &&
        _shouldPreloadWalletSnapshot(walletState)) {
      _preloadWalletIfNeeded();
    }

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

    unawaited(_reloadProfile(invalidatePremiumSummary: true));
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
    final subscriptionSummary = state.isAuthenticated && state.profile != null
        ? ref.watch(
            premiumSubscriptionSummaryProvider.select(
              (summary) => summary.value,
            ),
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
      final walletState = ref.read(walletControllerProvider);
      if (profileState.isAuthenticated &&
          profileState.profile != null &&
          _shouldPreloadWalletSnapshot(walletState)) {
        _preloadWalletIfNeeded();
      }

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

      unawaited(_reloadProfile(invalidatePremiumSummary: true));
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
            onRetry: () =>
                unawaited(_reloadProfile(invalidatePremiumSummary: true)),
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
        final message = mapProfileSuccessMessage(next.successMessage!, text);
        if (message != null) {
          PetMagicToast.show(
            context,
            message: message,
            tone: PetMagicToastTone.success,
          );
        }
      }
    });

    return ProfileScreenBackground(
      child: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : RefreshIndicator.adaptive(
                onRefresh: () async {
                  await _reloadProfile(invalidatePremiumSummary: true);
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
                                key: const ValueKey('profile_legal_shortcut'),
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

    await _reloadProfile(invalidatePremiumSummary: true);
    if (mounted) {
      setState(() => _isOpeningSubscription = false);
    }
  }
}
