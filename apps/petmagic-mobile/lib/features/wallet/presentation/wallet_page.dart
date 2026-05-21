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
  bool _isCheckingCheckout = false;
  String? _checkoutStatusMessage;
  bool _checkoutStatusIsError = false;
  String? _pendingCheckoutOrderId;
  String? _highlightedPurchaseOrderId;

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
      unawaited(_refreshAfterCheckout());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletControllerProvider);
    final controller = ref.read(walletControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final bottomNavInset = petMagicBottomNavInset(context);

    ref.listen(walletControllerProvider, (previous, next) {
      final checkoutUrl = next.checkoutUrl;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        return;
      }

      _pendingCheckoutOrderId = next.pendingCheckoutOrderId;
      _checkoutStatusMessage = null;
      _checkoutStatusIsError = false;
      _highlightedPurchaseOrderId = null;

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
                  padding: EdgeInsets.fromLTRB(16, 12, 16, bottomNavInset),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _WalletHeader(
                      title: text.walletPageTitle,
                      subtitle: text.walletPageSubtitle,
                      onRefresh: () => controller.load(refresh: true),
                    ),
                    if (_isCheckingCheckout) ...[
                      const SizedBox(height: 14),
                      ProfileProgressCard(
                        title: text.externalCheckoutCheckingTitle,
                        message: text.externalCheckoutCheckingMessage,
                        tone: colors.accent,
                        isLoading: true,
                      ),
                    ],
                    if (_checkoutStatusMessage != null) ...[
                      const SizedBox(height: 14),
                      ProfileMessageCard(
                        message: _checkoutStatusMessage!,
                        tone: _checkoutStatusIsError
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
                        highlightedOrderId: _highlightedPurchaseOrderId,
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

  Future<void> _refreshAfterCheckout() async {
    if (!mounted) {
      return;
    }

    final text = AppLocalizations.of(context);
    final controller = ref.read(walletControllerProvider.notifier);

    setState(() {
      _isCheckingCheckout = true;
      _checkoutStatusMessage = null;
      _checkoutStatusIsError = false;
    });

    await controller.load(refresh: true);

    if (!mounted) {
      return;
    }

    final state = ref.read(walletControllerProvider);
    PurchaseHistoryItem? purchase;
    for (final item in state.purchases) {
      if (item.orderId == _pendingCheckoutOrderId) {
        purchase = item;
        break;
      }
    }

    setState(() {
      _isCheckingCheckout = false;

      if (state.wallet == null && state.errorMessage != null) {
        _checkoutStatusMessage = _friendlyError(text, state.errorMessage!);
        _checkoutStatusIsError = true;
        return;
      }

      if (purchase != null && purchase.status == 'succeeded') {
        _checkoutStatusMessage = text.walletCheckoutSucceeded(
          purchase.sparkToGrant,
        );
        _checkoutStatusIsError = false;
        _highlightedPurchaseOrderId = purchase.orderId;
        _pendingCheckoutOrderId = null;
        return;
      }

      _checkoutStatusMessage = text.externalCheckoutPendingVerificationMessage;
      _checkoutStatusIsError = false;
    });
  }
}

class _WalletHeader extends StatelessWidget {
  const _WalletHeader({
    required this.title,
    required this.subtitle,
    required this.onRefresh,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final canPop = Navigator.of(context).canPop();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (canPop)
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                    )
                  else
                    const SizedBox(width: 48, height: 48),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: text.walletRefreshTooltip,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (canPop)
              IconButton.filledTonal(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              )
            else
              const SizedBox(width: 48, height: 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
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
            const SizedBox(width: 10),
            IconButton.filledTonal(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: text.walletRefreshTooltip,
            ),
          ],
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet});

  final WalletStateModel? wallet;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final balance = wallet?.balance ?? 0;

    return ProfileGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: colors.accent,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.walletBalanceEyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      text.walletBalanceTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 15.5,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ProfileStatusPill(
            label: wallet?.isPremium == true
                ? text.walletPremiumStatus
                : text.walletFreeStatus,
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
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceStrong.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border.withValues(alpha: 0.86)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  NumberFormat.decimalPattern().format(balance),
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  text.walletBalanceUnit,
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text.walletBalanceExplanation,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardsOverviewCard extends StatelessWidget {
  const _RewardsOverviewCard({
    required this.wallet,
    required this.isClaimingAd,
    required this.onClaimAd,
  });

  final WalletStateModel? wallet;
  final bool isClaimingAd;
  final VoidCallback onClaimAd;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final remaining = wallet?.adRewardsRemainingToday ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: text.walletRewardsTitle),
        _RewardStatusCard(
          icon: Icons.play_circle_outline_rounded,
          title: text.walletAdRewardCompactTitle,
          subtitle: text.walletAdRewardCompactDescription,
          badgeLabel: text.walletAdRewardRemaining(remaining),
          actionLabel: text.walletWatchAdAction,
          accent: colors.blue,
          onTap: remaining <= 0 || isClaimingAd ? null : onClaimAd,
          isLoading: isClaimingAd,
        ),
      ],
    );
  }
}

class _RewardStatusCard extends StatelessWidget {
  const _RewardStatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.actionLabel,
    required this.accent,
    required this.onTap,
    required this.isLoading,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final String actionLabel;
  final Color accent;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return ProfileGlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: accent.withValues(alpha: 0.2)),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 12.2,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProfileStatusPill(
            label: badgeLabel,
            leading: Icons.bolt_rounded,
            backgroundColor: accent.withValues(alpha: 0.14),
            foregroundColor: accent,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onTap,
              icon: Icon(
                isLoading
                    ? Icons.hourglass_top_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(isLoading ? '...' : actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

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
