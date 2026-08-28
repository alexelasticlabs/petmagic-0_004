import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/application/premium_controller.dart';
import 'package:petmagic_mobile/features/premium/application/premium_subscription_status_presenter.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/shared/auth/auth_required_sheet.dart';
import 'package:petmagic_mobile/shared/profile/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/features/gamification/application/achievements_page_state.dart';
import 'package:petmagic_mobile/features/gamification/application/gamification_providers.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/gamification_highlights_card.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
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
part 'profile_page_view.part.dart';

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

  void _preloadWalletIfNeeded({bool forceRefresh = false}) {
    final profileState = ref.read(profileControllerProvider);
    final walletState = ref.read(walletControllerProvider);
    if (!profileState.isAuthenticated ||
        profileState.profile == null ||
        !ref.read(appLaunchControllerProvider).isAuthenticated ||
        !ref.read(networkStatusControllerProvider).hasInternet) {
      return;
    }

    if (!_shouldPreloadWalletSnapshot(
      walletState,
      forceRefresh: forceRefresh,
    )) {
      return;
    }

    unawaited(
      ref
          .read(walletControllerProvider.notifier)
          .syncSnapshot(forceRefresh: forceRefresh),
    );
  }

  bool _shouldPreloadWalletSnapshot(
    WalletState walletState, {
    required bool forceRefresh,
  }) {
    // WalletController starts with isLoading=true before any request exists.
    // Do not treat that idle bootstrap state as an active wallet load: otherwise
    // the profile card can wait forever for a balance until WalletPage is opened.
    if (walletState.isRefreshing ||
        (walletState.isLoading && walletState.wallet != null)) {
      return false;
    }

    return forceRefresh || walletState.wallet == null;
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
        _shouldPreloadWalletSnapshot(walletState, forceRefresh: true)) {
      _preloadWalletIfNeeded(forceRefresh: true);
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
  Widget build(BuildContext context) => _buildProfilePage(context);

  Future<void> _handlePremiumTap(
    PremiumSubscriptionSummaryView? summary,
  ) async {
    if (summary?.isPremium == true && summary?.canManageSubscription == true) {
      await _handleSubscriptionAction(summary);
      return;
    }

    if (mounted) {
      context.appNavigator.push(const PremiumDestination());
    }
  }

  Future<void> _handleSubscriptionAction(
    PremiumSubscriptionSummaryView? summary,
  ) async {
    if (_isOpeningSubscription) {
      return;
    }

    if (summary == null ||
        !summary.isPremium ||
        !summary.canManageSubscription) {
      if (mounted) {
        context.appNavigator.push(const PremiumDestination());
      }

      return;
    }

    setState(() => _isOpeningSubscription = true);
    await context.appNavigator.push(const SubscriptionManagementDestination());
    if (!mounted) {
      return;
    }

    await _reloadProfile(invalidatePremiumSummary: true);
    if (mounted) {
      setState(() => _isOpeningSubscription = false);
    }
  }
}
