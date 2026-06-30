import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/legal_acceptance_gate_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/all_transactions_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_stripe_checkout_page.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/payments/payment_method_sheet.dart';
import 'package:petmagic_mobile/shared/payments/stripe_paymentsheet_coordinator.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/shared/widgets/premium_shimmer_button.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_haptics.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';
import 'package:url_launcher/url_launcher.dart';

part 'widgets/wallet_page_activity_widgets.dart';
part 'widgets/wallet_page_ledger_widgets.part.dart';
part 'widgets/wallet_page_overview_chrome.part.dart';
part 'widgets/wallet_page_purchase_widgets.part.dart';
part 'wallet_page_checkout.part.dart';
part 'wallet_page_helpers.part.dart';

const int _kWalletApproxPhotoCostSpark = 6;
const int _kWalletApproxVideoCostSpark = 33;

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
  late final WalletController _walletController;
  ModalRoute<dynamic>? _route;
  int _autoRefreshErrorStreak = 0;

  @override
  void initState() {
    super.initState();
    _walletController = ref.read(walletControllerProvider.notifier);
    _walletController.setWalletPageVisible(true);
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(appLaunchControllerProvider).isAuthenticated) {
      _startAutoRefresh();
      Future.microtask(() {
        if (!mounted) {
          return;
        }

        _walletController.load();
      });
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    _walletController.setWalletPageVisible(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void deactivate() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    _walletController.setWalletPageVisible(false);
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
    _walletController.setWalletPageVisible(true);
    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
      return;
    }

    _scheduleNextAutoRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(appLaunchControllerProvider).isAuthenticated) {
        return;
      }

      unawaited(
        ref.read(walletControllerProvider.notifier).load(refresh: true),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
      return;
    }

    if (state != AppLifecycleState.resumed) {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
      return;
    }

    if (state == AppLifecycleState.resumed && _shouldReloadOnResume) {
      _shouldReloadOnResume = false;
      unawaited(
        () async {
          final controller = ref.read(walletControllerProvider.notifier);
          await controller.verifyCheckoutStatus();

          final verificationState = ref
              .read(walletControllerProvider)
              .checkoutVerificationState;
          if (verificationState != WalletCheckoutVerificationState.succeeded) {
            await controller.verifyStripeCheckout(null);
          }
        }().whenComplete(_scheduleNextAutoRefresh),
      );
      return;
    }

    unawaited(
      _walletController
          .load(refresh: true)
          .whenComplete(_scheduleNextAutoRefresh),
    );
  }

  void _startAutoRefresh() {
    _scheduleNextAutoRefresh();
  }

  void _scheduleNextAutoRefresh() {
    if (!mounted) {
      return;
    }

    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer(_currentAutoRefreshInterval(), () {
      if (!mounted) {
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
        _walletController
            .load(refresh: true)
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
  Widget build(BuildContext context) {
    final state = ref.watch(
      walletControllerProvider.select(
        (state) => (
          isInitialLoading: state.isInitialLoading,
          wallet: state.wallet,
          errorMessage: state.errorMessage,
          packs: state.packs,
          paymentMethods: state.paymentMethods,
          storeProductPrices: state.storeProductPrices,
          isBuying: state.isBuying,
          isClaimingAd: state.isClaimingAd,
          ledger: state.ledger,
          purchases: state.purchases,
          highlightedPurchaseOrderId: state.highlightedPurchaseOrderId,
        ),
      ),
    );
    final controller = ref.read(walletControllerProvider.notifier);
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select((launch) => launch.isAuthenticated),
    );
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final unavailableKind = state.wallet == null && !state.isInitialLoading
        ? classifyAppUnavailable(
            raw: state.errorMessage,
            hasInternet: hasInternet,
          )
        : null;
    final legalAcceptanceRequired = isLegalAcceptanceRequiredError(
      state.errorMessage,
    );
    final hasShell =
        context.findAncestorWidgetOfExactType<PetMagicShell>() != null;
    final bottomNavInset = hasShell
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
            padding: EdgeInsets.only(bottom: bottomNavInset),
            child: ProtectedAuthGate(
              subtitle: text.authRequiredMessage,
              onSignIn: () => showAuthRequiredSheet(
                context,
                redirectPath: WalletPage.routePath,
              ),
            ),
          ),
        ),
      );
    }

    if (state.wallet == null &&
        !state.isInitialLoading &&
        legalAcceptanceRequired) {
      return ProfileScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomNavInset),
            child: _WalletUnavailableCard(
              message:
                  mapCommonAuthFeedbackMessage(
                    text,
                    state.errorMessage,
                    preferAuthRequiredMessage: true,
                  ) ??
                  text.profileLegalAcceptanceRequired,
              onAction: () => context.go(LegalAcceptanceGatePage.routePath),
              actionLabel: text.profileLegalAcceptAction,
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

      final currentState = ref.read(walletControllerProvider);
      final currentUnavailableKind =
          currentState.wallet == null && !currentState.isInitialLoading
          ? classifyAppUnavailable(
              raw: currentState.errorMessage,
              hasInternet: next.hasInternet,
            )
          : null;
      if (currentUnavailableKind == null) {
        return;
      }

      unawaited(controller.load(refresh: true));
    });

    ref.listen(walletControllerProvider, (previous, next) {
      if (!mounted) {
        return;
      }

      final previousState =
          previous?.checkoutVerificationState ??
          WalletCheckoutVerificationState.idle;
      final nextState = next.checkoutVerificationState;
      if (previousState == nextState) {
        return;
      }

      if (nextState == WalletCheckoutVerificationState.succeeded) {
        final grantedSpark = next.checkoutGrantedSpark ?? 0;
        PetMagicToast.show(
          context,
          message: text.walletCheckoutSucceeded(grantedSpark),
          tone: PetMagicToastTone.success,
        );
        return;
      }

      if (nextState == WalletCheckoutVerificationState.pending) {
        PetMagicToast.show(
          context,
          message: text.externalCheckoutPendingVerificationMessage,
          tone: PetMagicToastTone.info,
        );
        return;
      }

      if (nextState == WalletCheckoutVerificationState.error) {
        PetMagicToast.show(
          context,
          message: _friendlyError(
            text,
            next.checkoutErrorMessage ??
                next.errorMessage ??
                text.walletDataUnavailableFallback,
          ),
          tone: PetMagicToastTone.warning,
        );
      }
    });

    ref.listen(walletControllerProvider, (previous, next) {
      if (!mounted) {
        return;
      }

      final previousError = previous?.errorMessage?.trim();
      final nextError = next.errorMessage?.trim();
      if (nextError == null ||
          nextError.isEmpty ||
          nextError == previousError) {
        return;
      }

      // Keep full-page unavailable card for hard failures when wallet is absent.
      if (next.wallet == null) {
        return;
      }

      if (_isWalletPartialError(nextError)) {
        return;
      }

      PetMagicToast.show(
        context,
        message: _friendlyError(text, nextError),
        tone: PetMagicToastTone.warning,
      );
    });

    return ProfileScreenBackground(
      child: SafeArea(
        child: state.isInitialLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : unavailableKind != null
            ? PetMagicUnavailableView(
                kind: unavailableKind,
                onRetry: () => unawaited(controller.load(refresh: true)),
                padding: EdgeInsets.fromLTRB(28, 36, 28, bottomNavInset),
              )
            : RefreshIndicator.adaptive(
                onRefresh: () async {
                  await PetMagicHaptics.medium();
                  await controller.load(refresh: true);
                },
                color: colors.accent,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, bottomNavInset),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _WalletHeader(
                      title: text.walletPageTitle,
                      subtitle: text.walletPageSubtitle,
                    ),
                    if (state.wallet == null) ...[
                      const SizedBox(height: 22),
                      _WalletUnavailableCard(
                        message: _friendlyError(
                          text,
                          state.errorMessage ??
                              text.walletDataUnavailableFallback,
                        ),
                        onAction: () => controller.load(refresh: true),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      _BalanceCard(wallet: state.wallet),
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        ProfileMessageCard(
                          message: _friendlyError(text, state.errorMessage!),
                          tone: const Color(0xFFFFC107),
                        ),
                      ],
                      if (isAuthenticated &&
                          !(state.wallet?.isPremium ?? false)) ...[
                        const SizedBox(height: 14),
                        _PremiumUpsellCard(
                          onOpenPremium: () =>
                              context.push(PremiumPage.routePath),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _PacksSection(
                        packs: state.packs,
                        storeProductPrices: state.storeProductPrices,
                        isBuying: state.isBuying,
                        onSelect: (pack) => _showPackDetailSheet(
                          context,
                          state.packs,
                          paymentMethods: state.paymentMethods,
                          initialPack: pack,
                          isBuying: state.isBuying,
                          onBuy: (selectedPack, selectedPaymentMethod) =>
                              controller.buyPack(
                                selectedPack,
                                selectedPaymentMethod,
                              ),
                          onCheckoutReady: (checkout) async {
                            controller.resetCheckoutVerification();
                            controller.consumeCheckoutUrl();
                            return _handleCheckout(checkout);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LedgerSection(
                        items: state.ledger,
                        onViewAll: () =>
                            context.pushNamed(AllTransactionsPage.routeName),
                      ),
                      const SizedBox(height: 16),
                      _PurchasesSection(
                        items: state.purchases,
                        highlightedOrderId: state.highlightedPurchaseOrderId,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
