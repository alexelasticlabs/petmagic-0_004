import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';

class RewardsPage extends ConsumerStatefulWidget {
  const RewardsPage({super.key});

  static const routePath = '/rewards';

  @override
  ConsumerState<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends ConsumerState<RewardsPage> {
  static const _warningTone = Color(0xFFD7A44A);

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
    final bottomNavInset = petMagicBottomNavInset(context);
    final bonusLedger = state.ledger
        .where((item) => _bonusSources.contains(item.source))
        .toList(growable: false);

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
                    _RewardsHeader(
                      onRefresh: () => controller.load(refresh: true),
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 14),
                      ProfileMessageCard(
                        message: _friendlyRewardsError(
                          text,
                          state.errorMessage!,
                        ),
                        tone: _warningTone,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _PromoCodeCard(
                      isSubmitting: state.isRedeeming,
                      onSubmit: controller.applyRedeemCode,
                    ),
                    const SizedBox(height: 14),
                    _ReferralCard(
                      rewards: state.rewards,
                      isSubmitting: state.isApplyingReferral,
                      onSubmit: controller.applyReferralCode,
                    ),
                    const SizedBox(height: 14),
                    _BonusHistoryCard(items: bonusLedger),
                  ],
                ),
              ),
      ),
    );
  }
}

const _bonusSources = {
  'redeem_code',
  'referral_bonus',
  'ad_reward',
  'weekly_grant',
  'premium_subscription_grant',
};

