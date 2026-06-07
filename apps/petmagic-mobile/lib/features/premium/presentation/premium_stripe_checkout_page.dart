import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';

enum PremiumStripeCheckoutActionStatus { success, cancelled, failed }

class PremiumStripeCheckoutSubmitResult {
  const PremiumStripeCheckoutSubmitResult({required this.status, this.message});

  final PremiumStripeCheckoutActionStatus status;
  final String? message;
}

typedef PremiumStripeCheckoutSubmit =
    Future<PremiumStripeCheckoutSubmitResult> Function();

class PremiumStripeCheckoutPage extends StatefulWidget {
  const PremiumStripeCheckoutPage({
    super.key,
    required this.plan,
    required this.paymentMethodLabel,
    required this.onSubmit,
    required this.onChooseAnotherMethod,
  });

  final PremiumPlanModel plan;
  final String paymentMethodLabel;
  final PremiumStripeCheckoutSubmit onSubmit;
  final VoidCallback onChooseAnotherMethod;

  @override
  State<PremiumStripeCheckoutPage> createState() =>
      _PremiumStripeCheckoutPageState();
}

class _PremiumStripeCheckoutPageState extends State<PremiumStripeCheckoutPage> {
  bool _isSubmitting = false;
  PremiumStripeCheckoutSubmitResult? _result;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final price = NumberFormat.simpleCurrency(
      name: widget.plan.currencyCode,
    ).format(widget.plan.priceAmount);
    final periodLabel = _planPeriodLabel(text, widget.plan);
    final planLabel = _planTitle(text, widget.plan);

    return Scaffold(
      appBar: AppBar(
        title: Text(text.premiumCheckoutPageTitle),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _PlanHeroCard(
            title: planLabel,
            periodLabel: periodLabel,
            price: price,
            tokenAllowance: widget.plan.tokenAllowance,
          ),
          const SizedBox(height: 20),
          _IncludedSection(tokenAllowance: widget.plan.tokenAllowance),
          const SizedBox(height: 20),
          _PaymentMethodSection(label: widget.paymentMethodLabel),
          const SizedBox(height: 8),
          const _TrustNote(),
          const SizedBox(height: 20),
          _SummaryCard(
            planLabel: planLabel,
            periodLabel: periodLabel,
            price: price,
          ),
          if (_isSubmitting) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text.externalCheckoutCheckingMessage,
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_result != null &&
              _result!.status != PremiumStripeCheckoutActionStatus.success) ...[
            const SizedBox(height: 14),
            _ErrorCard(status: _result!.status, message: _result!.message),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 54,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_outline_rounded, size: 20),
                label: Text(
                  text.premiumCheckoutPayAction(price),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (_result != null &&
                _result!.status !=
                    PremiumStripeCheckoutActionStatus.success) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: Text(text.walletRetryAction),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              widget.onChooseAnotherMethod();
                              Navigator.of(context).pop(false);
                            },
                      child: Text(text.paymentChooseAnotherMethodAction),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _result = null;
    });

    late final PremiumStripeCheckoutSubmitResult result;
    try {
      result = await widget.onSubmit();
    } on Object {
      if (!mounted) {
        return;
      }

      result = const PremiumStripeCheckoutSubmitResult(
        status: PremiumStripeCheckoutActionStatus.failed,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
      _result = result;
    });

    if (result.status == PremiumStripeCheckoutActionStatus.success) {
      Navigator.of(context).pop(true);
    }
  }
}

class _PlanHeroCard extends StatelessWidget {
  const _PlanHeroCard({
    required this.title,
    required this.periodLabel,
    required this.price,
    required this.tokenAllowance,
  });

  final String title;
  final String periodLabel;
  final String price;
  final int tokenAllowance;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.gold.withValues(alpha: 0.18),
            colors.accent.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.gold.withValues(alpha: 0.42),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      color: colors.gold,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      text.premiumCheckoutHeroBadge,
                      style: TextStyle(
                        color: colors.gold,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  text.premiumCheckoutTokensPerPeriod(tokenAllowance),
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text.premiumCheckoutHeroSubtitle,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, color: colors.accent, size: 13),
                const SizedBox(width: 5),
                Text(
                  text.premiumCheckoutTokensPerPeriod(tokenAllowance),
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  periodLabel,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncludedSection extends StatelessWidget {
  const _IncludedSection({required this.tokenAllowance});

  final int tokenAllowance;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.premiumCheckoutIncludesTitle,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _CheckItem(
          label: text.premiumCheckoutTokensPerPeriod(tokenAllowance),
          color: colors.accent,
        ),
        const SizedBox(height: 6),
        _CheckItem(label: text.premiumCheckoutIncludedTemplates),
        const SizedBox(height: 6),
        _CheckItem(label: text.premiumCheckoutIncludedPriority),
        const SizedBox(height: 6),
        _CheckItem(label: text.premiumCheckoutIncludedNoWatermark),
      ],
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final iconColor = color ?? colors.accent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: iconColor, size: 13),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodSection extends StatelessWidget {
  const _PaymentMethodSection({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.premiumPaymentTitle,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceGlass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.accent, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.credit_card_rounded,
                  color: colors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text.premiumCheckoutPaymentMethodSubtitle,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrustNote extends StatelessWidget {
  const _TrustNote();

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.shield_outlined,
              color: colors.textMuted,
              size: 14,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text.premiumCheckoutTrustText,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.planLabel,
    required this.periodLabel,
    required this.price,
  });

  final String planLabel;
  final String periodLabel;
  final String price;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.premiumCheckoutSummaryTitle,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: text.premiumCheckoutSummaryPlanLabel,
            value: planLabel,
          ),
          const SizedBox(height: 6),
          _SummaryRow(
            label: text.premiumCheckoutSummaryPeriodLabel,
            value: periodLabel,
          ),
          const SizedBox(height: 6),
          _SummaryRow(
            label: text.walletCheckoutTaxLabel,
            value: text.walletCheckoutTaxIncludedValue,
          ),
          Divider(height: 16, color: colors.border),
          _SummaryRow(
            label: text.premiumCheckoutTotalLabel,
            value: price,
            isStrong: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isStrong = false,
  });

  final String label;
  final String value;
  final bool isStrong;

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
        Text(
          value,
          style: TextStyle(
            color: isStrong ? colors.textStrong : colors.textSoft,
            fontSize: isStrong ? 15 : 13,
            fontWeight: isStrong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.status, required this.message});

  final PremiumStripeCheckoutActionStatus status;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);

    final resolved = message?.trim().isNotEmpty == true
        ? message!.trim()
        : (status == PremiumStripeCheckoutActionStatus.cancelled
              ? text.premiumPurchaseCancelled
              : text.premiumCheckoutFailed);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colors.gold.withValues(alpha: 0.12),
        border: Border.all(color: colors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              color: colors.gold,
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              resolved,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _planTitle(AppLocalizations text, PremiumPlanModel plan) {
  return _isYearlyPlan(plan) ? text.premiumYearlyPlan : text.premiumMonthlyPlan;
}

String _planPeriodLabel(AppLocalizations text, PremiumPlanModel plan) {
  return _isYearlyPlan(plan)
      ? text.premiumCheckoutPeriodYearly
      : text.premiumCheckoutPeriodMonthly;
}

bool _isYearlyPlan(PremiumPlanModel plan) {
  final value = '${plan.billingInterval}:${plan.planCode}'.toLowerCase();
  return value.contains('year') || value.contains('annual');
}
