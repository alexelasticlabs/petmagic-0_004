import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/premium/application/premium_error_key_mapper.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_error_key_mapper.dart';

void main() {
  group('normalizeWalletErrorKey', () {
    test('extracts wrapped safe wallet keys', () {
      expect(
        normalizeWalletErrorKey('  RuntimeError: WALLET.NETWORK_UNAVAILABLE  '),
        'wallet.network_unavailable',
      );
      expect(
        normalizeWalletErrorKey('AppException: redeem_code_user_limit_reached'),
        'redeem_code_user_limit_reached',
      );
    });

    test('maps backend economy payment codes to localized wallet keys', () {
      expect(
        normalizeWalletErrorKey(
          'ProblemDetails.title: economy.payment_provider_unavailable',
        ),
        'wallet.payment_unavailable',
      );
      expect(
        normalizeWalletErrorKey(
          'ProblemDetails.title: economy.payment_gateway_failed',
        ),
        'payment_gateway_failed',
      );
      expect(
        normalizeWalletErrorKey(
          'ProblemDetails.title: economy.store_purchase_invalid',
        ),
        'wallet.payment_unavailable',
      );
    });

    test('rejects arbitrary wallet error text', () {
      expect(
        normalizeWalletErrorKey('FileSystemException: /private/payment.txt'),
        isNull,
      );
    });
  });

  group('normalizePremiumErrorKey', () {
    test('extracts wrapped safe premium keys', () {
      expect(
        normalizePremiumErrorKey(' AppException: PREMIUM.CHECKOUT_FAILED '),
        'premium.checkout_failed',
      );
      expect(
        normalizePremiumErrorKey('RuntimeError: auth.session_expired'),
        'auth.session_expired',
      );
    });

    test('maps backend economy premium codes to localized premium keys', () {
      expect(
        normalizePremiumErrorKey(
          'ProblemDetails.title: economy.store_verification_unavailable',
        ),
        'premium.store_unavailable',
      );
      expect(
        normalizePremiumErrorKey(
          'ProblemDetails.title: economy.payment_gateway_failed',
        ),
        'premium.checkout_failed',
      );
      expect(
        normalizePremiumErrorKey(
          'ProblemDetails.title: economy.premium_plan_not_found',
        ),
        'premium.store_product_unavailable',
      );
      expect(
        normalizePremiumErrorKey(
          'ProblemDetails.title: economy.payment_method_not_found',
        ),
        'premium.manage_failed',
      );
    });

    test('rejects arbitrary premium error text', () {
      expect(normalizePremiumErrorKey('Exception: card secret leaked'), isNull);
    });
  });
}
