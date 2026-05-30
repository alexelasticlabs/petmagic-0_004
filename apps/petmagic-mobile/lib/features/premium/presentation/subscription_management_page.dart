import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionManagementPage extends ConsumerStatefulWidget {
  const SubscriptionManagementPage({super.key});

  static const routePath = '/profile/subscription/manage';

  @override
  ConsumerState<SubscriptionManagementPage> createState() =>
      _SubscriptionManagementPageState();
}

class _SubscriptionManagementPageState
    extends ConsumerState<SubscriptionManagementPage> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(premiumSubscriptionSummaryProvider);
    final text = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(text.profileSubscriptionTitle)),
      body: SafeArea(
        child: summaryAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(text.premiumManageFailed),
            ),
          ),
          data: (summary) => _SubscriptionContent(
            summary: summary,
            isProcessing: _isProcessing,
            onManage: () => _openManageTarget(summary.manageSubscriptionAction),
            onRestore: _restorePurchases,
            onChangePayment: () =>
                _openManageTarget(summary.manageSubscriptionAction),
            onCancel: _cancelAtPeriodEnd,
          ),
        ),
      ),
    );
  }

  Future<void> _openManageTarget(String manageSubscriptionAction) async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(premiumSubscriptionManagementServiceProvider);
      final url = await service.createManagementUrl(manageSubscriptionAction);
      final uri = Uri.parse(url);
      var launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (_) {
        launched = false;
      }
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } finally {
      if (mounted) {
        ref.invalidate(premiumSubscriptionSummaryProvider);
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _cancelAtPeriodEnd() async {
    final summary = ref.read(premiumSubscriptionSummaryProvider).value;
    final text = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateStr = summary?.currentPeriodEndUtc != null
        ? DateFormat.yMMMd(
            locale,
          ).format(summary!.currentPeriodEndUtc!.toLocal())
        : '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _CancelConfirmDialog(text: text, periodEndDateStr: dateStr),
    );
    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final service = ref.read(premiumSubscriptionManagementServiceProvider);
      await service.requestCancelAtPeriodEnd();
      ref.invalidate(premiumSubscriptionSummaryProvider);
      ref.invalidate(profileControllerProvider);
      ref.invalidate(premiumControllerProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).subscriptionAutoRenewOff,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(premiumControllerProvider.notifier).restorePurchases();
      ref.invalidate(premiumSubscriptionSummaryProvider);
      ref.invalidate(profileControllerProvider);
      // Read updated summary to determine snackbar message
      final updated = await ref.read(premiumSubscriptionSummaryProvider.future);
      if (mounted) {
        final text = AppLocalizations.of(context);
        final message = updated.isPremium
            ? text.subscriptionRestoreSuccessMessage
            : text.subscriptionRestoreNoneFoundMessage;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

// ─── main content ────────────────────────────────────────────────────────────

class _SubscriptionContent extends StatelessWidget {
  const _SubscriptionContent({
    required this.summary,
    required this.isProcessing,
    required this.onManage,
    required this.onRestore,
    required this.onChangePayment,
    required this.onCancel,
  });

  final PremiumSubscriptionSummaryView summary;
  final bool isProcessing;
  final VoidCallback onManage;
  final VoidCallback onRestore;
  final VoidCallback onChangePayment;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isStripe = summary.provider == PremiumSubscriptionProviderView.stripe;
    final canCancel =
        isStripe && summary.isPremium && summary.cancelAtPeriodEnd != true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        _PremiumHeroCard(summary: summary),
        const SizedBox(height: 12),
        _TokensCard(summary: summary),
        const SizedBox(height: 12),
        _BenefitsCard(),
        if (isStripe) ...[
          const SizedBox(height: 12),
          _PaymentCard(
            summary: summary,
            isProcessing: isProcessing,
            onChangePayment: onChangePayment,
          ),
        ],
        const SizedBox(height: 20),
        _ActionsSection(
          summary: summary,
          isProcessing: isProcessing,
          canCancel: canCancel,
          onManage: onManage,
          onRestore: onRestore,
          onCancel: onCancel,
        ),
        if (summary.isPremium && summary.cancelAtPeriodEnd == true) ...[
          const SizedBox(height: 16),
          _CancelledHintBanner(summary: summary, colors: colors, text: text),
        ],
      ],
    );
  }
}

