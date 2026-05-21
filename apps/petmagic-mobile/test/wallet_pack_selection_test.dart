import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_pack_selection.dart';

void main() {
  test('selectPopularPack chooses highest PawSpark per price unit', () {
    const packs = [
      CurrencyPackModel(
        packId: 'starter',
        code: 'starter',
        displayName: 'Starter',
        currencyCode: 'EUR',
        priceAmount: 4.99,
        grantedSpark: 100,
        bonusSpark: 10,
        totalSpark: 110,
      ),
      CurrencyPackModel(
        packId: 'creator',
        code: 'creator',
        displayName: 'Creator',
        currencyCode: 'EUR',
        priceAmount: 9.99,
        grantedSpark: 350,
        bonusSpark: 30,
        totalSpark: 380,
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
