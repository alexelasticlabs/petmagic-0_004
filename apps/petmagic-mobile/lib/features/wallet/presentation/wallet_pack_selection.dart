import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';

CurrencyPackModel? selectPopularPack(List<CurrencyPackModel> packs) {
  if (packs.isEmpty) {
    return null;
  }

  return packs.reduce((best, candidate) {
    final bestPrice = best.priceAmount <= 0 ? 1 : best.priceAmount;
    final candidatePrice = candidate.priceAmount <= 0 ? 1 : candidate.priceAmount;
    final bestValue = best.totalSpark / bestPrice;
    final candidateValue = candidate.totalSpark / candidatePrice;

    if (candidateValue != bestValue) {
      return candidateValue > bestValue ? candidate : best;
    }

    if (candidate.totalSpark != best.totalSpark) {
      return candidate.totalSpark > best.totalSpark ? candidate : best;
    }

    if (candidate.priceAmount != best.priceAmount) {
      return candidate.priceAmount < best.priceAmount ? candidate : best;
    }

    return best;
  });
}