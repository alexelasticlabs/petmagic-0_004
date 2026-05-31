import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/shared/payments/stripe_paymentsheet_coordinator.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

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
    final text = AppLocalizations.of(context);
    final state = ref.watch(premiumControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(text.debugStripeSmokeTestTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                text.debugStripeSmokeTestSubtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isLaunching || state.isLoading
                    ? null
                    : _openPaymentSheet,
                child: Text(
                  _isLaunching
                      ? text.debugStripeSmokeTestOpeningAction
                      : text.debugStripeSmokeTestOpenAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPaymentSheet() async {
    final text = AppLocalizations.of(context);
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
      _showMessage(text.debugStripeSmokeTestMethodUnavailable);
      return;
    }

    final stripePlan = state.plans.where((plan) => plan.stripeCheckoutEnabled);
    if (stripePlan.isEmpty) {
      _showMessage(text.debugStripeSmokeTestNoPlans);
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
          _showMessage(text.debugStripeSmokeTestPrepareFailed);
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
        _showMessage(text.debugStripeSmokeTestOpenedSuccess);
      } else {
        _showMessage(
          result.errorMessage ?? text.debugStripeSmokeTestDismissedOrFailed,
        );
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
      _showMessage(
        state.checkoutErrorMessage ?? text.debugStripeSmokeTestVerifyFailed,
      );
    }
  }

  void _showMessage(String message) {
    PetMagicToast.show(
      context,
      message: message,
      tone: PetMagicToastTone.info,
    );
  }
}
