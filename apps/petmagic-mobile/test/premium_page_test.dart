import 'dart:async';
import 'dart:io';

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
  test('premium animated background stays in a dedicated part file', () {
    final pageSource = File(
      'lib/features/premium/presentation/premium_page.dart',
    ).readAsStringSync();
    final contentSource = File(
      'lib/features/premium/presentation/premium_page_content.part.dart',
    ).readAsStringSync();
    final backgroundSource = File(
      'lib/features/premium/presentation/premium_page_background.part.dart',
    ).readAsStringSync();

    expect(pageSource, contains("part 'premium_page_background.part.dart';"));
    expect(contentSource, isNot(contains('class _PremiumGoldenBackground')));
    expect(contentSource, isNot(contains('class _PremiumSparkleLayer')));
    expect(contentSource, isNot(contains('class _PremiumSparklePainter')));
    expect(backgroundSource, contains("part of 'premium_page.dart';"));
    expect(backgroundSource, contains('class _PremiumGoldenBackground'));
    expect(backgroundSource, contains('class _PremiumSparkleLayer'));
    expect(backgroundSource, contains('class _PremiumSparklePainter'));
  });

  test('premium plan cards stay in a dedicated part file', () {
    final pageSource = File(
      'lib/features/premium/presentation/premium_page.dart',
    ).readAsStringSync();
    final contentSource = File(
      'lib/features/premium/presentation/premium_page_content.part.dart',
    ).readAsStringSync();
    final plansSource = File(
      'lib/features/premium/presentation/premium_page_plans.part.dart',
    ).readAsStringSync();

    expect(pageSource, contains("part 'premium_page_plans.part.dart';"));
    expect(contentSource, isNot(contains('class _PlansSection')));
    expect(contentSource, isNot(contains('class _PlanCard')));
    expect(contentSource, isNot(contains('class _BillingChip')));
    expect(plansSource, contains("part of 'premium_page.dart';"));
    expect(plansSource, contains('class _PlansSection'));
    expect(plansSource, contains('class _PlanCard'));
    expect(plansSource, contains('class _BillingChip'));
    expect(plansSource, contains('bool _isYearlyPlan'));
  });

  test('premium hero and benefits stay in dedicated section parts', () {
    final pageSource = File(
      'lib/features/premium/presentation/premium_page.dart',
    ).readAsStringSync();
    final contentSource = File(
      'lib/features/premium/presentation/premium_page_content.part.dart',
    ).readAsStringSync();
    final sectionsSource = File(
      'lib/features/premium/presentation/premium_page_sections.part.dart',
    ).readAsStringSync();

    expect(pageSource, contains("part 'premium_page_sections.part.dart';"));
    expect(contentSource, isNot(contains('class _Header')));
    expect(contentSource, isNot(contains('class _HeroBlock')));
    expect(contentSource, isNot(contains('class _ComparisonCard')));
    expect(contentSource, isNot(contains('class _BenefitsSection')));
    expect(contentSource, isNot(contains('class _BenefitItem')));
    expect(sectionsSource, contains("part of 'premium_page.dart';"));
    expect(sectionsSource, contains('class _Header'));
    expect(sectionsSource, contains('class _HeroBlock'));
    expect(sectionsSource, contains('class _ComparisonCard'));
    expect(sectionsSource, contains('class _BenefitsSection'));
    expect(sectionsSource, contains('class _BenefitItem'));
  });

  test('premium CTA and footer stay in dedicated part files', () {
    final pageSource = File(
      'lib/features/premium/presentation/premium_page.dart',
    ).readAsStringSync();
    final contentSource = File(
      'lib/features/premium/presentation/premium_page_content.part.dart',
    ).readAsStringSync();
    final ctaSource = File(
      'lib/features/premium/presentation/premium_page_cta.part.dart',
    ).readAsStringSync();
    final footerSource = File(
      'lib/features/premium/presentation/premium_page_footer.part.dart',
    ).readAsStringSync();

    expect(pageSource, contains("part 'premium_page_cta.part.dart';"));
    expect(pageSource, contains("part 'premium_page_footer.part.dart';"));
    expect(contentSource, isNot(contains('class _CtaButton')));
    expect(contentSource, isNot(contains('class _FadeSlideIn')));
    expect(contentSource, isNot(contains('class _Footer')));
    expect(contentSource, isNot(contains('class _Link')));
    expect(ctaSource, contains("part of 'premium_page.dart';"));
    expect(ctaSource, contains('class _CtaButton'));
    expect(ctaSource, contains('class _FadeSlideIn'));
    expect(footerSource, contains("part of 'premium_page.dart';"));
    expect(footerSource, contains('class _Footer'));
    expect(footerSource, contains('class _Link'));
  });

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
    CancelToken? cancelToken,
  }) async => config;

  @override
  Future<PremiumStatusModel> fetchStatus({CancelToken? cancelToken}) async =>
      status;

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
  ) async {
    return (
      isAvailable: false,
      productIds: <String>{},
      productPrices: <String, String>{},
    );
  }
}
