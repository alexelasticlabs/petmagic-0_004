import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_pack_selection.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:url_launcher/url_launcher.dart';

part 'widgets/wallet_page_overview_widgets.dart';
part 'widgets/wallet_page_activity_widgets.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  static const routePath = '/wallet';
  static const legacyRoutePath = '/profile/wallet';

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage>
    with WidgetsBindingObserver {
  bool _shouldReloadOnResume = false;

  static const _warningTone = Color(0xFFD7A44A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => ref.read(walletControllerProvider.notifier).load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _shouldReloadOnResume) {
      _shouldReloadOnResume = false;
      unawaited(
        ref.read(walletControllerProvider.notifier).verifyCheckoutStatus(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletControllerProvider);
    final controller = ref.read(walletControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final bottomNavInset = petMagicBottomNavInset(context);
    final checkoutStatusMessage = _checkoutStatusMessage(text, state);

    ref.listen(walletControllerProvider, (previous, next) {
      final checkoutUrl = next.checkoutUrl;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        return;
      }

      controller.resetCheckoutVerification();
      controller.consumeCheckoutUrl();
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
                  padding: EdgeInsets.fromLTRB(16, 12, 16, bottomNavInset),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _WalletHeader(
                      title: text.walletPageTitle,
                      subtitle: text.walletPageSubtitle,
                      onRefresh: () => controller.load(refresh: true),
                    ),
                    if (state.checkoutVerificationState ==
                        WalletCheckoutVerificationState.checking) ...[
                      const SizedBox(height: 14),
                      ProfileProgressCard(
                        title: text.externalCheckoutCheckingTitle,
                        message: text.externalCheckoutCheckingMessage,
                        tone: colors.accent,
                        isLoading: true,
                      ),
                    ],
                    if (checkoutStatusMessage != null) ...[
                      const SizedBox(height: 14),
                      ProfileMessageCard(
                        message: checkoutStatusMessage,
                        tone:
                            state.checkoutVerificationState ==
                                WalletCheckoutVerificationState.error
                            ? _warningTone
                            : colors.accent,
                      ),
                    ],
                    if (state.wallet == null) ...[
                      const SizedBox(height: 18),
                      _WalletUnavailableCard(
                        message: _friendlyError(
                          text,
                          state.errorMessage ??
                              text.walletDataUnavailableFallback,
                        ),
                        onRetry: () => controller.load(refresh: true),
                      ),
                    ] else ...[
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 14),
                        ProfileMessageCard(
                          message: _friendlyError(text, state.errorMessage!),
                          tone: _warningTone,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _BalanceCard(wallet: state.wallet),
                      const SizedBox(height: 14),
                      _RewardsOverviewCard(
                        wallet: state.wallet,
                        isClaimingAd: state.isClaimingAd,
                        onClaimAd: controller.claimAdReward,
                      ),
                      _PacksSection(
                        packs: state.packs,
                        isBuying: state.isBuying,
                        onSelect: (pack) => _showPackDetailSheet(
                          context,
                          pack,
                          isBuying: state.isBuying,
                          onBuy: () => controller.buyPack(pack),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _LedgerSection(items: state.ledger),
                      const SizedBox(height: 14),
                      _PurchasesSection(
                        items: state.purchases,
                        highlightedOrderId: state.highlightedPurchaseOrderId,
                      ),
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

    _shouldReloadOnResume = true;
    final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!launched) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

Future<void> _showPackDetailSheet(
  BuildContext context,
  CurrencyPackModel pack, {
  required bool isBuying,
  required Future<String?> Function() onBuy,
}) async {
  final text = AppLocalizations.of(context);
  final colors = context.petMagicColors;
  final price = _formatPrice(pack);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.bolt_rounded, color: colors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.displayName,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        text.walletPackDetailSubtitle,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceStrong.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.walletPackTotalSpark(pack.totalSpark),
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 23,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          text.walletPackBreakdown(
                            pack.grantedSpark,
                            pack.bonusSpark,
                          ),
                          style: TextStyle(
                            color: colors.textSoft,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    price,
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (pack.bonusSpark > 0) ...[
              const SizedBox(height: 12),
              _PackDetailRow(
                icon: Icons.add_circle_outline_rounded,
                label: text.walletPackBonusPill(pack.bonusSpark),
                accent: colors.gold,
              ),
            ],
            const SizedBox(height: 12),
            ProfileProgressCard(
              title: text.externalCheckoutStripeTitle,
              message: text.externalCheckoutStripeMessage,
              tone: colors.gold,
              icon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isBuying
                    ? null
                    : () async {
                        Navigator.of(sheetContext).pop();
                        await onBuy();
                      },
                icon: Icon(
                  isBuying
                      ? Icons.hourglass_top_rounded
                      : Icons.open_in_browser_rounded,
                ),
                label: Text(text.externalCheckoutContinueAction),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text.walletCheckoutHint,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    },
  );
}

String _formatPrice(CurrencyPackModel pack) {
  return NumberFormat.simpleCurrency(
    name: pack.currencyCode,
  ).format(pack.priceAmount);
}

String _formatDate(BuildContext context, DateTime? value) {
  if (value == null) {
    return AppLocalizations.of(context).walletPending;
  }

  return DateFormat.MMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(value.toLocal());
}

String _sourceLabel(AppLocalizations text, String source) {
  return switch (source) {
    'pack_purchase' => text.walletSourcePackPurchase,
    'generation_spend' => text.walletSourceGenerationSpend,
    'generation_refund' => text.walletSourceGenerationRefund,
    'weekly_grant' => text.walletSourceWeeklyGrant,
    'ad_reward' => text.walletSourceAdReward,
    'admin_grant' => text.walletSourceAdminGrant,
    'admin_debit' => text.walletSourceAdminDebit,
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

String _purchaseStatusLabel(AppLocalizations text, String status) {
  return switch (status) {
    'succeeded' => text.walletPurchaseCompleted,
    'failed' => text.walletPurchaseFailed,
    _ => text.walletPending,
  };
}

Color _purchaseStatusColor(String status, PetMagicColors colors) {
  return switch (status) {
    'succeeded' => colors.accent,
    'failed' => colors.danger,
    _ => colors.gold,
  };
}

Color _ledgerTone(WalletLedgerItem item, PetMagicColors colors) {
  return switch (item.source) {
    'generation_spend' || 'admin_debit' => colors.danger,
    'generation_refund' => colors.textMuted,
    _ => item.delta >= 0 ? colors.accent : colors.danger,
  };
}

String? _checkoutStatusMessage(AppLocalizations text, WalletState state) {
  return switch (state.checkoutVerificationState) {
    WalletCheckoutVerificationState.idle => null,
    WalletCheckoutVerificationState.checking => null,
    WalletCheckoutVerificationState.succeeded => text.walletCheckoutSucceeded(
      state.checkoutGrantedSpark ?? 0,
    ),
    WalletCheckoutVerificationState.pending =>
      text.externalCheckoutPendingVerificationMessage,
    WalletCheckoutVerificationState.error => _friendlyError(
      text,
      state.checkoutErrorMessage ??
          state.errorMessage ??
          text.walletDataUnavailableFallback,
    ),
  };
}

String _friendlyError(AppLocalizations text, String value) {
  if (value.contains('wallet.ledger_failed') ||
      value.contains('wallet.packs_failed') ||
      value.contains('wallet.purchases_failed')) {
    return text.walletPartialActivityUnavailable;
  }

  if (value.contains('payment_gateway_failed')) {
    return text.walletPaymentGatewayUnavailableError;
  }

  if (value.contains('economy.pack_not_found')) {
    return text.walletPackUnavailableError;
  }

  if (value.contains('redeem_code_not_found')) {
    return text.walletRedeemCodeNotFoundError;
  }

  if (value.contains('redeem_code_already_used')) {
    return text.walletRedeemCodeAlreadyUsedError;
  }

  if (value.contains('redeem_code_expired')) {
    return text.walletRedeemCodeExpiredError;
  }

  if (value.contains('redeem_code_inactive')) {
    return text.walletRedeemCodeInactiveError;
  }

  if (value.contains('redeem_code_exhausted')) {
    return text.walletRedeemCodeExhaustedError;
  }

  if (value.contains('redeem_code_user_limit_reached')) {
    return text.walletRedeemCodeUserLimitError;
  }

  if (value.contains('economy.insufficient_balance')) {
    return text.walletInsufficientBalanceError;
  }

  if (value.contains('wallet.network_unavailable')) {
    return text.walletRedeemOfflineError;
  }

  if (value.contains('wallet.server_unavailable')) {
    return text.walletRedeemServerError;
  }

  if (value.contains('AppException(500)') ||
      value.contains('processing your request')) {
    return text.walletRedeemServerError;
  }

  return value;
}
