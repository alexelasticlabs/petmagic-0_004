import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/premium/presentation/mappers/premium_error_key_mapper.dart';
import 'package:petmagic_mobile/features/wallet/presentation/mappers/wallet_error_key_mapper.dart';

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

    test('rejects arbitrary premium error text', () {
      expect(normalizePremiumErrorKey('Exception: card secret leaked'), isNull);
    });
  });
}
