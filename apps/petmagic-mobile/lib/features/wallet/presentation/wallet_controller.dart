import 'dart:async';

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
    bool clearError = false,
    bool clearCheckoutUrl = false,
    bool clearPendingCheckout = false,
    bool clearCheckoutGrantedSpark = false,
    bool clearCheckoutError = false,
    bool clearHighlightedPurchaseOrderId = false,
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
    );
  }
}

class WalletController extends Notifier<WalletState> {
  late final WalletRepository _repository;

  @override
  WalletState build() {
    _repository = ref.watch(walletRepositoryProvider);
    return const WalletState(isLoading: true);
  }

  Future<void> load({bool refresh = false}) async {
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

  Future<String?> buyPack(CurrencyPackModel pack) async {
    final paymentMethod = state.selectedPaymentMethod;
    if (paymentMethod == null) {
      state = state.copyWith(errorMessage: 'wallet.payment_unavailable');
      return null;
    }

    state = state.copyWith(
      isBuying: true,
      clearError: true,
      clearCheckoutUrl: true,
      clearPendingCheckout: true,
      checkoutVerificationState: WalletCheckoutVerificationState.idle,
      clearCheckoutGrantedSpark: true,
      clearCheckoutError: true,
      clearHighlightedPurchaseOrderId: true,
    );

    try {
      final checkout = await _repository.createPurchase(
        pack,
        paymentMethod,
        WidgetsBinding.instance.platformDispatcher.locale,
      );
      state = state.copyWith(
        isBuying: false,
        checkoutUrl: checkout.checkoutUrl,
        pendingCheckoutOrderId: checkout.orderId,
      );
      unawaited(load(refresh: true));
      return checkout.checkoutUrl;
    } catch (error) {
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
    );

    await load(refresh: true);

    final refreshedState = state;
    if (refreshedState.wallet == null && refreshedState.errorMessage != null) {
      state = state.copyWith(
        checkoutVerificationState: WalletCheckoutVerificationState.error,
        checkoutErrorMessage: refreshedState.errorMessage,
      );
      return;
    }

    PurchaseHistoryItem? purchase;
    for (final item in refreshedState.purchases) {
      if (item.orderId == pendingOrderId) {
        purchase = item;
        break;
      }
    }

    if (purchase != null && purchase.status == 'succeeded') {
      state = state.copyWith(
        checkoutVerificationState: WalletCheckoutVerificationState.succeeded,
        checkoutGrantedSpark: purchase.sparkToGrant,
        highlightedPurchaseOrderId: purchase.orderId,
        clearPendingCheckout: true,
        clearCheckoutError: true,
      );
      return;
    }

    state = state.copyWith(
      checkoutVerificationState: WalletCheckoutVerificationState.pending,
      clearCheckoutError: true,
    );
  }
}
