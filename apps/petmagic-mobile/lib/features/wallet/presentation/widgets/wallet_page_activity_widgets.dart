part of 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';

class _PacksSection extends StatelessWidget {
  const _PacksSection({
    required this.packs,
    required this.isBuying,
    required this.onSelect,
  });

  final List<CurrencyPackModel> packs;
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
    required this.isBestOffer,
    required this.isPopular,
    required this.isBuying,
    required this.onTap,
  });

  final CurrencyPackModel pack;
  final bool isBestOffer;
  final bool isPopular;
  final bool isBuying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final price = _formatPrice(pack);
    final valueLabel = _valuePerCurrencyLabel(pack);
    final photosApprox = (pack.totalSpark / _kPhotoCostSpark).floor();
    final videosApprox = (pack.totalSpark / _kVideoCostSpark).floor();
    final usageLabel = videosApprox > 0
        ? '≈ ${text.walletApproxPhotos(photosApprox)} или ${text.walletApproxVideos(videosApprox)}'
        : '≈ ${text.walletApproxPhotos(photosApprox)}';
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
                    textStyle: const TextStyle(
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
                fontSize: 12.2,
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
                  textStyle: const TextStyle(
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

class _LedgerSection extends StatelessWidget {
  const _LedgerSection({required this.items, required this.onViewAll});

  final List<WalletLedgerItem> items;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final visibleItems = items.take(5).toList(growable: false);
    final hasItems = visibleItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  text.walletRecentTransactionsTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (hasItems)
                TextButton.icon(
                  onPressed: onViewAll,
                  iconAlignment: IconAlignment.end,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded, size: 16),
                  label: Text(text.walletViewAllTransactions),
                ),
            ],
          ),
        ),
        ProfileGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: !hasItems
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colors.surfaceStrong,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          size: 18,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          text.walletNoActivity,
                          style: TextStyle(
                            color: colors.textSoft,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < visibleItems.length;
                      index++
                    ) ...[
                      _LedgerRow(item: visibleItems[index]),
                      if (index != visibleItems.length - 1)
                        Divider(
                          height: 10,
                          thickness: 0.8,
                          color: colors.border.withValues(alpha: 0.6),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.item});

  final WalletLedgerItem item;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final positive = item.delta >= 0;
    final tone = _ledgerTone(item, colors);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.surfaceStrong,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_sourceIcon(item.source), color: tone, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sourceLabel(text, item.source),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(context, item.createdAtUtc),
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${positive ? '+' : ''}${item.delta}',
                style: TextStyle(
                  color: tone,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text.walletBalanceAfter(item.balanceAfter),
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PurchasesSection extends StatelessWidget {
  const _PurchasesSection({required this.items, this.highlightedOrderId});

  final List<PurchaseHistoryItem> items;
  final String? highlightedOrderId;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final visibleItems = items.take(5).toList(growable: false);

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: text.walletPurchaseHistoryTitle),
        ProfileGlassCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              for (var index = 0; index < visibleItems.length; index++) ...[
                _PurchaseRow(
                  item: visibleItems[index],
                  isHighlighted:
                      visibleItems[index].orderId == highlightedOrderId,
                ),
                if (index != visibleItems.length - 1)
                  const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PurchaseRow extends StatelessWidget {
  const _PurchaseRow({required this.item, required this.isHighlighted});

  final PurchaseHistoryItem item;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final statusColor = _purchaseStatusColor(item.status, colors);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: isHighlighted
            ? colors.accent.withValues(alpha: 0.1)
            : colors.surfaceStrong.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighlighted
              ? colors.accent.withValues(alpha: 0.45)
              : colors.border.withValues(alpha: 0.78),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 20,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.packDisplayName,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text.walletPurchaseSummary(
                    item.sparkToGrant,
                    _formatDate(
                      context,
                      item.confirmedAtUtc ?? item.createdAtUtc,
                    ),
                  ),
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isHighlighted) ...[
                  const SizedBox(height: 6),
                  Text(
                    text.walletPurchaseJustConfirmed,
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ProfileStatusPill(
            label: _purchaseStatusLabel(text, item.status),
            leading: isHighlighted ? Icons.check_circle_rounded : null,
            backgroundColor: statusColor.withValues(
              alpha: isHighlighted ? 0.2 : 0.14,
            ),
            foregroundColor: statusColor,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: colors.accent,
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.45),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletUnavailableCard extends StatelessWidget {
  const _WalletUnavailableCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.danger.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.error_outline_rounded, color: colors.danger),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text.walletUnavailableTitle,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: colors.textSoft,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(text.walletTryAgainAction),
          ),
        ],
      ),
    );
  }
}