class _RewardsHeader extends StatelessWidget {
  const _RewardsHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.rewardsPageTitle,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text.rewardsPageSubtitle,
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
        IconButton.filledTonal(
          tooltip: text.walletRefreshTooltip,
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _PromoCodeCard extends StatefulWidget {
  const _PromoCodeCard({required this.isSubmitting, required this.onSubmit});

  final bool isSubmitting;
  final Future<String?> Function(String code) onSubmit;

  @override
  State<_PromoCodeCard> createState() => _PromoCodeCardState();
}

class _PromoCodeCardState extends State<_PromoCodeCard> {
  late final TextEditingController _controller;
  String? _message;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty || widget.isSubmitting) {
      return;
    }

    final text = AppLocalizations.of(context);
    final error = await widget.onSubmit(code);
    if (!mounted) {
      return;
    }

    setState(() {
      _isSuccess = error == null;
      _message = error == null
          ? text.walletRedeemSuccessMessage
          : _friendlyRewardsError(text, error);
    });

    if (error == null) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileGlassCard(
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(
              icon: Icons.confirmation_number_rounded,
              title: text.rewardsPromoTitle,
              subtitle: text.rewardsPromoSubtitle,
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('rewards_promo_input'),
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => unawaited(_submit()),
              style: TextStyle(
                color: colors.textStrong,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
              decoration: InputDecoration(
                labelText: text.walletRedeemInputLabel,
                hintText: text.walletRedeemHint,
                prefixIcon: const Icon(Icons.local_activity_rounded),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              _InlineStatus(
                message: _message!,
                tone: _isSuccess ? colors.accent : const Color(0xFFD7A44A),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('rewards_promo_submit'),
                onPressed: widget.isSubmitting ? null : _submit,
                icon: widget.isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: Text(text.walletRedeemAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferralCard extends StatefulWidget {
  const _ReferralCard({
    required this.rewards,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final RewardsSummaryModel? rewards;
  final bool isSubmitting;
  final Future<String?> Function(String code) onSubmit;

  @override
  State<_ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends State<_ReferralCard> {
  late final TextEditingController _controller;
  String? _message;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyCode() async {
    final code = widget.rewards?.referralCode;
    if (code == null || code.isEmpty) {
      return;
    }

    final text = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.rewardsReferralCopiedMessage)));
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty || widget.isSubmitting) {
      return;
    }

    final text = AppLocalizations.of(context);
    final error = await widget.onSubmit(code);
    if (!mounted) {
      return;
    }

    setState(() {
      _isSuccess = error == null;
      _message = error == null
          ? text.rewardsReferralActivatedMessage
          : _friendlyRewardsError(text, error);
    });

    if (error == null) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final rewards = widget.rewards;
    final statusText = rewards == null
        ? text.rewardsReferralStatusLoading
        : _referralStatusText(text, rewards);

    return ProfileGlassCard(
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(
              icon: Icons.group_add_rounded,
              title: text.rewardsReferralTitle,
              subtitle: text.rewardsReferralSubtitle,
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.accent.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.rewardsYourReferralCode,
                            style: TextStyle(
                              color: colors.textSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rewards?.referralCode.isNotEmpty == true
                                ? rewards!.referralCode
                                : '...',
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: text.rewardsCopyReferralCodeAction,
                      onPressed: rewards == null ? null : _copyCode,
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ReferralStats(rewards: rewards),
            const SizedBox(height: 12),
            _InlineStatus(message: statusText, tone: colors.accent),
            if (rewards?.hasActivatedReferral != true) ...[
              const SizedBox(height: 14),
              TextField(
                key: const Key('rewards_referral_input'),
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => unawaited(_submit()),
                style: TextStyle(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
                decoration: InputDecoration(
                  labelText: text.rewardsReferralInputLabel,
                  hintText: text.rewardsReferralInputHint,
                  prefixIcon: const Icon(Icons.group_rounded),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                _InlineStatus(
                  message: _message!,
                  tone: _isSuccess ? colors.accent : const Color(0xFFD7A44A),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  key: const Key('rewards_referral_submit'),
                  onPressed: widget.isSubmitting ? null : _submit,
                  icon: widget.isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(text.rewardsReferralActivateAction),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReferralStats extends StatelessWidget {
  const _ReferralStats({required this.rewards});

  final RewardsSummaryModel? rewards;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: _MetricPill(
            label: text.rewardsReferralEarnedLabel,
            value: '${rewards?.totalReferralBonusEarned ?? 0}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricPill(
            label: text.rewardsReferralFriendsLabel,
            value:
                '${rewards?.rewardedReferredUsersCount ?? 0}/${rewards?.referredUsersCount ?? 0}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricPill(
            label: text.rewardsReferralBonusLabel,
            value: '${rewards?.referralBonusSpark ?? 0}',
          ),
        ),
      ],
    );
  }
}

class _BonusHistoryCard extends StatelessWidget {
  const _BonusHistoryCard({required this.items});

  final List<WalletLedgerItem> items;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.history_rounded,
            title: text.rewardsHistoryTitle,
            subtitle: text.rewardsHistorySubtitle,
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              text.rewardsHistoryEmpty,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            for (final item in items.take(8)) ...[
              _BonusHistoryRow(item: item),
              if (item != items.take(8).last)
                Divider(color: colors.border.withValues(alpha: 0.55)),
            ],
        ],
      ),
    );
  }
}

class _BonusHistoryRow extends StatelessWidget {
  const _BonusHistoryRow({required this.item});

  final WalletLedgerItem item;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final createdAt = item.createdAtUtc;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              _sourceIcon(item.source),
              color: colors.accent,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sourceTitle(text, item.source),
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  createdAt == null
                      ? item.reason
                      : DateFormat.yMMMd(
                          Localizations.localeOf(context).toLanguageTag(),
                        ).format(createdAt.toLocal()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            item.delta > 0 ? '+${item.delta}' : '${item.delta}',
            style: TextStyle(
              color: item.delta >= 0 ? colors.accent : colors.textSoft,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: colors.accent, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.65)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({required this.message, required this.tone});

  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          message,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 12.5,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _referralStatusText(AppLocalizations text, RewardsSummaryModel rewards) {
  if (rewards.isReferralRewarded) {
    return text.rewardsReferralStatusRewarded;
  }

  if (rewards.hasActivatedReferral) {
    return text.rewardsReferralStatusPending;
  }

  return text.rewardsReferralStatusNone;
}

IconData _sourceIcon(String source) {
  return switch (source) {
    'redeem_code' => Icons.confirmation_number_rounded,
    'referral_bonus' => Icons.group_add_rounded,
    'ad_reward' => Icons.play_circle_outline_rounded,
    'weekly_grant' => Icons.calendar_month_rounded,
    'premium_subscription_grant' => Icons.workspace_premium_rounded,
    _ => Icons.bolt_rounded,
  };
}

String _sourceTitle(AppLocalizations text, String source) {
  return switch (source) {
    'redeem_code' => text.rewardsSourcePromo,
    'referral_bonus' => text.rewardsSourceReferral,
    'ad_reward' => text.rewardsSourceAd,
    'weekly_grant' => text.rewardsSourceWeekly,
    'premium_subscription_grant' => text.rewardsSourcePremium,
    _ => text.rewardsSourceBonus,
  };
}

String _friendlyRewardsError(AppLocalizations text, String raw) {
  final value = raw.toLowerCase();

  if (value.contains('referral_code_not_found')) {
    return text.rewardsReferralCodeNotFoundError;
  }

  if (value.contains('referral_self_referral')) {
    return text.rewardsReferralSelfError;
  }

  if (value.contains('referral_already_linked')) {
    return text.rewardsReferralAlreadyLinkedError;
  }

  if (value.contains('referral_paid_user_ineligible')) {
    return text.rewardsReferralPaidUserError;
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

  if (value.contains('wallet.network_unavailable')) {
    return text.walletRedeemOfflineError;
  }

  if (value.contains('wallet.server_unavailable') ||
      value.contains('rewards.summary_failed')) {
    return text.walletRedeemServerError;
  }

  return raw;
}
