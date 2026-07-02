import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';

part 'wallet_stripe_checkout_page_sections.part.dart';
part 'wallet_stripe_checkout_page_summary.part.dart';

enum WalletStripeCheckoutActionStatus { success, cancelled, failed }

class WalletStripeCheckoutSubmitResult {
  const WalletStripeCheckoutSubmitResult({required this.status, this.message});

  final WalletStripeCheckoutActionStatus status;
  final String? message;
}

typedef WalletStripeCheckoutSubmit =
    Future<WalletStripeCheckoutSubmitResult> Function();

class WalletStripeCheckoutPage extends ConsumerStatefulWidget {
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
  ConsumerState<WalletStripeCheckoutPage> createState() =>
      _WalletStripeCheckoutPageState();
}

class _WalletStripeCheckoutPageState
    extends ConsumerState<WalletStripeCheckoutPage> {
  bool _isSubmitting = false;
  WalletStripeCheckoutSubmitResult? _result;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final price = NumberFormat.simpleCurrency(
      name: widget.pack.currencyCode,
    ).format(widget.pack.priceAmount);
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final canSubmit = !_isSubmitting && hasInternet;

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
                onPressed: canSubmit ? _submit : null,
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
        _result = WalletStripeCheckoutSubmitResult(
          status: WalletStripeCheckoutActionStatus.failed,
          message: AppLocalizations.of(context).globalOfflineBannerMessage,
        );
      });
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
