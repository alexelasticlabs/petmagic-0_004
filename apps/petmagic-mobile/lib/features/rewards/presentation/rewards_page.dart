import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:share_plus/share_plus.dart';
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
    final hasShell =
        context.findAncestorWidgetOfExactType<PetMagicShell>() != null;
    final hasKeyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bottomNavInset = hasKeyboard
        ? MediaQuery.viewPaddingOf(context).bottom + 12
        : hasShell
        ? petMagicBottomNavInset(context)
        : MediaQuery.viewPaddingOf(context).bottom + 16;
    final rewards = state.rewards;
    final rewardsSummary = rewards == null
        ? null
        : _RewardsSummaryView(
            referralCode: rewards.referralCode,
            referralBonusSpark: rewards.referralBonusSpark,
            referralStatus: rewards.referralStatus,
            totalReferralBonusEarned: rewards.totalReferralBonusEarned,
            referredUsersCount: rewards.referredUsersCount,
            pendingReferredUsersCount: rewards.pendingReferredUsersCount,
            rewardedReferredUsersCount: rewards.rewardedReferredUsersCount,
          );
    final warningMessage = _rewardsWarningMessage(text, state.errorMessage);

    return ProfileScreenBackground(
      child: SafeArea(
        child: state.isInitialLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : RefreshIndicator.adaptive(
                onRefresh: () => controller.load(refresh: true),
                color: colors.accent,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(14, 8, 14, bottomNavInset),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _RewardsHeader(
                      lastUpdatedAt: state.wallet?.updatedAtUtc,
                      onRefresh: () => controller.load(refresh: true),
                    ),
                    if (warningMessage != null) ...[
                      const SizedBox(height: 12),
                      ProfileMessageCard(
                        message: warningMessage,
                        tone: _warningTone,
                      ),
                    ],
                    const SizedBox(height: 10),
                    _RewardsBalanceCard(balance: state.wallet?.balance),
                    const SizedBox(height: 12),
                    _PromoCodeCard(
                      isSubmitting: state.isRedeeming,
                      onSubmit: controller.applyRedeemCode,
                    ),
                    const SizedBox(height: 10),
                    _ReferralCard(
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
    required this.totalReferralBonusEarned,
    required this.referredUsersCount,
    required this.pendingReferredUsersCount,
    required this.rewardedReferredUsersCount,
  });

  final String referralCode;
  final int referralBonusSpark;
  final String referralStatus;
  final int totalReferralBonusEarned;
  final int referredUsersCount;
  final int pendingReferredUsersCount;
  final int rewardedReferredUsersCount;

  bool get hasActivatedReferral => referralStatus != 'none';
  bool get isReferralRewarded => referralStatus == 'rewarded';
}

enum _FeedbackTone { success, warning, info }

class _RewardsHeader extends StatelessWidget {
  const _RewardsHeader({required this.onRefresh, this.lastUpdatedAt});

  final VoidCallback onRefresh;
  final DateTime? lastUpdatedAt;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final lastUpdatedText = _formatLastUpdatedText(
      text,
      lastUpdatedAt,
      localeTag,
    );

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
                  fontSize: 23,
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text.rewardsLastUpdatedLabel(lastUpdatedText),
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            IconButton(
              tooltip: text.walletRefreshTooltip,
              onPressed: onRefresh,
              icon: Icon(
                Icons.refresh_rounded,
                size: 20,
                color: colors.textSoft,
              ),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            ),
          ],
        ),
      ],
    );
  }
}

class _RewardsBalanceCard extends StatelessWidget {
  const _RewardsBalanceCard({required this.balance});

  final int? balance;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final balanceValue = balance == null
        ? text.profileWalletLoadingHint
        : '${NumberFormat.decimalPattern(localeTag).format(balance)} ${text.walletBalanceUnit}';

    return ProfileGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 18,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.walletBalanceEyebrow,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  balanceValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
  _FeedbackTone _messageTone = _FeedbackTone.info;

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
    final text = AppLocalizations.of(context);
    if (code.isEmpty) {
      setState(() {
        _messageTone = _FeedbackTone.warning;
        _message = text.rewardsPromoEmptyError;
      });
      return;
    }

