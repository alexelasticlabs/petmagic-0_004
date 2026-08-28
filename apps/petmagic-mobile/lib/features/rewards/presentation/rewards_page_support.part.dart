part of 'rewards_page.dart';

Future<void> _showRewardsReferralHowItWorksSheet(
  BuildContext context,
  int bonusSpark,
) async {
  final text = AppLocalizations.of(context);

  await showPetMagicModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context, bottomInset) {
      final colors = context.petMagicColors;

      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.border, width: 1.1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.surface,
                  colors.surfaceStrong.withValues(alpha: 0.97),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: colors.textSoft,
                    ),
                  ),
                  Text(
                    text.rewardsReferralHowItWorksAction,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    text.rewardsReferralSubtitle,
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text.rewardsReferralBonusPerFriend(bonusSpark),
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text.rewardsReferralRulesNote,
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _showRewardsHistorySheet(
  BuildContext context,
  List<WalletLedgerItem> items,
) async {
  final text = AppLocalizations.of(context);
  final screenHeight = Overlay.of(
    context,
    rootOverlay: true,
  ).context.size!.height;

  await showPetMagicModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    constraints: BoxConstraints.tightFor(height: screenHeight),
    builder: (sheetContext, bottomInset) {
      final colors = sheetContext.petMagicColors;
      final localeTag = Localizations.localeOf(sheetContext).toLanguageTag();

      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: screenHeight - bottomInset,
            child: DecoratedBox(
              decoration: BoxDecoration(color: colors.surface),
              child: SafeArea(
                top: true,
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              text.rewardsHistoryTitle,
                              style: TextStyle(
                                color: colors.textStrong,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              color: colors.textSoft,
                              size: 24,
                            ),
                            tooltip: MaterialLocalizations.of(
                              sheetContext,
                            ).closeButtonTooltip,
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: colors.border.withValues(alpha: 0.58),
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 36,
                                ),
                                child: Text(
                                  text.rewardsHistoryEmpty,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.textSoft,
                                    fontSize: 15,
                                    height: 1.45,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(14, 2, 14, 18),
                              itemCount: items.length,
                              separatorBuilder: (_, separatorIndex) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final positive = item.delta >= 0;
                                final tone = positive
                                    ? colors.accent
                                    : colors.blue;
                                final date = item.createdAtUtc?.toLocal();

                                return DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: tone.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: tone.withValues(alpha: 0.24),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      10,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: tone.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            positive
                                                ? Icons.arrow_downward_rounded
                                                : Icons.arrow_upward_rounded,
                                            size: 18,
                                            color: tone,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _ledgerEntryTitle(text, item),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: colors.textStrong,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              if (date != null)
                                                Text(
                                                  DateFormat.MMMd(
                                                    localeTag,
                                                  ).add_Hm().format(date),
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
                                        Text(
                                          '${positive ? '+' : ''}${item.delta}',
                                          style: TextStyle(
                                            color: tone,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
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
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _RewardsLegalGateCard extends StatelessWidget {
  const _RewardsLegalGateCard({
    required this.message,
    required this.onOpenLegalGate,
  });

  final String message;
  final VoidCallback onOpenLegalGate;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ProfileGlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.rewardsPageTitle,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: TextStyle(
                  color: colors.textSoft,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onOpenLegalGate,
                child: Text(text.profileLegalAcceptAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardsSummaryView {
  const _RewardsSummaryView({
    required this.referralCode,
    required this.referralBonusSpark,
    required this.referralStatus,
    required this.referrerCode,
    required this.totalReferralBonusEarned,
    required this.referredUsersCount,
    required this.pendingReferredUsersCount,
    required this.rewardedReferredUsersCount,
  });

  final String referralCode;
  final int referralBonusSpark;
  final String referralStatus;
  final String? referrerCode;
  final int totalReferralBonusEarned;
  final int referredUsersCount;
  final int pendingReferredUsersCount;
  final int rewardedReferredUsersCount;

  bool get hasActivatedReferral => referralStatus != 'none';
  bool get isReferralRewarded => referralStatus == 'rewarded';
}

enum _FeedbackTone { success, warning, info }

String _ledgerEntryTitle(AppLocalizations text, WalletLedgerItem item) {
  final reason = item.reason.trim();
  final source = item.source.trim().toLowerCase();

  if (reason.isNotEmpty) {
    final normalizedReason = reason.toLowerCase();

    if (normalizedReason.startsWith('purchase:')) {
      return text.walletSourcePackPurchase;
    }

    if (normalizedReason.startsWith('template_generation:')) {
      return text.walletSourceGenerationSpend;
    }

    if (normalizedReason.startsWith('redeem:')) {
      final code = reason.split(':').skip(1).join(':').trim();
      if (code.isNotEmpty) {
        return '${text.walletSourcePromoCode} · $code';
      }
      return text.walletSourcePromoCode;
    }

    if (normalizedReason == 'rewarded ad') {
      return text.walletSourceAdReward;
    }

    if (_looksTechnical(reason)) {
      return _sourceLabel(text, source);
    }

    return reason;
  }

  return _sourceLabel(text, source);
}

String _sourceLabel(AppLocalizations text, String source) {
  return switch (source) {
    'pack_purchase' || 'purchase' => text.walletSourcePackPurchase,
    'generation_spend' ||
    'template_generation' => text.walletSourceGenerationSpend,
    'generation_refund' => text.walletSourceGenerationRefund,
    'weekly_grant' ||
    'premium_subscription_weekly_grant' => text.walletSourceWeeklyGrant,
    'ad_reward' => text.walletSourceAdReward,
    'promo_redeem' || 'redeem_code' || 'redeem' => text.walletSourcePromoCode,
    'admin_grant' => text.walletSourceAdminGrant,
    'admin_debit' => text.walletSourceAdminDebit,
    _ => text.walletSourceOther,
  };
}

bool _looksTechnical(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }

  if (normalized.contains(':') || normalized.contains('_')) {
    return true;
  }

  // Detect long ids/hashes in event names.
  final compact = normalized.replaceAll('-', '');
  return compact.length >= 24 && RegExp(r'^[a-z0-9]+$').hasMatch(compact);
}
