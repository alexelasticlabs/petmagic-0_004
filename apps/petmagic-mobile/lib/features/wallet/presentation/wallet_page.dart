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
      ref.read(walletControllerProvider.notifier).load(refresh: true);
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
                      title: text.profileWalletTitle,
                      subtitle: text.profileWalletHistoryHint,
                      onRefresh: () => controller.load(refresh: true),
                    ),
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
                        isClaimingWeekly: state.isClaimingWeekly,
                        isClaimingAd: state.isClaimingAd,
                        onClaimWeekly: controller.claimWeeklyGrant,
                        onClaimAd: controller.claimAdReward,
                      ),
                      const SizedBox(height: 14),
                      _WalletToolsSection(
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

    _shouldReloadOnResume = true;
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
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final balanceStyle = TextStyle(
            color: colors.textStrong,
            fontSize: compact ? 26 : 34,
            fontWeight: FontWeight.w900,
            height: 0.98,
          );
          final graphic = _WalletAbstractGraphic(
            accent: colors.accent,
            gold: colors.gold,
            blue: colors.blue,
            surface: colors.surfaceStrong,
          );

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.walletBalanceEyebrow,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text.walletBalanceTitle,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(
                    NumberFormat.decimalPattern().format(balance),
                    style: balanceStyle,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      text.walletBalanceUnit,
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: compact ? 18 : 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                text.walletBalanceExplanation,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
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
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerRight, child: graphic),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: content),
              const SizedBox(width: 14),
              graphic,
            ],
          );
        },
      ),
    );
  }
}

class _RewardsOverviewCard extends StatelessWidget {
  const _RewardsOverviewCard({
    required this.wallet,
    required this.isClaimingWeekly,
    required this.isClaimingAd,
    required this.onClaimWeekly,
    required this.onClaimAd,
  });