    if (widget.isSubmitting) {
      return;
    }

    setState(() {
      _messageTone = _FeedbackTone.info;
      _message = text.rewardsPromoCheckingStatus;
    });

    final error = await widget.onSubmit(code);
    if (!mounted) {
      return;
    }

    setState(() {
      _messageTone = error == null
          ? _FeedbackTone.success
          : _FeedbackTone.warning;
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
      padding: const EdgeInsets.all(14),
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
                tone: _feedbackToneColor(_messageTone, colors),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('rewards_promo_submit'),
                onPressed: widget.isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                icon: widget.isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  widget.isSubmitting
                      ? '${text.walletRedeemAction}...'
                      : text.walletRedeemAction,
                ),
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

  final _RewardsSummaryView? rewards;
  final bool isSubmitting;
  final Future<String?> Function(String code) onSubmit;

  @override
  State<_ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends State<_ReferralCard> {
  late final TextEditingController _controller;
  late final FocusNode _friendCodeFocusNode;
  Timer? _copyHintTimer;
  String? _message;
  _FeedbackTone _messageTone = _FeedbackTone.info;
  bool _showCopyHint = false;
  bool _showFriendCodeInput = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _friendCodeFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _ReferralCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.rewards?.hasActivatedReferral == true) {
      _showFriendCodeInput = false;
    }
  }

  @override
  void dispose() {
    _copyHintTimer?.cancel();
    _controller.dispose();
    _friendCodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _copyCode() async {
    final code = widget.rewards?.referralCode;
    if (code == null || code.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) {
      return;
    }

    _copyHintTimer?.cancel();
    setState(() => _showCopyHint = true);
    _copyHintTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }

      setState(() => _showCopyHint = false);
    });
  }

  Future<void> _shareCode() async {
    final rewards = widget.rewards;
    if (rewards == null || rewards.referralCode.isEmpty) {
      return;
    }

    final text = AppLocalizations.of(context);
    final shareMessage = text.rewardsReferralShareMessage(
      rewards.referralCode,
      rewards.referralBonusSpark,
    );

    await SharePlus.instance.share(ShareParams(text: shareMessage));
  }

  void _openFriendCodeInput() {
    if (_showFriendCodeInput) {
      return;
    }

    setState(() => _showFriendCodeInput = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _friendCodeFocusNode.requestFocus();
    });
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    final text = AppLocalizations.of(context);
    if (code.isEmpty) {
      setState(() {
        _messageTone = _FeedbackTone.warning;
        _message = text.rewardsReferralEmptyError;
      });
      return;
    }

    if (widget.isSubmitting) {
      return;
    }

    setState(() {
      _messageTone = _FeedbackTone.info;
      _message = text.rewardsReferralCheckingStatus;
    });

    final error = await widget.onSubmit(code);
    if (!mounted) {
      return;
    }

    setState(() {
      _messageTone = error == null
          ? _FeedbackTone.success
          : _FeedbackTone.warning;
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
    final hasRewards = rewards != null;
    final hasActivatedReferral = rewards?.hasActivatedReferral == true;
    final statusText = rewards == null
        ? text.rewardsReferralStatusLoading
        : _referralStatusText(text, rewards);

    return ProfileGlassCard(
      padding: const EdgeInsets.all(14),
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
            const SizedBox(height: 10),
            Text(
              text.rewardsReferralBonusPerFriend(
                rewards?.referralBonusSpark ?? 0,
              ),
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text.rewardsReferralRulesNote,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 11.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border.withValues(alpha: 0.9)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasRewards && rewards.referralCode.isNotEmpty
                                ? rewards.referralCode
                                : '...',
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('rewards_referral_copy'),
                      onPressed: hasRewards ? _copyCode : null,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(text.rewardsCopyReferralCodeAction),
                    ),
                  ],
                ),
              ),
            ),
            if (_showCopyHint) ...[
              const SizedBox(height: 6),
              Text(
                text.rewardsReferralCopiedMessage,
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('rewards_referral_share'),
                onPressed: hasRewards ? _shareCode : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                label: Text(text.rewardsReferralShareCodeAction),
              ),
            ),
            const SizedBox(height: 10),
            _ReferralStats(rewards: rewards),
            const SizedBox(height: 10),
            _InlineStatus(message: statusText, tone: colors.accent),
            if (!hasActivatedReferral) ...[
              const SizedBox(height: 12),
              Text(
                text.rewardsReferralFriendCodePrompt,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text.rewardsReferralFriendCodeHint,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 11.5,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              if (!_showFriendCodeInput)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('rewards_referral_show_input'),
                    onPressed: _openFriendCodeInput,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      side: BorderSide(
                        color: colors.border.withValues(alpha: 0.95),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: Text(text.rewardsReferralUseFriendCodeAction),
                  ),
                )
              else ...[
                TextField(
                  key: const Key('rewards_referral_input'),
                  controller: _controller,
                  focusNode: _friendCodeFocusNode,
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
                    filled: true,
                    fillColor: colors.surface.withValues(alpha: 0.35),
                    hintStyle: TextStyle(
                      color: colors.textSoft.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: colors.border.withValues(alpha: 0.95),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: colors.accent.withValues(alpha: 0.95),
                        width: 1.4,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.group_rounded,
                      size: 20,
                      color: colors.textSoft,
                    ),
                  ),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                _InlineStatus(
                  message: _message!,
                  tone: _feedbackToneColor(_messageTone, colors),
                ),
              ],
              if (_showFriendCodeInput) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    key: const Key('rewards_referral_submit'),
                    onPressed: widget.isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                    ),
                    icon: widget.isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 20,
                          ),
                    label: Text(text.rewardsReferralActivateAction),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ReferralStats extends StatelessWidget {
  const _ReferralStats({required this.rewards});

  final _RewardsSummaryView? rewards;

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
            value: '${rewards?.referredUsersCount ?? 0}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricPill(
            label: text.rewardsReferralBonusLabel,
            value: '${rewards?.rewardedReferredUsersCount ?? 0}',
          ),
        ),
      ],
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colors.accent, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 12,
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.65)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 14,
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
                fontSize: 10,
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          message,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

