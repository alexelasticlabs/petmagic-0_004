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
    final featuredPack = selectPopularPack(packs);

    if (packs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: text.walletBuySparkTitle),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: packs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final pack = packs[index];
            return _PackListTile(
              pack: pack,
              isFeatured: featuredPack?.packId == pack.packId,
              isBuying: isBuying,
              onTap: () => onSelect(pack),
            );
          },
        ),
      ],
    );
  }
}

class _PackListTile extends StatelessWidget {
  const _PackListTile({
    required this.pack,
    required this.isFeatured,
    required this.isBuying,
    required this.onTap,
  });

  final CurrencyPackModel pack;
  final bool isFeatured;
  final bool isBuying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final accent = isFeatured ? colors.gold : colors.accent;
    final price = _formatPrice(pack);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: isBuying ? null : onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isFeatured
                  ? colors.gold.withValues(alpha: 0.28)
                  : colors.border,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isFeatured
                  ? [
                      colors.gold.withValues(alpha: 0.17),
                      colors.accent.withValues(alpha: 0.08),
                      colors.surfaceGlass,
                    ]
                  : [
                      colors.surfaceGlass,
                      colors.surfaceStrong.withValues(alpha: 0.3),
                    ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 350;
                final leading = Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Icon(
                    isFeatured
                        ? Icons.workspace_premium_rounded
                        : Icons.bolt_rounded,
                    color: accent,
                    size: 21,
                  ),
                );
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (isFeatured) ...[
                      const SizedBox(height: 7),
                      ProfileStatusPill(
                        label: text.walletPopularBadge,
                        leading: Icons.local_fire_department_rounded,
                        backgroundColor: colors.gold.withValues(alpha: 0.16),
                        foregroundColor: colors.gold,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      text.walletPackBreakdown(
                        pack.grantedSpark,
                        pack.bonusSpark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
                final value = Column(
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        color: accent,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text.walletPackTotalSpark(pack.totalSpark),
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          text.walletPackDetailsAction,
                          style: TextStyle(
                            color: colors.textSoft,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: colors.textSoft,
                          size: 15,
                        ),
                      ],
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          leading,
                          const SizedBox(width: 12),
                          Expanded(child: details),
                        ],
                      ),
                      const SizedBox(height: 12),
                      value,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                    const SizedBox(width: 12),
                    value,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PackDetailRow extends StatelessWidget {
  const _PackDetailRow({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: accent),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerSection extends StatelessWidget {
  const _LedgerSection({required this.items});

  final List<WalletLedgerItem> items;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: text.walletRecentTransactionsTitle),
        ProfileGlassCard(
          padding: EdgeInsets.zero,
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    text.walletNoActivity,
                    style: TextStyle(color: colors.textSoft),
                  ),
                )
              : Column(
                  children: [
                    for (var index = 0; index < items.length; index++)
                      _LedgerRow(
                        item: items[index],
                        showDivider: index != items.length - 1,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.item, required this.showDivider});

  final WalletLedgerItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final positive = item.delta >= 0;
    final tone = _ledgerTone(item, colors);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(color: colors.border.withValues(alpha: 0.6)),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_sourceIcon(item.source), color: tone, size: 23),
            ),
            const SizedBox(width: 12),
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(context, item.createdAtUtc),
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
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
                const SizedBox(height: 4),
                Text(
                  text.walletBalanceAfter(item.balanceAfter),
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
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

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: text.walletPurchaseHistoryTitle),
        ProfileGlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              for (final item in items.take(5))
                _PurchaseRow(
                  item: item,
                  isHighlighted: item.orderId == highlightedOrderId,
                ),
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
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlighted
            ? colors.accent.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighlighted
              ? colors.accent.withValues(alpha: 0.45)
              : colors.border.withValues(alpha: 0),
        ),
      ),
      child: Row(
        children: [
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
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Text(
        title,
        style: TextStyle(
          color: colors.textStrong,
          fontSize: 15.5,
          fontWeight: FontWeight.w900,
        ),
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
