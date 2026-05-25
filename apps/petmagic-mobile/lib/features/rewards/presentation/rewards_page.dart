import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:share_plus/share_plus.dart';

class RewardsPage extends ConsumerStatefulWidget {
  const RewardsPage({super.key});

  static const routePath = '/rewards';

  @override
  ConsumerState<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends ConsumerState<RewardsPage> {
  static const _warningTone = Color(0xFFD7A44A);

  Future<void> _showReferralHowItWorksSheet(int bonusSpark) async {
    final text = AppLocalizations.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final colors = context.petMagicColors;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF1D2B3C), width: 1.1),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF121D2C).withValues(alpha: 0.96),
                    const Color(0xFF07101A).withValues(alpha: 0.98),
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

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final colors = context.petMagicColors;
        final localeTag = Localizations.localeOf(context).toLanguageTag();
        final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.72;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF1D2B3C),
                    width: 1.1,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF121D2C).withValues(alpha: 0.96),
                      const Color(0xFF07101A).withValues(alpha: 0.98),
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
                        color: const Color(0xFF31465D),
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
                                    ? const Color(0xFF49DA87)
                                    : const Color(0xFF7EA4D1);
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
                                                item.reason.isEmpty
                                                    ? item.source
                                                    : item.reason,
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
    final hasKeyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final bottomNavInset = hasKeyboard
        ? safeBottom + 20
        : hasShell
        ? petMagicBottomNavInset(context) + 28
        : safeBottom + 24;
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

    return _RewardsBackdrop(
      child: SafeArea(
        child: state.isInitialLoading
            ? Center(
                child: CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                ),
              )
            : RefreshIndicator.adaptive(
                onRefresh: () => controller.load(refresh: true),
                color: colors.accent,
                backgroundColor: colors.surfaceStrong,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, bottomNavInset),
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
                        tone: _warningTone,
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
                    if (rewardsSummary?.hasActivatedReferral != true) ...[
                      const SizedBox(height: 16),
                      _FriendCodeCard(
                        rewards: rewardsSummary,
                        isSubmitting: state.isApplyingReferral,
                        onSubmit: controller.applyReferralCode,
                      ),
                    ],
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

class _RewardsBackdrop extends StatelessWidget {
  const _RewardsBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF030A14), Color(0xFF01060D)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -88,
            right: -96,
            child: _GlowOrb(
              size: 220,
              color: const Color(0xFF0EA86D).withValues(alpha: 0.13),
            ),
          ),
          Positioned(
            top: 120,
            left: -104,
            child: _GlowOrb(
              size: 180,
              color: const Color(0xFF1E8CFF).withValues(alpha: 0.05),
            ),
          ),
          const Positioned(
            top: 44,
            right: 108,
            child: _DecorativePaw(size: 36, opacity: 0.12, turns: -0.12),
          ),
          const Positioned(
            top: 74,
            left: 154,
            child: _DecorativePaw(size: 34, opacity: 0.1, turns: 0.1),
          ),
          const Positioned(
            top: 112,
            right: 20,
            child: _DecorativeSpark(size: 18),
          ),
          const Positioned(
            top: 154,
            left: 196,
            child: _DecorativeSpark(size: 14),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _DecorativePaw extends StatelessWidget {
  const _DecorativePaw({
    required this.size,
    required this.opacity,
    required this.turns,
  });

  final double size;
  final double opacity;
  final double turns;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: turns,
        child: Icon(
          Icons.pets_rounded,
          size: size,
          color: const Color(0xFF38D77A).withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class _DecorativeSpark extends StatelessWidget {
  const _DecorativeSpark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Icon(
        Icons.auto_awesome_rounded,
        size: size,
        color: const Color(0xFFFFF0A6).withValues(alpha: 0.95),
      ),
    );
  }
}

class _RewardsHero extends StatelessWidget {
  const _RewardsHero({required this.balance, required this.onHistoryTap});

  static const _balanceImage = 'assets/rewards/balance.png';

  final int? balance;
  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final balanceValue = balance == null
        ? '...'
        : NumberFormat.decimalPattern(localeTag).format(balance);

    return LayoutBuilder(
      builder: (context, constraints) {
        final heroWidth = constraints.maxWidth;
        final imageWidth = (heroWidth * 0.42).clamp(132.0, 176.0);
        final subtitleWidth = heroWidth * 0.52;
        final balanceRightInset = (imageWidth * 0.74).clamp(104.0, 130.0);

        return SizedBox(
          height: 238,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Row(
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
                              fontSize: 33,
                              height: 1.0,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: subtitleWidth,
                            child: Text(
                              text.rewardsPageSubtitle,
                              style: TextStyle(
                                color: colors.textSoft,
                                fontSize: 14,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _HistoryButton(onPressed: onHistoryTap),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 104,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: _BalancePanel(
                          balanceValue: balanceValue,
                          unit: text.walletBalanceUnit,
                          rightInset: balanceRightInset,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: -2,
                        child: IgnorePointer(
                          child: Image.asset(
                            _balanceImage,
                            width: imageWidth,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF07111C).withValues(alpha: 0.66),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF243143)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.history_toggle_off_rounded,
                size: 17,
                color: Color(0xFF38E681),
              ),
              const SizedBox(width: 8),
              Text(
                text.rewardsHistoryTitle,
                style: const TextStyle(
                  color: Color(0xFF48E581),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalancePanel extends StatelessWidget {
  const _BalancePanel({
    required this.balanceValue,
    required this.unit,
    required this.rightInset,
  });

  final String balanceValue;
  final String unit;
  final double rightInset;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Container(
      height: 98,
      padding: EdgeInsets.fromLTRB(16, 12, rightInset, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF042E25).withValues(alpha: 0.95),
            const Color(0xFF0C6A40).withValues(alpha: 0.68),
            const Color(0xFF0A1A22).withValues(alpha: 0.88),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF136746).withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0DD978).withValues(alpha: 0.18),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text.walletBalanceEyebrow,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF44E681),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Text(
                    balanceValue,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 39,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const PawSparkIcon(size: 22),
                  const SizedBox(width: 6),
                  Text(
                    unit,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardsGlassPanel extends StatelessWidget {
  const _RewardsGlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(15),
    this.gradient,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? borderColor;

  static const _radius = 26.0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            gradient:
                gradient ??
                LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF121D2C).withValues(alpha: 0.9),
                    const Color(0xFF07101A).withValues(alpha: 0.92),
                  ],
                ),
            border: Border.all(
              color: borderColor ?? const Color(0xFF1D2B3C),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
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

    return _RewardsGlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Material(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final actionWidth = (constraints.maxWidth * 0.34).clamp(
              118.0,
              140.0,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  icon: Icons.confirmation_number_rounded,
                  iconGradient: const LinearGradient(
                    colors: [Color(0xFFDDFB72), Color(0xFF49C667)],
                  ),
                  title: text.rewardsPromoTitle,
                  subtitle: text.rewardsPromoSubtitle,
                  iconBoxSize: 42,
                  iconSize: 22,
                  titleSize: 17,
                  subtitleSize: 12.5,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: TextField(
                          key: const Key('rewards_promo_input'),
                          controller: _controller,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => unawaited(_submit()),
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                          decoration: _fieldDecoration(
                            context,
                            hintText: text.walletRedeemHint,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: actionWidth,
                      height: 50,
                      child: FilledButton(
                        key: const Key('rewards_promo_submit'),
                        onPressed: widget.isSubmitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF49DA87),
                          foregroundColor: const Color(0xFF06140C),
                          disabledBackgroundColor: const Color(0xFF314036),
                          disabledForegroundColor: const Color(0xFF7F8EA0),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        child: widget.isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF06140C),
                                  ),
                                ),
                              )
                            : Text(
                                text.walletRedeemAction,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ),
                  ],
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  _InlineStatus(
                    message: _message!,
                    tone: _feedbackToneColor(_messageTone, colors),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReferralCard extends StatefulWidget {
  const _ReferralCard({required this.rewards});

  final _RewardsSummaryView? rewards;

  @override
  State<_ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends State<_ReferralCard> {
  static const _inviteImage = 'assets/rewards/invite-friend.png';

  Timer? _copyHintTimer;
  bool _showCopyHint = false;

  @override
  void dispose() {
    _copyHintTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final rewards = widget.rewards;
    final hasRewards = rewards != null;
    final bonus = rewards?.referralBonusSpark ?? 15;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 36 = 18px left + 18px right padding inside the glass panel
        final innerWidth = constraints.maxWidth - 36;
        final textWidth = innerWidth * 0.58;
        final imageWidth = (innerWidth * 0.44).clamp(132.0, 188.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            _RewardsGlassPanel(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              borderColor: const Color(0xFF0C6E4D).withValues(alpha: 0.78),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF062D24).withValues(alpha: 0.96),
                  const Color(0xFF092B22).withValues(alpha: 0.88),
                  const Color(0xFF061018).withValues(alpha: 0.94),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: textWidth,
                      child: _SectionHeader(
                        icon: Icons.group_rounded,
                        iconGradient: const LinearGradient(
                          colors: [Color(0xFF46E58B), Color(0xFF11753D)],
                        ),
                        title: text.rewardsReferralTitle,
                        subtitle: null,
                        iconBoxSize: 48,
                        iconSize: 24,
                        titleSize: 17.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: textWidth,
                      child: _ReferralInviteText(bonus: bonus),
                    ),
                    const SizedBox(height: 12),
                    _ReferralCodeBox(
                      code: hasRewards && rewards.referralCode.isNotEmpty
                          ? rewards.referralCode
                          : '...',
                      canCopy: hasRewards,
                      onCopy: _copyCode,
                    ),
                    if (_showCopyHint) ...[
                      const SizedBox(height: 6),
                      Text(
                        text.rewardsReferralCopiedMessage,
                        style: const TextStyle(
                          color: Color(0xFF44E681),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _GradientActionButton(
                      key: const Key('rewards_referral_share'),
                      height: 52,
                      label: text.rewardsReferralShareCodeAction,
                      icon: Icons.ios_share_rounded,
                      onPressed: hasRewards ? _shareCode : null,
                    ),
                    const SizedBox(height: 8),
                    _ReferralStats(rewards: rewards),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: -14,
              child: IgnorePointer(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: imageWidth,
                    maxHeight: 202,
                  ),
                  child: Image.asset(
                    _inviteImage,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReferralInviteText extends StatelessWidget {
  const _ReferralInviteText({required this.bonus});

  final int bonus;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${text.rewardsReferralInvitePrefix} '),
          TextSpan(
            text: '+$bonus ${text.walletBalanceUnit}',
            style: const TextStyle(
              color: Color(0xFF48E581),
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(text: ' ${text.rewardsReferralInviteSuffix}'),
        ],
      ),
      style: TextStyle(
        color: colors.textSoft,
        fontSize: 12.6,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ReferralCodeBox extends StatelessWidget {
  const _ReferralCodeBox({
    required this.code,
    required this.canCopy,
    required this.onCopy,
  });

  final String code;
  final bool canCopy;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF031116).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFF12382F).withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
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
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 16,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.55,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            key: const Key('rewards_referral_copy'),
            onPressed: canCopy ? onCopy : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text(text.rewardsCopyReferralCodeAction),
          ),
        ],
      ),
    );
  }
}

class _ReferralInfoNote extends StatelessWidget {
  const _ReferralInfoNote({
    required this.rewards,
    required this.onHowItWorksTap,
  });

  final _RewardsSummaryView? rewards;
  final VoidCallback onHowItWorksTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final statusText = rewards == null
        ? text.rewardsReferralStatusLoading
        : rewards!.hasActivatedReferral
        ? _referralStatusText(text, rewards!)
        : text.rewardsReferralRulesNote;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: colors.textMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                TextButton(
                  onPressed: onHowItWorksTap,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(
                    text.rewardsReferralHowItWorksAction,
                    style: const TextStyle(
                      color: Color(0xFF44E681),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
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

class _FriendCodeCard extends StatefulWidget {
  const _FriendCodeCard({
    required this.rewards,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final _RewardsSummaryView? rewards;
  final bool isSubmitting;
  final Future<String?> Function(String code) onSubmit;

  @override
  State<_FriendCodeCard> createState() => _FriendCodeCardState();
}

class _FriendCodeCardState extends State<_FriendCodeCard> {
  late final TextEditingController _controller;
  late final FocusNode _friendCodeFocusNode;
  String? _message;
  _FeedbackTone _messageTone = _FeedbackTone.info;
  bool _showFriendCodeInput = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _friendCodeFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _FriendCodeCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.rewards?.hasActivatedReferral == true) {
      _showFriendCodeInput = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _friendCodeFocusNode.dispose();
    super.dispose();
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

    return _RewardsGlassPanel(
      padding: const EdgeInsets.all(16),
      borderColor: const Color(0xFF3B3264).withValues(alpha: 0.86),
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF15182B).withValues(alpha: 0.96),
          const Color(0xFF101421).withValues(alpha: 0.96),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 390;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5B347C), Color(0xFF2B1F54)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFA855F7,
                            ).withValues(alpha: 0.17),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.group_add_rounded,
                        color: Color(0xFFEBD6FF),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.rewardsReferralFriendCodePrompt,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text.rewardsReferralFriendCodeHint,
                            style: TextStyle(
                              color: colors.textSoft,
                              fontSize: 12,
                              height: 1.32,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_showFriendCodeInput && !compact) ...[
                      const SizedBox(width: 12),
                      _GradientActionButton(
                        key: const Key('rewards_referral_show_input'),
                        width: 168,
                        height: 48,
                        label: text.rewardsReferralUseFriendCodeAction,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFA867F2), Color(0xFF7440B9)],
                        ),
                        onPressed: _openFriendCodeInput,
                      ),
                    ],
                  ],
                ),
                if (!_showFriendCodeInput && compact) ...[
                  const SizedBox(height: 14),
                  _GradientActionButton(
                    key: const Key('rewards_referral_show_input'),
                    height: 48,
                    label: text.rewardsReferralUseFriendCodeAction,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA867F2), Color(0xFF7440B9)],
                    ),
                    onPressed: _openFriendCodeInput,
                  ),
                ],
                if (_showFriendCodeInput) ...[
                  const SizedBox(height: 14),
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
                    decoration: _fieldDecoration(
                      context,
                      hintText: text.rewardsReferralInputHint,
                      labelText: text.rewardsReferralInputLabel,
                      icon: Icons.group_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GradientActionButton(
                    key: const Key('rewards_referral_submit'),
                    height: 48,
                    label: text.rewardsReferralActivateAction,
                    isLoading: widget.isSubmitting,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA867F2), Color(0xFF7440B9)],
                    ),
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: widget.isSubmitting ? null : _submit,
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  _InlineStatus(
                    message: _message!,
                    tone: _feedbackToneColor(_messageTone, colors),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconGradient,
    required this.title,
    this.subtitle,
    this.iconBoxSize = 50,
    this.iconSize = 26,
    this.titleSize = 19,
    this.subtitleSize = 13.5,
  });

  final IconData icon;
  final Gradient iconGradient;
  final String title;
  final String? subtitle;
  final double iconBoxSize;
  final double iconSize;
  final double titleSize;
  final double subtitleSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: iconBoxSize,
          height: iconBoxSize,
          decoration: BoxDecoration(
            gradient: iconGradient,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2BE66C).withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF042013), size: iconSize),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: titleSize,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: subtitleSize,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReferralStats extends StatelessWidget {
  const _ReferralStats({required this.rewards});

  final _RewardsSummaryView? rewards;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF071915).withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF174439).withValues(alpha: 0.62),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MetricStat(
              leading: const PawSparkIcon(size: 18),
              label: text.rewardsReferralEarnedLabel,
              value: '${rewards?.totalReferralBonusEarned ?? 0}',
              unit: text.walletBalanceUnit,
            ),
          ),
          const _MetricDivider(),
          Expanded(
            child: _MetricStat(
              icon: Icons.group_rounded,
              iconColor: const Color(0xFF48E581),
              label: text.rewardsReferralFriendsLabel,
              value: '${rewards?.referredUsersCount ?? 0}',
            ),
          ),
          const _MetricDivider(),
          Expanded(
            child: _MetricStat(
              icon: Icons.shopping_bag_rounded,
              iconColor: const Color(0xFFFFD35B),
              label: text.rewardsReferralBonusLabel,
              value: '${rewards?.rewardedReferredUsersCount ?? 0}',
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricStat extends StatelessWidget {
  const _MetricStat({
    this.icon,
    this.iconColor,
    this.leading,
    required this.label,
    required this.value,
    this.unit,
  });

  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (leading != null)
              leading!
            else
              Icon(icon ?? Icons.circle, color: iconColor, size: 18),
            const SizedBox(width: 4),
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value),
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFF7FE6B6).withValues(alpha: 0.22),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.gradient = const LinearGradient(
      colors: [Color(0xFF49DA87), Color(0xFF3ECE76)],
    ),
    this.width,
    this.height = 50,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Gradient gradient;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(15),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: enabled
                  ? gradient
                  : LinearGradient(
                      colors: [
                        const Color(0xFF314036).withValues(alpha: 0.8),
                        const Color(0xFF243328).withValues(alpha: 0.8),
                      ],
                    ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: const Color(0xFF37DF78).withValues(alpha: 0.24),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF06140C),
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null) ...[
                            Icon(
                              icon,
                              color: const Color(0xFF06140C),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF06140C),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
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

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message, required this.tone});

  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

InputDecoration _fieldDecoration(
  BuildContext context, {
  required String hintText,
  String? labelText,
  IconData? icon,
}) {
  final colors = context.petMagicColors;

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    filled: true,
    fillColor: const Color(0xFF0A1522).withValues(alpha: 0.82),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 20, color: colors.textSoft),
    hintStyle: TextStyle(
      color: colors.textMuted.withValues(alpha: 0.72),
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
    ),
    labelStyle: TextStyle(
      color: colors.textSoft,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(
        color: const Color(0xFF253549).withValues(alpha: 0.95),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xFF47DF82), width: 1.4),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(
        color: const Color(0xFF253549).withValues(alpha: 0.95),
      ),
    ),
  );
}

Color _feedbackToneColor(_FeedbackTone tone, PetMagicColors colors) {
  return switch (tone) {
    _FeedbackTone.success => colors.accent,
    _FeedbackTone.warning => const Color(0xFFD7A44A),
    _FeedbackTone.info => colors.blue,
  };
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

  if (value.contains('auth.sign_in_required')) {
    return text.authRequiredMessage;
  }

  if (value.contains('auth.session_expired')) {
    return text.authExternalSessionExpired;
  }

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
