import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/payments/store_purchase.dart';
import 'package:petmagic_mobile/features/wallet/domain/pending_store_wallet_purchase.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';

final walletRepositoryProvider = Provider<WalletRepositoryPort>((ref) {
  throw StateError(
    'WalletRepositoryPort is not bound. Add the app composition overrides.',
  );
});

abstract interface class WalletRepositoryPort {
  Stream<List<StorePurchaseDetails>> get purchaseUpdates;
  Future<WalletStateModel> fetchWallet({RequestCancellation? cancelToken});
  Future<OffsetPagedModel<WalletLedgerItem>> fetchLedger({
    int skip = 0,
    int take = 20,
    RequestCancellation? cancelToken,
  });
  Future<RewardsSummaryModel> fetchRewards({RequestCancellation? cancelToken});
  Future<List<CurrencyPackModel>> fetchPacks();
  Future<WalletCheckoutConfigModel> fetchCheckoutConfig({
    required AppLocale locale,
    RequestCancellation? cancelToken,
  });
  Future<OffsetPagedModel<PurchaseHistoryItem>> fetchPurchases({
    int skip = 0,
    int take = 20,
    RequestCancellation? cancelToken,
  });
  Future<PurchaseHistoryItem> fetchPurchase(
    String orderId, {
    RequestCancellation? cancelToken,
  });
  Future<PurchaseCheckoutModel> createPurchase(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
    AppLocale locale, {
    RequestCancellation? cancelToken,
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
    required StorePurchaseDetails purchase,
  });
  Future<StoreBillingValidationModel> validateStorePurchase({
    required String provider,
    required StorePurchaseDetails purchase,
  });
  Future<void> savePendingStorePurchase(PendingStoreWalletPurchase purchase);
  Future<PendingStoreWalletPurchase?> readPendingStorePurchase();
  Future<void> clearPendingStorePurchase({String? orderId});
  Future<void> restoreStorePurchases();
  Future<void> completePurchase(StorePurchaseDetails purchase);
  Future<void> consumeVerifiedPurchase(StorePurchaseDetails purchase);
  Future<WalletStateModel> claimAdReward();
  Future<WalletStateModel> applyRedeemCode(String code);
  Future<RewardsSummaryModel> applyReferralCode(String code);
  Future<PurchaseHistoryItem> verifyStripeCheckoutSession({
    required String orderId,
    String? stripeReferenceId,
    RequestCancellation? cancelToken,
  });
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? locale,
  });
  Future<void> unregisterPushToken(String token);
}