  final WalletStateModel? wallet;
  final bool isClaimingWeekly;
  final bool isClaimingAd;
  final VoidCallback onClaimWeekly;
  final VoidCallback onClaimAd;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final weeklyReady =
        wallet?.nextWeeklyGrantAtUtc == null ||
        wallet!.nextWeeklyGrantAtUtc!.isBefore(DateTime.now().toUtc());
    final cards = [
      _RewardStatusCard(
        icon: Icons.calendar_month_rounded,
        title: text.walletWeeklyRewardAction,
        subtitle: weeklyReady
            ? text.walletRewardReadyDescription
            : text.walletRewardPendingDescription,
        badgeLabel: weeklyReady
            ? text.walletWeeklyReady
            : text.walletWeeklyPending,
        accent: weeklyReady ? colors.accent : colors.gold,
        onTap: isClaimingWeekly ? null : onClaimWeekly,
        isLoading: isClaimingWeekly,
      ),
      _RewardStatusCard(
        icon: Icons.play_circle_outline_rounded,
        title: text.walletAdRewardAction,
        subtitle: text.walletAdRewardDescription(
          wallet?.adRewardsRemainingToday ?? 0,
        ),
        badgeLabel: text.walletAdRewardsCount(
          wallet?.adRewardsRemainingToday ?? 0,
        ),
        accent: colors.blue,
        onTap: isClaimingAd ? null : onClaimAd,
        isLoading: isClaimingAd,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: text.walletRewardsTitle),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;

            if (compact) {
              return Column(
                children: [
                  for (var index = 0; index < cards.length; index++) ...[
                    cards[index],
                    if (index != cards.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            }

            return Row(
              children: [
                for (var index = 0; index < cards.length; index++) ...[
                  Expanded(child: cards[index]),
                  if (index != cards.length - 1) const SizedBox(width: 10),
                ],
              ],
            );
          },
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
    required this.accent,
    required this.onTap,
    required this.isLoading,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeLabel;
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
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _WalletMetricChip(icon: icon, label: badgeLabel, accent: accent),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: onTap,
              child: Text(isLoading ? '...' : title),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletMetricChip extends StatelessWidget {
  const _WalletMetricChip({
    required this.icon,
    required this.label,
    this.accent,
  });

  final IconData icon;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final chipAccent = accent ?? colors.accent;

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
          Icon(icon, size: 15, color: chipAccent),
          const SizedBox(width: 6),
          Flexible(
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

class _WalletToolsSection extends StatelessWidget {
  const _WalletToolsSection({
    required this.onShowRedeem,
    required this.onShowPaymentMethods,
  });

  final VoidCallback onShowRedeem;
  final VoidCallback onShowPaymentMethods;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: text.walletQuickActionsTitle),
        LayoutBuilder(
          builder: (context, constraints) {
            final singleColumn = constraints.maxWidth < 330;

            return GridView.count(
              crossAxisCount: singleColumn ? 1 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: singleColumn ? 4.8 : 2.2,
              children: [
                _ActionTile(
                  icon: Icons.credit_card_rounded,
                  label: text.walletPaymentMethodsAction,
                  onTap: onShowPaymentMethods,
                ),
                _ActionTile(
                  icon: Icons.card_giftcard_rounded,
                  label: text.walletRedeemAction,
                  onTap: onShowRedeem,
                ),
              ],
            );
          },
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 148;

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: colors.accent, size: 22),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Icon(icon, color: colors.accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
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
                );
              },
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
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final featuredPack = selectPopularPack(packs);

    if (packs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: text.walletBuySparkTitle),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 430;
            final cardWidth = compact
                ? (constraints.maxWidth - 12).clamp(220.0, 320.0)
                : 220.0;

            return SizedBox(
              height: compact ? 364 : 244,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: packs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final pack = packs[index];
                  final isFeatured = featuredPack?.packId == pack.packId;
                  final priceLabel = _formatPrice(pack);

                  return SizedBox(
                    width: cardWidth,
                    child: _PackCardShell(
                      highlight: isFeatured,
                      child: ProfileGlassCard(
                        padding: const EdgeInsets.all(13),
                        child: LayoutBuilder(
                          builder: (context, cardConstraints) {
                            final stackHeader = cardConstraints.maxWidth <= 270;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (stackHeader) ...[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: isFeatured
                                              ? colors.gold.withValues(
                                                  alpha: 0.12,
                                                )
                                              : colors.accent.withValues(
                                                  alpha: 0.12,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          isFeatured
                                              ? Icons.workspace_premium_rounded
                                              : Icons.pets_rounded,
                                          color: isFeatured
                                              ? colors.gold
                                              : colors.accent,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          pack.displayName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: colors.textStrong,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isFeatured) ...[
                                    const SizedBox(height: 8),
                                    _PackFeaturedBadge(
                                      label: text.walletPopularBadge,
                                    ),
                                  ],
                                ] else
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: isFeatured
                                              ? colors.gold.withValues(
                                                  alpha: 0.12,
                                                )
                                              : colors.accent.withValues(
                                                  alpha: 0.12,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          isFeatured
                                              ? Icons.workspace_premium_rounded
                                              : Icons.pets_rounded,
                                          color: isFeatured
                                              ? colors.gold
                                              : colors.accent,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          pack.displayName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: colors.textStrong,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      if (isFeatured) ...[
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: _PackFeaturedBadge(
                                            label: text.walletPopularBadge,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: isFeatured
                                        ? LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              colors.gold.withValues(
                                                alpha: 0.16,
                                              ),
                                              colors.accent.withValues(
                                                alpha: 0.1,
                                              ),
                                              colors.surfaceStrong.withValues(
                                                alpha: 0.62,
                                              ),
                                            ],
                                          )
                                        : null,
                                    color: isFeatured
                                        ? null
                                        : colors.surfaceStrong.withValues(
                                            alpha: 0.52,
                                          ),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isFeatured
                                          ? colors.gold.withValues(alpha: 0.28)
                                          : colors.border.withValues(
                                              alpha: 0.9,
                                            ),
                                    ),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, heroConstraints) {
                                      final stackedValue =
                                          heroConstraints.maxWidth < 185;

                                      final sparkSummary = Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            text.walletPackTotalSpark(
                                              pack.totalSpark,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: colors.textStrong,
                                              fontSize: 21,
                                              fontWeight: FontWeight.w900,
                                              height: 1.05,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            text.walletPackBaseSpark(
                                              pack.grantedSpark,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: colors.textSoft,
                                              fontSize: 11.5,
                                              height: 1.25,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      );

                                      final priceBadge = _PackPriceBadge(
                                        price: priceLabel,
                                        highlight: isFeatured,
                                      );

                                      if (stackedValue) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            sparkSummary,
                                            const SizedBox(height: 10),
                                            priceBadge,
                                          ],
                                        );
                                      }

                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: sparkSummary),
                                          const SizedBox(width: 10),
                                          priceBadge,
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                if (pack.bonusSpark > 0) ...[
                                  const SizedBox(height: 10),
                                  ProfileStatusPill(
                                    label: text.walletPackBonus(
                                      pack.bonusSpark,
                                    ),
                                    leading: Icons.add_rounded,
                                    backgroundColor: colors.gold.withValues(
                                      alpha: 0.16,
                                    ),
                                    foregroundColor: colors.gold,
                                  ),
                                ],
                                if (isFeatured) ...[
                                  const SizedBox(height: 8),
                                  _PackDetailRow(
                                    icon: Icons.local_fire_department_rounded,
                                    label: text.walletBestValueLabel,
                                    accent: colors.gold,
                                  ),
                                ],
                                const Spacer(),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: isBuying
                                        ? null
                                        : () => onBuy(pack),
                                    style: isFeatured
                                        ? FilledButton.styleFrom(
                                            backgroundColor: colors.gold,
                                            foregroundColor:
                                                colors.backgroundBottom,
                                            disabledBackgroundColor: colors.gold
                                                .withValues(alpha: 0.3),
                                            disabledForegroundColor: colors
                                                .backgroundBottom
                                                .withValues(alpha: 0.55),
                                          )
                                        : null,
                                    icon: Icon(
                                      isFeatured
                                          ? Icons.auto_awesome_rounded
                                          : Icons.shopping_bag_outlined,
                                    ),
                                    label: Text(
                                      text.walletBuyForPrice(priceLabel),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
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

class _PackCardShell extends StatelessWidget {
  const _PackCardShell({required this.highlight, required this.child});

  final bool highlight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!highlight) {
      return child;
    }

    final colors = context.petMagicColors;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.gold.withValues(alpha: 0.26),
            colors.accent.withValues(alpha: 0.16),
            colors.blue.withValues(alpha: 0.14),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.gold.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(1.5), child: child),
    );
  }
}

class _PackFeaturedBadge extends StatelessWidget {
  const _PackFeaturedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return ProfileStatusPill(
      label: label,
      leading: Icons.local_fire_department_rounded,
      backgroundColor: colors.gold.withValues(alpha: 0.22),
      foregroundColor: colors.gold,
    );
  }
}

class _PackPriceBadge extends StatelessWidget {
  const _PackPriceBadge({required this.price, required this.highlight});

  final String price;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: highlight
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.gold.withValues(alpha: 0.22),
                  colors.gold.withValues(alpha: 0.12),
                ],
              )
            : null,
        color: highlight ? null : colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? colors.gold.withValues(alpha: 0.24)
              : colors.accent.withValues(alpha: 0.18),
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: colors.gold.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Text(
        price,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: highlight ? colors.gold : colors.accent,
          fontSize: 17,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
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
  const _PurchasesSection({required this.items});

  final List<PurchaseHistoryItem> items;

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
    final text = AppLocalizations.of(context);
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
              ],
            ),
          ),
          const SizedBox(width: 12),
          ProfileStatusPill(
            label: _purchaseStatusLabel(text, item.status),
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

class _WalletAbstractGraphic extends StatelessWidget {
  const _WalletAbstractGraphic({
    required this.accent,
    required this.gold,
    required this.blue,
    required this.surface,
  });

  final Color accent;
  final Color gold;
  final Color blue;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent, blue.withValues(alpha: 0.88)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: surface.withValues(alpha: 0.94),
                border: Border.all(color: gold.withValues(alpha: 0.34)),
              ),
              child: Icon(Icons.bolt_rounded, color: gold, size: 14),
            ),
          ),
          Positioned(
            left: 24,
            top: 24,
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          Positioned(
            left: 0,
            bottom: 10,
            child: Transform.rotate(
              angle: -0.28,
              child: Container(
                width: 34,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: accent.withValues(alpha: 0.18),
                ),
              ),
            ),
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
  final text = AppLocalizations.of(context);
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
              text.walletPaymentMethodsTitle,
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
                  text.walletNoSavedCards,
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
                label: Text(
                  isSettingUp ? text.walletOpeningStripe : text.walletAddCard,
                ),
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
    final text = AppLocalizations.of(context);
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
                  _formatCardExpiry(text, method),
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
            tooltip: text.walletRemoveCardTooltip,
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
  final text = AppLocalizations.of(context);
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
              text.walletPackTotalSpark(pack.totalSpark),
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
                label: Text(text.walletStripeCheckout),
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
                    label: Text(text.walletPayWithCard(method.last4)),
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

String _formatCardExpiry(AppLocalizations text, PaymentMethodModel method) {
  final month = method.expMonth;
  final year = method.expYear;
  if (month == null || year == null) {
    return method.isDefault ? text.walletDefaultCard : text.walletSavedCard;
  }

  final paddedMonth = month.toString().padLeft(2, '0');
  final suffix = method.isDefault ? text.walletDefaultSuffix : '';
  return text.walletExpires(paddedMonth, year, suffix);
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

  if (value.contains('economy.payment_method_not_found')) {
    return text.walletPaymentMethodUnavailableError;
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

  if (value.contains('economy.insufficient_balance')) {
    return text.walletInsufficientBalanceError;
  }

  if (value.contains('AppException(500)') ||
      value.contains('processing your request')) {
    return text.walletUnavailableError;
  }

  if (value.contains('weekly')) {
    return text.walletWeeklyNotReadyError;
  }

  return value;
}

Future<void> _showRedeemSheet(
  BuildContext context,
  WalletController controller,
) async {
  final text = AppLocalizations.of(context);
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
              text.walletRedeemSheetTitle,
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
              decoration: InputDecoration(
                hintText: text.walletRedeemHint,
                prefixIcon: const Icon(Icons.card_giftcard_rounded),
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
              label: Text(text.walletApplyCode),
            ),
          ],
        ),
      );
    },
  );

  inputController.dispose();
}
