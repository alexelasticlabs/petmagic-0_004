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
                  summary.planName ?? text.premiumPageTitle,
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
          if (summary.isPremium)
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
