import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
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
import 'package:petmagic_mobile/shared/widgets/premium_banner_style.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/shared/widgets/premium_shimmer_button.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_haptics.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:url_launcher/url_launcher.dart';

part 'widgets/wallet_page_activity_widgets.dart';
part 'widgets/wallet_page_overview_widgets.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  static const routePath = '/profile/wallet';
  static const legacyRoutePath = '/wallet';

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
  int _autoRefreshErrorStreak = 0;

  @override
  void initState() {
    super.initState();
    _walletController = ref.read(walletControllerProvider.notifier);
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void deactivate() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
      return;
    }

    _scheduleNextAutoRefresh();
    unawaited(_walletController.load(refresh: true));
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

      final route = ModalRoute.of(context);
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
    final state = ref.watch(walletControllerProvider);
    final controller = ref.read(walletControllerProvider.notifier);
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select((launch) => launch.isAuthenticated),
    );
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
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
            padding: EdgeInsets.fromLTRB(16, 24, 16, bottomNavInset),
            child: _WalletUnavailableCard(
              message: text.authSignInRequired,
              onRetry: () => showAuthRequiredSheet(
                context,
                redirectPath: WalletPage.routePath,
              ),
            ),
          ),
        ),
      );
    }

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
                        onRetry: () => controller.load(refresh: true),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      _BalanceCard(
                        wallet: state.wallet,
                        onRefresh: () => controller.load(refresh: true),
                      ),
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
                      _RewardsOverviewCard(
                        wallet: state.wallet,
                        isClaimingAd: state.isClaimingAd,
                        onClaimAd: controller.claimAdReward,
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

  Future<StripePaymentSheetResult> _handleCheckout(
    PurchaseCheckoutModel checkout,
  ) async {
    final text = AppLocalizations.of(context);
    if (!checkout.usesPaymentSheet) {
      final checkoutUrl = checkout.checkoutUrl.trim();
      final uri = parseSafeExternalUri(
        checkoutUrl,
        allowedHttpsHosts: premiumExternalAllowedHosts(),
      );
      if (uri != null) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          _shouldReloadOnResume = true;
          return StripePaymentSheetResult.success;
        }
      }

      return StripePaymentSheetResult.failure(
        error: StateError('wallet.payment_gateway_unavailable'),
        errorMessage: text.walletPaymentGatewayUnavailableError,
      );
    }

    return _presentStripePaymentSheet(checkout);
  }

  Future<StripePaymentSheetResult> _presentStripePaymentSheet(
    PurchaseCheckoutModel checkout,
  ) async {
    final text = AppLocalizations.of(context);
    final clientSecret = checkout.paymentIntentClientSecret;
    final publishableKey = checkout.publishableKey;
    if (clientSecret == null ||
        clientSecret.isEmpty ||
        publishableKey == null ||
        publishableKey.isEmpty) {
      return StripePaymentSheetResult.failure(
        error: StateError('wallet.payment_gateway_unavailable'),
        errorMessage: text.walletPaymentGatewayUnavailableError,
      );
    }

    _shouldReloadOnResume = true;
    final sheetResult = await StripePaymentSheetCoordinator.present(
      context,
      request: StripePaymentSheetRequest(
        paymentIntentClientSecret: clientSecret,
        publishableKey: publishableKey,
        customerId: checkout.customerId,
        customerEphemeralKeySecret: checkout.customerEphemeralKeySecret,
      ),
    );

    if (!sheetResult.completed) {
      _shouldReloadOnResume = false;
      return sheetResult;
    }

    if (!mounted) {
      _shouldReloadOnResume = false;
      return StripePaymentSheetResult.failure(
        error: StateError('wallet.context_unmounted'),
        errorMessage: text.walletPaymentGatewayUnavailableError,
      );
    }

    final controller = ref.read(walletControllerProvider.notifier);
    await controller.verifyStripeCheckout(checkout.externalPaymentId);

    // Fallback polling keeps UX resilient when direct verification is delayed.
    var verificationState = ref
        .read(walletControllerProvider)
        .checkoutVerificationState;
    if (verificationState != WalletCheckoutVerificationState.succeeded) {
      await controller.verifyCheckoutStatus();
      verificationState = ref
          .read(walletControllerProvider)
          .checkoutVerificationState;
    }

    _shouldReloadOnResume = false;

    if (verificationState == WalletCheckoutVerificationState.succeeded) {
      return StripePaymentSheetResult.success;
    }

    final currentState = ref.read(walletControllerProvider);
    final message = switch (verificationState) {
      WalletCheckoutVerificationState.pending =>
        text.externalCheckoutPendingVerificationMessage,
      WalletCheckoutVerificationState.error => _friendlyError(
        text,
        currentState.checkoutErrorMessage ??
            currentState.errorMessage ??
            text.walletPaymentGatewayUnavailableError,
      ),
      _ => text.walletPaymentGatewayUnavailableError,
    };

    return StripePaymentSheetResult.failure(
      error: StateError('wallet.checkout_verification_failed'),
      errorMessage: message,
    );
  }
}

