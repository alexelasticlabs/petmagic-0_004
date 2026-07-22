import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/shared/auth/auth_required_sheet.dart';
import 'package:petmagic_mobile/shared/profile/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/widgets/all_transactions_widgets.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

class AllTransactionsPage extends ConsumerStatefulWidget {
  const AllTransactionsPage({super.key});

  static const routeName = 'wallet-all-transactions';
  static const routePath = '/profile/wallet/transactions';

  @override
  ConsumerState<AllTransactionsPage> createState() =>
      _AllTransactionsPageState();
}

class _AllTransactionsPageState extends ConsumerState<AllTransactionsPage> {
  static const String _kAllTransactionsEmptyAsset =
      'assets/rewards/wallet-pack-chest.png';
  static const double _ledgerLoadMoreThreshold = 320;

  final ScrollController _scrollController = ScrollController();
  WalletController? _visibleWalletController;
  ProviderSubscription<WalletState>? _walletSubscription;
  ProviderSubscription<AppLaunchState>? _launchSubscription;
  bool _wasAuthenticated = false;
  bool _autoLoadMoreScheduled = false;
  bool _walletPageVisible = false;

  @override
  void initState() {
    super.initState();
    _setWalletPageVisible(true);
    _walletSubscription = ref.listenManual<WalletState>(
      walletControllerProvider,
      (_, _) => _syncVisibleWalletController(),
    );
    _scrollController.addListener(_handleScroll);
    _launchSubscription = ref.listenManual<AppLaunchState>(
      appLaunchControllerProvider,
      (_, next) => _handleLaunchState(next),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _launchSubscription?.close();
    _walletSubscription?.close();
    _setStoredWalletPageVisible(false);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    _setStoredWalletPageVisible(false);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _setWalletPageVisible(true);
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

  void _handleLaunchState(AppLaunchState launchState) {
    if (launchState.isAuthenticated && !_wasAuthenticated) {
      _wasAuthenticated = true;
      _scheduleInitialLoadIfNeeded();
      return;
    }

    _wasAuthenticated = launchState.isAuthenticated;
  }

  void _scheduleInitialLoadIfNeeded() {
    final snapshot = ref.read(walletControllerProvider);
    if (_hasHydratedTransactionsSnapshot(snapshot)) {
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
      if (_hasHydratedTransactionsSnapshot(current)) {
        return;
      }

      unawaited(_loadIfOnline());
    });
  }

  bool _hasHydratedTransactionsSnapshot(WalletState state) {
    return state.ledger.isNotEmpty ||
        (state.hasCompletedFullLoad && state.wallet != null);
  }

  Future<void> _loadIfOnline({bool refresh = false}) async {
    if (!mounted ||
        !ref.read(appLaunchControllerProvider).isAuthenticated ||
        !ref.read(networkStatusControllerProvider).hasInternet) {
      return;
    }

    await ref.read(walletControllerProvider.notifier).load(refresh: refresh);
  }

  Future<void> _loadMoreIfOnline({bool force = false}) async {
    if (!mounted ||
        !ref.read(appLaunchControllerProvider).isAuthenticated ||
        !ref.read(networkStatusControllerProvider).hasInternet) {
      return;
    }

    await ref
        .read(walletControllerProvider.notifier)
        .loadMoreLedger(force: force);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        !ref.read(appLaunchControllerProvider).isAuthenticated ||
        !ref.read(networkStatusControllerProvider).hasInternet) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - _ledgerLoadMoreThreshold) {
      return;
    }

