import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'monetization external launches fall back safely on launcher exceptions',
    () {
      final premiumPageSource = File(
        'lib/features/premium/presentation/premium_page_checkout.part.dart',
      ).readAsStringSync();
      final premiumFooterSource = File(
        'lib/features/premium/presentation/premium_page_footer.part.dart',
      ).readAsStringSync();
      final subscriptionManagementSource = File(
        'lib/features/premium/presentation/subscription_management_page.dart',
      ).readAsStringSync();
      final walletCheckoutSource = File(
        'lib/features/wallet/presentation/wallet_page_checkout.part.dart',
      ).readAsStringSync();

      final premiumOpenBody = _methodBody(
        premiumPageSource,
        'Future<void> _openExternalUrl(String url)',
      );
      final premiumFooterBody = _methodBody(
        premiumFooterSource,
        'Future<void> _handleUrlTap(BuildContext context)',
      );
      final subscriptionManagementBody = _methodBody(
        subscriptionManagementSource,
        'Future<void> _openManageTarget(String manageSubscriptionAction)',
      );
      final walletCheckoutBody = _methodBody(
        walletCheckoutSource,
        'Future<ExternalCheckoutResult> _handleCheckout(',
      );

      expect(premiumOpenBody, contains('var launched = false;'));
      expect(premiumOpenBody, contains('on Object'));
      expect(premiumOpenBody, contains('text.premiumManageFailed'));

      expect(premiumFooterBody, contains('var launched = false;'));
      expect(premiumFooterBody, contains('on Object'));
      expect(premiumFooterBody, contains('text.premiumManageFailed'));

      expect(subscriptionManagementBody, contains('var launched = false;'));
      expect(
        subscriptionManagementBody,
        contains('_logSubscriptionLaunchFailure('),
      );
      expect(
        subscriptionManagementBody,
        contains('AppLocalizations.of(context).premiumManageFailed'),
      );
      expect(
        subscriptionManagementSource,
        contains("feature: 'Premium.SubscriptionManagement'"),
      );
      expect(
        subscriptionManagementSource,
        contains('void _logSubscriptionLaunchFailure({'),
      );

      expect(walletCheckoutBody, contains('var launched = false;'));
      expect(walletCheckoutBody, contains('on Object'));
      expect(
        walletCheckoutBody,
        contains('text.walletPaymentGatewayUnavailableError'),
      );
    },
  );

  test('monetization checkout keeps native PaymentSheet and hosted fallback', () {
    final premiumPageSource = File(
      'lib/features/premium/presentation/premium_page_checkout.part.dart',
    ).readAsStringSync();
    final premiumModelsSource = File(
      'lib/features/premium/domain/premium_models.dart',
    ).readAsStringSync();
    final walletModelsSource = File(
      'lib/features/wallet/domain/wallet_models.dart',
    ).readAsStringSync();
    final walletCheckoutSource = File(
      'lib/features/wallet/presentation/wallet_page_checkout.part.dart',
    ).readAsStringSync();

    expect(
      File(
        'lib/shared/payments/stripe_paymentsheet_coordinator.dart',
      ).existsSync(),
      isFalse,
    );
    expect(premiumModelsSource, contains('hasNativeStripePaymentSheet'));
    expect(walletModelsSource, contains('hasNativeStripePaymentSheet'));
    expect(walletCheckoutSource, contains('StripePaymentSheetRequest('));
    expect(walletCheckoutSource, contains('verifyStripeCheckout('));
    expect(
      walletCheckoutSource,
      contains('parseSafePremiumExternalUri(checkoutUrl)'),
    );
    expect(premiumPageSource, contains('StripePaymentSheetRequest('));
    expect(
      premiumPageSource,
      contains('final externalUrl = checkoutState.externalUrl;'),
    );
    expect(
      premiumPageSource,
      contains('status: PremiumStripeCheckoutActionStatus.success'),
    );
  });
}

String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNonNegative, reason: 'Missing method: $signature');

  final braceStart = source.indexOf('{', start);
  expect(braceStart, isNonNegative, reason: 'Missing method body: $signature');

  var depth = 0;
  for (var index = braceStart; index < source.length; index += 1) {
    final character = source[index];
    if (character == '{') {
      depth += 1;
    } else if (character == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(braceStart, index + 1);
      }
    }
  }

  fail('Unclosed method body: $signature');
}
