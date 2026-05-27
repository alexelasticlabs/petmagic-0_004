import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';

final walletControllerProvider =
    NotifierProvider<WalletController, WalletState>(WalletController.new);

enum WalletCheckoutVerificationState {
  idle,
  checking,
  succeeded,
  pending,
  error,
}

class WalletState {
  const WalletState({
    this.wallet,
    this.rewards,
    this.ledger = const [],
    this.packs = const [],
    this.paymentMethods = const [],
    this.purchases = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.isBuying = false,
    this.isClaimingAd = false,
    this.isRedeeming = false,
    this.isApplyingReferral = false,
    this.errorMessage,
    this.checkoutUrl,
    this.pendingCheckoutOrderId,
    this.checkoutVerificationState = WalletCheckoutVerificationState.idle,
    this.checkoutGrantedSpark,
    this.checkoutErrorMessage,
    this.highlightedPurchaseOrderId,
    this.checkoutProgressMessage,
    this.checkoutVerificationStartedAt,
  });

  final WalletStateModel? wallet;
  final RewardsSummaryModel? rewards;
  final List<WalletLedgerItem> ledger;
  final List<CurrencyPackModel> packs;
  final List<WalletPaymentMethodModel> paymentMethods;
  final List<PurchaseHistoryItem> purchases;
  final bool isLoading;
  final bool isRefreshing;
  final bool isBuying;
  final bool isClaimingAd;
  final bool isRedeeming;
  final bool isApplyingReferral;
  final String? errorMessage;
  final String? checkoutUrl;
  final String? pendingCheckoutOrderId;
  final WalletCheckoutVerificationState checkoutVerificationState;
  final int? checkoutGrantedSpark;
  final String? checkoutErrorMessage;
  final String? highlightedPurchaseOrderId;
  final String? checkoutProgressMessage;
  final DateTime? checkoutVerificationStartedAt;

  bool get isInitialLoading => isLoading && wallet == null;

  WalletPaymentMethodModel? get selectedPaymentMethod {
    final enabledStripeMethods = paymentMethods
        .where((method) => method.isEnabled && method.isStripe)
        .toList(growable: false);
    if (enabledStripeMethods.isEmpty) {
      return null;
    }

    return enabledStripeMethods
            .where((method) => method.isSelectedByDefault)
            .cast<WalletPaymentMethodModel?>()
            .firstOrNull ??
        enabledStripeMethods
            .where((method) => method.isRecommended)
            .cast<WalletPaymentMethodModel?>()
            .firstOrNull ??
        enabledStripeMethods.first;
  }

  WalletState copyWith({
    WalletStateModel? wallet,
    RewardsSummaryModel? rewards,
    List<WalletLedgerItem>? ledger,
    List<CurrencyPackModel>? packs,
    List<WalletPaymentMethodModel>? paymentMethods,
    List<PurchaseHistoryItem>? purchases,
    bool? isLoading,
    bool? isRefreshing,
    bool? isBuying,
    bool? isClaimingAd,
    bool? isRedeeming,
    bool? isApplyingReferral,
    String? errorMessage,
    String? checkoutUrl,
    String? pendingCheckoutOrderId,
    WalletCheckoutVerificationState? checkoutVerificationState,
    int? checkoutGrantedSpark,
    String? checkoutErrorMessage,
    String? highlightedPurchaseOrderId,
    String? checkoutProgressMessage,
    DateTime? checkoutVerificationStartedAt,
    bool clearError = false,
    bool clearCheckoutUrl = false,
    bool clearPendingCheckout = false,
    bool clearCheckoutGrantedSpark = false,
    bool clearCheckoutError = false,
    bool clearHighlightedPurchaseOrderId = false,
    bool clearCheckoutProgressMessage = false,
    bool clearCheckoutVerificationStartedAt = false,
  }) {
    return WalletState(
      wallet: wallet ?? this.wallet,
      rewards: rewards ?? this.rewards,
      ledger: ledger ?? this.ledger,
      packs: packs ?? this.packs,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      purchases: purchases ?? this.purchases,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isBuying: isBuying ?? this.isBuying,
      isClaimingAd: isClaimingAd ?? this.isClaimingAd,
      isRedeeming: isRedeeming ?? this.isRedeeming,
      isApplyingReferral: isApplyingReferral ?? this.isApplyingReferral,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      checkoutUrl: clearCheckoutUrl ? null : checkoutUrl ?? this.checkoutUrl,
      pendingCheckoutOrderId: clearPendingCheckout
          ? null
          : pendingCheckoutOrderId ?? this.pendingCheckoutOrderId,
      checkoutVerificationState:
          checkoutVerificationState ?? this.checkoutVerificationState,
      checkoutGrantedSpark: clearCheckoutGrantedSpark
          ? null
          : checkoutGrantedSpark ?? this.checkoutGrantedSpark,
      checkoutErrorMessage: clearCheckoutError
          ? null
          : checkoutErrorMessage ?? this.checkoutErrorMessage,
      highlightedPurchaseOrderId: clearHighlightedPurchaseOrderId
          ? null
          : highlightedPurchaseOrderId ?? this.highlightedPurchaseOrderId,
      checkoutProgressMessage: clearCheckoutProgressMessage
          ? null
          : checkoutProgressMessage ?? this.checkoutProgressMessage,
      checkoutVerificationStartedAt: clearCheckoutVerificationStartedAt
          ? null
          : checkoutVerificationStartedAt ?? this.checkoutVerificationStartedAt,
    );
  }
}

