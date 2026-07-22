part of 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';

class _PacksSection extends StatelessWidget {
  const _PacksSection({
    required this.packs,
    required this.storeProductPrices,
    required this.templatePricing,
    required this.isBuying,
    required this.onSelect,
  });

  final List<CurrencyPackModel> packs;
  final Map<String, String> storeProductPrices;
  final _WalletTemplatePricing templatePricing;
  final bool isBuying;
  final ValueChanged<CurrencyPackModel> onSelect;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final sortedPacks = packs.toList(growable: false)
      ..sort((left, right) {
        final bySpark = left.totalSpark.compareTo(right.totalSpark);
        if (bySpark != 0) {
          return bySpark;
        }

        return left.priceAmount.compareTo(right.priceAmount);
      });

    if (packs.isEmpty) {
      return const SizedBox.shrink();
    }

    final bestOfferPack = sortedPacks.last;
    final popularPack = sortedPacks.length >= 3
        ? sortedPacks[(sortedPacks.length - 1) ~/ 2]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: text.walletBuySparkTitle),
        for (var index = 0; index < sortedPacks.length; index++) ...[
          _FeaturedPackTile(
            pack: sortedPacks[index],
            displayPrice: _storePriceForPack(
              sortedPacks[index],
              storeProductPrices,
            ),
            templatePricing: templatePricing,
            isBestOffer: bestOfferPack.packId == sortedPacks[index].packId,
            isPopular:
                popularPack?.packId == sortedPacks[index].packId &&
                bestOfferPack.packId != sortedPacks[index].packId,
            isBuying: isBuying,
            onTap: () => onSelect(sortedPacks[index]),
          ),
          if (index != sortedPacks.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FeaturedPackTile extends StatelessWidget {
  const _FeaturedPackTile({
    required this.pack,
    required this.displayPrice,
    required this.templatePricing,
    required this.isBestOffer,
    required this.isPopular,
    required this.isBuying,
    required this.onTap,
  });

  final CurrencyPackModel pack;
  final String? displayPrice;
  final _WalletTemplatePricing templatePricing;
  final bool isBestOffer;
  final bool isPopular;
  final bool isBuying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final colors = context.petMagicColors;
    final price = displayPrice ?? _formatPrice(pack, localeTag);
    final valueLabel = _valuePerCurrencyLabel(text, pack);
    final usageLabel = templatePricing.usageLabel(text, pack.totalSpark);
    final badgeLabel = isBestOffer
        ? '🔥 ${text.walletBestValueBadge}'
        : (isPopular ? text.walletPopularBadge : null);
    final badgeLabelWithIcon = isPopular && badgeLabel != null
        ? '⭐ $badgeLabel'
        : badgeLabel;
    final badgeColor = isBestOffer ? colors.gold : colors.accent;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBestOffer
              ? badgeColor.withValues(alpha: 0.55)
              : isPopular
              ? colors.accent.withValues(alpha: 0.46)
              : colors.border.withValues(alpha: 0.98),
          width: isBestOffer ? 1.5 : 1.1,
        ),
        boxShadow: isBestOffer
            ? [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
        gradient: isBestOffer
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.5, 1.0],
                colors: [
                  badgeColor.withValues(alpha: 0.10),
                  colors.surfaceGlass,
                  badgeColor.withValues(alpha: 0.05),
                ],
              )
            : null,
        color: isBestOffer ? null : colors.surfaceGlass,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: Image.asset(
                    _packImageAsset(pack.code),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (badgeLabel != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: badgeColor.withValues(alpha: 0.22),
                            border: Border.all(
                              color: badgeColor.withValues(alpha: 0.42),
                            ),
                          ),
                          child: Text(
                            badgeLabelWithIcon!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${pack.totalSpark}',
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            height: 0.96,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const PawSparkIcon(size: 16),
                        const SizedBox(width: 6),
                        Text(
                          text.walletBalanceUnit,
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: isBuying ? null : onTap,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(104, 36),
                    backgroundColor: colors.accent,
                    disabledBackgroundColor: colors.surfaceStrong.withValues(
                      alpha: 0.95,
                    ),
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    disabledForegroundColor: colors.textMuted,
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(price),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              valueLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              usageLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: isBuying ? null : onTap,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: colors.textSoft,
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(text.walletPackDetailsAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _packImageAsset(String code) {
  return switch (code) {
    'starter' => 'assets/rewards/wallet-pack-coffee.png',
    'creator' => 'assets/rewards/wallet-pack-suitcase.png',
    'viral' => 'assets/rewards/wallet-pack-chest.png',
    _ => 'assets/rewards/wallet-pack-chest.png',
  };
}
