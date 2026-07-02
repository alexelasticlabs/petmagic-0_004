import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

class AllTransactionsPage extends ConsumerStatefulWidget {
  const AllTransactionsPage({super.key});

  static const routeName = 'wallet-all-transactions';
  static const routePath = '/profile/wallet/transactions';

  @override
  ConsumerState<AllTransactionsPage> createState() =>
      _AllTransactionsPageState();
}

class _AllTransactionsPageState extends ConsumerState<AllTransactionsPage> {
  static const String _kAllTransactionsEmptyAsset =
      'assets/rewards/wallet-pack-chest.png';
  static const double _ledgerLoadMoreThreshold = 320;

  final ScrollController _scrollController = ScrollController();
  late final WalletController _walletController;
  ProviderSubscription<AppLaunchState>? _launchSubscription;
  bool _wasAuthenticated = false;
  bool _autoLoadMoreScheduled = false;

  @override
  void initState() {
    super.initState();
    _walletController = ref.read(walletControllerProvider.notifier);
    _walletController.setWalletPageVisible(true);
    _scrollController.addListener(_handleScroll);
    _launchSubscription = ref.listenManual<AppLaunchState>(
      appLaunchControllerProvider,
      (_, next) => _handleLaunchState(next),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _launchSubscription?.close();
    _scrollController.dispose();
    _walletController.setWalletPageVisible(false);
    super.dispose();
  }

  @override
  void deactivate() {
    _walletController.setWalletPageVisible(false);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _walletController.setWalletPageVisible(true);
  }

  void _handleLaunchState(AppLaunchState launchState) {
    if (launchState.isAuthenticated && !_wasAuthenticated) {
      _wasAuthenticated = true;
      _scheduleInitialLoadIfNeeded();
      return;
    }

    _wasAuthenticated = launchState.isAuthenticated;
  }

  void _scheduleInitialLoadIfNeeded() {
    final snapshot = ref.read(walletControllerProvider);
    if (_hasHydratedTransactionsSnapshot(snapshot)) {
      return;
    }

    Future.microtask(() {
      if (!mounted) {
        return;
      }
      if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
        return;
      }

      final current = ref.read(walletControllerProvider);
      if (_hasHydratedTransactionsSnapshot(current)) {
        return;
      }

      _walletController.load();
    });
  }

  bool _hasHydratedTransactionsSnapshot(WalletState state) {
    return state.ledger.isNotEmpty ||
        (state.hasCompletedFullLoad && state.wallet != null);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        !ref.read(appLaunchControllerProvider).isAuthenticated) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - _ledgerLoadMoreThreshold) {
      return;
    }

    _walletController.loadMoreLedger();
  }

  void _scheduleAutoLoadMoreIfNeeded(WalletState state) {
    if (_autoLoadMoreScheduled ||
        state.ledger.isEmpty ||
        !state.ledgerHasMore ||
        state.isLoadingMoreLedger ||
        state.ledgerLoadMoreErrorMessage != null) {
      return;
    }

    _autoLoadMoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLoadMoreScheduled = false;
      if (!mounted ||
          !_scrollController.hasClients ||
          !ref.read(appLaunchControllerProvider).isAuthenticated) {
        return;
      }

      final position = _scrollController.position;
      if (position.maxScrollExtent > _ledgerLoadMoreThreshold) {
        return;
      }

      _walletController.loadMoreLedger();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select((launch) => launch.isAuthenticated),
    );
    final state = ref.watch(walletControllerProvider);
    final router = GoRouter.of(context);
    final errorToShow = state.errorMessage != null && state.ledger.isEmpty
        ? _friendlyTransactionsError(text, state.errorMessage!)
        : null;
    final loadMoreErrorToShow =
        state.ledgerLoadMoreErrorMessage != null && state.ledger.isNotEmpty
        ? _friendlyTransactionsError(text, state.ledgerLoadMoreErrorMessage!)
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

    if (!isAuthenticated) {
      return ProfileScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: ProtectedAuthGate(
              subtitle: text.authRequiredMessage,
              onSignIn: () => showAuthRequiredSheet(
                context,
                redirectPath: AllTransactionsPage.routePath,
              ),
            ),
          ),
        ),
      );
    }

    _scheduleAutoLoadMoreIfNeeded(state);

    return ProfileScreenBackground(
      child: SafeArea(
        child: state.isInitialLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : RefreshIndicator.adaptive(
                color: colors.accent,
                onRefresh: () => _walletController.load(refresh: true),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _transactionListItemCount(
                    itemCount: state.ledger.length,
                    hasError: errorToShow != null,
                    showLoadMoreIndicator: state.isLoadingMoreLedger,
                    showLoadMoreError: loadMoreErrorToShow != null,
                  ),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _AllTransactionsHeader(
                        title: text.walletViewAllTransactions,
                        onBack: () {
                          if (router.canPop()) {
                            router.pop();
                            return;
                          }

                          router.go(WalletPage.routePath);
                        },
                      );
                    }

                    final contentStartIndex = errorToShow == null ? 1 : 2;
                    if (errorToShow != null && index == 1) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _AllTransactionsErrorState(
                          message: errorToShow,
                          tone: colors.gold,
                          onRetry: () =>
                              unawaited(_walletController.load(refresh: true)),
                        ),
                      );
                    }

                    if (state.ledger.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _AllTransactionsEmptyState(
                          asset: _kAllTransactionsEmptyAsset,
                          message: text.walletNoActivity,
                        ),
                      );
                    }

                    final ledgerIndex = index - contentStartIndex;
                    if (ledgerIndex >= state.ledger.length) {
                      if (loadMoreErrorToShow != null) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 4),
                          child: _AllTransactionsLoadMoreError(
                            message: loadMoreErrorToShow,
                            tone: colors.gold,
                            onRetry: () => unawaited(
                              _walletController.loadMoreLedger(force: true),
                            ),
                          ),
                        );
                      }

                      return const Padding(
                        padding: EdgeInsets.only(top: 12, bottom: 4),
                        child: _AllTransactionsLoadMoreIndicator(),
                      );
                    }

                    return Padding(
                      padding: EdgeInsets.only(top: ledgerIndex == 0 ? 16 : 8),
                      child: ProfileGlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: _AllTransactionsRow(
                          item: state.ledger[ledgerIndex],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _AllTransactionsErrorState extends StatelessWidget {
  const _AllTransactionsErrorState({
    required this.message,
    required this.tone,
    required this.onRetry,
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

int _transactionListItemCount({
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

class _AllTransactionsLoadMoreIndicator extends StatelessWidget {
  const _AllTransactionsLoadMoreIndicator();

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

class _AllTransactionsLoadMoreError extends StatelessWidget {
  const _AllTransactionsLoadMoreError({
    required this.message,
    required this.tone,
    required this.onRetry,
  });

  final String message;
  final Color tone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _AllTransactionsErrorState(
      message: message,
      tone: tone,
      onRetry: onRetry,
    );
  }
}

class _AllTransactionsHeader extends StatelessWidget {
  const _AllTransactionsHeader({required this.title, required this.onBack});

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

class _AllTransactionsEmptyState extends StatelessWidget {
  const _AllTransactionsEmptyState({
    required this.asset,
    required this.message,
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
