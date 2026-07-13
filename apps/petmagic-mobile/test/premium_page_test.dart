import 'dart:async';
import 'package:petmagic_mobile/core/payments/store_purchase.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/domain/premium_models.dart';
import 'package:petmagic_mobile/features/premium/data/premium_repository.dart';
import 'package:petmagic_mobile/features/premium/application/premium_controller.dart';
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
    expect(plansSource, contains('NumberFormat.simpleCurrency('));
    expect(
      plansSource,
      isNot(
        contains(r"displayPrice ?? '\$${plan.priceAmount.toStringAsFixed(2)}'"),
      ),
    );
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

  test('premium provider fallback labels use shared localizations', () {
    final checkoutSource = File(
      'lib/features/premium/presentation/premium_page_checkout.part.dart',
    ).readAsStringSync();

    expect(checkoutSource, contains('text.premiumPaymentStripe'));
    expect(checkoutSource, contains('text.premiumPaymentGooglePlay'));
    expect(checkoutSource, contains('text.premiumPaymentApple'));
    expect(checkoutSource, isNot(contains("=> 'Stripe'")));
    expect(checkoutSource, isNot(contains("=> 'Google Play'")));
    expect(checkoutSource, isNot(contains("=> 'App Store'")));
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
    expect(
      footerSource,
      contains('state.selectedProvider == PremiumPaymentProvider.stripe'),
    );
    expect(footerSource, contains('text.premiumCardPaymentDisclaimerTitle'));
    expect(footerSource, contains('text.premiumCardPaymentDisclaimerBody'));
    expect(footerSource, contains('text.premiumStorePaymentDisclaimerTitle'));
    expect(footerSource, contains('text.premiumStorePaymentDisclaimerBody'));
  });

  test(
    'premium CTA foreground uses theme contrast for custom gradient tones',
    () {
      final ctaSource = File(
        'lib/features/premium/presentation/premium_page_cta.part.dart',
      ).readAsStringSync();

      expect(ctaSource, contains('context.petMagicColors'));
      expect(ctaSource, contains('colors.on(gradientEnd)'));
      expect(ctaSource, isNot(contains('final btnTextColor = isDark')));
      expect(ctaSource, isNot(contains('Colors.white')));
    },
  );

  test('premium CTA keeps localized provider labels inside button bounds', () {
    final ctaSource = File(
      'lib/features/premium/presentation/premium_page_cta.part.dart',
    ).readAsStringSync();

    expect(ctaSource, contains('Flexible('));
    expect(ctaSource, contains('maxLines: 1'));
    expect(ctaSource, contains('overflow: TextOverflow.ellipsis'));
    expect(
      ctaSource,
      contains(
        'padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18)',
      ),
    );
    expect(ctaSource, isNot(contains('letterSpacing: -0.2')));
  });

  test('premium page reports a completed purchase restore to the user', () {
    final pageSource = File(
      'lib/features/premium/presentation/premium_page.dart',
    ).readAsStringSync();

    expect(pageSource, contains("'premium.restore_started'"));
    expect(pageSource, contains('fallbackText.premiumRestoreStarted'));
    expect(pageSource, contains('PetMagicToastTone.success'));
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
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
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

  testWidgets(
    'premium page skips eager reload when premium snapshot is already hydrated',
    (tester) async {
      final controller = _TrackedPremiumPageController(
        const PremiumState(
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
          status: PremiumStatusModel(
            isPremium: false,
            canManageBilling: false,
            paymentProvider: 'stripe',
            purchaseChannel: 'external_checkout',
            status: 'None',
            cancelAtPeriodEnd: false,
            monthlyTokenLimit: 0,
            tokensAvailable: 0,
            canManageSubscription: false,
            manageSubscriptionAction: '',
          ),
          legalTexts: PremiumLegalTextsModel(
            storeNotice: 'store',
            externalCheckoutNotice: 'external',
            stripeNotice: 'stripe',
          ),
          isLoading: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedAppLaunchController.new,
            ),
            premiumControllerProvider.overrideWith(() => controller),
          ],
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

      expect(controller.loadCalls, 0);
      expect(find.text('Monthly'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets(
    'premium page keeps guest paywall public and gates checkout with auth sheet',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
          recommendedPlanCode: 'monthly',
        ),
        status: const PremiumStatusModel(
          isPremium: false,
          canManageBilling: false,
          status: 'None',
          cancelAtPeriodEnd: false,
          monthlyTokenLimit: 0,
          tokensAvailable: 0,
          canManageSubscription: false,
          manageSubscriptionAction: '',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _GuestAppLaunchController.new,
            ),
            premiumRepositoryProvider.overrideWithValue(repository),
            premiumRefreshProfileProvider.overrideWithValue(() async {}),
          ],
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

      final context = tester.element(find.byType(PremiumPage));
      final text = AppLocalizations.of(context);
      final ctaLabel = text.paymentContinueViaProviderAction(
        text.premiumPaymentStripe,
      );
      final ctaButton = find.widgetWithText(ElevatedButton, ctaLabel);

      expect(repository.fetchPaywallConfigCalls, 1);
      expect(repository.fetchStatusCalls, 0);
      expect(find.text('Monthly'), findsOneWidget);

      await tester.scrollUntilVisible(
        ctaButton,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(ctaButton);
      await tester.pump();
      await tester.tap(ctaButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(text.authRequiredTitle), findsWidgets);
      expect(find.text(text.authRequiredMessage), findsWidgets);
      expect(repository.createStripeCheckoutCalls, 0);
    },
  );

  testWidgets(
    'premium page stays offline without loading and retries on reconnect',
    (tester) async {
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
          recommendedPlanCode: 'monthly',
        ),
        status: const PremiumStatusModel(
          isPremium: false,
          canManageBilling: false,
          status: 'None',
          cancelAtPeriodEnd: false,
          monthlyTokenLimit: 0,
          tokensAvailable: 0,
          canManageSubscription: false,
          manageSubscriptionAction: '',
        ),
      );
      final networkController = _TestPremiumNetworkStatusController(false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _GuestAppLaunchController.new,
            ),
            premiumRepositoryProvider.overrideWithValue(repository),
            premiumRefreshProfileProvider.overrideWithValue(() async {}),
            networkStatusControllerProvider.overrideWith(
              () => networkController,
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

      expect(repository.fetchPaywallConfigCalls, 0);
      expect(repository.fetchStatusCalls, 0);
      expect(find.text("You're offline"), findsOneWidget);

      networkController.setHasInternet(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 800));

      expect(repository.fetchPaywallConfigCalls, 1);
      expect(repository.fetchStatusCalls, 0);
      expect(find.text('Monthly'), findsOneWidget);
    },
  );
}

class _FakePremiumRepository extends PremiumRepository {
  _FakePremiumRepository({required this.config, required this.status})
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final PremiumPaywallConfigModel config;
  final PremiumStatusModel status;

  final _streamController =
      StreamController<List<StorePurchaseDetails>>.broadcast();
  int fetchPaywallConfigCalls = 0;
  int fetchStatusCalls = 0;
  int createStripeCheckoutCalls = 0;

  @override
  Stream<List<StorePurchaseDetails>> get purchaseUpdates =>
      _streamController.stream;

  @override
  Future<PremiumPaywallConfigModel> fetchPaywallConfig({
    required AppLocale locale,
    RequestCancellation? cancelToken,
  }) async {
    fetchPaywallConfigCalls++;
    return config;
  }

  @override
  Future<PremiumStatusModel> fetchStatus({
    RequestCancellation? cancelToken,
  }) async {
    fetchStatusCalls++;
    return status;
  }

  @override
  Future<PremiumCheckoutModel> createStripeCheckout(
    PremiumPlanModel plan,
    AppLocale locale, {
    RequestCancellation? cancelToken,
  }) async {
    createStripeCheckoutCalls++;
    return const PremiumCheckoutModel(
      paymentProvider: 'stripe',
      checkoutUrl: 'https://checkout.stripe.com/c/pay/cs_test_123',
      status: 'pending',
      externalSubscriptionId: 'cs_test_123',
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

class _TrackedPremiumPageController extends PremiumController {
  _TrackedPremiumPageController(this._initialState);

  final PremiumState _initialState;
  int loadCalls = 0;

  @override
  PremiumState build() => _initialState;

  @override
  Future<void> load({bool refresh = false}) async {
    loadCalls++;
  }
}

class _GuestAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: false,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class _AuthenticatedAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: true,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class _TestPremiumNetworkStatusController extends NetworkStatusController {
  _TestPremiumNetworkStatusController(this.initialHasInternet);

  final bool initialHasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: initialHasInternet);
  }

  void setHasInternet(bool value) {
    state = state.copyWith(hasInternet: value);
  }
}