Color _feedbackToneColor(_FeedbackTone tone, PetMagicColors colors) {
  return switch (tone) {
    _FeedbackTone.success => colors.accent,
    _FeedbackTone.warning => const Color(0xFFD7A44A),
    _FeedbackTone.info => colors.blue,
  };
}

String _formatLastUpdatedText(
  AppLocalizations text,
  DateTime? updatedAtUtc,
  String localeTag,
) {
  if (updatedAtUtc == null) {
    return text.rewardsLastUpdatedNow;
  }

  final now = DateTime.now();
  final diff = now.difference(updatedAtUtc.toLocal());
  if (diff.inMinutes < 1) {
    return text.rewardsLastUpdatedNow;
  }

  if (diff.inHours < 1) {
    return text.rewardsLastUpdatedMinutes(diff.inMinutes);
  }

  if (diff.inDays < 1) {
    return text.rewardsLastUpdatedHours(diff.inHours);
  }

  return DateFormat.MMMd(localeTag).format(updatedAtUtc.toLocal());
}

String _referralStatusText(AppLocalizations text, _RewardsSummaryView rewards) {
  if (rewards.isReferralRewarded) {
    return text.rewardsReferralStatusRewarded;
  }

  if (rewards.hasActivatedReferral) {
    return text.rewardsReferralStatusPending;
  }

  return text.rewardsReferralStatusNone;
}

String? _rewardsWarningMessage(AppLocalizations text, String? raw) {
  if (raw == null) {
    return null;
  }

  final value = raw.toLowerCase();
  if (value.contains('wallet.ledger_failed') ||
      value.contains('wallet.packs_failed') ||
      value.contains('wallet.purchases_failed')) {
    return null;
  }

  return _friendlyRewardsError(text, raw);
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
