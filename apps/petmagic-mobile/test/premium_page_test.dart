import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/data/premium_repository.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';

void main() {
  testWidgets('premium page renders monthly/yearly plans and manage action', (
    tester,
  ) async {
    final repository = _FakePremiumRepository(
      config: const PremiumPaywallConfigModel(
        plans: [
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
        paymentMethods: [
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
        legalTexts: PremiumLegalTextsModel(
          storeNotice: 'store',
          externalCheckoutNotice: 'external',
          stripeNotice: 'stripe',
        ),
        externalPaymentWarningRequired: false,
        recommendedPlanCode: 'yearly',
      ),
      status: PremiumStatusModel(
        isPremium: true,
        canManageBilling: true,
        paymentProvider: 'stripe',
        purchaseChannel: 'external_checkout',
        status: 'Active',
        planName: 'PetMagic Premium Yearly',
        billingPeriod: 'yearly',
        currentPeriodEndUtc: DateTime.utc(2026, 12, 1),
        cancelAtPeriodEnd: false,
        monthlyTokenLimit: 1000,
        tokensAvailable: 800,
        canManageSubscription: true,
        manageSubscriptionAction: 'StripeCustomerPortal',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumRepositoryProvider.overrideWithValue(repository),
          premiumRefreshProfileProvider.overrideWithValue(() async {}),
        ],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          locale: const Locale('ru'),
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const PremiumPage(),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Restore purchases'), findsWidgets);
  });
}

class _FakePremiumRepository extends PremiumRepository {
  _FakePremiumRepository({required this.config, required this.status})
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final PremiumPaywallConfigModel config;
  final PremiumStatusModel status;

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
  ) async {
    return const PremiumCheckoutModel(
      paymentProvider: 'stripe',
      checkoutUrl: 'https://checkout.stripe.com/c/pay/cs_test_123',
      status: 'pending',
      externalSubscriptionId: 'cs_test_123',
      paymentIntentClientSecret: null,
      customerId: null,
      customerEphemeralKeySecret: null,
      publishableKey: null,
    );
  }

  @override
  Future<({bool isAvailable, Set<String> productIds})> fetchStoreAvailability(
    List<PremiumPlanModel> plans,
    PremiumPaymentProvider provider,
  ) async {
    return (isAvailable: false, productIds: <String>{});
  }
}
