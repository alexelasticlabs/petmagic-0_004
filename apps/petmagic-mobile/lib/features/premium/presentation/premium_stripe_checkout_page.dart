import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/premium/domain/premium_models.dart';

part 'premium_stripe_checkout_page_helpers.part.dart';
part 'premium_stripe_checkout_page_sections.part.dart';
part 'premium_stripe_checkout_page_summary.part.dart';

enum PremiumStripeCheckoutActionStatus { success, cancelled, failed }

class PremiumStripeCheckoutSubmitResult {
  const PremiumStripeCheckoutSubmitResult({required this.status, this.message});

  final PremiumStripeCheckoutActionStatus status;
  final String? message;
}

typedef PremiumStripeCheckoutSubmit =
    Future<PremiumStripeCheckoutSubmitResult> Function();

class PremiumStripeCheckoutPage extends ConsumerStatefulWidget {
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
  ConsumerState<PremiumStripeCheckoutPage> createState() =>
      _PremiumStripeCheckoutPageState();
}

class _PremiumStripeCheckoutPageState
    extends ConsumerState<PremiumStripeCheckoutPage> {
  bool _isSubmitting = false;
  PremiumStripeCheckoutSubmitResult? _result;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final price = NumberFormat.simpleCurrency(
      locale: localeTag,
      name: widget.plan.currencyCode,
    ).format(widget.plan.priceAmount);
    final periodLabel = _planPeriodLabel(text, widget.plan);
    final planLabel = _planTitle(text, widget.plan);
    final submitForegroundColor = Theme.of(context).colorScheme.onPrimary;
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final canSubmit = !_isSubmitting && hasInternet;

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
          ),
          const SizedBox(height: 20),
          _IncludedSection(tokenAllowance: widget.plan.tokenAllowance),
          const SizedBox(height: 20),
          _PaymentMethodSection(label: widget.paymentMethodLabel),
          const SizedBox(height: 8),
          const _TrustNote(),
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
                onPressed: canSubmit ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: submitForegroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isSubmitting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: submitForegroundColor,
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
                      onPressed: canSubmit ? _submit : null,
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

    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      setState(() {
        _result = PremiumStripeCheckoutSubmitResult(
          status: PremiumStripeCheckoutActionStatus.failed,
          message: AppLocalizations.of(context).globalOfflineBannerMessage,
        );
      });
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