    unawaited(_loadMoreIfOnline());
  }

  void _scheduleAutoLoadMoreIfNeeded(WalletState state) {
    if (_autoLoadMoreScheduled ||
        state.ledger.isEmpty ||
        !state.ledgerHasMore ||
        state.isLoadingMoreLedger ||
        state.ledgerLoadMoreErrorMessage != null ||
        !ref.read(networkStatusControllerProvider).hasInternet) {
      return;
    }

    _autoLoadMoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLoadMoreScheduled = false;
      if (!mounted) {
        return;
      }
      if (!_scrollController.hasClients ||
          !ref.read(appLaunchControllerProvider).isAuthenticated ||
          !ref.read(networkStatusControllerProvider).hasInternet) {
        return;
      }

      final position = _scrollController.position;
      if (position.maxScrollExtent > _ledgerLoadMoreThreshold) {
        return;
      }

      unawaited(_loadMoreIfOnline());
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select((launch) => launch.isAuthenticated),
    );
    final state = ref.watch(walletControllerProvider);
    final navigator = context.appNavigator;
    final showOfflineUnavailable =
        !_hasHydratedTransactionsSnapshot(state) && !hasInternet;
    final errorToShow = state.errorMessage != null && state.ledger.isEmpty
        ? friendlyTransactionsError(text, state.errorMessage!)
        : null;
    final loadMoreErrorToShow =
        state.ledgerLoadMoreErrorMessage != null && state.ledger.isNotEmpty
        ? friendlyTransactionsError(text, state.ledgerLoadMoreErrorMessage!)
        : null;
    final hasShell = PetMagicShellScope.isPresent(context);
    final bottomInset = hasShell
        ? petMagicScrollableBottomInset(
            context,
            extraSpacing: kPetMagicBottomContentInsetRelaxed,
          )
        : MediaQuery.viewPaddingOf(context).bottom +
              kPetMagicBottomContentInsetCompact;

    if (!isAuthenticated) {
      return ProfileScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: ProtectedAuthGate(
              subtitle: text.authRequiredMessage,
              onSignIn: () => showAuthRequiredSheet(
                context,
                redirectPath: AllTransactionsPage.routePath,
              ),
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
      if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
        return;
      }

      final current = ref.read(walletControllerProvider);
      if (_hasHydratedTransactionsSnapshot(current)) {
        return;
      }

      unawaited(_loadIfOnline(refresh: true));
    });

    _scheduleAutoLoadMoreIfNeeded(state);

    return ProfileScreenBackground(
      child: SafeArea(
        child: showOfflineUnavailable
            ? PetMagicUnavailableView(
                kind: AppUnavailableKind.offline,
                onRetry: () => unawaited(_loadIfOnline(refresh: true)),
              )
            : state.isInitialLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : RefreshIndicator.adaptive(
                color: colors.accent,
                onRefresh: () => _loadIfOnline(refresh: true),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: allTransactionListItemCount(
                    itemCount: state.ledger.length,
                    hasError: errorToShow != null,
                    showLoadMoreIndicator: state.isLoadingMoreLedger,
                    showLoadMoreError: loadMoreErrorToShow != null,
                  ),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return AllTransactionsHeader(
                        title: text.walletViewAllTransactions,
                        onBack: () {
                          if (navigator.canPop()) {
                            navigator.pop();
                            return;
                          }

                          navigator.go(const WalletDestination());
                        },
                      );
                    }

                    final contentStartIndex = errorToShow == null ? 1 : 2;
                    if (errorToShow != null && index == 1) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: AllTransactionsErrorState(
                          message: errorToShow,
                          tone: colors.gold,
                          onRetry: () =>
                              unawaited(_loadIfOnline(refresh: true)),
                        ),
                      );
                    }

                    if (state.ledger.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: AllTransactionsEmptyState(
                          asset: _kAllTransactionsEmptyAsset,
                          message: text.walletNoActivity,
                        ),
                      );
                    }

                    final ledgerIndex = index - contentStartIndex;
                    if (ledgerIndex >= state.ledger.length) {
                      if (loadMoreErrorToShow != null) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 4),
                          child: AllTransactionsLoadMoreError(
                            message: loadMoreErrorToShow,
                            tone: colors.gold,
                            onRetry: () =>
                                unawaited(_loadMoreIfOnline(force: true)),
                          ),
                        );
                      }

                      return const Padding(
                        padding: EdgeInsets.only(top: 12, bottom: 4),
                        child: AllTransactionsLoadMoreIndicator(),
                      );
                    }

                    return Padding(
                      padding: EdgeInsets.only(top: ledgerIndex == 0 ? 16 : 8),
                      child: ProfileGlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: AllTransactionsRow(
                          item: state.ledger[ledgerIndex],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