class WalletController extends Notifier<WalletState> {
  late final WalletRepository _repository;
  Future<void>? _loadInFlight;

  @override
  WalletState build() {
    _repository = ref.watch(walletRepositoryProvider);
    return const WalletState(isLoading: true);
  }

  Future<void> load({bool refresh = false}) async {
    final inFlight = _loadInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final operation = _performLoad(refresh: refresh);
    _loadInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_loadInFlight, operation)) {
        _loadInFlight = null;
      }
    }
  }

  Future<void> _performLoad({required bool refresh}) async {
    state = state.copyWith(
      isLoading: !refresh,
      isRefreshing: refresh,
      clearError: true,
      clearCheckoutUrl: true,
    );

    try {
      final wallet = await _repository.fetchWallet();
      var ledger = const <WalletLedgerItem>[];
      RewardsSummaryModel? rewards;
      var packs = const <CurrencyPackModel>[];
      var paymentMethods = const <WalletPaymentMethodModel>[];
      var purchases = const <PurchaseHistoryItem>[];
      String? softError;

      await Future.wait<void>([
        () async {
          try {
            ledger = (await _repository.fetchLedger(take: 24)).items;
          } catch (_) {
            softError ??= 'wallet.ledger_failed';
          }
        }(),
        () async {
          try {
            rewards = await _repository.fetchRewards();
          } catch (_) {
            softError ??= 'rewards.summary_failed';
          }
        }(),
        () async {
          try {
            final config = await _repository.fetchCheckoutConfig(
              locale: WidgetsBinding.instance.platformDispatcher.locale,
            );
            packs = config.packs;
            paymentMethods = config.paymentMethods;
          } catch (_) {
            softError ??= 'wallet.packs_failed';
          }
        }(),
        () async {
          try {
            purchases = (await _repository.fetchPurchases(take: 12)).items;
          } catch (_) {
            softError ??= 'wallet.purchases_failed';
          }
        }(),
      ]);

      state = state.copyWith(
        wallet: wallet,
        rewards: rewards,
        ledger: ledger,
        packs: packs,
        paymentMethods: paymentMethods,
        purchases: purchases,
        isLoading: false,
        isRefreshing: false,
        errorMessage: softError,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<PurchaseCheckoutModel?> buyPack(CurrencyPackModel pack) async {
    final paymentMethod = state.selectedPaymentMethod;
    if (paymentMethod == null) {
      developer.log(
        'Checkout blocked: no enabled Stripe payment method (pack=${pack.code}, methods=${state.paymentMethods.length})',
        name: 'PetMagic.Wallet.Checkout',
      );
      state = state.copyWith(errorMessage: 'wallet.payment_unavailable');
      return null;
    }

    developer.log(
      'Checkout start (pack=${pack.code}, provider=${paymentMethod.provider}, currency=${pack.currencyCode}, amount=${pack.priceAmount})',
      name: 'PetMagic.Wallet.Checkout',
    );

    state = state.copyWith(
      isBuying: true,
      clearError: true,
      clearCheckoutUrl: true,
      clearPendingCheckout: true,
      checkoutVerificationState: WalletCheckoutVerificationState.idle,
      clearCheckoutGrantedSpark: true,
      clearCheckoutError: true,
      clearHighlightedPurchaseOrderId: true,
      clearCheckoutProgressMessage: true,
      clearCheckoutVerificationStartedAt: true,
    );

    try {
      final checkout = await _repository.createPurchase(
        pack,
        paymentMethod,
        WidgetsBinding.instance.platformDispatcher.locale,
      );

      developer.log(
        'Checkout response (order=${checkout.orderId}, status=${checkout.status}, urlLength=${checkout.checkoutUrl.length})',
        name: 'PetMagic.Wallet.Checkout',
      );

      final checkoutUrl = checkout.checkoutUrl.trim();
      if (checkoutUrl.isEmpty && !checkout.usesPaymentSheet) {
        final payload = <String, Object>{
          'pack_id': pack.packId,
          'pack_code': pack.code,
          'provider': paymentMethod.provider,
          'order_id': checkout.orderId,
          'status': checkout.status,
        };
        developer.Timeline.instantSync(
          'petmagic.wallet.checkout_empty_url',
          arguments: payload,
        );
        developer.log(
          'Empty checkout URL from purchase create API '
          '(pack=${pack.code}, provider=${paymentMethod.provider}, order=${checkout.orderId}, status=${checkout.status})',
          name: 'PetMagic.Wallet.Checkout',
          error: 'wallet.checkout_empty_url',
        );

        state = state.copyWith(
          isBuying: false,
          clearCheckoutUrl: true,
          clearPendingCheckout: true,
          errorMessage: 'payment_gateway_failed',
        );
        return null;
      }

      state = state.copyWith(
        isBuying: false,
        checkoutUrl: checkoutUrl,
        pendingCheckoutOrderId: checkout.orderId,
      );
      return checkout;
    } catch (error) {
      developer.log(
        'Checkout failed (pack=${pack.code}, provider=${paymentMethod.provider})',
        name: 'PetMagic.Wallet.Checkout',
        error: error,
      );
      state = state.copyWith(isBuying: false, errorMessage: error.toString());
      return null;
    }
  }

  Future<void> claimAdReward() async {
    state = state.copyWith(isClaimingAd: true, clearError: true);

    try {
      final wallet = await _repository.claimAdReward();
      final ledger = await _repository.fetchLedger(take: 24);
      state = state.copyWith(
        wallet: wallet,
        ledger: ledger.items,
        isClaimingAd: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isClaimingAd: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<String?> applyRedeemCode(String code) async {
    if (code.trim().isEmpty) {
      return null;
    }

    state = state.copyWith(isRedeeming: true, clearError: true);

    try {
      final wallet = await _repository.applyRedeemCode(code);
      final ledger = await _repository.fetchLedger(take: 24);
      final rewards = await _repository.fetchRewards();
      state = state.copyWith(
        wallet: wallet,
        rewards: rewards,
        ledger: ledger.items,
        isRedeeming: false,
        clearError: true,
      );
      return null;
    } catch (error) {
      state = state.copyWith(
        isRedeeming: false,
        errorMessage: error.toString(),
      );
      return error.toString();
    }
  }

  Future<String?> applyReferralCode(String code) async {
    if (code.trim().isEmpty) {
      return null;
    }

    state = state.copyWith(isApplyingReferral: true, clearError: true);

    try {
      final rewards = await _repository.applyReferralCode(code);
      state = state.copyWith(
        rewards: rewards,
        isApplyingReferral: false,
        clearError: true,
      );
      return null;
    } catch (error) {
      state = state.copyWith(
        isApplyingReferral: false,
        errorMessage: error.toString(),
      );
      return error.toString();
    }
  }

  void consumeCheckoutUrl() {
    state = state.copyWith(clearCheckoutUrl: true);
  }

  void resetCheckoutVerification() {
    state = state.copyWith(
      checkoutVerificationState: WalletCheckoutVerificationState.idle,
      clearCheckoutGrantedSpark: true,
      clearCheckoutError: true,
      clearHighlightedPurchaseOrderId: true,
      clearCheckoutProgressMessage: true,
      clearCheckoutVerificationStartedAt: true,
    );
  }

  Future<void> verifyCheckoutStatus() async {
    final pendingOrderId = state.pendingCheckoutOrderId;
    if (pendingOrderId == null || pendingOrderId.isEmpty) {
      return;
    }

    state = state.copyWith(
      checkoutVerificationState: WalletCheckoutVerificationState.checking,
      clearCheckoutGrantedSpark: true,
      clearCheckoutError: true,
      clearHighlightedPurchaseOrderId: true,
      checkoutProgressMessage: 'Checking payment status...',
      checkoutVerificationStartedAt: DateTime.now().toUtc(),
    );

    const maxAttempts = 6;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      state = state.copyWith(
        checkoutProgressMessage:
            'Checking payment status: attempt ${attempt + 1}/$maxAttempts',
      );

      try {
        final purchase = await _repository.fetchPurchase(pendingOrderId);
        if (purchase.status == 'succeeded') {
          await load(refresh: true);
          state = state.copyWith(
            checkoutVerificationState:
                WalletCheckoutVerificationState.succeeded,
            checkoutGrantedSpark: purchase.sparkToGrant,
            highlightedPurchaseOrderId: purchase.orderId,
            clearPendingCheckout: true,
            clearCheckoutError: true,
            clearCheckoutProgressMessage: true,
            clearCheckoutVerificationStartedAt: true,
          );
          return;
        }
      } catch (error) {
        state = state.copyWith(
          checkoutVerificationState: WalletCheckoutVerificationState.error,
          checkoutErrorMessage: error.toString(),
          clearCheckoutProgressMessage: true,
          clearCheckoutVerificationStartedAt: true,
        );
        return;
      }

      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    state = state.copyWith(
      checkoutVerificationState: WalletCheckoutVerificationState.pending,
      clearCheckoutError: true,
      checkoutProgressMessage: 'Payment confirmation is still processing.',
    );
  }

  Future<void> verifyStripeCheckout(String? stripeReferenceId) async {
    final pendingOrderId = state.pendingCheckoutOrderId;
    if (pendingOrderId == null || pendingOrderId.isEmpty) {
      return;
    }

    state = state.copyWith(
      checkoutVerificationState: WalletCheckoutVerificationState.checking,
      clearCheckoutGrantedSpark: true,
      clearCheckoutError: true,
      clearHighlightedPurchaseOrderId: true,
      checkoutProgressMessage: 'Checking payment at Stripe...',
      checkoutVerificationStartedAt: DateTime.now().toUtc(),
    );

    const maxAttempts = 5;
    final normalizedReference = stripeReferenceId?.trim();

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      state = state.copyWith(
        checkoutProgressMessage:
            'Checking payment at Stripe: attempt ${attempt + 1}/$maxAttempts',
      );

      try {
        final purchase = await _repository.verifyStripeCheckoutSession(
          orderId: pendingOrderId,
          stripeReferenceId: normalizedReference,
        );

        if (purchase.status == 'succeeded') {
          await load(refresh: true);
          state = state.copyWith(
            checkoutVerificationState:
                WalletCheckoutVerificationState.succeeded,
            checkoutGrantedSpark: purchase.sparkToGrant,
            highlightedPurchaseOrderId: purchase.orderId,
            clearPendingCheckout: true,
            clearCheckoutError: true,
            clearCheckoutProgressMessage: true,
            clearCheckoutVerificationStartedAt: true,
          );
          return;
        }
      } catch (error) {
        developer.log(
          'Stripe verify attempt failed (order=$pendingOrderId, attempt=${attempt + 1}, reference=${normalizedReference ?? ''})',
          name: 'PetMagic.Wallet.Checkout',
          error: error,
        );
      }

      try {
        final purchase = await _repository.fetchPurchase(pendingOrderId);
        if (purchase.status == 'succeeded') {
          await load(refresh: true);
          state = state.copyWith(
            checkoutVerificationState:
                WalletCheckoutVerificationState.succeeded,
            checkoutGrantedSpark: purchase.sparkToGrant,
            highlightedPurchaseOrderId: purchase.orderId,
            clearPendingCheckout: true,
            clearCheckoutError: true,
            clearCheckoutProgressMessage: true,
            clearCheckoutVerificationStartedAt: true,
          );
          return;
        }
      } catch (_) {
        // Keep retrying verify endpoint; failures here should not interrupt confirmation loop.
      }

      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    await verifyCheckoutStatus();
  }
}
