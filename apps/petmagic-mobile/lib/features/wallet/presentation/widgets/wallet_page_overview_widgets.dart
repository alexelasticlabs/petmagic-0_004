part of 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';

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
