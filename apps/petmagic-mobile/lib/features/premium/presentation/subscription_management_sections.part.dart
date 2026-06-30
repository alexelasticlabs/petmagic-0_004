part of 'subscription_management_page.dart';

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

    return _SubscriptionPanel(
      accentColor: colors.gold,
      borderOpacity: 0.28,
      glowOpacity: 0.14,
      showAccentGlow: true,
      glowAlignment: const Alignment(-0.92, -0.9),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.gold.withValues(alpha: 0.24),
                  ),
                ),
                child: const Center(child: PremiumCrownIcon(size: 18)),
              ),
              const SizedBox(width: 10),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GlowStatusBadge(label: statusLabel, color: statusColor),
              if (summary.provider == PremiumSubscriptionProviderView.stripe)
                _OutlineMetaBadge(
                  label: text.subscriptionPaymentProviderStripe,
                  foregroundColor: colors.textSoft.withValues(alpha: 0.9),
                ),
            ],
          ),
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

class _TokensCard extends StatelessWidget {
  const _TokensCard({required this.summary});

  final PremiumSubscriptionSummaryView summary;

  DateTime? _nextGrantUtc(DateTime now) {
    final base = summary.lastTokenGrantAtUtc ?? summary.currentPeriodStartUtc;
    if (base == null) {
      return null;
    }

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

    return _SubscriptionPanel(
      accentColor: colors.gold,
      borderOpacity: 0.22,
      glowOpacity: 0.1,
      showAccentGlow: true,
      glowAlignment: const Alignment(-0.82, -0.22),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
                      text.subscriptionTokensWeeklyGrantPeriodSuffix,
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
                    color: colors.textSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TokenGrantProgressBar(
            nextGrantUtc: nextGrant,
            weeklyGrantAmount: weeklyGrant,
          ),
          const SizedBox(height: 12),
          Text(
            text.subscriptionTokensExplanation,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

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
        description: text.subscriptionBenefitTokensDescription,
      ),
      _BenefitItem(
        icon: Icons.card_giftcard_rounded,
        title: text.subscriptionBenefitFirstBonus,
        description: text.subscriptionBenefitFirstBonusDescription,
      ),
      _BenefitItem(
        icon: Icons.auto_awesome_rounded,
        title: text.subscriptionBenefitTemplates,
        description: text.subscriptionBenefitTemplatesDescription,
      ),
      _BenefitItem(
        icon: Icons.flash_on_rounded,
        title: text.subscriptionBenefitPriorityGeneration,
        description: text.subscriptionBenefitPriorityGenerationDescription,
      ),
      _BenefitItem(
        icon: Icons.hide_image_outlined,
        title: text.subscriptionBenefitNoWatermark,
        description: text.subscriptionBenefitNoWatermarkDescription,
      ),
    ];

    return _SubscriptionPanel(
      accentColor: colors.border,
      borderOpacity: 0.14,
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

    return _SubscriptionPanel(
      accentColor: colors.border,
      borderOpacity: 0.14,
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
                      color: colors.textSoft,
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
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
              style: OutlinedButton.styleFrom(
                backgroundColor: isLight ? const Color(0xFFFDFEFF) : null,
                side: BorderSide(
                  color: isLight
                      ? const Color(0xFFAFC2DB)
                      : colors.border.withValues(alpha: 0.9),
                ),
                foregroundColor: isLight ? const Color(0xFF2F3E56) : null,
              ),
              child: Text(text.subscriptionChangePaymentAction),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final isLight = Theme.of(context).brightness == Brightness.light;
    const manageColor = Color(0xFFFFC107);

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
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(36),
            backgroundColor: manageColor,
            foregroundColor: const Color(0xFF261903),
            disabledBackgroundColor: colors.surfaceStrong,
            disabledForegroundColor: colors.textMuted,
            textStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
            shadowColor: Colors.transparent,
          ),
          child: Text(text.premiumManageAction),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: isProcessing ? null : onRestore,
          style: OutlinedButton.styleFrom(
            backgroundColor: isLight ? const Color(0xFFFDFEFF) : null,
            side: BorderSide(
              color: isLight
                  ? const Color(0xFFAFC2DB)
                  : colors.border.withValues(alpha: 0.9),
            ),
            foregroundColor: isLight ? const Color(0xFF2F3E56) : null,
          ),
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
                  color: colors.danger.withValues(alpha: 0.82),
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
              foregroundColor: colors.danger.withValues(
                alpha: isLight ? 0.95 : 1,
              ),
              backgroundColor: isLight ? const Color(0xFFFFF8F8) : null,
              side: BorderSide(
                color: colors.danger.withValues(alpha: isLight ? 0.62 : 0.5),
              ),
            ),
            child: Text(text.subscriptionCancelAction),
          ),
        ],
      ],
    );
  }
}

String _resolveStatusLabel(
  PremiumSubscriptionSummaryView summary,
  AppLocalizations text,
) {
  if (!summary.isPremium) {
    return text.subscriptionStatusInactive;
  }
  if (summary.cancelAtPeriodEnd == true) {
    return text.subscriptionStatusCancelled;
  }
  return switch (summary.status.toLowerCase()) {
    'active' || 'trialing' => text.subscriptionStatusActive,
    'past_due' || 'unpaid' => text.subscriptionStatusPaymentFailed,
    'canceled' => text.subscriptionStatusExpired,
    'incomplete' || 'incomplete_expired' => text.subscriptionStatusPending,
    _ => text.subscriptionStatusActive,
  };
}

Color _resolveStatusColor(
  PremiumSubscriptionSummaryView summary,
  PetMagicColors colors,
) {
  if (!summary.isPremium) {
    return colors.textMuted;
  }
  if (summary.cancelAtPeriodEnd == true) {
    return colors.gold;
  }
  return switch (summary.status.toLowerCase()) {
    'active' || 'trialing' => colors.accent,
    'past_due' || 'unpaid' => colors.danger,
    'canceled' => colors.textMuted,
    'incomplete' || 'incomplete_expired' => colors.gold,
    _ => colors.accent,
  };
}
