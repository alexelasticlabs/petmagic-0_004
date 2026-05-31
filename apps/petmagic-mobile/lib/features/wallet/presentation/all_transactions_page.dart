import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';

class AllTransactionsPage extends ConsumerStatefulWidget {
  const AllTransactionsPage({super.key});

  static const routeName = 'wallet-all-transactions';
  static const routePath = '/profile/wallet/transactions';
  static const legacyRoutePath = '/wallet/transactions';

  @override
  ConsumerState<AllTransactionsPage> createState() =>
      _AllTransactionsPageState();
}

class _AllTransactionsPageState extends ConsumerState<AllTransactionsPage> {
  static const String _kAllTransactionsEmptyAsset =
      'assets/rewards/wallet-pack-chest.png';

  @override
  void initState() {
    super.initState();
    final snapshot = ref.read(walletControllerProvider);
    if (snapshot.wallet == null && snapshot.ledger.isEmpty) {
      Future.microtask(
        () => ref.read(walletControllerProvider.notifier).load(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final state = ref.watch(walletControllerProvider);
    final controller = ref.read(walletControllerProvider.notifier);
    final router = GoRouter.of(context);
    final errorToShow = state.errorMessage != null && state.ledger.isEmpty
        ? _friendlyTransactionsError(text, state.errorMessage!)
        : null;
    final hasShell =
        context.findAncestorWidgetOfExactType<PetMagicShell>() != null;
    final bottomInset = hasShell
        ? petMagicScrollableBottomInset(
            context,
            extraSpacing: kPetMagicBottomContentInsetRelaxed,
          )
        : MediaQuery.viewPaddingOf(context).bottom +
              kPetMagicBottomContentInsetCompact;

    return ProfileScreenBackground(
      child: SafeArea(
        child: state.isInitialLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : RefreshIndicator.adaptive(
                color: colors.accent,
                onRefresh: () => controller.load(refresh: true),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () {
                            if (router.canPop()) {
                              router.pop();
                              return;
                            }

                            router.go(WalletPage.routePath);
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            text.walletViewAllTransactions,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (errorToShow != null) ...[
                      const SizedBox(height: 12),
                      ProfileMessageCard(
                        message: errorToShow,
                        tone: colors.gold,
                      ),
                    ],
                    const SizedBox(height: 16),
                    ProfileGlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: state.ledger.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
                              child: Column(
                                children: [
                                  Image.asset(
                                    _kAllTransactionsEmptyAsset,
                                    height: 84,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.medium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    text.walletNoActivity,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: colors.textSoft),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                for (
                                  var index = 0;
                                  index < state.ledger.length;
                                  index++
                                )
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: index == state.ledger.length - 1
                                          ? 0
                                          : 4,
                                    ),
                                    child: _AllTransactionsRow(
                                      item: state.ledger[index],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _AllTransactionsRow extends StatelessWidget {
  const _AllTransactionsRow({required this.item});

  final WalletLedgerItem item;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final positive = item.delta >= 0;
    final tone = _ledgerTone(item, colors);

    return Padding(
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
          const SizedBox(height: 6),
          Divider(
            height: 1,
            thickness: 0.8,
            color: colors.border.withValues(alpha: 0.6),
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
    _ => source,
  };
}

String _friendlyTransactionsError(AppLocalizations text, String raw) {
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
