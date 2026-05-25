import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_pack_selection.dart';

void main() {
  test('selectPopularPack chooses highest PawSpark per price unit', () {
    const packs = [
      CurrencyPackModel(
        packId: 'starter',
        code: 'starter',
        displayName: 'Tiny Treat',
        currencyCode: 'EUR',
        priceAmount: 6.29,
        grantedSpark: 20,
        bonusSpark: 0,
        totalSpark: 20,
      ),
      CurrencyPackModel(
        packId: 'creator',
        code: 'creator',
        displayName: 'Happy Pack',
        currencyCode: 'EUR',
        priceAmount: 13.49,
        grantedSpark: 45,
        bonusSpark: 0,
        totalSpark: 45,
      ),
    ];

    expect(selectPopularPack(packs)?.packId, 'creator');
  });

  test('selectPopularPack breaks equal value ties by larger total spark', () {
    const packs = [
      CurrencyPackModel(
        packId: 'small',
        code: 'small',
        displayName: 'Small',
        currencyCode: 'EUR',
        priceAmount: 5,
        grantedSpark: 100,
        bonusSpark: 0,
        totalSpark: 100,
      ),
      CurrencyPackModel(
        packId: 'large',
        code: 'large',
        displayName: 'Large',
        currencyCode: 'EUR',
        priceAmount: 10,
        grantedSpark: 200,
        bonusSpark: 0,
        totalSpark: 200,
      ),
    ];

    expect(selectPopularPack(packs)?.packId, 'large');
  });
}
