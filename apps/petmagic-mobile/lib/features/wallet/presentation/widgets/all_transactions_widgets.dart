import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';
import 'package:petmagic_mobile/shared/profile/profile_surface_widgets.dart';

class AllTransactionsErrorState extends StatelessWidget {
  const AllTransactionsErrorState({
    required this.message,
    required this.tone,
    required this.onRetry,
    super.key,
  });

  final String message;
  final Color tone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: colors.textStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(text.retryAction),
            ),
          ],
        ),
      ),
    );
  }
}

int allTransactionListItemCount({
  required int itemCount,
  required bool hasError,
  required bool showLoadMoreIndicator,
  required bool showLoadMoreError,
}) {
  final leadingItems = hasError ? 2 : 1;
  final contentItems = itemCount == 0 ? (hasError ? 0 : 1) : itemCount;
  final trailingItems = showLoadMoreIndicator || showLoadMoreError ? 1 : 0;
  return leadingItems + contentItems + trailingItems;
}

class AllTransactionsLoadMoreIndicator extends StatelessWidget {
  const AllTransactionsLoadMoreIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator.adaptive(
          key: ValueKey<String>('wallet_transactions_load_more'),
          strokeWidth: 2.6,
        ),
      ),
    );
  }
}

class AllTransactionsLoadMoreError extends StatelessWidget {
  const AllTransactionsLoadMoreError({
    required this.message,
    required this.tone,
    required this.onRetry,
    super.key,
  });

  final String message;
  final Color tone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AllTransactionsErrorState(
      message: message,
      tone: tone,
      onRetry: onRetry,
    );
  }
}

class AllTransactionsHeader extends StatelessWidget {
  const AllTransactionsHeader({
    required this.title,
    required this.onBack,
    super.key,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class AllTransactionsEmptyState extends StatelessWidget {
  const AllTransactionsEmptyState({
    required this.asset,
    required this.message,
    super.key,
  });

  final String asset;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return ProfileGlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        children: [
          Image.asset(
            asset,
            height: 84,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSoft),
          ),
        ],
      ),
    );
  }
}

class AllTransactionsRow extends StatelessWidget {
  const AllTransactionsRow({required this.item, super.key});

  final WalletLedgerItem item;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final positive = item.delta >= 0;
    final tone = _ledgerTone(item, colors);

    return Padding(
      key: ValueKey<String>('wallet_transaction_${item.entryId}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
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
        ],
      ),
    );
  }
}

String _sourceLabel(AppLocalizations text, String source) {
  return switch (source) {
    'pack_purchase' => text.walletSourcePackPurchase,
    'generation_spend' => text.walletSourceGenerationSpend,
    'generation_refund' => text.walletSourceGenerationRefund,
    'weekly_grant' ||
    'premium_subscription_weekly_grant' => text.walletSourceWeeklyGrant,
    'ad_reward' => text.walletSourceAdReward,
    'promo_redeem' || 'redeem_code' => text.walletSourcePromoCode,
    'admin_grant' => text.walletSourceAdminGrant,
    'admin_debit' => text.walletSourceAdminDebit,
    _ => text.walletSourceOther,
  };
}

String friendlyTransactionsError(AppLocalizations text, String raw) {
  final value = raw.toLowerCase();

  if (value.contains('wallet.ledger_failed')) {
    return text.walletPartialActivityUnavailable;
  }

  if (value.contains('wallet.network_unavailable')) {
    return text.walletRedeemOfflineError;
  }

  if (value.contains('wallet.payment_unavailable')) {
    return text.walletPaymentUnavailableError;
  }

  if (value.contains('wallet.packs_failed')) {
    return text.walletPaymentUnavailableError;
  }

  return text.walletDataUnavailableFallback;
}

IconData _sourceIcon(String source) {
  return switch (source) {
    'pack_purchase' => Icons.account_balance_wallet_rounded,
    'generation_spend' => Icons.auto_awesome_rounded,
    'generation_refund' => Icons.undo_rounded,
    'weekly_grant' ||
    'premium_subscription_weekly_grant' => Icons.card_giftcard_rounded,
    'ad_reward' => Icons.play_circle_fill_rounded,
    'promo_redeem' || 'redeem_code' => Icons.confirmation_number_rounded,
    'admin_grant' => Icons.support_agent_rounded,
    'admin_debit' => Icons.remove_circle_outline_rounded,
    _ => Icons.receipt_long_rounded,
  };
}

String _formatDate(BuildContext context, DateTime? value) {
  if (value == null) {
    return AppLocalizations.of(context).walletPending;
  }

  return DateFormat.MMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).add_Hm().format(value.toLocal());
}

Color _ledgerTone(WalletLedgerItem item, PetMagicColors colors) {
  return switch (item.source) {
    'generation_spend' || 'admin_debit' => colors.danger,
    'generation_refund' => colors.textMuted,
    _ => item.delta >= 0 ? colors.accent : colors.danger,
  };
}
