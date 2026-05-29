import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/data/premium_repository.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'load selects configured non-stripe provider when store products are available',
    () async {
      final repository = _FakePremiumRepository(
        config: _paywallConfig(
          methods: const [
            PremiumPaymentMethodModel(
              provider: PremiumPaymentProvider.googlePlay,
              purchaseChannel: 'in_app',
              platform: 'android',
              region: '*',
              isEnabled: true,
              isSelectedByDefault: true,
              requiresExternalWarning: false,
              requiresStoreDisclosure: false,
              isRecommended: true,
              bonusTokensPercent: 0,
            ),
          ],
        ),
        status: _status(provider: 'google_play', canManageSubscription: true),
        availabilityByProvider: {
          PremiumPaymentProvider.googlePlay: (
            isAvailable: true,
            productIds: {
              'com.petmagic.app.premium.monthly',
              'com.petmagic.app.premium.yearly',
            },
          ),
        },
      );

      final container = ProviderContainer(
        overrides: [
          premiumRepositoryProvider.overrideWithValue(repository),
          premiumRefreshProfileProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);

      await container.read(premiumControllerProvider.notifier).load();

      final state = container.read(premiumControllerProvider);
      expect(state.selectedProvider, PremiumPaymentProvider.googlePlay);
      expect(state.selectedPlan?.planCode, 'yearly');
      expect(state.canStartCheckout, isTrue);
    },
  );

  test('stripe checkout returns payment sheet payload for in-app flow', () async {
    final repository = _FakePremiumRepository(
      config: _paywallConfig(
        methods: const [
          PremiumPaymentMethodModel(
            provider: PremiumPaymentProvider.stripe,
            purchaseChannel: 'external_checkout',
            platform: 'android',
            region: '*',
            isEnabled: true,
            isSelectedByDefault: true,
            requiresExternalWarning: false,
            requiresStoreDisclosure: false,
            isRecommended: true,
            bonusTokensPercent: 0,
          ),
        ],
      ),
      status: _status(provider: 'stripe', canManageSubscription: false),
      stripeCheckout: const PremiumCheckoutModel(
        paymentProvider: 'stripe',
        checkoutUrl: '',
        status: 'pending',
        externalSubscriptionId: 'cs_test_123',
        paymentIntentClientSecret: 'pi_client_secret',
        customerId: 'cus_123',
        customerEphemeralKeySecret: 'ephkey_123',
        publishableKey: 'pk_test_123',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        premiumRepositoryProvider.overrideWithValue(repository),
        premiumRefreshProfileProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(container.dispose);

    await container.read(premiumControllerProvider.notifier).load();
    final checkout = await container
        .read(premiumControllerProvider.notifier)
        .startCheckout();

    final state = container.read(premiumControllerProvider);
    expect(checkout, isNotNull);
    expect(checkout?.usesPaymentSheet, isTrue);
    expect(state.externalUrl, isNull);
    expect(state.isBuying, isFalse);
  });
}

PremiumPaywallConfigModel _paywallConfig({
  required List<PremiumPaymentMethodModel> methods,
}) {
  return PremiumPaywallConfigModel(
    plans: const [
      PremiumPlanModel(
        planCode: 'monthly',
        billingInterval: 'month',
        priceAmount: 14.99,
        currencyCode: 'USD',
        tokenAllowance: 500,
        isPopular: false,
        sortOrder: 1,
        stripeCheckoutEnabled: true,
        googlePlayProductId: 'com.petmagic.app.premium.monthly',
        appStoreProductId: 'com.petmagic.app.premium.monthly',
      ),
      PremiumPlanModel(
        planCode: 'yearly',
        billingInterval: 'year',
        priceAmount: 99.99,
        currencyCode: 'USD',
        tokenAllowance: 1000,
        isPopular: true,
        sortOrder: 2,
        stripeCheckoutEnabled: true,
        googlePlayProductId: 'com.petmagic.app.premium.yearly',
        appStoreProductId: 'com.petmagic.app.premium.yearly',
      ),
    ],
    paymentMethods: methods,
    legalTexts: const PremiumLegalTextsModel(
      storeNotice: 'store',
      externalCheckoutNotice: 'external',
      stripeNotice: 'stripe',
    ),
    externalPaymentWarningRequired: false,
    recommendedPlanCode: 'yearly',
  );
}

PremiumStatusModel _status({
  required String provider,
  required bool canManageSubscription,
}) {
  return PremiumStatusModel(
    isPremium: false,
    canManageBilling: canManageSubscription,
    paymentProvider: provider,
    purchaseChannel: 'web',
    status: 'Active',
    planName: 'PetMagic Premium',
    billingPeriod: 'monthly',
    currentPeriodEndUtc: DateTime.utc(2026, 12, 1),
    cancelAtPeriodEnd: false,
    monthlyTokenLimit: 500,
    tokensAvailable: 120,
    canManageSubscription: canManageSubscription,
    manageSubscriptionAction: provider == 'stripe'
        ? 'StripeCustomerPortal'
        : 'GooglePlaySettings',
  );
}

class _FakePremiumRepository extends PremiumRepository {
  _FakePremiumRepository({
    required this.config,
    required this.status,
    this.stripeCheckout = const PremiumCheckoutModel(
      paymentProvider: 'stripe',
      checkoutUrl: '',
      status: 'pending',
      externalSubscriptionId: '',
      paymentIntentClientSecret: null,
      customerId: null,
      customerEphemeralKeySecret: null,
      publishableKey: null,
    ),
    this.availabilityByProvider = const {},
  }) : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final PremiumPaywallConfigModel config;
  final PremiumStatusModel status;
  final PremiumCheckoutModel stripeCheckout;
  final Map<
    PremiumPaymentProvider,
    ({bool isAvailable, Set<String> productIds})
  >
  availabilityByProvider;

  final _streamController = StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseUpdates => _streamController.stream;

  @override
  Future<PremiumPaywallConfigModel> fetchPaywallConfig({
    required Locale locale,
  }) async => config;

  @override
  Future<PremiumStatusModel> fetchStatus() async => status;

  @override
  Future<PremiumCheckoutModel> createStripeCheckout(
    PremiumPlanModel plan,
    Locale locale,
  ) async => stripeCheckout;

  @override
  Future<PremiumBillingPortalModel> createBillingPortal() async =>
      const PremiumBillingPortalModel(
        paymentProvider: 'stripe',
        portalUrl: 'https://billing.stripe.com/session/test',
      );

  @override
  Future<({bool isAvailable, Set<String> productIds})> fetchStoreAvailability(
    List<PremiumPlanModel> plans,
    PremiumPaymentProvider provider,
  ) async {
    return availabilityByProvider[provider] ??
        (isAvailable: false, productIds: <String>{});
  }

  @override
  Future<void> startStoreCheckout(
    PremiumPlanModel plan,
    PremiumPaymentProvider provider,
  ) async {}

  @override
  Future<void> restoreStorePurchases() async {}

  @override
  Future<PremiumStoreVerificationModel> verifyStorePurchase({
    required PremiumPlanModel plan,
    required PremiumPaymentProvider provider,
    required PurchaseDetails purchase,
  }) async {
    return PremiumStoreVerificationModel(
      paymentProvider: provider.value,
      productId: purchase.productID,
      isActive: true,
      status: 'Active',
      expiresAtUtc: DateTime.utc(2026, 12, 1),
    );
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}
}