// ─── Block 1: Premium Hero Card ───────────────────────────────────────────────

class _PremiumHeroCard extends StatelessWidget {
  const _PremiumHeroCard({required this.summary});

  final PremiumSubscriptionSummaryView summary;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = DateFormat.yMMMd(locale);

    final statusLabel = _resolveStatusLabel(summary, text);
    final statusColor = _resolveStatusColor(summary, colors);

    final startDate = summary.currentPeriodStartUtc != null
        ? fmt.format(summary.currentPeriodStartUtc!.toLocal())
        : null;
    final periodEnd = summary.currentPeriodEndUtc != null
        ? fmt.format(summary.currentPeriodEndUtc!.toLocal())
        : null;
    final nextBilling =
        summary.currentPeriodEndUtc != null &&
            summary.isPremium &&
            summary.cancelAtPeriodEnd != true
        ? fmt.format(summary.currentPeriodEndUtc!.toLocal())
        : null;
    final billingPeriodStr = switch (summary.billingPeriod?.toLowerCase()) {
      'monthly' => text.subscriptionBillingPeriodMonthly,
      'yearly' => text.subscriptionBillingPeriodYearly,
      _ => summary.billingPeriod,
    };

    return ProfileGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: colors.gold,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary.planName ?? 'PetMagic Premium',
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _GlowStatusBadge(label: statusLabel, color: statusColor),
          const SizedBox(height: 16),
          Divider(color: colors.border, height: 1),
          const SizedBox(height: 16),
          if (startDate != null) ...[
            _InfoRow(label: text.subscriptionStartDateLabel, value: startDate),
            const SizedBox(height: 10),
          ],
          if (periodEnd != null) ...[
            _InfoRow(label: text.subscriptionPeriodEndLabel, value: periodEnd),
            const SizedBox(height: 10),
          ],
          if (nextBilling != null) ...[
            _InfoRow(
              label: text.profileSubscriptionNextBillingLabel,
              value: nextBilling,
            ),
            const SizedBox(height: 10),
          ],
          if (billingPeriodStr != null) ...[
            _InfoRow(
              label: text.subscriptionBillingPeriodLabel,
              value: billingPeriodStr,
            ),
            const SizedBox(height: 10),
          ],
          _InfoRow(
            label: text.subscriptionAutoRenewLabel,
            value: summary.cancelAtPeriodEnd == true
                ? text.subscriptionAutoRenewOff
                : text.subscriptionAutoRenewOn,
            valueColor: summary.cancelAtPeriodEnd == true
                ? colors.danger
                : colors.accent,
          ),
        ],
      ),
    );
  }
}

// ─── Block 2: Tokens Card ─────────────────────────────────────────────────────

class _TokensCard extends StatelessWidget {
  const _TokensCard({required this.summary});

  final PremiumSubscriptionSummaryView summary;

