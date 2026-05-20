import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';

final walletControllerProvider =
    NotifierProvider<WalletController, WalletState>(WalletController.new);

class WalletState {
  const WalletState({
    this.wallet,
    this.ledger = const [],
    this.packs = const [],
    this.purchases = const [],
    this.paymentMethods = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.isBuying = false,
    this.isClaimingWeekly = false,
    this.isClaimingAd = false,
    this.isRedeeming = false,
    this.isSettingUpPaymentMethod = false,
    this.removingPaymentMethodId,
    this.errorMessage,
    this.checkoutUrl,
  });

  final WalletStateModel? wallet;
  final List<WalletLedgerItem> ledger;
  final List<CurrencyPackModel> packs;
  final List<PurchaseHistoryItem> purchases;
  final List<PaymentMethodModel> paymentMethods;
  final bool isLoading;
  final bool isRefreshing;
  final bool isBuying;
  final bool isClaimingWeekly;
  final bool isClaimingAd;
  final bool isRedeeming;
  final bool isSettingUpPaymentMethod;
  final String? removingPaymentMethodId;
  final String? errorMessage;
  final String? checkoutUrl;

  bool get isInitialLoading => isLoading && wallet == null;

  WalletState copyWith({
    WalletStateModel? wallet,
    List<WalletLedgerItem>? ledger,
    List<CurrencyPackModel>? packs,
    List<PurchaseHistoryItem>? purchases,
    List<PaymentMethodModel>? paymentMethods,
    bool? isLoading,
    bool? isRefreshing,
    bool? isBuying,
    bool? isClaimingWeekly,
    bool? isClaimingAd,
    bool? isRedeeming,
    bool? isSettingUpPaymentMethod,
    String? removingPaymentMethodId,
    String? errorMessage,
    String? checkoutUrl,
    bool clearError = false,
    bool clearCheckoutUrl = false,
    bool clearRemovingPaymentMethod = false,
  }) {
    return WalletState(
      wallet: wallet ?? this.wallet,
      ledger: ledger ?? this.ledger,
      packs: packs ?? this.packs,
      purchases: purchases ?? this.purchases,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isBuying: isBuying ?? this.isBuying,
      isClaimingWeekly: isClaimingWeekly ?? this.isClaimingWeekly,
      isClaimingAd: isClaimingAd ?? this.isClaimingAd,
      isRedeeming: isRedeeming ?? this.isRedeeming,
      isSettingUpPaymentMethod:
          isSettingUpPaymentMethod ?? this.isSettingUpPaymentMethod,
      removingPaymentMethodId: clearRemovingPaymentMethod
          ? null
          : removingPaymentMethodId ?? this.removingPaymentMethodId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      checkoutUrl: clearCheckoutUrl ? null : checkoutUrl ?? this.checkoutUrl,
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
      final results = await Future.wait<Object>([
        _repository.fetchWallet(),
        _repository.fetchLedger(take: 24),
        _repository.fetchPacks(),
        _repository.fetchPurchases(take: 12),
      ]);

      final wallet = results[0] as WalletStateModel;
      final ledger = results[1] as OffsetPagedModel<WalletLedgerItem>;
      final packs = results[2] as List<CurrencyPackModel>;
      final purchases = results[3] as OffsetPagedModel<PurchaseHistoryItem>;
      var paymentMethods = state.paymentMethods;

      try {
        paymentMethods = await _repository.fetchPaymentMethods();
      } catch (_) {
        // Saved cards are an optional capability. Keep the wallet usable even
        // if the payment-method endpoint is temporarily unavailable.
      }

      state = state.copyWith(
        wallet: wallet,
        ledger: ledger.items,
        packs: packs,
        purchases: purchases.items,
        paymentMethods: paymentMethods,
        isLoading: false,
        isRefreshing: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<String?> buyPack(
    CurrencyPackModel pack, {
    String? paymentMethodId,
  }) async {
    state = state.copyWith(
      isBuying: true,
      clearError: true,
      clearCheckoutUrl: true,
    );

    try {
      final checkout = await _repository.createPurchase(
        pack,
        paymentMethodId: paymentMethodId,
      );
      state = state.copyWith(
        isBuying: false,
        checkoutUrl: checkout.checkoutUrl,
      );
      unawaited(load(refresh: true));
      return checkout.checkoutUrl;
    } catch (error) {
      state = state.copyWith(isBuying: false, errorMessage: error.toString());
      return null;
    }
  }

  Future<void> claimWeeklyGrant() async {
    state = state.copyWith(isClaimingWeekly: true, clearError: true);

    try {
      final wallet = await _repository.claimWeeklyGrant();
      final ledger = await _repository.fetchLedger(take: 24);
      state = state.copyWith(
        wallet: wallet,
        ledger: ledger.items,
        isClaimingWeekly: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isClaimingWeekly: false,
        errorMessage: error.toString(),
      );
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

  Future<void> applyRedeemCode(String code) async {
    if (code.trim().isEmpty) {
      return;
    }

    state = state.copyWith(isRedeeming: true, clearError: true);

    try {
      final wallet = await _repository.applyRedeemCode(code);
      final ledger = await _repository.fetchLedger(take: 24);
      state = state.copyWith(
        wallet: wallet,
        ledger: ledger.items,
        isRedeeming: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isRedeeming: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<String?> createPaymentMethodSetup() async {
    state = state.copyWith(
      isSettingUpPaymentMethod: true,
      clearError: true,
      clearCheckoutUrl: true,
    );

    try {
      final setup = await _repository.createPaymentMethodSetup();
      state = state.copyWith(
        isSettingUpPaymentMethod: false,
        checkoutUrl: setup.checkoutUrl,
      );
      return setup.checkoutUrl;
    } catch (error) {
      state = state.copyWith(
        isSettingUpPaymentMethod: false,
        errorMessage: error.toString(),
      );
      return null;
    }
  }

  Future<void> removePaymentMethod(String paymentMethodId) async {
    state = state.copyWith(
      removingPaymentMethodId: paymentMethodId,
      clearError: true,
    );

    try {
      await _repository.removePaymentMethod(paymentMethodId);
      final paymentMethods = await _repository.fetchPaymentMethods();
      state = state.copyWith(
        paymentMethods: paymentMethods,
        clearError: true,
        clearRemovingPaymentMethod: true,
      );
    } catch (error) {
      state = state.copyWith(
        errorMessage: error.toString(),
        clearRemovingPaymentMethod: true,
      );
    }
  }

  void clearCheckoutUrl() {
    state = state.copyWith(clearCheckoutUrl: true);
  }
}
