import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';

enum WalletStripeCheckoutActionStatus { success, cancelled, failed }

class WalletStripeCheckoutSubmitResult {
  const WalletStripeCheckoutSubmitResult({required this.status, this.message});

  final WalletStripeCheckoutActionStatus status;
  final String? message;
}

typedef WalletStripeCheckoutSubmit =
    Future<WalletStripeCheckoutSubmitResult> Function();

class WalletStripeCheckoutPage extends StatefulWidget {
  const WalletStripeCheckoutPage({
    super.key,
    required this.pack,
    required this.paymentMethodLabel,
    required this.onSubmit,
    required this.onChooseAnotherMethod,
  });

  final CurrencyPackModel pack;
  final String paymentMethodLabel;
  final WalletStripeCheckoutSubmit onSubmit;
  final VoidCallback onChooseAnotherMethod;

  @override
  State<WalletStripeCheckoutPage> createState() =>
      _WalletStripeCheckoutPageState();
}

class _WalletStripeCheckoutPageState extends State<WalletStripeCheckoutPage> {
  bool _isSubmitting = false;
  WalletStripeCheckoutSubmitResult? _result;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final price = NumberFormat.simpleCurrency(
      name: widget.pack.currencyCode,
    ).format(widget.pack.priceAmount);

    return Scaffold(
      appBar: AppBar(
        title: Text(text.walletBuySparkTitle),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _HeroPackCard(pack: widget.pack, price: price),
          const SizedBox(height: 20),
          _IncludedSection(pack: widget.pack),
          const SizedBox(height: 20),
          _PaymentMethodSection(label: widget.paymentMethodLabel),
          const SizedBox(height: 8),
          const _TrustNote(),
          const SizedBox(height: 20),
          _OrderSummaryCard(pack: widget.pack, price: price),
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
              _result!.status != WalletStripeCheckoutActionStatus.success) ...[
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
                onPressed: _isSubmitting ? null : () => _submit(price),
                style: FilledButton.styleFrom(
                  backgroundColor: context.petMagicColors.accent,
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
                  text.walletCheckoutPayAction(price),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (_result != null &&
                _result!.status !=
                    WalletStripeCheckoutActionStatus.success) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => _submit(price),
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

  Future<void> _submit(String price) async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _result = null;
    });

    late final WalletStripeCheckoutSubmitResult result;
    try {
      result = await widget.onSubmit();
    } on Object {
      if (!mounted) {
        return;
      }

      result = const WalletStripeCheckoutSubmitResult(
        status: WalletStripeCheckoutActionStatus.failed,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
      _result = result;
    });

    if (result.status == WalletStripeCheckoutActionStatus.success) {
      Navigator.of(context).pop(true);
    }
  }
}

// ── Hero card ──────────────────────────────────────────────────────────────

class _HeroPackCard extends StatelessWidget {
  const _HeroPackCard({required this.pack, required this.price});

  final CurrencyPackModel pack;
  final String price;

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
            colors.purple.withValues(alpha: 0.18),
            colors.accent.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.purple.withValues(alpha: 0.38),
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
                  color: colors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: colors.purple, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      text.walletBuySparkTitle,
                      style: TextStyle(
                        color: colors.purple,
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
                  text.walletPackTotalSpark(pack.totalSpark),
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
            pack.displayName,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text.walletCheckoutProductSubtitle,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _BenefitChip(
                icon: Icons.bolt_rounded,
                label: text.walletCheckoutTokensImmediately(pack.totalSpark),
                color: colors.accent,
              ),
              if (pack.bonusSpark > 0)
                _BenefitChip(
                  icon: Icons.card_giftcard_rounded,
                  label: text.walletCheckoutBonusTokens(pack.bonusSpark),
                  color: colors.gold,
                ),
            ],
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
                  '· ${text.walletCheckoutTaxIncludedValue}',
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

class _BenefitChip extends StatelessWidget {
  const _BenefitChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── What's included ────────────────────────────────────────────────────────

class _IncludedSection extends StatelessWidget {
  const _IncludedSection({required this.pack});

  final CurrencyPackModel pack;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.walletCheckoutIncludesTitle,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _CheckItem(
          label: text.walletCheckoutTokensImmediately(pack.totalSpark),
          color: colors.accent,
        ),
        if (pack.bonusSpark > 0) ...[
          const SizedBox(height: 6),
          _CheckItem(
            label: text.walletCheckoutBonusTokens(pack.bonusSpark),
            color: colors.gold,
          ),
        ],
        const SizedBox(height: 6),
        _CheckItem(label: text.walletPackUsageNote),
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

// ── Payment method ─────────────────────────────────────────────────────────

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
          text.subscriptionPaymentMethodLabel,
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
                    Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text.walletCheckoutStripeMethodSubtitle,
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

// ── Trust note ─────────────────────────────────────────────────────────────

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
              text.walletCheckoutTrustText,
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

// ── Order summary ──────────────────────────────────────────────────────────

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.pack, required this.price});

  final CurrencyPackModel pack;
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
            text.walletCheckoutOrderSectionTitle,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: text.walletSourcePackPurchase,
            value: text.walletPackTotalSpark(pack.totalSpark),
          ),
          const SizedBox(height: 6),
          _SummaryRow(label: pack.displayName, value: price),
          const SizedBox(height: 6),
          _SummaryRow(
            label: text.walletCheckoutTaxLabel,
            value: text.walletCheckoutTaxIncludedValue,
          ),
          Divider(height: 16, color: colors.border),
          _SummaryRow(
            label: text.walletCheckoutTotalLabel,
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

// ── Error card ─────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.status, required this.message});

  final WalletStripeCheckoutActionStatus status;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);

    final resolved = message?.trim().isNotEmpty == true
        ? message!.trim()
        : (status == WalletStripeCheckoutActionStatus.cancelled
              ? text.premiumPurchaseCancelled
              : text.walletPaymentGatewayUnavailableError);

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