  DateTime? _nextGrantUtc(DateTime now) {
    final base = summary.lastTokenGrantAtUtc ?? summary.currentPeriodStartUtc;
    if (base == null) return null;
    var next = base.add(const Duration(days: 7));
    while (next.isBefore(now)) {
      next = next.add(const Duration(days: 7));
    }
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final now = DateTime.now().toUtc();

    final nextGrant = _nextGrantUtc(now);
    final tokensAvailable = summary.tokensAvailable ?? 0;
    final weeklyGrant = summary.weeklyGrantAmount ?? 40;

    return ProfileGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title + badge
          Row(
            children: [
              Expanded(
                child: Text(
                  text.subscriptionTokensSectionTitle,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: colors.gold, size: 13),
                    const SizedBox(width: 3),
                    Text(
                      '+$weeklyGrant',
                      style: TextStyle(
                        color: colors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      ' / 7д',
                      style: TextStyle(
                        color: colors.gold.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Balance row: big number + label side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$tokensAvailable',
                style: TextStyle(
                  color: colors.gold,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  text.subscriptionTokensAvailableLabel,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Animated progress bar + live countdown
          _TokenGrantProgressBar(
            nextGrantUtc: nextGrant,
            weeklyGrantAmount: weeklyGrant,
          ),
          const SizedBox(height: 12),
          Text(
            text.subscriptionTokensExplanation,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated token grant progress bar ───────────────────────────────────────

class _TokenGrantProgressBar extends StatefulWidget {
  const _TokenGrantProgressBar({
    required this.nextGrantUtc,
    required this.weeklyGrantAmount,
  });

  final DateTime? nextGrantUtc;
  final int weeklyGrantAmount;

  @override
  State<_TokenGrantProgressBar> createState() => _TokenGrantProgressBarState();
}

class _TokenGrantProgressBarState extends State<_TokenGrantProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _progressAnim;
  Timer? _ticker;
  DateTime _now = DateTime.now().toUtc();

  double get _currentProgress {
    final next = widget.nextGrantUtc;
    if (next == null) return 0.0;
    final prev = next.subtract(const Duration(days: 7));
    final total = const Duration(days: 7).inSeconds;
    final elapsed = _now.difference(prev).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressAnim = Tween<double>(begin: 0, end: _currentProgress)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _controller.forward();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  String _buildCountdown() {
    final next = widget.nextGrantUtc;
    if (next == null) return '';
    final diff = next.difference(_now);
    if (diff.isNegative) return '';
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    if (d > 0) return '$dд $hч $mм';
    if (h > 0) return '$hч $mм $sс';
    return '$mм $sс';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final p = _controller.isCompleted ? _currentProgress : _progressAnim.value;
    final countdown = _buildCountdown();
    final isReady = widget.nextGrantUtc != null &&
        _now.isAfter(widget.nextGrantUtc!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final fillW = (w * p).clamp(0.0, w);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Track
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Fill with gradient
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: fillW,
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.accent, colors.gold],
                      ),
                    ),
                  ),
                ),
                // Glow dot at fill end
                if (fillW > 6)
                  Positioned(
                    left: fillW - 6,
                    top: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.gold,
                        boxShadow: [
                          BoxShadow(
                            color: colors.gold.withValues(alpha: 0.55),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isReady)
              Text(
                '✦ Готово к начислению!',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
            else if (countdown.isNotEmpty)
              Text(
                'Следующее начисление: $countdown',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              const SizedBox.shrink(),
            Text(
              '${(p * 100).round()}%',
              style: TextStyle(
                color: colors.accent.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Block 3: Benefits Card ───────────────────────────────────────────────────

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard();

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    final benefits = [
      _BenefitItem(
        icon: Icons.bolt_rounded,
        title: text.subscriptionBenefitTokens,
        description: 'Автоматически каждые 7 дней',
      ),
      _BenefitItem(
        icon: Icons.card_giftcard_rounded,
        title: text.subscriptionBenefitFirstBonus,
        description: 'Мгновенно при покупке',
      ),
      _BenefitItem(
        icon: Icons.auto_awesome_rounded,
        title: text.subscriptionBenefitTemplates,
        description: 'Все сценарии разблокированы',
      ),
      _BenefitItem(
        icon: Icons.flash_on_rounded,
        title: text.subscriptionBenefitPriorityGeneration,
        description: 'Ваши задачи в приоритете',
      ),
      _BenefitItem(
        icon: Icons.hide_image_outlined,
        title: text.subscriptionBenefitNoWatermark,
        description: 'Чистый результат',
      ),
    ];

    return ProfileGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.subscriptionBenefitsSectionTitle,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          ...benefits.asMap().entries.map((entry) {
            final i = entry.key;
            final b = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: i < benefits.length - 1 ? 14 : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(b.icon, color: colors.accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.title,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          b.description,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _BenefitItem {
  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;
}

// ─── Block 4: Payment Card (Stripe only) ─────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.summary,
    required this.isProcessing,
    required this.onChangePayment,
  });

  final PremiumSubscriptionSummaryView summary;
  final bool isProcessing;
  final VoidCallback onChangePayment;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final maskedCard = summary.cardLast4 != null
        ? '**** ${summary.cardLast4}'
        : null;
    final paymentLabel = maskedCard != null
        ? '${text.subscriptionPaymentProviderStripe}  ·  $maskedCard'
        : text.subscriptionPaymentProviderStripe;

    return ProfileGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.subscriptionPaymentSectionTitle,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.credit_card_rounded,
                  color: colors.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  paymentLabel,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceStrong.withValues(
                alpha: isLight ? 0.94 : 0.78,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.border.withValues(alpha: isLight ? 0.92 : 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: colors.textMuted,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text.subscriptionPaymentTrustText,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isProcessing || !summary.canManageSubscription
                  ? null
                  : onChangePayment,
              child: Text(text.subscriptionChangePaymentAction),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Block 5: Actions Section ─────────────────────────────────────────────────

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({
    required this.summary,
    required this.isProcessing,
    required this.canCancel,
    required this.onManage,
    required this.onRestore,
    required this.onCancel,
  });

  final PremiumSubscriptionSummaryView summary;
  final bool isProcessing;
  final bool canCancel;
  final VoidCallback onManage;
  final VoidCallback onRestore;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed:
              isProcessing ||
                  !summary.canManageSubscription ||
                  !summary.isPremium
              ? null
              : onManage,
          child: Text(text.premiumManageAction),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: isProcessing ? null : onRestore,
          child: Text(text.premiumRestoreAction),
        ),
        if (canCancel) ...[
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: Divider(color: colors.danger.withValues(alpha: 0.25)),
              ),
              const SizedBox(width: 12),
              Text(
                text.subscriptionDangerZoneTitle,
                style: TextStyle(
                  color: colors.danger.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Divider(color: colors.danger.withValues(alpha: 0.25)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: isProcessing ? null : onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.danger,
              side: BorderSide(color: colors.danger.withValues(alpha: 0.5)),
            ),
            child: Text(text.subscriptionCancelAction),
          ),
        ],
      ],
    );
  }
}

// ─── Cancel Confirm Dialog ────────────────────────────────────────────────────

class _CancelConfirmDialog extends StatelessWidget {
  const _CancelConfirmDialog({
    required this.text,
    required this.periodEndDateStr,
  });

  final AppLocalizations text;
  final String periodEndDateStr;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return AlertDialog(
      title: Text(text.subscriptionCancelConfirmTitle),
      content: Text(
        text.subscriptionCancelConfirmBody(periodEndDateStr),
        style: TextStyle(color: colors.textSoft, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(text.subscriptionCancelConfirmKeep),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: colors.danger),
          child: Text(text.subscriptionCancelConfirmAction),
        ),
      ],
    );
  }
}

// ─── Cancelled hint ───────────────────────────────────────────────────────────

class _CancelledHintBanner extends StatelessWidget {
  const _CancelledHintBanner({
    required this.summary,
    required this.colors,
    required this.text,
  });

  final PremiumSubscriptionSummaryView summary;
  final PetMagicColors colors;
  final AppLocalizations text;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateStr = summary.currentPeriodEndUtc != null
        ? DateFormat.yMMMd(
            locale,
          ).format(summary.currentPeriodEndUtc!.toLocal())
        : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.danger.withValues(alpha: 0.2)),
      ),
      child: Text(
        text.subscriptionCancelledHint(dateStr),
        style: TextStyle(color: colors.danger, fontSize: 13, height: 1.5),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? colors.textStrong,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _GlowStatusBadge extends StatelessWidget {
  const _GlowStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: Offset.zero,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _resolveStatusLabel(
  PremiumSubscriptionSummaryView summary,
  AppLocalizations text,
) {
  if (!summary.isPremium) return text.subscriptionStatusInactive;
  if (summary.cancelAtPeriodEnd == true) {
    return text.subscriptionStatusCancelled;
  }
  return switch (summary.status.toLowerCase()) {
    'active' || 'trialing' => text.subscriptionStatusActive,
    'past_due' || 'unpaid' => text.subscriptionStatusPaymentFailed,
    'canceled' || 'cancelled' => text.subscriptionStatusExpired,
    'incomplete' || 'incomplete_expired' => text.subscriptionStatusPending,
    _ => text.subscriptionStatusActive,
  };
}

Color _resolveStatusColor(
  PremiumSubscriptionSummaryView summary,
  PetMagicColors colors,
) {
  if (!summary.isPremium) return colors.textMuted;
  if (summary.cancelAtPeriodEnd == true) return colors.gold;
  return switch (summary.status.toLowerCase()) {
    'active' || 'trialing' => colors.accent,
    'past_due' || 'unpaid' => colors.danger,
    'canceled' || 'cancelled' => colors.textMuted,
    'incomplete' || 'incomplete_expired' => colors.gold,
    _ => colors.accent,
  };
}
