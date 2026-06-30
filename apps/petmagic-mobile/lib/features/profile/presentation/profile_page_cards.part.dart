part of 'profile_page.dart';

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.profile});

  final MobileUserProfile profile;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final displayName = profile.displayName?.trim().isNotEmpty == true
        ? profile.displayName!
        : profile.email;
    final membershipLabel = profile.isPremium
        ? text.profilePremiumPlanLabel
        : text.profileFreePlanLabel;
    final emailLabel = profile.emailConfirmed
        ? text.profileEmailVerifiedShort
        : text.profileEmailPendingShort;

    return ProfileGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProfileAvatarBadge(
                imageUrl: profile.avatar?.url,
                fallbackLabel: displayName,
                size: 72,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ProfileStatusPill(
                          label: membershipLabel,
                          leading: profile.isPremium
                              ? null
                              : Icons.pets_rounded,
                          leadingWidget: profile.isPremium
                              ? const PremiumCrownIcon(size: 14)
                              : null,
                          backgroundColor:
                              (profile.isPremium ? colors.gold : colors.accent)
                                  .withValues(alpha: isLight ? 0.26 : 0.2),
                          foregroundColor: profile.isPremium
                              ? colors.gold
                              : colors.accent,
                        ),
                        ProfileStatusPill(
                          label: emailLabel,
                          leading: profile.emailConfirmed
                              ? Icons.verified_rounded
                              : Icons.mark_email_unread_outlined,
                          backgroundColor:
                              (profile.emailConfirmed
                                      ? colors.blue
                                      : colors.textMuted)
                                  .withValues(alpha: isLight ? 0.26 : 0.2),
                          foregroundColor: profile.emailConfirmed
                              ? colors.blue
                              : colors.textSoft,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletHighlightCard extends StatelessWidget {
  const _WalletHighlightCard({
    required this.wallet,
    required this.isWalletLoading,
    required this.onTap,
  });

  final WalletStateModel? wallet;
  final bool isWalletLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final walletValue = wallet;
    final nextWeeklyGrantAtUtc = walletValue?.nextWeeklyGrantAtUtc;
    final weeklyReady =
        nextWeeklyGrantAtUtc == null ||
        nextWeeklyGrantAtUtc.isBefore(DateTime.now().toUtc());
    final balanceText = walletValue == null
        ? (isWalletLoading
              ? text.profileWalletLoadingHint
              : text.profileWalletEmptyHint)
        : '${_formatProfileNumber(context, walletValue.balance)} ${text.walletBalanceUnit}';
    final rewardLabel = walletValue == null
        ? text.profileWalletPreviewLoadingStatus
        : weeklyReady
        ? text.profileWalletPreviewWeeklyReady
        : text.profileWalletPreviewAdCount(walletValue.adRewardsRemainingToday);
    const cardAccent = Color(0xFF00F2A6);
    final rewardColor = walletValue == null
        ? colors.textMuted
        : weeklyReady
        ? colors.gold
        : colors.accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          child: PetMagicAccentCard(
            accentColor: cardAccent,
            borderOpacity: isLight ? 0.2 : 0.28,
            glowOpacity: isLight ? 0.1 : 0.15,
            glowAlignment: const Alignment(-0.94, -0.16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(
                          alpha: isLight ? 0.04 : 0.16,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cardAccent.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: colors.textStrong,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.profileWalletPreviewEyebrow,
                            style: TextStyle(
                              color: colors.textSoft.withValues(alpha: 0.78),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text.profileWalletTitle,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: colors.textSoft,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  balanceText,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 24,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text.profileWalletPreviewSubtitle,
                  style: TextStyle(
                    color: colors.textSoft.withValues(alpha: 0.82),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ProfileStatusPill(
                      label: rewardLabel,
                      leading: wallet == null
                          ? Icons.sync_rounded
                          : weeklyReady
                          ? Icons.card_giftcard_rounded
                          : Icons.play_circle_outline_rounded,
                      backgroundColor: rewardColor.withValues(alpha: 0.14),
                      foregroundColor: rewardColor,
                    ),
                    _ProfileActionChip(label: text.profileWalletPreviewAction),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileActionChip extends StatelessWidget {
  const _ProfileActionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final chipBg = isLight
        ? const Color(0xFFDCF6EA)
        : colors.accent.withValues(alpha: 0.12);
    final chipBorder = isLight
        ? const Color(0xFF8FD6B8)
        : colors.accent.withValues(alpha: 0.24);
    final chipText = isLight ? const Color(0xFF0A7A4D) : colors.accent;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: chipText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.arrow_forward_rounded, color: chipText, size: 14),
          ],
        ),
      ),
    );
  }
}

class _HeaderActionIcon extends StatelessWidget {
  const _HeaderActionIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: Icon(icon, color: colors.textStrong, size: 26)),
        ),
      ),
    );
  }
}

String _formatProfileNumber(BuildContext context, int value) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return NumberFormat.decimalPattern(locale).format(value);
}
