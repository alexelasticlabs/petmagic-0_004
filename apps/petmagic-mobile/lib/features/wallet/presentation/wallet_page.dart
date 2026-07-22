import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/shared/auth/auth_required_sheet.dart';
import 'package:petmagic_mobile/shared/profile/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_contract.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_stripe_checkout_page.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/payments/external_checkout_result.dart';
import 'package:petmagic_mobile/shared/payments/payment_method_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/shared/widgets/premium_shimmer_button.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_haptics.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';
import 'package:url_launcher/url_launcher.dart';

part 'widgets/wallet_page_activity_widgets.dart';
part 'widgets/wallet_page_history_widgets.dart';
part 'widgets/wallet_page_ledger_widgets.part.dart';
part 'widgets/wallet_page_overview_chrome.part.dart';
part 'widgets/wallet_page_premium_upsell.part.dart';
part 'widgets/wallet_page_view.part.dart';
part 'widgets/wallet_page_purchase_widgets.part.dart';
part 'wallet_page_checkout.part.dart';
part 'wallet_page_helpers.part.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  static const routePath = '/profile/wallet';

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage>
    with WidgetsBindingObserver {
  static const Duration _autoRefreshMinInterval = Duration(seconds: 12);
  static const Duration _autoRefreshMaxInterval = Duration(seconds: 36);

  bool _shouldReloadOnResume = false;
  Timer? _autoRefreshTimer;
  WalletController? _visibleWalletController;
  ProviderSubscription<WalletState>? _walletSubscription;
  ModalRoute<dynamic>? _route;
  int _autoRefreshErrorStreak = 0;
  bool _walletPageVisible = false;

  @override
  void initState() {
    super.initState();
    _setWalletPageVisible(true);
    _walletSubscription = ref.listenManual<WalletState>(
      walletControllerProvider,
      (_, _) => _syncVisibleWalletController(),
    );
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (!mounted) {
        return;
      }
      if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
        _stopAutoRefresh();
        return;
      }

      _startAutoRefresh();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
          return;
        }

        unawaited(_ensureTemplatePricingLoaded());
        final current = ref.read(walletControllerProvider);
        if (_hasHydratedWalletSnapshot(current)) {
          return;
        }

        ref.read(walletControllerProvider.notifier).load();
      });
    });
  }

  Future<void> _ensureTemplatePricingLoaded() async {
    final templatesState = ref.read(templatesControllerProvider);
    if (templatesState.items.isNotEmpty ||
        templatesState.isLoading ||
        templatesState.isRefreshing) {
      return;
    }

    await ref.read(templatesControllerProvider.notifier).loadInitial();
  }

  bool _hasHydratedWalletSnapshot(WalletState state) {
    return state.hasCompletedFullLoad && state.wallet != null;
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    _walletSubscription?.close();
    _setStoredWalletPageVisible(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void deactivate() {
    _stopAutoRefresh();
    _setStoredWalletPageVisible(false);
    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void activate() {
    super.activate();
    _setWalletPageVisible(true);
    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
      _stopAutoRefresh();
      return;
    }

    _scheduleNextAutoRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
        return;
      }
      if (!ref.read(networkStatusControllerProvider).hasInternet) {
        return;
      }

      unawaited(_refreshVisibleWalletData(forceRefresh: true));
    });
  }

  void _setWalletPageVisible(bool visible) {
    _walletPageVisible = visible;
    _syncVisibleWalletController();
  }

  void _syncVisibleWalletController() {
    final controller = ref.read(walletControllerProvider.notifier);
    if (!identical(_visibleWalletController, controller)) {
      _visibleWalletController?.setWalletPageVisible(false);
      _visibleWalletController = controller;
    }

    controller.setWalletPageVisible(_walletPageVisible);
  }

  void _setStoredWalletPageVisible(bool visible) {
    _walletPageVisible = visible;
    _visibleWalletController?.setWalletPageVisible(visible);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
      _stopAutoRefresh();
      return;
    }

    if (state != AppLifecycleState.resumed) {
      _stopAutoRefresh();
      return;
    }

    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      return;
    }

    if (state == AppLifecycleState.resumed && _shouldReloadOnResume) {
      unawaited(
        _resumePendingCheckoutVerification().whenComplete(
          _scheduleNextAutoRefresh,
        ),
      );
      return;
    }

    unawaited(
      _refreshVisibleWalletData(
        forceRefresh: true,
      ).whenComplete(_scheduleNextAutoRefresh),
    );
  }

  void _startAutoRefresh() {
    _scheduleNextAutoRefresh();
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> _resumePendingCheckoutVerification() async {
    if (!_shouldReloadOnResume) {
      return;
    }

    _shouldReloadOnResume = false;
    final controller = ref.read(walletControllerProvider.notifier);
    await controller.verifyCheckoutStatus();

    final verificationState = ref
        .read(walletControllerProvider)
        .checkoutVerificationState;
    if (verificationState != WalletCheckoutVerificationState.succeeded) {
      await controller.verifyStripeCheckout(null);
    }
  }

  void _scheduleNextAutoRefresh() {
    if (!mounted ||
        !ref.read(appLaunchControllerProvider).isAuthenticated ||
        !ref.read(networkStatusControllerProvider).hasInternet) {
      _stopAutoRefresh();
      return;
    }

    _stopAutoRefresh();
    _autoRefreshTimer = Timer(_currentAutoRefreshInterval(), () {
      if (!mounted) {
        return;
      }

      if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
        _stopAutoRefresh();
        return;
      }

      if (!ref.read(networkStatusControllerProvider).hasInternet) {
        _stopAutoRefresh();
        return;
      }

      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
        return;
      }

      final route = _route;
      if (route != null && !route.isCurrent) {
        _scheduleNextAutoRefresh();
        return;
      }

      unawaited(
        _refreshVisibleWalletData(forceRefresh: true)
            .then((_) {
              if (!mounted) {
                return;
              }

              final hasError =
                  ref.read(walletControllerProvider).errorMessage != null;
              if (hasError) {
                _registerAutoRefreshFailure();
              } else {
                _registerAutoRefreshSuccess();
              }
            })
            .whenComplete(_scheduleNextAutoRefresh),
      );
    });
  }

  Future<void> _refreshVisibleWalletData({bool forceRefresh = false}) async {
    if (!mounted ||
        !ref.read(appLaunchControllerProvider).isAuthenticated ||
        !ref.read(networkStatusControllerProvider).hasInternet) {
      _stopAutoRefresh();
      return;
    }

    final controller = ref.read(walletControllerProvider.notifier);
    final state = ref.read(walletControllerProvider);
    // Background refresh only needs the lightweight balance snapshot once the
    // wallet itself is present. Full reload remains available for the initial
    // hydrate and explicit manual refreshes.
    if (state.wallet != null) {
      await controller.syncSnapshot(forceRefresh: forceRefresh);
      return;
    }

    await controller.load(refresh: true);
  }

  Duration _currentAutoRefreshInterval() {
    final multiplier = 1 << _autoRefreshErrorStreak.clamp(0, 2);
    final nextSeconds = _autoRefreshMinInterval.inSeconds * multiplier;
    final maxSeconds = _autoRefreshMaxInterval.inSeconds;
    final boundedSeconds = nextSeconds > maxSeconds ? maxSeconds : nextSeconds;
    return Duration(seconds: boundedSeconds);
  }

  void _registerAutoRefreshSuccess() {
    _autoRefreshErrorStreak = 0;
  }

  void _registerAutoRefreshFailure() {
    final next = _autoRefreshErrorStreak + 1;
    _autoRefreshErrorStreak = next > 2 ? 2 : next;
  }

  @override
  Widget build(BuildContext context) => _buildWalletPage(context);
}
