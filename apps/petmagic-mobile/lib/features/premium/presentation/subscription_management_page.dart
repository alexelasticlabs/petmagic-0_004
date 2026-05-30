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
  Timer? _countdownTimer;
  DateTime _now = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
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
            now: _now,
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
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _cancelAtPeriodEnd() async {
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
    required this.now,
    required this.onManage,
    required this.onRestore,
    required this.onChangePayment,
    required this.onCancel,
  });

  final PremiumSubscriptionSummaryView summary;
  final bool isProcessing;
  final DateTime now;
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _StatusSection(summary: summary, now: now),
        const SizedBox(height: 12),
        _TokensSection(summary: summary, now: now),
        const SizedBox(height: 12),
        _BenefitsSection(),
        if (isStripe) ...[
          const SizedBox(height: 12),
          _PaymentSection(
            summary: summary,
            isProcessing: isProcessing,
            onChangePayment: onChangePayment,
          ),
        ],
        const SizedBox(height: 24),
        _ActionsSection(
          summary: summary,
          isProcessing: isProcessing,
          canCancel: canCancel,
          onManage: onManage,
          onRestore: onRestore,
          onChangePayment: onChangePayment,
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

// ─── Block 1: Status ─────────────────────────────────────────────────────────

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.summary, required this.now});

  final PremiumSubscriptionSummaryView summary;
  final DateTime now;

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

    return ProfileGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(label: statusLabel, color: statusColor),
              const Spacer(),
              if (summary.planName != null)
                Text(
                  summary.planName!,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (startDate != null) ...[
            const SizedBox(height: 14),
            _InfoRow(label: text.subscriptionStartDateLabel, value: startDate),
          ],
          if (periodEnd != null) ...[
            const SizedBox(height: 8),
            _InfoRow(label: text.subscriptionPeriodEndLabel, value: periodEnd),
          ],
          if (nextBilling != null) ...[
            const SizedBox(height: 8),
            _InfoRow(
              label: text.profileSubscriptionNextBillingLabel,
              value: nextBilling,
            ),
          ],
          const SizedBox(height: 8),
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

// ─── Block 2: Tokens ─────────────────────────────────────────────────────────

class _TokensSection extends StatelessWidget {
  const _TokensSection({required this.summary, required this.now});

  final PremiumSubscriptionSummaryView summary;
  final DateTime now;

  DateTime? _nextGrantUtc() {
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
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = DateFormat.yMMMd(locale);

    final nextGrant = _nextGrantUtc();
    final tokensAvailable = summary.tokensAvailable ?? 0;
    final tokensPerPeriod = summary.monthlyTokenLimit ?? 40;

    String? countdownStr;
    String? nextGrantDateStr;
    if (nextGrant != null) {
      nextGrantDateStr = fmt.format(nextGrant.toLocal());
      final diff = nextGrant.difference(now);
      if (diff.isNegative == false) {
        final days = diff.inDays;
        final hours = diff.inHours % 24;
        final minutes = diff.inMinutes % 60;
        countdownStr = text.subscriptionTokensCountdown(
          days.toString(),
          hours.toString(),
          minutes.toString(),
        );
      }
    }

    return ProfileGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.subscriptionTokensSectionTitle,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _InfoRow(
            label: text.subscriptionTokensAvailableLabel,
            value: '$tokensAvailable',
            valueColor: colors.gold,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            label: text.subscriptionTokensPerPeriodLabel,
            value: '$tokensPerPeriod',
          ),
          if (nextGrantDateStr != null) ...[
            const SizedBox(height: 8),
            _InfoRow(
              label: text.subscriptionTokensNextGrantLabel,
              value: nextGrantDateStr,
            ),
            if (countdownStr != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  countdownStr,
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          Text(
            text.subscriptionTokensExplanation,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Block 3: Benefits ───────────────────────────────────────────────────────

class _BenefitsSection extends StatelessWidget {
  const _BenefitsSection();

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    final benefits = [
      text.subscriptionBenefitTokens,
      text.subscriptionBenefitFirstBonus,
      text.subscriptionBenefitTemplates,
      text.subscriptionBenefitPriorityGeneration,
      text.subscriptionBenefitNoWatermark,
    ];

    return ProfileGlassCard(
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
          const SizedBox(height: 12),
          ...benefits.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b,
                      style: TextStyle(color: colors.textSoft, fontSize: 14),
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

// ─── Block 4: Payment (Stripe only) ──────────────────────────────────────────

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({
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
    final maskedCard = summary.cardLast4 != null
        ? '**** ${summary.cardLast4}'
        : null;

    return ProfileGlassCard(
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
          _InfoRow(
            label: text.subscriptionPaymentMethodLabel,
            value: text.subscriptionPaymentProviderStripe,
          ),
          if (maskedCard != null) ...[
            const SizedBox(height: 8),
            _InfoRow(
              label: text.subscriptionPaymentCardLabel,
              value: maskedCard,
            ),
          ],
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

// ─── Block 5: Actions ────────────────────────────────────────────────────────

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({
    required this.summary,
    required this.isProcessing,
    required this.canCancel,
    required this.onManage,
    required this.onRestore,
    required this.onChangePayment,
    required this.onCancel,
  });

  final PremiumSubscriptionSummaryView summary;
  final bool isProcessing;
  final bool canCancel;
  final VoidCallback onManage;
  final VoidCallback onRestore;
  final VoidCallback onChangePayment;
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
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: isProcessing ? null : onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.danger,
              side: BorderSide(color: colors.danger.withValues(alpha: 0.4)),
            ),
            child: Text(text.subscriptionCancelAction),
          ),
        ],
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
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
  if (summary.cancelAtPeriodEnd == true)
    return text.subscriptionStatusCancelled;
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
