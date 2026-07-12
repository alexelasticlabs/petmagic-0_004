import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/payments/store_purchase.dart';
import 'package:petmagic_mobile/features/premium/domain/premium_models.dart';

final premiumRepositoryProvider = Provider<PremiumRepositoryPort>((ref) {
  throw StateError(
    'PremiumRepositoryPort is not bound. Add the app composition overrides.',
  );
});

abstract interface class PremiumRepositoryPort {
  Stream<List<StorePurchaseDetails>> get purchaseUpdates;
  Future<PremiumPaywallConfigModel> fetchPaywallConfig({
    required AppLocale locale,
    RequestCancellation? cancelToken,
  });
  Future<List<PremiumPlanModel>> fetchPlans();
  Future<PremiumStatusModel> fetchStatus({RequestCancellation? cancelToken});
  Future<PremiumCheckoutModel> createStripeCheckout(
    PremiumPlanModel plan,
    AppLocale locale, {
    RequestCancellation? cancelToken,
  });
  Future<PremiumBillingPortalModel> createBillingPortal({
    RequestCancellation? cancelToken,
  });
  Future<PremiumStatusModel> cancelSubscription({
    PremiumPaymentProvider provider = PremiumPaymentProvider.stripe,
    RequestCancellation? cancelToken,
  });
  Future<String> createManagementUrl(
    PremiumStatusModel status, {
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
    required StorePurchaseDetails purchase,
    RequestCancellation? cancelToken,
  });
  Future<void> verifyStripeSubscriptionCheckout({
    required String planCode,
    required String externalSubscriptionId,
    RequestCancellation? cancelToken,
  });
  Future<void> restoreStorePurchases();
  Future<void> completePurchase(StorePurchaseDetails purchase);
}
