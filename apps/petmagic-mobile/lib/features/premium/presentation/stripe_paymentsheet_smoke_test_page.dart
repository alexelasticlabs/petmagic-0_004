import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/shared/payments/stripe_paymentsheet_coordinator.dart';

class StripePaymentSheetSmokeTestPage extends ConsumerStatefulWidget {
  const StripePaymentSheetSmokeTestPage({super.key});

  static const routePath = '/debug/stripe-paymentsheet';

  @override
  ConsumerState<StripePaymentSheetSmokeTestPage> createState() =>
      _StripePaymentSheetSmokeTestPageState();
}

class _StripePaymentSheetSmokeTestPageState
    extends ConsumerState<StripePaymentSheetSmokeTestPage> {
  bool _isLaunching = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(premiumControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(premiumControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stripe PaymentSheet Smoke Test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Minimal screen for PaymentSheet tap/focus diagnostics.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isLaunching || state.isLoading
                    ? null
                    : _openPaymentSheet,
                child: Text(
                  _isLaunching ? 'Opening...' : 'Open Stripe PaymentSheet',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPaymentSheet() async {
    final controller = ref.read(premiumControllerProvider.notifier);
    var state = ref.read(premiumControllerProvider);

    final stripeMethod = state.paymentMethods.firstWhere(
      (method) =>
          method.provider == PremiumPaymentProvider.stripe && method.isEnabled,
      orElse: () => const PremiumPaymentMethodModel(
        provider: PremiumPaymentProvider.stripe,
        purchaseChannel: 'web',
        platform: '',
        region: '',
        isEnabled: false,
        isSelectedByDefault: false,
        requiresExternalWarning: false,
        requiresStoreDisclosure: false,
        isRecommended: false,
        bonusTokensPercent: 0,
      ),
    );

    if (!stripeMethod.isEnabled) {
      _showMessage('Stripe payment method is not available.');
      return;
    }

    final stripePlan = state.plans.where((plan) => plan.stripeCheckoutEnabled);
    if (stripePlan.isEmpty) {
      _showMessage('No Stripe-enabled premium plans found.');
      return;
    }

    final plan = stripePlan.first;

    controller.selectProvider(PremiumPaymentProvider.stripe);
    controller.selectPlan(plan.planCode);

    setState(() {
      _isLaunching = true;
    });

    try {
      final checkout = await controller.startCheckout();
      if (!mounted || checkout == null || !checkout.usesPaymentSheet) {
        if (mounted) {
          _showMessage('Unable to prepare PaymentSheet checkout.');
        }
        return;
      }

      final result = await StripePaymentSheetCoordinator.present(
        context,
        request: StripePaymentSheetRequest(
          paymentIntentClientSecret: checkout.paymentIntentClientSecret!,
          publishableKey: checkout.publishableKey!,
          customerId: checkout.customerId,
          customerEphemeralKeySecret: checkout.customerEphemeralKeySecret,
        ),
      );

      if (!mounted) {
        return;
      }

      if (result.completed) {
        _showMessage('PaymentSheet opened successfully.');
      } else {
        _showMessage(result.errorMessage ?? 'PaymentSheet was dismissed/failed.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLaunching = false;
        });
      }
    }

    state = ref.read(premiumControllerProvider);
    if (state.checkoutVerificationState == PremiumCheckoutVerificationState.error &&
        mounted) {
      _showMessage(state.checkoutErrorMessage ?? 'Checkout verification failed.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
