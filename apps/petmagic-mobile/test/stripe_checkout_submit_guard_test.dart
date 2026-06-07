import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_stripe_checkout_page.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
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
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
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
