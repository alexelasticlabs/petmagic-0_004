import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/premium/domain/premium_models.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_stripe_checkout_page.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_stripe_checkout_page.dart';

void main() {
  testWidgets('wallet Stripe checkout ignores duplicate submits in flight', (
    tester,
  ) async {
    final completer = Completer<WalletStripeCheckoutSubmitResult>();
    var submitCount = 0;

    await tester.pumpWidget(
      _TestApp(
        child: WalletStripeCheckoutPage(
          pack: _walletPack,
          paymentMethodLabel: 'Stripe',
          onChooseAnotherMethod: () {},
          onSubmit: () {
            submitCount += 1;
            return completer.future;
          },
        ),
      ),
    );

    final payButton = find.byType(FilledButton).first;
    await tester.tap(payButton);
    await tester.tap(payButton);

    expect(submitCount, 1);

    completer.complete(
      const WalletStripeCheckoutSubmitResult(
        status: WalletStripeCheckoutActionStatus.cancelled,
      ),
    );
    await tester.pumpAndSettle();

    expect(submitCount, 1);
  });

  testWidgets('premium Stripe checkout ignores duplicate submits in flight', (
    tester,
  ) async {
    final completer = Completer<PremiumStripeCheckoutSubmitResult>();
    var submitCount = 0;

    await tester.pumpWidget(
      _TestApp(
        child: PremiumStripeCheckoutPage(
          plan: _premiumPlan,
          paymentMethodLabel: 'Stripe',
          onChooseAnotherMethod: () {},
          onSubmit: () {
            submitCount += 1;
            return completer.future;
          },
        ),
      ),
    );

    final payButton = find.byType(FilledButton).first;
    await tester.tap(payButton);
    await tester.tap(payButton);

    expect(submitCount, 1);

    completer.complete(
      const PremiumStripeCheckoutSubmitResult(
        status: PremiumStripeCheckoutActionStatus.cancelled,
      ),
    );
    await tester.pumpAndSettle();

    expect(submitCount, 1);
  });

  testWidgets('wallet Stripe checkout maps submit exceptions to failed state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: WalletStripeCheckoutPage(
          pack: _walletPack,
          paymentMethodLabel: 'Stripe',
          onChooseAnotherMethod: () {},
          onSubmit: () async {
            throw StateError('raw wallet failure should stay internal');
          },
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('raw wallet failure'), findsNothing);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'premium Stripe checkout maps submit exceptions to failed state',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: PremiumStripeCheckoutPage(
            plan: _premiumPlan,
            paymentMethodLabel: 'Stripe',
            onChooseAnotherMethod: () {},
            onSubmit: () async {
              throw StateError('raw premium failure should stay internal');
            },
          ),
        ),
      );

      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('raw premium failure'), findsNothing);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('wallet Stripe checkout does not submit while offline', (
    tester,
  ) async {
    var submitCount = 0;

    await tester.pumpWidget(
      _TestApp(
        hasInternet: false,
        child: WalletStripeCheckoutPage(
          pack: _walletPack,
          paymentMethodLabel: 'Stripe',
          onChooseAnotherMethod: () {},
          onSubmit: () async {
            submitCount += 1;
            return const WalletStripeCheckoutSubmitResult(
              status: WalletStripeCheckoutActionStatus.success,
            );
          },
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton).first);
    await tester.pump();

    expect(submitCount, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('premium Stripe checkout does not submit while offline', (
    tester,
  ) async {
    var submitCount = 0;

    await tester.pumpWidget(
      _TestApp(
        hasInternet: false,
        child: PremiumStripeCheckoutPage(
          plan: _premiumPlan,
          paymentMethodLabel: 'Stripe',
          onChooseAnotherMethod: () {},
          onSubmit: () async {
            submitCount += 1;
            return const PremiumStripeCheckoutSubmitResult(
              status: PremiumStripeCheckoutActionStatus.success,
            );
          },
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton).first);
    await tester.pump();

    expect(submitCount, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'wallet Stripe checkout submit spinner uses theme foreground in ${brightness.name}',
      (tester) async {
        final completer = Completer<WalletStripeCheckoutSubmitResult>();

        await tester.pumpWidget(
          _TestApp(
            brightness: brightness,
            child: WalletStripeCheckoutPage(
              pack: _walletPack,
              paymentMethodLabel: 'Stripe',
              onChooseAnotherMethod: () {},
              onSubmit: () => completer.future,
            ),
          ),
        );

        await tester.tap(find.byType(FilledButton).first);
        await tester.pump();

        final context = tester.element(find.byType(WalletStripeCheckoutPage));
        final expectedColor = Theme.of(context).colorScheme.onPrimary;
        final indicators = tester.widgetList<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );

        expect(
          indicators.any((indicator) => indicator.color == expectedColor),
          isTrue,
        );

        completer.complete(
          const WalletStripeCheckoutSubmitResult(
            status: WalletStripeCheckoutActionStatus.cancelled,
          ),
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'premium Stripe checkout submit spinner uses theme foreground in ${brightness.name}',
      (tester) async {
        final completer = Completer<PremiumStripeCheckoutSubmitResult>();

        await tester.pumpWidget(
          _TestApp(
            brightness: brightness,
            child: PremiumStripeCheckoutPage(
              plan: _premiumPlan,
              paymentMethodLabel: 'Stripe',
              onChooseAnotherMethod: () {},
              onSubmit: () => completer.future,
            ),
          ),
        );

        await tester.tap(find.byType(FilledButton).first);
        await tester.pump();

        final context = tester.element(find.byType(PremiumStripeCheckoutPage));
        final expectedColor = Theme.of(context).colorScheme.onPrimary;
        final indicators = tester.widgetList<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );

        expect(
          indicators.any((indicator) => indicator.color == expectedColor),
          isTrue,
        );

        completer.complete(
          const PremiumStripeCheckoutSubmitResult(
            status: PremiumStripeCheckoutActionStatus.cancelled,
          ),
        );
        await tester.pumpAndSettle();
      },
    );
  }

  test('Stripe checkout method check icons use themed primary foreground', () {
    final walletPage = File(
      'lib/features/wallet/presentation/wallet_stripe_checkout_page.dart',
    ).readAsStringSync();
    final premiumPage = File(
      'lib/features/premium/presentation/premium_stripe_checkout_page.dart',
    ).readAsStringSync();
    final walletSections = File(
      'lib/features/wallet/presentation/wallet_stripe_checkout_page_sections.part.dart',
    ).readAsStringSync();
    final premiumSections = File(
      'lib/features/premium/presentation/premium_stripe_checkout_page_sections.part.dart',
    ).readAsStringSync();

    for (final source in [walletSections, premiumSections]) {
      expect(source, contains('Theme.of(context).colorScheme.onPrimary'));
      expect(source, isNot(contains('color: Colors.white')));
    }

    for (final source in [walletPage, premiumPage]) {
      expect(source, contains('Localizations.localeOf(context)'));
      expect(source, contains('locale: localeTag'));
    }
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.child,
    this.hasInternet = true,
    this.brightness = Brightness.dark,
  });

  final Widget child;
  final bool hasInternet;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        networkStatusControllerProvider.overrideWith(
          () => _TestNetworkStatusController(hasInternet: hasInternet),
        ),
      ],
      child: MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.dark()
            : AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }
}

class _TestNetworkStatusController extends NetworkStatusController {
  _TestNetworkStatusController({required this.hasInternet});

  final bool hasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: hasInternet);
  }
}

const _walletPack = CurrencyPackModel(
  packId: 'starter',
  code: 'starter',
  displayName: 'Tiny Treat',
  currencyCode: 'USD',
  priceAmount: 4.99,
  grantedSpark: 20,
  bonusSpark: 0,
  totalSpark: 20,
);

const _premiumPlan = PremiumPlanModel(
  planCode: 'monthly',
  billingInterval: 'month',
  priceAmount: 9.99,
  currencyCode: 'USD',
  tokenAllowance: 500,
  isPopular: false,
  sortOrder: 1,
  stripeCheckoutEnabled: true,
);
