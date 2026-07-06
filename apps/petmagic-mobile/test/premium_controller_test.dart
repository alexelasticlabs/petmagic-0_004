import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/data/premium_repository.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';

import 'premium_controller_test_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'premium controller does not cache dependencies through build assignment',
    () {
      final source = readPremiumControllerLibrarySource();

      expect(source, isNot(contains('late PremiumRepository _repository')));
      expect(
        source,
        isNot(contains('late PremiumRefreshProfile _refreshProfile')),
      );
      expect(source, contains('PremiumRepository? _activeRepository;'));
      expect(source, contains('PremiumRefreshProfile? _activeRefreshProfile;'));
      expect(
        source,
        contains('_activeRepository = ref.read(premiumRepositoryProvider);'),
      );
      expect(
        source,
        contains(
          '_activeRefreshProfile = ref.read(premiumRefreshProfileProvider);',
        ),
      );
      expect(
        source,
        isNot(contains('_repository = ref.watch(premiumRepositoryProvider)')),
      );
      expect(
        source,
        isNot(
          contains(
            '_refreshProfile = ref.watch(premiumRefreshProfileProvider)',
          ),
        ),
      );
      expect(source, contains('CancelToken? _activePremiumActionCancelToken;'));
      expect(
        source,
        contains('CancelToken? _activeCheckoutVerificationCancelToken;'),
      );
      expect(source, contains('void _cancelActivePremiumAction()'));
      expect(source, contains('void _cancelActiveCheckoutVerification()'));
      expect(source, contains('_cancelActivePremiumAction();'));
      expect(source, contains('_cancelActiveCheckoutVerification();'));
      expect(source, contains('CancelToken _startPremiumActionCancelToken()'));
      expect(
        source,
        contains('CancelToken _startCheckoutVerificationCancelToken()'),
      );
      expect(source, contains('_clearActivePremiumAction(cancelToken)'));
      expect(
        source,
        contains('_clearActiveCheckoutVerification(verificationCancelToken)'),
      );
      expect(source, contains('cancelToken: cancelToken'));
      expect(source, contains('cancelToken: verificationCancelToken'));
    },
  );

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
            productPrices: {
              'com.petmagic.app.premium.monthly': r'$14.99',
              'com.petmagic.app.premium.yearly': r'$99.99',
            },
          ),
        },
      );

      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
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

  test('stripe checkout opens external checkout url for mobile flow', () async {
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
        checkoutUrl: 'https://checkout.stripe.com/c/pay/cs_test_123',
        status: 'pending',
        externalSubscriptionId: 'cs_test_123',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          _AuthenticatedAppLaunchController.new,
        ),
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
    expect(checkout, isNull);
    expect(state.externalUrl, 'https://checkout.stripe.com/c/pay/cs_test_123');
    expect(state.isBuying, isFalse);
  });

  test('stripe checkout rejects unsafe external checkout url', () async {
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
        checkoutUrl: 'https://checkout.stripe.com@evil.example/session',
        status: 'pending',
        externalSubscriptionId: 'cs_test_123',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          _AuthenticatedAppLaunchController.new,
        ),
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
    expect(checkout, isNull);
    expect(state.externalUrl, isNull);
    expect(state.errorMessage, 'premium.checkout_failed');
    expect(state.isBuying, isFalse);
  });

  test('premium load normalizes wrapped backend error keys', () async {
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
      paywallError: const AppException(
        '  RuntimeError: PREMIUM.STORE_UNAVAILABLE  ',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          _AuthenticatedAppLaunchController.new,
        ),
        premiumRepositoryProvider.overrideWithValue(repository),
        premiumRefreshProfileProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(container.dispose);

    await container.read(premiumControllerProvider.notifier).load();

    final state = container.read(premiumControllerProvider);
    expect(state.errorMessage, 'premium.store_unavailable');
    expect(state.isLoading, isFalse);
  });

  test('premium checkout normalizes wrapped purchase error keys', () async {
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
      checkoutError: const AppException(
        ' AppException: premium.checkout_failed ',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          _AuthenticatedAppLaunchController.new,
        ),
        premiumRepositoryProvider.overrideWithValue(repository),
        premiumRefreshProfileProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(premiumControllerProvider.notifier);
    await controller.load();
    await controller.startCheckout();

    final state = container.read(premiumControllerProvider);
    expect(state.errorMessage, 'premium.checkout_failed');
    expect(state.isBuying, isFalse);
  });

  test(
    'guest premium monetization actions do not call checkout or billing APIs',
    () async {
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
      );

      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _GuestAppLaunchController.new,
          ),
          premiumRepositoryProvider.overrideWithValue(repository),
          premiumRefreshProfileProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(premiumControllerProvider.notifier);
      await controller.load();

      final checkout = await controller.startCheckout();
      await controller.manageBilling();
      await controller.restorePurchases();

      final state = container.read(premiumControllerProvider);
      expect(checkout, isNull);
      expect(repository.createStripeCheckoutCalls, 0);
      expect(repository.createBillingPortalCalls, 0);
      expect(repository.restoreStorePurchasesCalls, 0);
      expect(repository.startStoreCheckoutCalls, 0);
      expect(state.isBuying, isFalse);
      expect(state.isManaging, isFalse);
      expect(state.isRestoring, isFalse);
      expect(state.externalUrl, isNull);
      expect(state.errorMessage, isNull);
    },
  );

  test(
    'canStartCheckout is false while a checkout is already in flight',
    () async {
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
      );

      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          premiumRepositoryProvider.overrideWithValue(repository),
          premiumRefreshProfileProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);

      await container.read(premiumControllerProvider.notifier).load();

      final state = container.read(premiumControllerProvider);
      expect(state.canStartCheckout, isTrue);

      final stateWithBuying = state.copyWith(isBuying: true);
      expect(stateWithBuying.canStartCheckout, isFalse);
    },
  );

  test('load completes safely after provider disposal', () async {
    final repository = _DelayedPremiumRepository(
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
    );

    final container = ProviderContainer(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          _AuthenticatedAppLaunchController.new,
        ),
        premiumRepositoryProvider.overrideWithValue(repository),
        premiumRefreshProfileProvider.overrideWithValue(() async {}),
      ],
    );

    final loadFuture = container
        .read(premiumControllerProvider.notifier)
        .load();
    await repository.fetchPaywallStarted.future;

    container.dispose();
    expect(repository.paywallCancelToken?.isCancelled, isTrue);
    repository.completePaywallConfig();

    await expectLater(loadFuture, completes);
  });

  test(
    'premium load cancels in-flight request when network goes offline',
    () async {
      final repository = _DelayedPremiumRepository(
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
      );
      final networkController = _TestPremiumNetworkStatusController(true);

      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          networkStatusControllerProvider.overrideWith(() => networkController),
          premiumRepositoryProvider.overrideWithValue(repository),
          premiumRefreshProfileProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(premiumControllerProvider.notifier);
      final loadFuture = controller.load();
      await repository.fetchPaywallStarted.future;

      expect(repository.paywallCancelToken?.isCancelled, isFalse);

      networkController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);

      var state = container.read(premiumControllerProvider);
      expect(repository.paywallCancelToken?.isCancelled, isTrue);
      expect(state.isLoading, isFalse);

      repository.completePaywallConfig();
      await expectLater(loadFuture, completes);

      state = container.read(premiumControllerProvider);
      expect(state.plans, isEmpty);
      expect(state.status, isNull);
    },
  );

  test('concurrent premium loads share one in-flight request', () async {
    final repository = _DelayedPremiumRepository(
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
    );

    final container = ProviderContainer(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          _AuthenticatedAppLaunchController.new,
        ),
        premiumRepositoryProvider.overrideWithValue(repository),
        premiumRefreshProfileProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(premiumControllerProvider.notifier);
    final firstLoad = controller.load();
    await repository.fetchPaywallStarted.future;

    final secondLoad = controller.load(refresh: true);

    repository.completePaywallConfig();
    await Future.wait([firstLoad, secondLoad]);

    expect(repository.fetchPaywallConfigCalls, 1);
    expect(repository.fetchStatusCalls, 1);
  });

  test(
    'guest premium load keeps paywall usable without subscription status request',
    () async {
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
      );

      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _GuestAppLaunchController.new,
          ),
          premiumRepositoryProvider.overrideWithValue(repository),
          premiumRefreshProfileProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);

      await container.read(premiumControllerProvider.notifier).load();

      final state = container.read(premiumControllerProvider);
      expect(repository.fetchPaywallConfigCalls, 1);
      expect(repository.fetchStatusCalls, 0);
      expect(state.plans, isNotEmpty);
      expect(state.isPremium, isFalse);
      expect(state.canStartCheckout, isTrue);
    },
  );

  test('checkout verification stops safely after provider disposal', () async {
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
    );
    final refreshStarted = Completer<void>();
    final releaseRefresh = Completer<void>();

    final container = ProviderContainer(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          _AuthenticatedAppLaunchController.new,
        ),
        premiumRepositoryProvider.overrideWithValue(repository),
        premiumRefreshProfileProvider.overrideWithValue(() {
          if (!refreshStarted.isCompleted) {
            refreshStarted.complete();
          }
          return releaseRefresh.future;
        }),
      ],
    );

    final controller = container.read(premiumControllerProvider.notifier);
    await controller.load();
    controller.markCheckoutOpened(wasPremiumBeforeCheckout: false);

    final verificationFuture = controller.verifyCheckoutStatus();
    await refreshStarted.future;

    container.dispose();
    releaseRefresh.complete();

    await expectLater(verificationFuture, completes);
  });

  test(
    'explicit Stripe checkout verification cancels active request on provider disposal',
    () async {
      final repository = _DelayedStripeVerificationPremiumRepository(
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
      );

      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          premiumRepositoryProvider.overrideWithValue(repository),
          premiumRefreshProfileProvider.overrideWithValue(() async {}),
        ],
      );

      final controller = container.read(premiumControllerProvider.notifier);
      await controller.load();
      controller.markCheckoutOpened(wasPremiumBeforeCheckout: false);

      final verificationFuture = controller.verifyCheckoutStatus(
        stripePlanCode: 'yearly',
        stripeExternalSubscriptionId: 'sub_test_cancel',
      );
      final cancelToken = await repository.stripeVerificationStarted.future;
      expect(cancelToken.isCancelled, isFalse);

      container.dispose();

      expect(cancelToken.isCancelled, isTrue);
      repository.completeStripeVerification();
      await expectLater(verificationFuture, completes);
    },
  );

  test(
    'checkout verification stops quietly after sign out without polling subscription status',
    () async {
      final launchController = _MutableAppLaunchController(true);
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
      );

      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(() => launchController),
          premiumRepositoryProvider.overrideWithValue(repository),
          premiumRefreshProfileProvider.overrideWithValue(() async {
            launchController.markSignedOut();
          }),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(premiumControllerProvider.notifier);
      await controller.load();
      controller.markCheckoutOpened(wasPremiumBeforeCheckout: false);

      await controller.verifyCheckoutStatus();

      final state = container.read(premiumControllerProvider);
      expect(repository.fetchPaywallConfigCalls, 1);
      expect(repository.fetchStatusCalls, 1);
      expect(
        state.checkoutVerificationState,
        PremiumCheckoutVerificationState.idle,
      );
      expect(state.isAwaitingCheckoutVerification, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.isPremium, isFalse);
      expect(
        container.read(appLaunchControllerProvider).isAuthenticated,
        isFalse,
      );
    },
  );

  test(
    'checkout status refresh cancels active subscription status request on provider disposal',
    () async {
      final repository = _DelayedVerificationStatusPremiumRepository(
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
      );

      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          premiumRepositoryProvider.overrideWithValue(repository),
          premiumRefreshProfileProvider.overrideWithValue(() async {}),
        ],
      );

      final controller = container.read(premiumControllerProvider.notifier);
      await controller.load();
      controller.markCheckoutOpened(wasPremiumBeforeCheckout: false);

      final verificationFuture = controller.verifyCheckoutStatus();
      final cancelToken = await repository.statusRefreshStarted.future;
      expect(cancelToken.isCancelled, isFalse);

      container.dispose();

      expect(cancelToken.isCancelled, isTrue);
      repository.completeStatusRefresh();
      await expectLater(verificationFuture, completes);
    },
  );

  test(
    'premium checkout action cancels active Stripe request on provider disposal',
    () async {
      final repository = _DelayedCheckoutPremiumRepository(
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
        status: _status(provider: 'stripe', canManageSubscription: true),
      );

      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          premiumRepositoryProvider.overrideWithValue(repository),
          premiumRefreshProfileProvider.overrideWithValue(() async {}),
        ],
      );

      final controller = container.read(premiumControllerProvider.notifier);
      await controller.load();

      final checkoutFuture = controller.startCheckout();
      final cancelToken = await repository.checkoutStarted.future;
      expect(cancelToken.isCancelled, isFalse);

      container.dispose();

      expect(cancelToken.isCancelled, isTrue);
      repository.completeCheckout();
      await expectLater(checkoutFuture, completes);
    },
  );

  test(
    'checkout status refresh cancels active subscription status request when network goes offline',
    () async {
      final repository = _DelayedVerificationStatusPremiumRepository(
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
      );
      final networkController = _TestPremiumNetworkStatusController(true);

      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          networkStatusControllerProvider.overrideWith(() => networkController),
          premiumRepositoryProvider.overrideWithValue(repository),
          premiumRefreshProfileProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(premiumControllerProvider.notifier);
      await controller.load();
      controller.markCheckoutOpened(wasPremiumBeforeCheckout: false);

      final verificationFuture = controller.verifyCheckoutStatus();
      final cancelToken = await repository.statusRefreshStarted.future;
      expect(cancelToken.isCancelled, isFalse);

      networkController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);

      expect(cancelToken.isCancelled, isTrue);
      final state = container.read(premiumControllerProvider);
      expect(
        state.checkoutVerificationState,
        PremiumCheckoutVerificationState.error,
      );
      expect(state.isAwaitingCheckoutVerification, isFalse);
      expect(state.checkoutErrorMessage, 'templates.network_unavailable');

      repository.completeStatusRefresh();
      await expectLater(verificationFuture, completes);
    },
  );

  test(
    'checkout verification refreshes status without reloading paywall',
    () async {
      var refreshCalls = 0;
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
        status: _status(
          provider: 'stripe',
          canManageSubscription: false,
          isPremium: false,
        ),
        statusSequence: [
          _status(
            provider: 'stripe',
            canManageSubscription: false,
            isPremium: false,
          ),
          _status(
            provider: 'stripe',
            canManageSubscription: false,
            isPremium: false,
          ),
          _status(
            provider: 'stripe',
            canManageSubscription: true,
            isPremium: true,
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          premiumRepositoryProvider.overrideWithValue(repository),
          premiumRefreshProfileProvider.overrideWithValue(() async {
            refreshCalls++;
          }),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(premiumControllerProvider.notifier);
      await controller.load();
      controller.markCheckoutOpened(wasPremiumBeforeCheckout: false);

      await controller.verifyCheckoutStatus();

      final state = container.read(premiumControllerProvider);
      expect(repository.fetchPaywallConfigCalls, 1);
      expect(repository.fetchStoreAvailabilityCalls, 0);
      expect(repository.fetchStatusCalls, 3);
      expect(refreshCalls, 2);
      expect(
        state.checkoutVerificationState,
        PremiumCheckoutVerificationState.activated,
      );
      expect(state.isPremium, isTrue);
    },
  );

  test(
    'concurrent checkout verification shares one in-flight polling loop',
    () async {
      var refreshCalls = 0;
      final refreshStarted = Completer<void>();
      final releaseRefresh = Completer<void>();
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
        status: _status(
          provider: 'stripe',
          canManageSubscription: false,
          isPremium: false,
        ),
        statusSequence: [
          _status(
            provider: 'stripe',
            canManageSubscription: true,
            isPremium: true,
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          premiumRepositoryProvider.overrideWithValue(repository),
          premiumRefreshProfileProvider.overrideWithValue(() async {
            refreshCalls++;
            if (!refreshStarted.isCompleted) {
              refreshStarted.complete();
            }
            await releaseRefresh.future;
          }),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(premiumControllerProvider.notifier);
      await controller.load();
      controller.markCheckoutOpened(wasPremiumBeforeCheckout: false);

      final firstVerification = controller.verifyCheckoutStatus();
      await refreshStarted.future;

      final secondVerification = controller.verifyCheckoutStatus();
      await Future<void>.delayed(Duration.zero);

      releaseRefresh.complete();
      await Future.wait([firstVerification, secondVerification]);

      final state = container.read(premiumControllerProvider);
      expect(refreshCalls, 1);
      expect(repository.fetchPaywallConfigCalls, 1);
      expect(repository.fetchStatusCalls, 2);
      expect(
        state.checkoutVerificationState,
        PremiumCheckoutVerificationState.activated,
      );
      expect(state.isPremium, isTrue);
    },
  );

  test(
    'stripe restore clears restoring state when profile refresh fails',
    () async {
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
        status: _status(provider: 'stripe', canManageSubscription: true),
      );

      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          premiumRepositoryProvider.overrideWithValue(repository),
          premiumRefreshProfileProvider.overrideWithValue(() async {
            throw const AppException('templates.network_unavailable');
          }),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(premiumControllerProvider.notifier);
      await controller.load();
      await controller.restorePurchases();

      final state = container.read(premiumControllerProvider);
      expect(state.isRestoring, isFalse);
      expect(state.errorMessage, 'templates.network_unavailable');
      expect(state.successMessage, isNull);
    },
  );

  test('checkout status refresh invalidates cached subscription summary', () {
    final source = readPremiumControllerLibrarySource();
    final methodBody = _premiumMethodBody(
      source,
      '_refreshPremiumStatusSnapshot',
    );

    expect(
      methodBody,
      contains('ref.invalidate(premiumSubscriptionSummaryProvider);'),
    );
  });

  test(
    'store purchase verification deduplicates non-secret purchase updates',
    () {
      final source = readPremiumControllerLibrarySource();
      final verifyBody = _premiumMethodBody(source, '_verifyStorePurchase');

      expect(
        source,
        contains('Set<String> _storePurchaseVerificationInFlightKeys'),
      );
      expect(source, contains('Set<String> _storePurchaseVerifiedKeys'));
      expect(
        verifyBody,
        contains('_storePurchaseVerificationInFlightKeys.add'),
      );
      expect(verifyBody, contains('_storePurchaseVerifiedKeys.contains'));
      expect(verifyBody, contains('_rememberStorePurchaseVerifiedKey'));
      expect(
        verifyBody,
        contains('_storePurchaseVerificationInFlightKeys.remove'),
      );
      expect(source, contains('_maxStorePurchaseVerificationKeys = 32'));
      expect(source, contains('_storePurchaseVerifiedKeys.remove'));
      expect(source, contains('String? _storePurchaseVerificationKey'));
      expect(source, contains('purchase.purchaseID'));
      expect(source, contains('purchase.transactionDate'));
      expect(source, contains('provider.value'));
      expect(source, contains('purchase.productID'));
      expect(source, isNot(contains('serverVerificationData')));
      expect(source, isNot(contains('localVerificationData')));
    },
  );
}

String _premiumMethodBody(String source, String methodName) {
  final methodMatch = RegExp(
    r'(?:@override\s+)?(?:String\?|void|Future<[^>]+>)\s+' +
        methodName +
        r'\s*\([^)]*\)\s*(?:async\s*)?\{',
  ).firstMatch(source);
  if (methodMatch == null) {
    fail('Method $methodName was not found.');
  }

  final openBraceIndex = source.indexOf('{', methodMatch.start);
  if (openBraceIndex < 0) {
    fail('Method $methodName has no body.');
  }

  var depth = 0;
  for (var index = openBraceIndex; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
      continue;
    }
    if (char != '}') {
      continue;
    }

    depth--;
    if (depth == 0) {
      return source.substring(openBraceIndex, index + 1);
    }
  }

  fail('Method $methodName body did not close.');
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
  bool isPremium = false,
}) {
  return PremiumStatusModel(
    isPremium: isPremium,
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
    ),
    this.availabilityByProvider = const {},
    this.statusSequence = const [],
    this.paywallError,
    this.checkoutError,
  }) : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final PremiumPaywallConfigModel config;
  final PremiumStatusModel status;
  final PremiumCheckoutModel stripeCheckout;
  final Map<
    PremiumPaymentProvider,
    ({
      bool isAvailable,
      Set<String> productIds,
      Map<String, String> productPrices,
    })
  >
  availabilityByProvider;
  final List<PremiumStatusModel> statusSequence;
  final Object? paywallError;
  final Object? checkoutError;

  final _streamController = StreamController<List<PurchaseDetails>>.broadcast();
  int fetchPaywallConfigCalls = 0;
  int fetchStatusCalls = 0;
  int fetchStoreAvailabilityCalls = 0;
  int createStripeCheckoutCalls = 0;
  int createBillingPortalCalls = 0;
  int startStoreCheckoutCalls = 0;
  int restoreStorePurchasesCalls = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseUpdates => _streamController.stream;

  @override
  Future<PremiumPaywallConfigModel> fetchPaywallConfig({
    required Locale locale,
    CancelToken? cancelToken,
  }) async {
    fetchPaywallConfigCalls++;
    if (paywallError != null) {
      throw paywallError!;
    }
    return config;
  }

  @override
  Future<PremiumStatusModel> fetchStatus({CancelToken? cancelToken}) async {
    fetchStatusCalls++;
    if (statusSequence.isEmpty) {
      return status;
    }

    final index = fetchStatusCalls - 1;
    if (index < statusSequence.length) {
      return statusSequence[index];
    }

    return statusSequence.last;
  }

  @override
  Future<PremiumCheckoutModel> createStripeCheckout(
    PremiumPlanModel plan,
    Locale locale, {
    CancelToken? cancelToken,
  }) async {
    createStripeCheckoutCalls++;
    if (checkoutError != null) {
      throw checkoutError!;
    }
    return stripeCheckout;
  }

  @override
  Future<PremiumBillingPortalModel> createBillingPortal({
    CancelToken? cancelToken,
  }) async {
    createBillingPortalCalls++;
    return const PremiumBillingPortalModel(
      paymentProvider: 'stripe',
      portalUrl: 'https://billing.stripe.com/session/test',
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
    fetchStoreAvailabilityCalls++;
    return availabilityByProvider[provider] ??
        (
          isAvailable: false,
          productIds: <String>{},
          productPrices: <String, String>{},
        );
  }

  @override
  Future<void> startStoreCheckout(
    PremiumPlanModel plan,
    PremiumPaymentProvider provider,
  ) async {
    startStoreCheckoutCalls++;
  }

  @override
  Future<void> restoreStorePurchases() async {
    restoreStorePurchasesCalls++;
  }

  @override
  Future<PremiumStoreVerificationModel> verifyStorePurchase({
    required PremiumPlanModel plan,
    required PremiumPaymentProvider provider,
    required PurchaseDetails purchase,
    CancelToken? cancelToken,
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

class _DelayedPremiumRepository extends _FakePremiumRepository {
  _DelayedPremiumRepository({required super.config, required super.status});

  final fetchPaywallStarted = Completer<void>();
  final _paywallConfig = Completer<PremiumPaywallConfigModel>();
  CancelToken? paywallCancelToken;

  @override
  Future<PremiumPaywallConfigModel> fetchPaywallConfig({
    required Locale locale,
    CancelToken? cancelToken,
  }) {
    fetchPaywallConfigCalls++;
    paywallCancelToken = cancelToken;
    fetchPaywallStarted.complete();
    return _paywallConfig.future;
  }

  void completePaywallConfig() {
    _paywallConfig.complete(config);
  }
}

class _DelayedCheckoutPremiumRepository extends _FakePremiumRepository {
  _DelayedCheckoutPremiumRepository({
    required super.config,
    required super.status,
  });

  final checkoutStarted = Completer<CancelToken>();
  final _checkout = Completer<PremiumCheckoutModel>();

  @override
  Future<PremiumCheckoutModel> createStripeCheckout(
    PremiumPlanModel plan,
    Locale locale, {
    CancelToken? cancelToken,
  }) {
    createStripeCheckoutCalls++;
    final token = cancelToken ?? CancelToken();
    if (!checkoutStarted.isCompleted) {
      checkoutStarted.complete(token);
    }

    return Future.any<PremiumCheckoutModel>([
      _checkout.future,
      token.whenCancel.then((_) => throw const RequestCancelledException()),
    ]);
  }

  void completeCheckout() {
    if (!_checkout.isCompleted) {
      _checkout.complete(
        const PremiumCheckoutModel(
          paymentProvider: 'stripe',
          checkoutUrl: 'https://checkout.stripe.com/c/pay/cs_test_cancel',
          status: 'pending',
          externalSubscriptionId: 'cs_test_cancel',
        ),
      );
    }
  }
}

class _DelayedStripeVerificationPremiumRepository
    extends _FakePremiumRepository {
  _DelayedStripeVerificationPremiumRepository({
    required super.config,
    required super.status,
  });

  final stripeVerificationStarted = Completer<CancelToken>();
  final _stripeVerification = Completer<void>();

  @override
  Future<void> verifyStripeSubscriptionCheckout({
    required String planCode,
    required String externalSubscriptionId,
    CancelToken? cancelToken,
  }) {
    final token = cancelToken ?? CancelToken();
    if (!stripeVerificationStarted.isCompleted) {
      stripeVerificationStarted.complete(token);
    }

    return Future.any<void>([
      _stripeVerification.future,
      token.whenCancel.then((_) => throw const RequestCancelledException()),
    ]);
  }

  void completeStripeVerification() {
    if (!_stripeVerification.isCompleted) {
      _stripeVerification.complete();
    }
  }
}

class _DelayedVerificationStatusPremiumRepository
    extends _FakePremiumRepository {
  _DelayedVerificationStatusPremiumRepository({
    required super.config,
    required super.status,
  });

  final statusRefreshStarted = Completer<CancelToken>();
  final _statusRefresh = Completer<PremiumStatusModel>();

  @override
  Future<PremiumStatusModel> fetchStatus({CancelToken? cancelToken}) async {
    fetchStatusCalls++;
    if (fetchStatusCalls == 1) {
      return status;
    }

    final token = cancelToken ?? CancelToken();
    if (!statusRefreshStarted.isCompleted) {
      statusRefreshStarted.complete(token);
    }

    return Future.any<PremiumStatusModel>([
      _statusRefresh.future,
      token.whenCancel.then((_) => throw const RequestCancelledException()),
    ]);
  }

  void completeStatusRefresh() {
    if (!_statusRefresh.isCompleted) {
      _statusRefresh.complete(status);
    }
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

class _MutableAppLaunchController extends AppLaunchController {
  _MutableAppLaunchController(this._isAuthenticated);

  bool _isAuthenticated;

  @override
  AppLaunchState build() {
    return AppLaunchState(
      isLoading: false,
      isAuthenticated: _isAuthenticated,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }

  @override
  void markSignedOut() {
    _isAuthenticated = false;
    super.markSignedOut();
  }
}