Future<void> _showPackDetailSheet(
  BuildContext context,
  List<CurrencyPackModel> packs, {
  required List<WalletPaymentMethodModel> paymentMethods,
  required CurrencyPackModel initialPack,
  required bool isBuying,
  required Future<PurchaseCheckoutModel?> Function(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
  )
  onBuy,
  required Future<StripePaymentSheetResult> Function(
    PurchaseCheckoutModel checkout,
  )
  onCheckoutReady,
}) async {
  final text = AppLocalizations.of(context);
  if (packs.isEmpty) {
    return;
  }

  final selectedPack = packs.firstWhere(
    (pack) => pack.packId == initialPack.packId,
    orElse: () => packs.first,
  );

  final enabledMethods = paymentMethods
      .where((method) => method.isEnabled)
      .toList(growable: false);
  if (enabledMethods.isEmpty) {
    return;
  }

  var selectedMethod =
      enabledMethods
          .where((method) => method.isSelectedByDefault)
          .cast<WalletPaymentMethodModel?>()
          .firstOrNull ??
      enabledMethods
          .where((method) => method.isRecommended)
          .cast<WalletPaymentMethodModel?>()
          .firstOrNull ??
      enabledMethods.first;

  List<PaymentMethodSheetOption> buildMethodOptions() {
    return paymentMethods
        .map((method) {
          final provider = method.provider.trim().toLowerCase();
          final legalNotice = switch (provider) {
            'stripe' => text.walletCheckoutTrustText,
            'google_play' ||
            'app_store' => text.premiumStorePaymentDisclaimerBody,
            _ => null,
          };
          final storeUnavailableSubtitle =
              !method.isEnabled && method.isStoreNative
              ? _walletStoreUnavailableSubtitle(text, method)
              : null;

          return PaymentMethodSheetOption(
            id: method.provider,
            title: _walletProviderLabel(text, method),
            icon: _walletProviderIcon(method),
            subtitle: storeUnavailableSubtitle ?? method.displaySubtitle,
            badge: method.isRecommended
                ? text.premiumPaymentRecommendedBadge
                : (method.isSelectedByDefault
                      ? text.premiumPaymentDefaultBadge
                      : null),
            warningTitle: method.warningTitle,
            warningMessage: method.warningMessage,
            notes: method.notes,
            legalNotice: legalNotice,
            isEnabled: method.isEnabled,
          );
        })
        .toList(growable: false);
  }

  final selectedOption = await showPaymentMethodSheet(
    context: context,
    title: text.premiumPaymentTitle,
    subtitle: text.walletPaymentMethodChooseSubtitle,
    continueLabel: text.premiumContinueAction,
    continueLabelBuilder: (option) =>
        text.paymentContinueViaProviderAction(option.title),
    options: buildMethodOptions(),
    trustTitle: text.walletPaymentTrustTitle,
    trustLines: [
      text.walletPaymentTrustStripeProcesses,
      text.walletPaymentTrustNoStorage,
      text.walletPaymentTrustTopUpAnytime,
    ],
  );
  if (selectedOption == null || !context.mounted) {
    return;
  }

  for (final method in enabledMethods) {
    if (method.provider == selectedOption.id) {
      selectedMethod = method;
      break;
    }
  }

  if (!selectedMethod.isStripe) {
    final checkout = await onBuy(selectedPack, selectedMethod);
    if (!context.mounted || checkout == null) {
      return;
    }

    final result = await onCheckoutReady(checkout);
    if (!context.mounted || result.completed) {
      return;
    }

    if (!result.cancelled) {
      PetMagicToast.show(
        context,
        message: text.walletPaymentGatewayUnavailableError,
        tone: PetMagicToastTone.warning,
      );
    }
    return;
  }

  final checkoutCompleted = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (pageContext) => WalletStripeCheckoutPage(
        pack: selectedPack,
        paymentMethodLabel: _walletProviderLabel(text, selectedMethod),
        onChooseAnotherMethod: () {},
        onSubmit: () async {
          final checkout = await onBuy(selectedPack, selectedMethod);
          if (checkout == null) {
            return WalletStripeCheckoutSubmitResult(
              status: WalletStripeCheckoutActionStatus.failed,
              message: text.walletPaymentUnavailableError,
            );
          }

          final paymentResult = await onCheckoutReady(checkout);
          if (paymentResult.completed) {
            return const WalletStripeCheckoutSubmitResult(
              status: WalletStripeCheckoutActionStatus.success,
            );
          }

          if (paymentResult.cancelled) {
            return WalletStripeCheckoutSubmitResult(
              status: WalletStripeCheckoutActionStatus.cancelled,
              message: text.premiumPurchaseCancelled,
            );
          }

          return WalletStripeCheckoutSubmitResult(
            status: WalletStripeCheckoutActionStatus.failed,
            message: text.walletPaymentGatewayUnavailableError,
          );
        },
      ),
    ),
  );

  if (checkoutCompleted == false && context.mounted) {
    await _showPackDetailSheet(
      context,
      packs,
      paymentMethods: paymentMethods,
      initialPack: selectedPack,
      isBuying: isBuying,
      onBuy: onBuy,
      onCheckoutReady: onCheckoutReady,
    );
  }
}

