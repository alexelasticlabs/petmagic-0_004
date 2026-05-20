import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  static const routePath = '/profile/wallet';

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(walletControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletControllerProvider);
    final controller = ref.read(walletControllerProvider.notifier);
    final colors = context.petMagicColors;

    ref.listen(walletControllerProvider, (previous, next) {
      final checkoutUrl = next.checkoutUrl;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        return;
      }

      controller.clearCheckoutUrl();
      _openCheckout(checkoutUrl);
    });

    return ProfileScreenBackground(
      child: SafeArea(
        child: state.isInitialLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : RefreshIndicator.adaptive(
                onRefresh: () => controller.load(refresh: true),
                color: colors.accent,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _WalletHeader(
                      onRefresh: () => controller.load(refresh: true),
                    ),
                    if (state.wallet == null) ...[
                      const SizedBox(height: 18),
                      _WalletUnavailableCard(
                        message: _friendlyError(
                          state.errorMessage ??
                              'Wallet data is not available right now.',
                        ),
                        onRetry: () => controller.load(refresh: true),
                      ),
                    ] else ...[
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 14),
                        ProfileMessageCard(
                          message: _friendlyError(state.errorMessage!),
                          tone: colors.danger,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _BalanceCard(
                        wallet: state.wallet,
                        paymentMethodCount: state.paymentMethods.length,
                      ),
                      const SizedBox(height: 14),
                      _QuickActions(
                        isClaimingWeekly: state.isClaimingWeekly,
                        isClaimingAd: state.isClaimingAd,
                        onClaimWeekly: controller.claimWeeklyGrant,
                        onClaimAd: controller.claimAdReward,
                        onShowRedeem: () =>
                            _showRedeemSheet(context, controller),
                        onShowPaymentMethods: () => _showPaymentMethodsSheet(
                          context,
                          controller,
                          state.paymentMethods,
                          isSettingUp: state.isSettingUpPaymentMethod,
                          removingPaymentMethodId:
                              state.removingPaymentMethodId,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _PacksSection(
                        packs: state.packs,
                        isBuying: state.isBuying,
                        onBuy: (pack) => _handlePackPurchase(
                          context,
                          controller,
                          state,
                          pack,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _LedgerSection(items: state.ledger),
                      const SizedBox(height: 14),
                      _PurchasesSection(items: state.purchases),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _openCheckout(String checkoutUrl) async {
    final uri = Uri.tryParse(checkoutUrl);
    if (uri == null) {
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!launched) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handlePackPurchase(
    BuildContext context,
    WalletController controller,
    WalletState state,
    CurrencyPackModel pack,
  ) async {
    if (state.paymentMethods.isEmpty) {
      await controller.buyPack(pack);
      return;
    }

    await _showPackPaymentSheet(
      context,
      pack,
      state.paymentMethods,
      onStripeCheckout: () => controller.buyPack(pack),
      onSavedMethod: (method) =>
          controller.buyPack(pack, paymentMethodId: method.paymentMethodId),
    );
  }
}

class _WalletHeader extends StatelessWidget {
  const _WalletHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wallet',
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Balance, purchases and recent activity',
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          onPressed: onRefresh,
          icon: const Icon(Icons.history_rounded),
          tooltip: 'Refresh history',
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet, required this.paymentMethodCount});

  final WalletStateModel? wallet;
  final int paymentMethodCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final balance = wallet?.balance ?? 0;
    final weeklyReady =
        wallet?.nextWeeklyGrantAtUtc == null ||
        wallet!.nextWeeklyGrantAtUtc!.isBefore(DateTime.now().toUtc());

    return ProfileGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PawSpark balance',
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.pets_rounded,
                          color: colors.accent,
                          size: 28,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            NumberFormat.decimalPattern().format(balance),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              height: 0.98,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ProfileStatusPill(
                      label: wallet?.isPremium == true
                          ? 'Premium wallet'
                          : 'Free wallet',
                      leading: wallet?.isPremium == true
                          ? Icons.workspace_premium_rounded
                          : Icons.person_outline_rounded,
                      backgroundColor: wallet?.isPremium == true
                          ? colors.gold.withValues(alpha: 0.18)
                          : colors.accent.withValues(alpha: 0.13),
                      foregroundColor: wallet?.isPremium == true
                          ? colors.gold
                          : colors.accent,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _WalletMetricChip(
                          icon: Icons.credit_card_rounded,
                          label: '$paymentMethodCount cards',
                        ),
                        _WalletMetricChip(
                          icon: Icons.calendar_month_rounded,
                          label: weeklyReady
                              ? 'Weekly ready'
                              : 'Weekly pending',
                        ),
                        _WalletMetricChip(
                          icon: Icons.play_circle_outline_rounded,
                          label:
                              '${wallet?.adRewardsRemainingToday ?? 0} ad rewards',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: RadialGradient(
                    colors: [
                      colors.accent.withValues(alpha: 0.95),
                      colors.accent.withValues(alpha: 0.22),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.26),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.pets_rounded,
                  color: colors.backgroundBottom,
                  size: 36,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletMetricChip extends StatelessWidget {
  const _WalletMetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.isClaimingWeekly,
    required this.isClaimingAd,
    required this.onClaimWeekly,
    required this.onClaimAd,
    required this.onShowRedeem,
    required this.onShowPaymentMethods,
  });

  final bool isClaimingWeekly;
  final bool isClaimingAd;
  final VoidCallback onClaimWeekly;
  final VoidCallback onClaimAd;
  final VoidCallback onShowRedeem;
  final VoidCallback onShowPaymentMethods;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Quick actions'),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.5,
          children: [
            _ActionTile(
              icon: Icons.credit_card_rounded,
              label: 'Payment methods',
              onTap: onShowPaymentMethods,
            ),
            _ActionTile(
              icon: Icons.card_giftcard_rounded,
              label: 'Redeem code',
              onTap: onShowRedeem,
            ),
            _ActionTile(
              icon: isClaimingWeekly
                  ? Icons.hourglass_top_rounded
                  : Icons.calendar_month_rounded,
              label: 'Weekly reward',
              onTap: isClaimingWeekly ? null : onClaimWeekly,
            ),
            _ActionTile(
              icon: isClaimingAd
                  ? Icons.hourglass_top_rounded
                  : Icons.play_circle_outline_rounded,
              label: 'Ad reward',
              onTap: isClaimingAd ? null : onClaimAd,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surfaceGlass,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: colors.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PacksSection extends StatelessWidget {
  const _PacksSection({
    required this.packs,
    required this.isBuying,
    required this.onBuy,
  });

  final List<CurrencyPackModel> packs;
  final bool isBuying;
  final Future<void> Function(CurrencyPackModel pack) onBuy;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    if (packs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Buy PawSpark'),
        SizedBox(
          height: 138,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: packs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final pack = packs[index];
              return SizedBox(
                width: 176,
                child: ProfileGlassCard(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.pets_rounded, color: colors.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pack.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textStrong,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${pack.totalSpark} PawSpark',
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (pack.bonusSpark > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+${pack.bonusSpark} bonus',
                            style: TextStyle(
                              color: colors.gold,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: isBuying ? null : () => onBuy(pack),
                          child: Text(_formatPrice(pack)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LedgerSection extends StatelessWidget {
  const _LedgerSection({required this.items});

  final List<WalletLedgerItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Recent transactions'),
        ProfileGlassCard(
          padding: EdgeInsets.zero,
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'No wallet activity yet.',
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
    final colors = context.petMagicColors;
    final positive = item.delta >= 0;
    final tone = positive ? colors.accent : colors.danger;

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
                    _sourceLabel(item.source),
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
                    _formatDate(item.createdAtUtc),
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
                  'Bal. ${item.balanceAfter}',
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
  const _PurchasesSection({required this.items});

  final List<PurchaseHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Purchase history'),
        ProfileGlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              for (final item in items.take(5)) _PurchaseRow(item: item),
            ],
          ),
        ),
      ],
    );
  }
}

class _PurchaseRow extends StatelessWidget {
  const _PurchaseRow({required this.item});

  final PurchaseHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                  '${item.sparkToGrant} PawSpark • ${_formatDate(item.confirmedAtUtc ?? item.createdAtUtc)}',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ProfileStatusPill(
            label: _purchaseStatusLabel(item.status),
            backgroundColor: _purchaseStatusColor(
              item.status,
              colors,
            ).withValues(alpha: 0.14),
            foregroundColor: _purchaseStatusColor(item.status, colors),
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
                  'Wallet is temporarily unavailable',
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
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

Future<void> _showPaymentMethodsSheet(
  BuildContext context,
  WalletController controller,
  List<PaymentMethodModel> methods, {
  required bool isSettingUp,
  required String? removingPaymentMethodId,
}) async {
  final colors = context.petMagicColors;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment methods',
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            if (methods.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'No saved cards yet.',
                  style: TextStyle(
                    color: colors.textSoft,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              ...methods.map(
                (method) => _PaymentMethodRow(
                  method: method,
                  isRemoving: removingPaymentMethodId == method.paymentMethodId,
                  onRemove: () async {
                    Navigator.of(sheetContext).pop();
                    await controller.removePaymentMethod(
                      method.paymentMethodId,
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSettingUp
                    ? null
                    : () async {
                        Navigator.of(sheetContext).pop();
                        await controller.createPaymentMethodSetup();
                      },
                icon: Icon(
                  isSettingUp
                      ? Icons.hourglass_top_rounded
                      : Icons.add_card_rounded,
                ),
                label: Text(isSettingUp ? 'Opening Stripe' : 'Add card'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _PaymentMethodRow extends StatelessWidget {
  const _PaymentMethodRow({
    required this.method,
    required this.isRemoving,
    required this.onRemove,
  });

  final PaymentMethodModel method;
  final bool isRemoving;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        color: colors.surfaceGlass,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.credit_card_rounded, color: colors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${method.brand.toUpperCase()} •••• ${method.last4}',
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
                  _formatCardExpiry(method),
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isRemoving ? null : onRemove,
            icon: Icon(
              isRemoving ? Icons.hourglass_top_rounded : Icons.delete_outline,
            ),
            tooltip: 'Remove card',
          ),
        ],
      ),
    );
  }
}

Future<void> _showPackPaymentSheet(
  BuildContext context,
  CurrencyPackModel pack,
  List<PaymentMethodModel> methods, {
  required Future<String?> Function() onStripeCheckout,
  required Future<String?> Function(PaymentMethodModel method) onSavedMethod,
}) async {
  final colors = context.petMagicColors;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatPrice(pack),
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${pack.totalSpark} PawSpark',
              style: TextStyle(
                color: colors.textSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await onStripeCheckout();
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Stripe Checkout'),
              ),
            ),
            const SizedBox(height: 10),
            ...methods.map(
              (method) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await onSavedMethod(method);
                    },
                    icon: const Icon(Icons.credit_card_rounded),
                    label: Text('Pay with •••• ${method.last4}'),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

String _formatCardExpiry(PaymentMethodModel method) {
  final month = method.expMonth;
  final year = method.expYear;
  if (month == null || year == null) {
    return method.isDefault ? 'Default card' : 'Saved card';
  }

  final paddedMonth = month.toString().padLeft(2, '0');
  final suffix = method.isDefault ? ' • default' : '';
  return 'Expires $paddedMonth/$year$suffix';
}

String _formatPrice(CurrencyPackModel pack) {
  return NumberFormat.simpleCurrency(
    name: pack.currencyCode,
  ).format(pack.priceAmount);
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return 'Pending';
  }

  return DateFormat.MMMd().format(value.toLocal());
}

String _sourceLabel(String source) {
  return switch (source) {
    'pack_purchase' => 'Added funds',
    'generation_spend' => 'Template generation',
    'generation_refund' => 'Generation refund',
    'weekly_grant' => 'Weekly reward',
    'ad_reward' => 'Ad reward',
    'admin_grant' => 'Support credit',
    'admin_debit' => 'Support adjustment',
    _ => source,
  };
}

IconData _sourceIcon(String source) {
  return switch (source) {
    'pack_purchase' => Icons.account_balance_wallet_rounded,
    'generation_spend' => Icons.auto_awesome_rounded,
    'generation_refund' => Icons.undo_rounded,
    'weekly_grant' => Icons.card_giftcard_rounded,
    'ad_reward' => Icons.play_circle_fill_rounded,
    'admin_grant' => Icons.support_agent_rounded,
    'admin_debit' => Icons.remove_circle_outline_rounded,
    _ => Icons.receipt_long_rounded,
  };
}

String _purchaseStatusLabel(String status) {
  return switch (status) {
    'succeeded' => 'Completed',
    'failed' => 'Failed',
    _ => 'Pending',
  };
}

Color _purchaseStatusColor(String status, PetMagicColors colors) {
  return switch (status) {
    'succeeded' => colors.accent,
    'failed' => colors.danger,
    _ => colors.gold,
  };
}

String _friendlyError(String value) {
  if (value.contains('redeem_code_not_found')) {
    return 'Redeem code was not found.';
  }

  if (value.contains('redeem_code_already_used')) {
    return 'This redeem code was already used.';
  }

  if (value.contains('redeem_code_expired')) {
    return 'Redeem code has expired.';
  }

  if (value.contains('economy.insufficient_balance')) {
    return 'Not enough PawSpark for this operation.';
  }

  if (value.contains('AppException(500)') ||
      value.contains('processing your request')) {
    return 'Wallet data is temporarily unavailable. Please try again in a moment.';
  }

  if (value.contains('weekly')) {
    return 'Weekly reward is not ready yet.';
  }

  return value;
}

Future<void> _showRedeemSheet(
  BuildContext context,
  WalletController controller,
) async {
  final colors = context.petMagicColors;
  final inputController = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          28 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Redeem code',
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: inputController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'WELCOME-100',
                prefixIcon: Icon(Icons.card_giftcard_rounded),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final code = inputController.text.trim();
                if (code.isEmpty) {
                  return;
                }

                Navigator.of(context).pop();
                await controller.applyRedeemCode(code);
              },
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Apply code'),
            ),
          ],
        ),
      );
    },
  );

  inputController.dispose();
}
