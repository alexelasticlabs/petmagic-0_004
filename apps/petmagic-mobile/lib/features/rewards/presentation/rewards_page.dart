import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/rewards/presentation/mappers/rewards_error_mapper.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_haptics.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:share_plus/share_plus.dart';

part 'rewards_page_referral_cards.dart';
part 'rewards_page_shared_widgets.dart';
part 'rewards_page_shell_widgets.dart';

class RewardsPage extends ConsumerStatefulWidget {
  const RewardsPage({super.key});

  static const routePath = '/rewards';

  @override
  ConsumerState<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends ConsumerState<RewardsPage> {
  Future<void> _showReferralHowItWorksSheet(int bonusSpark) async {
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

  Future<void> _showHistorySheet(List<WalletLedgerItem> items) async {
    final text = AppLocalizations.of(context);

    await showPetMagicModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context, bottomInset) {
        final colors = context.petMagicColors;
        final isLight = Theme.of(context).brightness == Brightness.light;
        final localeTag = Localizations.localeOf(context).toLanguageTag();
        final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.72;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
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
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textMuted.withValues(
                          alpha: isLight ? 0.72 : 0.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              text.rewardsHistoryTitle,
                              style: TextStyle(
                                color: colors.textStrong,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: colors.textSoft,
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              child: Text(
                                text.rewardsHistoryEmpty,
                                style: TextStyle(
                                  color: colors.textSoft,
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
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
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(walletControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletControllerProvider);
    final controller = ref.read(walletControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final hasShell =
        context.findAncestorWidgetOfExactType<PetMagicShell>() != null;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomNavInset = hasShell
        ? petMagicScrollableBottomInset(context)
        : MediaQuery.viewPaddingOf(context).bottom +
              kPetMagicBottomContentInsetCompact;
    final rewards = state.rewards;
    final rewardsSummary = rewards == null
        ? null
        : _RewardsSummaryView(
            referralCode: rewards.referralCode,
            referralBonusSpark: rewards.referralBonusSpark,
            referralStatus: rewards.referralStatus,
            referrerCode: rewards.referrerCode,
            totalReferralBonusEarned: rewards.totalReferralBonusEarned,
            referredUsersCount: rewards.referredUsersCount,
            pendingReferredUsersCount: rewards.pendingReferredUsersCount,
            rewardedReferredUsersCount: rewards.rewardedReferredUsersCount,
          );
    final warningMessage = rewardsWarningMessage(text, state.errorMessage);

    return _RewardsBackdrop(
      child: SafeArea(
        child: state.isInitialLoading
            ? Center(
                child: CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                ),
              )
            : RefreshIndicator.adaptive(
                onRefresh: () async {
                  await PetMagicHaptics.medium();
                  await controller.load(refresh: true);
                },
                color: colors.accent,
                backgroundColor: colors.surfaceStrong,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    bottomNavInset + keyboardInset + 8,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _RewardsHero(
                      balance: state.wallet?.balance,
                      onHistoryTap: () => _showHistorySheet(state.ledger),
                    ),
                    if (warningMessage != null) ...[
                      const SizedBox(height: 16),
                      _WarningBanner(
                        message: warningMessage,
                        tone: colors.gold,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _PromoCodeCard(
                      isSubmitting: state.isRedeeming,
                      onSubmit: controller.applyRedeemCode,
                    ),
                    const SizedBox(height: 16),
                    _ReferralCard(rewards: rewardsSummary),
                    const SizedBox(height: 14),
                    _ReferralInfoNote(
                      rewards: rewardsSummary,
                      onHowItWorksTap: () => _showReferralHowItWorksSheet(
                        rewardsSummary?.referralBonusSpark ?? 15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FriendCodeCard(
                      rewards: rewardsSummary,
                      isSubmitting: state.isApplyingReferral,
                      onSubmit: controller.applyReferralCode,
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
      return _sourceLabel(text, source, fallbackDelta: item.delta);
    }

    return reason;
  }

  return _sourceLabel(text, source, fallbackDelta: item.delta);
}

String _sourceLabel(
  AppLocalizations text,
  String source, {
  required int fallbackDelta,
}) {
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
    _ => fallbackDelta >= 0
        ? text.walletSourceWeeklyGrant
        : text.walletSourceGenerationSpend,
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
  return compact.length >= 24 &&
      RegExp(r'^[a-z0-9]+$').hasMatch(compact);
}