String _walletProviderLabel(
  AppLocalizations text,
  WalletPaymentMethodModel method,
) {
  final provider = method.provider.trim().toLowerCase();
  final customLabel = method.displayLabel?.trim();
  if (customLabel != null && customLabel.isNotEmpty) {
    return customLabel;
  }

  return switch (provider) {
    'stripe' => text.premiumPaymentStripe,
    'google_play' => text.premiumPaymentGooglePlay,
    'app_store' => text.premiumPaymentApple,
    _ => method.provider,
  };
}

IconData _walletProviderIcon(WalletPaymentMethodModel method) {
  final provider = method.provider.trim().toLowerCase();
  return switch (provider) {
    'stripe' => Icons.credit_card_rounded,
    'google_play' => Icons.android_rounded,
    'app_store' => Icons.apple_rounded,
    _ => Icons.payments_rounded,
  };
}

String? _walletStoreUnavailableSubtitle(
  AppLocalizations text,
  WalletPaymentMethodModel method,
) {
  final provider = method.provider.trim().toLowerCase();
  return switch (provider) {
    'google_play' => text.walletPaymentStoreUnavailableGooglePlay,
    'app_store' => text.walletPaymentStoreUnavailableAppStore,
    _ => method.displaySubtitle,
  };
}

String _valuePerCurrencyLabel(CurrencyPackModel pack) {
  if (pack.priceAmount <= 0) {
    return '-';
  }

  final sparkPerUnit = pack.totalSpark / pack.priceAmount;
  final formatted = NumberFormat('0.0').format(sparkPerUnit);
  return '$formatted PawSpark / ${pack.currencyCode}1';
}

String _formatPrice(CurrencyPackModel pack) {
  return NumberFormat.simpleCurrency(
    name: pack.currencyCode,
  ).format(pack.priceAmount);
}

String _formatDate(BuildContext context, DateTime? value) {
  if (value == null) {
    return AppLocalizations.of(context).walletPending;
  }

  return DateFormat.MMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(value.toLocal());
}

String _sourceLabel(AppLocalizations text, String source) {
  return switch (source) {
    'pack_purchase' => text.walletSourcePackPurchase,
    'generation_spend' => text.walletSourceGenerationSpend,
    'generation_refund' => text.walletSourceGenerationRefund,
    'weekly_grant' ||
    'premium_subscription_weekly_grant' => text.walletSourceWeeklyGrant,
    'ad_reward' => text.walletSourceAdReward,
    'promo_redeem' || 'redeem_code' => text.walletSourcePromoCode,
    'admin_grant' => text.walletSourceAdminGrant,
    'admin_debit' => text.walletSourceAdminDebit,
    _ => source,
  };
}

