import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/features/premium/domain/premium_models.dart';

final premiumRepositoryProvider = Provider<PremiumRepositoryPort>((ref) {
  throw StateError(
    'PremiumRepositoryPort is not bound. Add the app composition overrides.',
  );
});

abstract interface class PremiumRepositoryPort {
  Stream<List<PurchaseDetails>> get purchaseUpdates;
  Future<PremiumPaywallConfigModel> fetchPaywallConfig({
    required Locale locale,
    CancelToken? cancelToken,
  });
  Future<List<PremiumPlanModel>> fetchPlans();
  Future<PremiumStatusModel> fetchStatus({CancelToken? cancelToken});
  Future<PremiumCheckoutModel> createStripeCheckout(
    PremiumPlanModel plan,
    Locale locale, {
    CancelToken? cancelToken,
  });
  Future<PremiumBillingPortalModel> createBillingPortal({
    CancelToken? cancelToken,
  });
  Future<PremiumStatusModel> cancelSubscription({
    PremiumPaymentProvider provider = PremiumPaymentProvider.stripe,
    CancelToken? cancelToken,
  });
  Future<String> createManagementUrl(
    PremiumStatusModel status, {
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
    List<PremiumPlanModel> plans,
    PremiumPaymentProvider provider,
  );
  Future<void> startStoreCheckout(
    PremiumPlanModel plan,
    PremiumPaymentProvider provider,
  );
  Future<PremiumStoreVerificationModel> verifyStorePurchase({
    required PremiumPlanModel plan,
    required PremiumPaymentProvider provider,
    required PurchaseDetails purchase,
    CancelToken? cancelToken,
  });
  Future<void> verifyStripeSubscriptionCheckout({
    required String planCode,
    required String externalSubscriptionId,
    CancelToken? cancelToken,
  });
  Future<void> restoreStorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
}
