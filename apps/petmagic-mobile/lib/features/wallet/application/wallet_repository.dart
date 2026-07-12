import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/features/wallet/domain/pending_store_wallet_purchase.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';

final walletRepositoryProvider = Provider<WalletRepositoryPort>((ref) {
  throw StateError(
    'WalletRepositoryPort is not bound. Add the app composition overrides.',
  );
});

abstract interface class WalletRepositoryPort {
  Stream<List<PurchaseDetails>> get purchaseUpdates;
  Future<WalletStateModel> fetchWallet({CancelToken? cancelToken});
  Future<OffsetPagedModel<WalletLedgerItem>> fetchLedger({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  });
  Future<RewardsSummaryModel> fetchRewards({CancelToken? cancelToken});
  Future<List<CurrencyPackModel>> fetchPacks();
  Future<WalletCheckoutConfigModel> fetchCheckoutConfig({
    required Locale locale,
    CancelToken? cancelToken,
  });
  Future<OffsetPagedModel<PurchaseHistoryItem>> fetchPurchases({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  });
  Future<PurchaseHistoryItem> fetchPurchase(
    String orderId, {
    CancelToken? cancelToken,
  });
  Future<PurchaseCheckoutModel> createPurchase(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
    Locale locale, {
    CancelToken? cancelToken,
  });
  Future<
    ({
      bool isAvailable,
      Set<String> productIds,
      Map<String, String> productPrices,
    })
  >
  fetchStoreAvailability(
    List<CurrencyPackModel> packs,
    WalletPaymentMethodModel paymentMethod,
  );
  Future<void> startStoreCheckout(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
  );
  Future<PurchaseHistoryItem> verifyStorePurchase({
    required String orderId,
    required WalletPaymentMethodModel paymentMethod,
    required PurchaseDetails purchase,
  });
  Future<StoreBillingValidationModel> validateStorePurchase({
    required String provider,
    required PurchaseDetails purchase,
  });
  Future<void> savePendingStorePurchase(PendingStoreWalletPurchase purchase);
  Future<PendingStoreWalletPurchase?> readPendingStorePurchase();
  Future<void> clearPendingStorePurchase({String? orderId});
  Future<void> restoreStorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
  Future<void> consumeVerifiedPurchase(PurchaseDetails purchase);
  Future<WalletStateModel> claimAdReward();
  Future<WalletStateModel> applyRedeemCode(String code);
  Future<RewardsSummaryModel> applyReferralCode(String code);
  Future<PurchaseHistoryItem> verifyStripeCheckoutSession({
    required String orderId,
    String? stripeReferenceId,
    CancelToken? cancelToken,
  });
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? locale,
  });
  Future<void> unregisterPushToken(String token);
}