IconData _sourceIcon(String source) {
  return switch (source) {
    'pack_purchase' => Icons.account_balance_wallet_rounded,
    'generation_spend' => Icons.auto_awesome_rounded,
    'generation_refund' => Icons.undo_rounded,
    'weekly_grant' ||
    'premium_subscription_weekly_grant' => Icons.card_giftcard_rounded,
    'ad_reward' => Icons.play_circle_fill_rounded,
    'promo_redeem' || 'redeem_code' => Icons.confirmation_number_rounded,
    'admin_grant' => Icons.support_agent_rounded,
    'admin_debit' => Icons.remove_circle_outline_rounded,
    _ => Icons.receipt_long_rounded,
  };
}

String _purchaseStatusLabel(AppLocalizations text, String status) {
  return switch (status) {
    'succeeded' => text.walletPurchaseCompleted,
    'failed' => text.walletPurchaseFailed,
    _ => text.walletPending,
  };
}

Color _purchaseStatusColor(String status, PetMagicColors colors) {
  return switch (status) {
    'succeeded' => colors.accent,
    'failed' => colors.danger,
    _ => colors.gold,
  };
}

Color _ledgerTone(WalletLedgerItem item, PetMagicColors colors) {
  return switch (item.source) {
    'generation_spend' || 'admin_debit' => colors.danger,
    'generation_refund' => colors.textMuted,
    _ => item.delta >= 0 ? colors.accent : colors.danger,
  };
}

String _friendlyError(AppLocalizations text, String value) {
  if (value.contains('auth.sign_in_required')) {
    return text.authRequiredMessage;
  }

  if (value.contains('auth.session_expired')) {
    return text.authExternalSessionExpired;
  }

  if (value.contains('wallet.ledger_failed') ||
      value.contains('wallet.packs_failed') ||
      value.contains('wallet.purchases_failed')) {
    return text.walletPartialActivityUnavailable;
  }

  if (value.contains('payment_gateway_failed')) {
    return text.walletPaymentGatewayUnavailableError;
  }

  if (value.contains('wallet.payment_unavailable')) {
    return text.walletPaymentUnavailableError;
  }

  if (value.contains('economy.pack_not_found')) {
    return text.walletPackUnavailableError;
  }

  if (value.contains('redeem_code_not_found')) {
    return text.walletRedeemCodeNotFoundError;
  }

  if (value.contains('redeem_code_already_used')) {
    return text.walletRedeemCodeAlreadyUsedError;
  }

  if (value.contains('redeem_code_expired')) {
    return text.walletRedeemCodeExpiredError;
  }

  if (value.contains('redeem_code_inactive')) {
    return text.walletRedeemCodeInactiveError;
  }

  if (value.contains('redeem_code_exhausted')) {
    return text.walletRedeemCodeExhaustedError;
  }

  if (value.contains('redeem_code_user_limit_reached')) {
    return text.walletRedeemCodeUserLimitError;
  }

  if (value.contains('economy.insufficient_balance')) {
    return text.walletInsufficientBalanceError;
  }

  if (value.contains('wallet.network_unavailable')) {
    return text.walletRedeemOfflineError;
  }

  if (value.contains('wallet.server_unavailable')) {
    return text.walletRedeemServerError;
  }

  if (value.contains('wallet.request_failed') ||
      value.contains('appexception(400)')) {
    return text.walletRedeemServerError;
  }

  if (value.toLowerCase().contains('debugpaintbaselinesenabled')) {
    return text.walletDataUnavailableFallback;
  }

  if (value.contains('AppException(500)') ||
      value.contains('processing your request')) {
    return text.walletRedeemServerError;
  }

  return text.walletDataUnavailableFallback;
}

bool _isWalletPartialError(String value) {
  return value.contains('wallet.ledger_failed') ||
      value.contains('wallet.packs_failed') ||
      value.contains('wallet.purchases_failed');
}
